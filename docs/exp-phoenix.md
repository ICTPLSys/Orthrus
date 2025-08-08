## Individual Experiment: Phoenix

### Throughput (Figure 6)

**Commands:**  `just test-phoenix-throughtput`

**Execution Time:** ~3 min

**Test Results:** `results/phoenix-throughtput-report.txt[.json]`

**Example:**

```
vanilla running
    Time taken: 28757 ms
orthrus running
    Time taken: 29177 ms
rbv running
    Time taken: 46747 ms
```

--------------

### Validation Latency CDF (Figure 8)

**Commands:**  `just test-phoenix-validation_latency_cdf`

**Execution Time:** ~3 min

**Test Results:** `results/phoenix-validation_latency-{vanilla|orthrus|rbv}.cdf`

**Example:** N/A

--------------

## Memory (Discussed in paper)

**Commands:**  `just test-phoenix-memory`

**Execution Time:** ~5 min

**Test Results:** `results/phoenix-memory_status-report.txt`

**Example:** 

```
=== Memory Stats ===
Processing raw
max mem run :  42994864
Processing scee
max mem run :  44591108
Processing rbv
max mem run :  43050520
max mem run :  43078260
----------  results(peak)  ----------
ratio (Orthrus vs Vanilla):  1.037126387933219
ratio (RBV vs Vanilla):      2.0032341537351996
----------  results(avg)  ----------
ratio (Orthrus vs Vanilla):  1.0127006153037241
ratio (RBV vs Vanilla):      1.9334951922224275
```

