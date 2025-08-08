## Individual Experiment: Memcached

### Throughput (Figure 6)

**Commands:**  `just test-memcached-throughtput`

**Execution Time:** ~20 min

**Test Results:** `results/memcached-throughtput-report.txt[.json]`

**Example:**

```text
vanilla running
throughput: 373808.5
orthrus running
throughput: 361216.5
rbv running
throughput: 235036.5
```

--------------

### Throughput vs Latency(p95) (Figure 7)

**Commands:** `just test-memcached-latency_vs_pXX`

**Execution Time:** ~4 hour 30 min

**Test Results:** `results/memcached-latency_vs_pXX_{vanilla|orthrus|rbv}.json`

**Example:** N/A

--------------

### Validation Latency CDF (Figure 8)

**Commands:**  `just test-memcached-validation_latency_cdf`

**Execution Time:** ~20 min

**Test Results:** `results/memcached-validation_latency-{vanilla|orthrus|rbv}.cdf`

**Example:** N/A

--------------

## Memory (Discussed in paper)

**Commands:**  `just test-memcached-memory`

**Execution Time:** ~25 min

**Test Results:** `results/memcached-memory_status-report.txt`

**Example:** 

```
=== Memory Stats ===
Processing raw
max mem run :  17391092
Processing scee
max mem run :  21958432
Processing rbv
max mem run :  17717556
max mem run :  17521548
----------  results(peak)  ----------
ratio (Orthrus vs Vanilla):  1.2626252566543839
ratio (RBV vs Vanilla):      2.026273220796026
----------  results(avg)  ----------
ratio (Orthrus vs Vanilla):  1.2616075431953984
ratio (RBV vs Vanilla):      2.042777587432064
```
