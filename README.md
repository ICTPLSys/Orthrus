# Orthrus: Efficient and Timely Detection of Silent User Data Corruption in the Cloud with Resource-Adaptive Computation Validation

## Introduction:

Orthrus is a system for the timely detection of silent user-data corruption (SDC) caused by post-installation CPU errors. Orthrus enables high-coverage protection of user-data in the cloud, with minimal performance impact. Please refer to our SOSP 2025 paper, `Orthrus: Efficient and Timely Detection of Silent User Data Corruption in the Cloud with Resource-Adaptive Computation Validation`, for more details.


## Instructions

This repository contains the research artifact for evaluating the performance of **Orthrus**. For the automated tesing framework of Fault-Injection (SDC errors Injection using LLVM compilers), Please refer to another repo [FaultInjection](https://github.com/ICTPLSys/Orthrus-FaultInjection).

1. The **complete** performance test takes approximately **7 hours** to run. (Refer to Figures 6-9 in the paper).
2. **Error Injection Tests** (Refer to Table 2 in the paper):
      * A **complete** error injection test may take over **30 hours**.
      * We also provide a **partial** error injection test for a fast check, which takes **2-3 hours**. Note that the results in the paper are based on the full test.

## Environment and Dependencies

Refer to the document: [docs/prerequisite.md](docs/prerequisite.md).

## Performance Testing
> This section corresponds to Figures 6-9 in the paper.

The tests are divided based on the target applications: **Memcached**, **Masstree**, **Phoenix**, and **LSMTree**.

### Complete Test

To calculate the detection rate, you first need the fault injection results. Since generating these results is a lengthy process, we've provided a pre-generated copy. Please download the file to `datasets/fault_injection.tar.gz` from the following link: https://1drv.ms/f/c/f66d2e84dd351208/Ekc-nXYZcZlPiK5CrfH7VbwBAqLTHGar_eC6JiwcbajMOg?e=e22l0M

You can run the tests using one of the following commands:

If you have already installed the required environment:

```bash
just test-all
```

Or, using Docker Compose:

```bash
docker-compose run test-all
```

The tests will run automatically, and the performance results will be saved in the `results` folder.

### Individual Tests

For the details of individual tests, please refer to the following documents:
- [docs/experiment - memcached.md](docs/exp-memcached.md)
- [docs/experiment - masstree.md](docs/exp-masstree.md)
- [docs/experiment - phoenix.md](docs/exp-phoenix.md)
- [docs/experiment - lsmtree.md](docs/exp-lsmtree.md)

## Error Coverage Analysis

Please refer to the FaultInjection Repo for more details.
