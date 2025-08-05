MASSTREE_DATASET := "datasets/lognormal-190M.bin"

[private]
test-masstree-warning:
  #!/usr/bin/env bash
  mkdir -p temp
  if [[ ! -f temp/.masstree-warning ]]; then
    echo -e "======== Warning masstree ========"
    echo -e "\n\033[31m* Please ensure you have >= 48 cores *\033[0m\n"
    read -p "Press enter to continue"
    touch temp/.masstree-warning
  fi

[private]
test-masstree-prepare: test-masstree-warning
  #!/usr/bin/env bash
  set -e
  echo -e "======== Preparing masstree ========"
  mkdir -p datasets results temp
  if [[ ! -f {{MASSTREE_DATASET}} ]]; then
    echo -e "Downloading datasets from internet"
    echo -e "File size around 1.5G, it will take some time..."
    if [[ ! -f temp/.unattended ]]; then
      read -p "Press enter to continue"
    else
      echo -e "unattended testing"
    fi
    bash ./ae/masstree/download-workload.sh
    mv lognormal-190M.bin {{MASSTREE_DATASET}}
  fi


test-masstree: build test-masstree-prepare
  just test-masstree-memory
  just test-masstree-throughput
  just test-masstree-validation_latency_cdf

test-masstree-throughput: build test-masstree-prepare
  #!/usr/bin/env bash
  set -e
  echo -e '\n======== test-masstree-throughput ========'
  trap 'echo -e "\n\nKilling all background jobs..."; pkill -9 -P $$ &>/dev/null; exit 130' SIGINT SIGTERM

  OUT="results/masstree-throughput-report.txt"; cat /dev/null > $OUT;
  function worker() {
    local NAME=$1;
    local CMDS=("${@:2}")
    echo "${NAME} running" | tee -a $OUT
    rm -rf client.log
    {
      for CMD in "${CMDS[@]}"
      do
          sleep 2; echo "Executing ${CMD}"
          ( ${CMD} ) &
      done; wait;
    } 2>&1 | tee temp/run-masstree-throughput-${NAME}.log
    mv client.log temp/masstree-throughput-client-${NAME}.log
  }
  worker "vanilla" \
    "taskset -c 1-5 ./build/ae/masstree/masstree_vanilla {{MASSTREE_DATASET}}" \
    ;
  worker "orthrus" \
    "taskset -c 1-10 ./build/ae/masstree/masstree_orthrus {{MASSTREE_DATASET}}" \
    ;
  worker "rbv" \
    "taskset -c 1-5,25-29 ./build/ae/masstree/masstree_rbv {{MASSTREE_DATASET}}" \
    ;
  just analyze-masstree-throughput

analyze-masstree-throughput:
  #!/usr/bin/env bash
  python scripts/masstree/parse-throughput.py \
    --input-raw temp/masstree-throughput-client-vanilla.log \
    --input-scee temp/masstree-throughput-client-orthrus.log \
    --input-rbv temp/masstree-throughput-client-rbv.log \
    -o results/masstree-throughput-report.txt

test-masstree-memory: build test-masstree-prepare
  #!/usr/bin/env bash
  set -e
  echo -e '\n======== test-masstree-memory ========'
  trap 'echo -e "\n\nKilling all background jobs..."; pkill -9 -P $$ &>/dev/null; exit 130' SIGINT SIGTERM
  function worker() {
    local NAME=$1;
    local CMDS=("${@:2}")
    echo "${NAME} running"
    {
      for CMD in "${CMDS[@]}"
      do
          sleep 1; echo "Executing ${CMD}"
          ( ${CMD} ) &
      done; wait; sleep 1;
    } 2>&1 | tee temp/run-masstree-mem-${NAME}.log
  }
  worker "vanilla" \
    "taskset -c 1-5 ./build/ae/masstree/masstree_vanilla_mem {{MASSTREE_DATASET}}" \
    ;
  worker "orthrus" \
    "taskset -c 1-10 ./build/ae/masstree/masstree_orthrus_mem {{MASSTREE_DATASET}}" \
    ;
  worker "rbv" \
    "taskset -c 1-5,25-29 ./build/ae/masstree/masstree_rbv_mem {{MASSTREE_DATASET}}" \
    ;
  mv masstree-memory_status-*.log temp/
  just analyze-masstree-memory

analyze-masstree-memory:
  #!/usr/bin/env bash
  set -e
  {
    echo -e "\n=== Memory Stats ===";
    python scripts/memory.py  \
      --input-raw temp/masstree-memory_status-vanilla.log \
      --input-scee temp/masstree-memory_status-orthrus.log \
      --input-rbv temp/masstree-memory_status-rbv.log
  } 2>&1 | tee results/masstree-mem-report.txt

test-masstree-validation_latency_cdf: build test-masstree-prepare
  #!/usr/bin/env bash
  set -e
  echo -e '\n=== test-masstree-validation_latency_cdf ==='
  trap 'echo -e "\n\nKilling all background jobs..."; pkill -9 -P $$ &>/dev/null; exit 130' SIGINT SIGTERM
  function worker() {
    local NAME=$1;
    local CMDS=("${@:2}")
    echo "${NAME} running" | tee -a $OUT
    {
      for CMD in "${CMDS[@]}"
      do
          sleep 1; echo "Executing ${CMD}"
          ( ${CMD} ) &
      done; wait; sleep 1;
      mv validation-latency-scee.cdf results/masstree-validation_latency-${NAME}.cdf
    } 2>&1 | tee temp/run-masstree-validation_latency_cdf-${NAME}.log
  }
  worker "orthrus" \
    "taskset -c 1-4 ./build/ae/masstree/masstree_orthrus_profile {{MASSTREE_DATASET}}" \
    ;
  worker "rbv" \
    "taskset -c 1-4 ./build/ae/masstree/masstree_rbv_profile {{MASSTREE_DATASET}}" \
    ;
