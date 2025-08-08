## Individual Experiment: Masstree

### Throughput (Figure 6)

**Commands:**  `just test-masstree-throughtput`

**Execution Time:** ~6 min

**Test Results:** `results/masstree-throughtput-report.txt[.json]`

**Example:**

```text
vanilla running
throughput: 448975
orthrus running
throughput: 447499
rbv running
throughput: 120955
```

--------------

### Validation Latency CDF (Figure 8)

**Commands:**  `just test-masstree-validation_latency_cdf`

**Execution Time:** ~6 min

**Test Results:** `results/masstree-validation_latency-{vanilla|orthrus|rbv}.cdf`

**Example:** N/A

--------------

## Memory (in paper)

**Commands:**  `just test-masstree-memory`

**Execution Time:** ~6 min

**Test Results:** `results/masstree-memory_status-report.txt`

**Example:**

```
=== Memory Stats ===
Processing raw
max mem run :  26867176
Processing scee
max mem run :  28669680
Processing rbv
max mem run :  60019172
----------  results(peak)  ----------
ratio (Orthrus vs Vanilla):  1.0670894477335466
ratio (RBV vs Vanilla):      2.233921868081707
----------  results(avg)  ----------
ratio (Orthrus vs Vanilla):  1.0684928163156082
ratio (RBV vs Vanilla):      1.9899983160812147
```
