#include <sys/mman.h>

#include <boost/sort/parallel_stable_sort/parallel_stable_sort.hpp>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <mutex>
#include <sstream>
#include <vector>

#include "context.hpp"
#include "control.hpp"
#include "ctltypes.hpp"
#include "custom_stl.hpp"
#include "log.hpp"
#include "namespace.hpp"
#include "profile.hpp"
#include "ptr.hpp"
#include "scee.hpp"
#include "thread.hpp"
#include "utils.hpp"

#ifdef PROFILE_MEM
#include "profile-mem.hpp"
#endif

namespace rbv {

constexpr uint64_t FNV_prime = 1099511628211ULL;
constexpr uint64_t FNV_offset_basis = 14695981039346656037ULL;

inline uint64_t fnv1a_hash_bytes(const void *data, size_t len) {
    uint64_t hash = FNV_offset_basis;
    const unsigned char *bytes = static_cast<const unsigned char *>(data);

    for (size_t i = 0; i < len; ++i) {
        hash ^= bytes[i];
        hash *= FNV_prime;
    }
    return hash;
}

constexpr int GRANULARITY = 16;

struct info_t {
    uint64_t hashv;
    uint64_t timestamp;
};

struct hasher_t {
    std::vector<info_t> info;
    uint64_t latest, reference;
    size_t cursor;
    hasher_t() { latest = reference = 0, cursor = 0; }
    std::string serialize() {
        std::stringstream ss;
        ss << info.size() << " " << latest << " ";
        for (auto &i : info) {
            ss << i.hashv << " " << i.timestamp << " ";
        }
        return ss.str();
    }
    void deserialize(const std::string &s) {
        std::stringstream ss(s);
        size_t info_size;
        ss >> info_size >> reference;
        info.resize(info_size);
        for (size_t i = 0; i < info_size; i++) {
            ss >> info[i].hashv >> info[i].timestamp;
        }
        latest = cursor = 0;
    }
    void combine_(uint64_t hashv) {
        latest ^= hashv + 0x9e3779b9 + (latest << 6) + (latest >> 2);
    }
    void combine(uint64_t x) { combine_(fnv1a_hash_bytes(&x, sizeof(x))); }
    void combine(const std::string &s) {
        combine_(fnv1a_hash_bytes(s.data(), s.length()));
    }
    void combine(std::string_view sv) {
        combine_(fnv1a_hash_bytes(sv.data(), sv.length()));
    }
    virtual void checkorder(std::atomic_uint64_t &order);
    virtual std::string finalize();
    virtual bool is_primary();
    void reset() { info.clear(), reference = latest = 0, cursor = 0; }
};

struct hasher_replica_t : hasher_t {
    void checkorder(std::atomic_uint64_t &order) {
        assert(cursor < info.size());
        uint64_t timenow = order.load();
        while (timenow != info[cursor].timestamp) {
            assert(timenow <= info[cursor].timestamp);
            order.wait(timenow);
            timenow = order.load();
        }
        assert(info[cursor].hashv == latest);
        latest = 0, order++, cursor++;
        order.notify_all();
    }
    std::string finalize() {
        assert(latest == reference);
        info.clear(), reference = latest = 0, cursor = 0;
        return "";
    }
    bool is_primary() { return false; }
};

struct hasher_primary_t : hasher_t {
    void checkorder(std::atomic_uint64_t &order) {
        uint64_t timestamp = order++;
        info.emplace_back(latest, timestamp);
        latest = 0;
    }
    std::string finalize() {
        std::string s = serialize();
        info.clear(), reference = latest = 0, cursor = 0;
        return s;
    }
    bool is_primary() { return true; }
};

struct ordered_mutex_t {
    pthread_mutex_t mtx;
    std::atomic_uint64_t order;
    void lock(hasher_t *hasher) {
        if (hasher->is_primary()) {
            pthread_mutex_lock(&mtx);
            hasher->checkorder(order);
        } else {
            hasher->checkorder(order);
            pthread_mutex_lock(&mtx);
        }
    }
    void unlock(hasher_t *hasher) {
        if (hasher->is_primary()) {
            hasher->checkorder(order);
            pthread_mutex_unlock(&mtx);
        } else {
            pthread_mutex_unlock(&mtx);
            hasher->checkorder(order);
        }
    }
};

struct lock_guard_t {
    ordered_mutex_t *mtx;
    hasher_t *hasher;
    lock_guard_t(ordered_mutex_t *mtx, hasher_t *hasher)
        : mtx(mtx), hasher(hasher) {
        mtx->lock(hasher);
    }
    ~lock_guard_t() { mtx->unlock(hasher); }
};
}  // namespace rbv

