PHOENIX_DATASET := "datasets/news.2024.en.shuffled.deduped"

[private]
test-phoenix-warning:
  #!/usr/bin/env bash
  mkdir -p temp
  if [[ ! -f temp/.phoenix-warning ]]; then
    echo -e "======== Warning phoenix ========"
    echo -e "\n\033[31m* Please ensure there exists >= 41 cores *\033[0m\n"
    read -p "Press enter to continue"
    touch temp/.phoenix-warning
  fi

[private]
test-phoenix-prepare: test-phoenix-warning
  #!/usr/bin/env bash
  set -e
  echo -e "======== Preparing phoenix ========"
  mkdir -p datasets results temp
  if [[ ! -f datasets/news.2024.en.shuffled.deduped ]]; then
    echo -e "Downloading datasets from internet"
    echo -e "File size around 2GiB, it will take some time..."
    read -p "Press enter to continue"
    wget https://data.statmt.org/news-crawl/en/news.2024.en.shuffled.deduped.gz \
      -O datasets/news.2024.en.shuffled.deduped.gz
    gzip -d datasets/news.2024.en.shuffled.deduped.gz
  fi

test-phoenix: build test-phoenix-prepare
  just test-phoenix-memory
  just test-phoenix-throughput
  just test-phoenix-validation_latency_cdf

test-phoenix-throughput: build test-phoenix-prepare
  #!/usr/bin/env bash
  set -e
  echo -e '\n======== test-phoenix-throughput ========'
  trap 'echo -e "\n\nKilling all background jobs..."; pkill -9 -P $$ &>/dev/null; exit 130' SIGINT SIGTERM

  OUT="results/phoenix-throughput-report.txt"; cat /dev/null > $OUT;
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
    } 2>&1 | tee temp/run-phoenix-throughput-${NAME}.log
    cat temp/run-phoenix-throughput-${NAME}.log | grep "Time taken:" >> $OUT
  }
  worker "vanilla" \
    "taskset -c 1-16 ./build/ae/phoenix/phoenix_vanilla" \
    "./build/ae/phoenix/phoenix_loader -i {{PHOENIX_DATASET}}" \
    ;
  worker "orthrus" \
    "taskset -c 1-34 ./build/ae/phoenix/phoenix_orthrus" \
    "./build/ae/phoenix/phoenix_loader -i {{PHOENIX_DATASET}}" \
    ;
  worker "rbv" \
    "taskset -c 1-16 ./build/ae/phoenix/phoenix_rbv_replica" \
    "taskset -c 25-40 ./build/ae/phoenix/phoenix_rbv_primary" \
    "./build/ae/phoenix/phoenix_loader -i {{PHOENIX_DATASET}}" \
    ;
  just analyze-phoenix-throughput

analyze-phoenix-throughput:
  #!/usr/bin/env bash
  python scripts/phoenix/parse-throughput.py \
    --input results/phoenix-throughput-report.txt \
    --output results/phoenix-throughput-report.txt.json

test-phoenix-memory: build test-phoenix-prepare
  #!/usr/bin/env bash
  set -e
  echo -e '\n======== test-phoenix-memory ========'
  trap 'echo -e "\n\nKilling all background jobs..."; pkill -9 -P $$ &>/dev/null; exit 130' SIGINT SIGTERM
  export MIMALLOC_VERBOSE=1 MIMALLOC_SHOW_ERRORS=1 MIMALLOC_PURGE_DELAY=0

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
    } 2>&1 | tee temp/run-phoenix-mem-${NAME}.log
  }
  worker "vanilla" \
    "taskset -c 1-16 ./build/ae/phoenix/phoenix_vanilla_mem" \
    "./build/ae/phoenix/phoenix_loader -i {{PHOENIX_DATASET}}" \
    ;
  worker "orthrus" \
    "taskset -c 1-34 ./build/ae/phoenix/phoenix_orthrus_mem" \
    "./build/ae/phoenix/phoenix_loader -i {{PHOENIX_DATASET}}" \
    ;
  worker "rbv" \
    "taskset -c 1-16 ./build/ae/phoenix/phoenix_rbv_replica_mem" \
    "taskset -c 25-40 ./build/ae/phoenix/phoenix_rbv_primary_mem" \
    "./build/ae/phoenix/phoenix_loader -i {{PHOENIX_DATASET}}" \
    ;
  mv phoenix-memory_status-*.log temp/
  just analyze-phoenix-memory

analyze-phoenix-memory:
  #!/usr/bin/env bash
  set -e
  {
    echo -e "\n=== Memory Stats ===";
    python3 scripts/memory.py  \
      --input-raw temp/phoenix-memory_status-vanilla.log \
      --input-scee temp/phoenix-memory_status-orthrus.log \
      --input-rbv temp/phoenix-memory_status-rbv-primary.log \
      --input-rbv temp/phoenix-memory_status-rbv-replica.log
  } 2>&1 | tee results/phoenix-mem-report.txt

test-phoenix-validation_latency_cdf: build test-phoenix-prepare
  #!/usr/bin/env bash
  set -e
  echo -e '\n=== test-phoenix-validation_latency_cdf ==='
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
      mv validation-latency-scee.cdf results/phoenix-validation_latency-${NAME}.cdf
    } 2>&1 | tee temp/run-phoenix-validation_latency_cdf-${NAME}.log
  }
  worker "orthrus" \
    "taskset -c 1-34 ./build/ae/phoenix/phoenix_orthrus_profile" \
    "./build/ae/phoenix/phoenix_loader -i {{PHOENIX_DATASET}}" \
    ;
  worker "rbv" \
    "taskset -c 1-16 ./build/ae/phoenix/phoenix_rbv_replica_profile" \
    "taskset -c 25-40 ./build/ae/phoenix/phoenix_rbv_primary" \
    "./build/ae/phoenix/phoenix_loader -i {{PHOENIX_DATASET}}" \
    ;
