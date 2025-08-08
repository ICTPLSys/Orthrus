## Individual Experiment: LSMTree

### Throughput (Figure 6)

**Commands:**  `just test-lsmtree-throughtput`

**Execution Time:** ~23 min

**Test Results:** `results/lsmtree-throughtput-report.txt[.json]`

**Example:**

```
vanilla running
execution time: 209518776, throughput: 257604
orthrus running
execution time: 237393243, throughput: 235082
rbv running
execution time: 319511258, throughput: 170664
```

--------------

### Throughput vs  Latency(p95) (Figure 7)

**Commands:** `just test-lsmtree-latency_vs_pXX`

**Execution Time:**  ~36 min

**Test Results:** `results/lsmtree-latency_vs_pXX_{vanilla|orthrus|rbv}.json`

**Example:** N/A

--------------

### Validation Latency CDF (Figure 8)

**Commands:**  `just test-lsmtree-validation_latency_cdf`

**Execution Time:** ~23 min

**Test Results:** `results/lsmtree-validation_latency-{vanilla|orthrus|rbv}.cdf`

**Example:** N/A

--------------

## Memory (Discussed in paper)

**Commands:**  `just test-lsmtree-memory`

**Execution Time:** ~23 min

**Test Results:** `results/memcached-memory_status-report.txt`

**Example:** 

```
======== LSMTree Memory Status ========
Processing raw
max mem run :  450136
Processing scee
max mem run :  575688
Processing rbv
max mem run :  895412
----------  results(peak)  ----------
ratio (scee vs raw):  1.278920148577319
ratio (rbv vs raw):   1.9892032630138448
----------  results(avg)  ----------
ratio (scee vs raw):  1.296086573008326
ratio (rbv vs raw):   2.1453626212861168
```