namespace monitor {

// monitor the throughput and latency of events
// log: the file descriptor to output summary
// num_ops: total number of operations for all threads
// n_threads: number of threads executing the ops
// task: task name of the evaluation
// cnts: # of operations executed on each thread
// latency: the latency for each operation by counting with rdtsc()
// report: report on stderr for most recent throughput, with last_scnt and
// last_rdtsc value
struct evaluation {
    static constexpr int max_n_threads = 256;
    evaluation(FILE *log, uint64_t num_ops, int n_threads, std::string task);
    ~evaluation();
    FILE *log;
    uint64_t num_ops;
    int n_threads;
    std::string task;
    struct alignas(64) Cnt {
        uint64_t c;
    };
    std::vector<uint64_t> latency;
    Cnt cnts[max_n_threads];
    std::vector<std::pair<std::chrono::steady_clock::time_point, uint64_t>>
        records;
    std::vector<uint64_t> scnts;
    void report();
};

evaluation::evaluation(FILE *log, uint64_t num_ops, int n_threads,
                       std::string task)
    : log(log), num_ops(num_ops), n_threads(n_threads), task(task) {
    latency.resize(num_ops);
    records.emplace_back(std::chrono::steady_clock::now(), 0);
    for (int i = 0; i < max_n_threads; ++i) cnts[i].c = 0;
}

evaluation::~evaluation() {
    uint64_t n_phases = std::min(num_ops, 8LU);
    uint64_t l = num_ops / n_phases, r = num_ops * (n_phases - 1) / n_phases;
    std::sort(latency.begin() + l, latency.begin() + r);
    uint64_t p90 = nanosecond(0, latency[l + uint64_t((r - l) * .9)]);
    uint64_t p95 = nanosecond(0, latency[l + uint64_t((r - l) * .95)]);
    uint64_t p99 = nanosecond(0, latency[l + uint64_t((r - l) * .99)]);
    uint64_t avg = nanosecond(0, std::accumulate(latency.begin() + l,
                                                 latency.begin() + r, 0ULL)) /
                   (r - l);
    auto period = std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::steady_clock::now() - records[0].first);
    fprintf(stderr, "Finished task %s. Time: %ld us; Throughput: %f/s.\n",
            task.c_str(), period.count(), num_ops * 1e6 / period.count());
    l = ((uint64_t)records.size() - 1) / n_phases,
    r = ((uint64_t)records.size() - 1) * (n_phases - 1) / n_phases;
    period = std::chrono::duration_cast<std::chrono::microseconds>(
        records[r + 1].first - records[l].first);
    // NOTE: Use put as the estimated throughput
    uint64_t put = (records[r + 1].second - records[l].second) * 1000000LL /
                   period.count();
    fprintf(stderr, "Estimated (operation) throughput: %lu/s\n", put);
    fprintf(log, "%s put %lu avg %lu p90 %lu p95 %lu p99 %lu\n", task.c_str(),
            put, avg, p90, p95, p99);
}

void evaluation::report() {
    static std::mutex lock;
    lock.lock();
    uint64_t cnt = 0;
    for (int i = 0; i < n_threads; ++i) cnt += cnts[i].c;
    if (cnt > records.back().second + 16384) {  // minimum print interval
        auto now = std::chrono::steady_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
                            now - records.back().first)
                            .count();
        fprintf(stderr, "Instant throughput: %f/s\n",
                (cnt - records.back().second) * 1e6 / duration);
    }
    records.emplace_back(std::chrono::steady_clock::now(), cnt);
    lock.unlock();
}
}  // namespace monitor

