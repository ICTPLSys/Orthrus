#include <sstream>

#include "context.hpp"
#include "namespace.hpp"

namespace scee {
using namespace NAMESPACE;

/**
 * OCCControl is the optimistic concurrency control structure.
 * LOCK: this node is blocked to writes;
 * INSERT: we are inserting to this node, maximum fanout-1 times;
 * SPLIT: we are splitting this node, maximum 1 time;
 * DELETED: this node have been removed from main tree;
 * INSERTCNT: count the number of times we have inserted.
 */
struct OCCControl {
    enum {
        LOCK = 1ULL,
        INSERT = LOCK << 1,
        SPLIT = INSERT << 1,
        DELETED = SPLIT << 1,
        INSERTCNT = DELETED << 1,
    };
    constexpr static uint64_t WRITING = INSERT | SPLIT;
    std::atomic<uint64_t> ver;
    explicit OCCControl(uint64_t version);
    uint64_t stable_version();
    uint64_t load();
    void lock();
    void unlock();
    void do_insert();
    void done_insert();
    void do_split();
    void done_create();
    void done_split_and_delete();
    static OCCControl *create(uint64_t version);
    void destroy();
};

FORCE_INLINE OCCControl::OCCControl(uint64_t version) : ver(version) {}

FORCE_INLINE void OCCControl::unlock() {
    if (!is_validator()) ver ^= LOCK;
}

FORCE_INLINE void OCCControl::do_insert() {
    if (!is_validator()) ver |= INSERT;
}

FORCE_INLINE void OCCControl::done_insert() {
    if (!is_validator()) {
        ver += INSERTCNT;
        ver ^= INSERT;
    }
}

FORCE_INLINE void OCCControl::do_split() {
    if (!is_validator()) ver |= SPLIT;
}

FORCE_INLINE void OCCControl::done_create() {
    if (!is_validator()) {
        ver += INSERTCNT;
        ver ^= SPLIT;
    }
}

FORCE_INLINE void OCCControl::done_split_and_delete() {
    if (!is_validator()) {
        ver += INSERTCNT;
        ver |= DELETED;
        ver ^= SPLIT;
    }
}

FORCE_INLINE OCCControl *OCCControl::create(uint64_t version) {
    auto *occ = (OCCControl *)alloc_obj(sizeof(OCCControl));
    if (!is_validator()) {
        new (occ) OCCControl(version);
    }
    return occ;
}

FORCE_INLINE void OCCControl::destroy() {
    if (!is_validator()) {
        free_immutable(this);
    }
}

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
        void reset() { info.clear(), reference = latest = 0, cursor = 0; }
    };

    extern thread_local hasher_t *hasher;
    extern thread_local bool is_primary;
    extern uint32_t node_count;
    
    FORCE_INLINE void checkorder(std::atomic_uint64_t &order) {
        if (is_primary) {
            uint64_t timestamp = order++;
            hasher->info.emplace_back(hasher->latest, timestamp);
            hasher->latest = 0;
        } else {
            assert(hasher->cursor < hasher->info.size());
            uint64_t timenow = order.load();
            while (timenow != hasher->info[hasher->cursor].timestamp) {
                assert(timenow <= hasher->info[hasher->cursor].timestamp);
                order.wait(timenow);
                timenow = order.load();
            }
            assert(hasher->info[hasher->cursor].hashv == hasher->latest);
            hasher->latest = 0, order++, hasher->cursor++;
            order.notify_all();
        }
    }
    
    FORCE_INLINE std::string finalize() {
        if (is_primary) {
            std::string s = hasher->serialize();
            hasher->info.clear(), hasher->reference = hasher->latest = 0, hasher->cursor = 0;
            return s;
        } else {
            assert(hasher->latest == hasher->reference);
            hasher->info.clear(), hasher->reference = hasher->latest = 0, hasher->cursor = 0;
            return "";
        }
    }
    
    struct ordered_mutex_t {
        pthread_mutex_t mtx;
        std::atomic_uint64_t order;
        void lock() {
            if (is_primary) {
                pthread_mutex_lock(&mtx);
                checkorder(order);
            } else {
                checkorder(order);
                pthread_mutex_lock(&mtx);
            }
        }
        void unlock() {
            if (is_primary) {
                checkorder(order);
                pthread_mutex_unlock(&mtx);
            } else {
                pthread_mutex_unlock(&mtx);
                checkorder(order);
            }
        }
    };

    extern thread_local ordered_mutex_t *node_mutex;
    
    struct lock_guard_t {
        ordered_mutex_t *mtx;
        lock_guard_t(ordered_mutex_t *mtx)
            : mtx(mtx) {
            mtx->lock();
        }
        ~lock_guard_t() {
            mtx->unlock();
        }
    };
}  // namespace rbv

}  // namespace scee