namespace raw {
#include "closure.hpp"
}  // namespace raw
namespace app {
#include "closure.hpp"
}  // namespace app
namespace validator {
#include "closure.hpp"
}  // namespace validator

using namespace raw;

Value uint64_to_value(uint64_t val) {
    constexpr uint64_t primes[] = {
        2,   3,   5,   7,   11,  13,  17,  19,  23,  29,  31,  37,  41,  43,
        47,  53,  59,  61,  67,  71,  73,  79,  83,  89,  97,  101, 103, 107,
        109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181,
        191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263,
        269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349,
        353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419, 421, 431, 433,
        439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499};
    assert(VAL_LEN <= sizeof(primes) / sizeof(primes[0]));
    Value v;
    for (size_t i = 0; i < VAL_LEN; ++i) {
        v.ch[i] = 'a' + (val % primes[i]) % 26;
    }
    return v;
}

void inline log(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    time_t t = time(nullptr);
    char tmp[64] = {0};
    strftime(tmp, sizeof(tmp), "%Y-%m-%d %H:%M:%S", localtime(&t));
    printf("%s ", tmp);
    vprintf(fmt, args);
    va_end(args);
    printf("\n");
}

inline void multi_thread_memcpy(void *dst, const void *src, size_t size,
                                uint64_t n_threads) {
    std::vector<std::thread> threads;
    size_t stride = (size + n_threads - 1) / n_threads;
    for (uint64_t t = 0; t < n_threads; ++t) {
        size_t offset = t * stride;
        void *tdst = (char *)dst + offset;
        void *tsrc = (char *)src + offset;
        size_t tsize = std::min(stride, size - offset);
        threads.emplace_back(
            [tdst, tsrc, stride]() { memcpy(tdst, tsrc, stride); });
    }
    for (auto &t : threads) {
        t.join();
    }
}

template <typename F>
inline void parallel_for(size_t n_threads, size_t n, F &&f) {
    std::vector<std::thread> threads;
    for (uint64_t t = 0; t < n_threads; ++t) {
        threads.emplace_back([t, n_threads, n, &f]() {
            size_t stride = (n + n_threads - 1) / n_threads;
            size_t start = t * stride;
            size_t end = std::min(start + stride, n);
            for (size_t i = start; i < end; ++i) {
                f(i);
            }
        });
    }
    for (auto &t : threads) t.join();
}

constexpr uint64_t kLoaderThreads = 24;

template <typename T>
void load_from_binary(T *data, size_t size, const std::string &filename) {
    FILE *fp = fopen(filename.c_str(), "r");
    assert(fp != nullptr);
    fseek(fp, 0L, SEEK_END);
    size_t file_size = ftell(fp);
    fseek(fp, 0L, 0);
    assert(file_size == sizeof(T) * size);

    void *mmap_ptr =
        mmap(nullptr, file_size, PROT_READ, MAP_SHARED, fp->_fileno, 0);
    assert(mmap_ptr != MAP_FAILED);
    multi_thread_memcpy(data, mmap_ptr, sizeof(T) * size, kLoaderThreads);
    fclose(fp);
}

struct KeyGenerator {
    KeyGenerator(std::vector<uint64_t> &keys_to_insert)
        : keys(keys_to_insert), index(0) {}
    uint64_t operator()() {
        int idx = index.fetch_add(1, std::memory_order_relaxed);
        assert((size_t)idx < keys.size() && "Too many inserts");
        return keys[idx];
    }
    std::vector<uint64_t> &keys;
    std::atomic_int index;
};

int main(int argc, char *argv[]) {
    if (argc < 2 || argc > 6) {
        fprintf(stderr,
                "Usage: %s <data_file> [n_threads] "
                "[rps] [record_count] [operation_count]\n",
                argv[0]);
        fprintf(stderr, "data_file: path to the data file\n");
        fprintf(stderr, "n_threads: number of threads to run, default: 4\n");
        fprintf(
            stderr,
            "rps: maximum number of records per second to load, default: 1M\n");
        fprintf(stderr,
                "record_count: number of records to load, default: 190M\n");
        fprintf(stderr,
                "operation_count: number of operations to run, default: 20M\n");
        return 1;
    }

    uint64_t n_threads = argc > 2 ? atoi(argv[2]) : 4;
    uint64_t rps = argc > 3 ? atoi(argv[3]) : 20000000;
    uint64_t record_count = argc > 4 ? atoi(argv[4]) : 190000000;
    uint64_t operation_count = argc > 5 ? atoi(argv[5]) : 20000000;

    fprintf(stderr, "hyperparameter parsed, start loading data\n");

    std::vector<uint64_t> keys(record_count);
    load_from_binary<uint64_t>(keys.data(), keys.size(), argv[1]);
    fprintf(stderr, "keys loaded\n");

    std::mt19937 rng(233333);
    keys.push_back(0);
    boost::sort::parallel_stable_sort(keys.begin(), keys.end(), kLoaderThreads);
    fprintf(stderr, "keys sorted\n");
    std::vector<Value> vals(keys.size());
    parallel_for(kLoaderThreads, keys.size(),
                 [&](size_t i) { vals[i] = uint64_to_value(rng()); });
    fprintf(stderr, "values generated\n");

    uint64_t sizes = keys.size();
    fprintf(stderr, "load completed, %zu K-V pairs\n", sizes - 1);

    scee::ptr_t<Node> *root = build_tree_from_keys(keys, vals);
    scee::ptr_t<Node> *root_rbv = build_tree_from_keys(keys, vals);

    fprintf(stderr, "tree built recursively\n");

    constexpr int p_all = 100, p_insert = 0, p_update = 50, p_read = 0,
                  p_scan = 50;
    constexpr int scan_max = 450, scan_min = 50;
    zipf_table_distribution<> zipf(keys.size(), 0.99);
    uint64_t kmin = ~0ULL, kmax = 0;
    for (uint64_t i = 0; i < keys.size(); ++i) {
        kmin = std::min(kmin, keys[i]);
        kmax = std::max(kmax, keys[i]);
    }
    std::vector<uint64_t> key_in(operation_count), key_out(operation_count),
        cnts(operation_count);
    std::vector<Value> val_out(operation_count);
    std::vector<int> ops(operation_count);
    for (uint64_t i = 0; i < operation_count; ++i) {
        key_in[i] = keys[zipf(rng)];
        key_out[i] = ((rng() << 32) ^ rng()) % (kmax - kmin + 1) + kmin;
        val_out[i] = uint64_to_value(rng());
        ops[i] = rng() % p_all;
        cnts[i] = rng() % (scan_max - scan_min + 1) + scan_min;
    }

    fprintf(stderr, "workload starts\n");

#ifdef PROFILE
    profile::start();
#endif
#ifdef PROFILE_MEM
    profile::mem::init_mem("masstree-memory_status-rbv.log");
    profile::mem::start();
#endif

    uint64_t workload_start = rdtsc();
    FILE *logger = fopen("client.log", "a");
    constexpr uint64_t WorkloadPrints = 20;
    monitor::evaluation eva(logger, operation_count, n_threads,
                            "MassTree-Workload");
    std::atomic_uint64_t finished = 0;
    std::vector<std::thread> threads;
    std::vector<std::thread> RBV_threads;
    std::vector<std::atomic_uint64_t> step(n_threads);
    std::vector<std::atomic_uint64_t> sstep(n_threads);
    std::vector<long long> start_us(operation_count);
    for (uint64_t t = 0; t < n_threads; ++t) {
        threads.emplace_back([&, t, root, rps, operation_count, n_threads]() {
            std::exponential_distribution<double> sampler(rps / n_threads /
                                                          1e9);
            std::mt19937 rng(1235467 + t);
            const uint64_t BNS = 1e6;
            uint64_t t_start = rdtsc();
            double t_dur = 0;
            for (uint64_t i = t; i < operation_count; i += n_threads) {
                while (sstep[t].load() + n_threads * 16 < i)
                    std::this_thread::yield();
                t_dur += sampler(rng);
                uint64_t p = rdtsc(), t_offset = 0;
                uint64_t t_now = nanosecond(t_start, p);
                if (t_now + BNS < t_dur) {
                    my_nsleep(t_dur - t_now - (BNS / 2));
                } else if (t_dur + BNS < t_now) {
                    t_offset = t_now - t_dur - (BNS / 2);
                }
                int op = ops[i];
                start_us[i] = profile::get_us_abs();
                if (op < p_insert) {
                    uint8_t ret = insert(root, key_out[i], val_out[i]);
                    assert(ret == 1);
                } else if (op < p_insert + p_read) {
                    const Value *ret = read(root, key_in[i]);
                    assert(ret != nullptr);
                } else if (op < p_insert + p_read + p_update) {
                    const Value *ret = update(root, key_in[i], val_out[i]);
                    assert(ret != nullptr);
                } else if (op < p_insert + p_read + p_update + p_scan) {
                    uint64_t ret = scan_and_sum(root, key_in[i], cnts[i]);
                    assert(
                        ret !=
                        0x23146789);  // random magic number unlikely to happen
                }
                eva.cnts[t].c++;
                eva.latency[i] = nanosecond(p, rdtsc()) + t_offset;
                step[t] = i;
            }
            finished += 1;
        });
        RBV_threads.emplace_back([&, t, root_rbv, rps, operation_count,
                                  n_threads]() {
            std::exponential_distribution<double> sampler(rps / n_threads /
                                                          1e9);
            std::mt19937 rng(1235467 + t);
            const uint64_t BNS = 1e6;
            uint64_t t_start = rdtsc();
            double t_dur = 0;
            for (uint64_t i = t; i < operation_count; i += n_threads) {
                if (i < step[t].load()) continue;
                int op = ops[i];
                if (op < p_insert) {
                    uint8_t ret = insert(root_rbv, key_out[i], val_out[i]);
                    assert(ret == 1);
                } else if (op < p_insert + p_read) {
                    const Value *ret = read(root_rbv, key_in[i]);
                    assert(ret != nullptr);
                } else if (op < p_insert + p_read + p_update) {
                    const Value *ret = update(root_rbv, key_in[i], val_out[i]);
                    assert(ret != nullptr);
                } else if (op < p_insert + p_read + p_update + p_scan) {
                    uint64_t ret = scan_and_sum(root_rbv, key_in[i], cnts[i]);
                    assert(
                        ret !=
                        0x23146789);  // random magic number unlikely to happen
                }
                if (rand() % 4) {
                    std::swap(key_in[i], key_in[rand() % operation_count]);
                    my_usleep(10);
                    i -= n_threads;
                    continue;
                }  // retry is caused
                sstep[t] = i;
#ifdef PROFILE
                profile::record_validation_latency(profile::get_us_abs() -
                                                   start_us[i]);
                profile::record_validation_cpu_time(0, 1);
#endif
            }
            finished += 1;
        });
    }
    threads.emplace_back([n_threads, &finished, &eva]() {
        while (finished.load(std::memory_order_relaxed) < n_threads) {
            if (!finished.load(std::memory_order_relaxed)) eva.report();
            std::this_thread::sleep_for(std::chrono::milliseconds(1000));
        }
    });
    for (auto &t : threads) t.join();
    for (auto &t : RBV_threads) t.join();
    threads.clear();

#ifdef PROFILE_MEM
    profile::mem::stop();
#endif
#ifdef PROFILE
    profile::stop();
#endif

    uint64_t workload_end = rdtsc();
    uint64_t workload_time = microsecond(workload_start, workload_end);
    fprintf(stderr, "workload finished in %zu us, throughput: %.2f Mops/s\n",
            workload_time, operation_count * 1.0 / workload_time);

    return 0;
}
