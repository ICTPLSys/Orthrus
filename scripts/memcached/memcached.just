[private]
test-memcached-warning:
  #!/usr/bin/env bash
  mkdir -p temp
  if [[ ! -f temp/.memcached-warning ]]; then
    echo -e "======== Warning memcached ========"
    echo -e "\n\033[31m* Please ensure you have >= 48 cores *\033[0m\n"
    read -p "Press enter to continue"
    touch temp/.memcached-warning
  fi

[private]
test-memcached-prepare: test-memcached-warning
  #!/usr/bin/env bash
  set -e
  echo -e "======== Preparing memcached ========"
  mkdir -p datasets results temp

test-memcached: build test-memcached-prepare
  just test-memcached-memory
  just test-memcached-throughput
  just test-memcached-latency_vs_pXX
  just test-memcached-validation_latency_cdf

test-memcached-throughput: build test-memcached-prepare
  #!/usr/bin/env bash
  set -e
  echo -e '\n======== test-memcached-throughput ========'
  trap 'echo -e "\n\nKilling all background jobs..."; pkill -9 -P $$ &>/dev/null; exit 130' SIGINT SIGTERM

  OUT="results/memcached-throughput-report.txt"; cat /dev/null > $OUT;
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
    } 2>&1 | tee temp/run-memcached-throughput-${NAME}.log
    mv client.log temp/memcached-throughput-client-${NAME}.log
  }
  PORT=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
  worker "vanilla" \
    "taskset -c 1-4 ./build/ae/memcached/memcached_vanilla ${PORT}" \
    "taskset -c 28-47 ./build/ae/memcached/memcached_client localhost ${PORT}" \
    ;
  PORT=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
  worker "orthrus" \
    "taskset -c 1-8 ./build/ae/memcached/memcached_orthrus ${PORT}" \
    "taskset -c 28-47 ./build/ae/memcached/memcached_client localhost ${PORT}" \
    ;
  PORT=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
  PORT1=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
  worker "rbv" \
    "taskset -c 24-27 ./build/ae/memcached/memcached_rbv_replica ${PORT1}" \
    "taskset -c 1-4 ./build/ae/memcached/memcached_rbv_primary ${PORT} 3 ${PORT1}" \
    "taskset -c 28-47 ./build/ae/memcached/memcached_client localhost ${PORT}" \
    ;

analyze-memcached-throughput:
  #!/usr/bin/env bash
  python scripts/memcached/parse-throughput.py \
    --input-raw temp/memcached-throughput-client-vanilla.log \
    --input-scee temp/memcached-throughput-client-orthrus.log \
    --input-rbv temp/memcached-throughput-client-rbv.log \
    -o results/memcached-throughput-report.txt

test-memcached-memory: build test-memcached-prepare
  #!/usr/bin/env bash
  set -e
  echo -e '\n======== test-memcached-memory ========'
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
    } 2>&1 | tee temp/run-memcached-mem-${NAME}.log
  }
  PORT=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
  worker "vanilla" \
    "taskset -c 1-4 ./build/ae/memcached/memcached_vanilla_mem ${PORT}" \
    "taskset -c 28-47 ./build/ae/memcached/memcached_client localhost ${PORT}" \
    ;
  PORT=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
  worker "orthrus" \
    "taskset -c 1-8 ./build/ae/memcached/memcached_orthrus_mem ${PORT}" \
    "taskset -c 28-47 ./build/ae/memcached/memcached_client localhost ${PORT}" \
    ;
  PORT=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
  PORT1=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
  worker "rbv" \
    "taskset -c 24-27 ./build/ae/memcached/memcached_rbv_replica_mem ${PORT1}" \
    "taskset -c 1-4 ./build/ae/memcached/memcached_rbv_primary_mem ${PORT} 3 ${PORT1}" \
    "taskset -c 28-47 ./build/ae/memcached/memcached_client localhost ${PORT}" \
    ;
  mv memcached-memory_status-*.log temp/
  just analyze-memcached-memory

analyze-memcached-memory:
  #!/usr/bin/env bash
  set -e
  {
    echo -e "\n=== Memory Stats ===";
    python scripts/memory.py  \
      --input-raw temp/memcached-memory_status-vanilla.log \
      --input-scee temp/memcached-memory_status-orthrus.log \
      --input-rbv temp/memcached-memory_status-rbv-primary.log \
      --input-rbv temp/memcached-memory_status-rbv-replica.log
  } 2>&1 | tee results/memcached-mem-report.txt

test-memcached-latency_vs_pXX: build test-memcached-prepare
  #!/usr/bin/env bash
  set -e
  echo -e "\n======== test-memcached-latency_pXX_all ========"
  trap 'echo -e "\n\nKilling all background jobs..."; pkill -9 -P $$ &>/dev/null; exit 130' SIGINT SIGTERM
  THROUGHPUT="50000 100000";
  {
    NAME="vanilla";
    echo "${NAME} running"
    {
      rm -rf client.log
      for i in $THROUGHPUT; do
        echo -e "\n====>  $NAME @ $i  <===="
        PORT=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
        taskset -c 1-4 ./build/ae/memcached/memcached_vanilla ${PORT} &
        sleep 1;
        taskset -c 28-47 ./build/ae/memcached/memcached_client localhost ${PORT} client.log 3 32 24 19 ${i} &
        wait; sleep 1;
      done
      mv client.log temp/run-memcached-latency_vs_pXX-vanilla.log
    }
  }
  {
    NAME="orthrus";
    echo "${NAME} running"
    {
      rm -rf client.log
      for i in $THROUGHPUT; do
        echo -e "\n====>  $NAME @ $i  <===="
        PORT=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
        taskset -c 1-8 ./build/ae/memcached/memcached_orthrus ${PORT} &
        sleep 1;
        taskset -c 28-47 ./build/ae/memcached/memcached_client localhost ${PORT} client.log 3 32 24 19 ${i} &
        wait; sleep 1;
      done
      mv client.log temp/run-memcached-latency_vs_pXX-orthrus.log
    }
  }
  {
    NAME="rbv";
    echo "${NAME} running"
    {
      rm -rf client.log
      for i in $THROUGHPUT; do
        echo -e "\n====>  $NAME @ $i  <===="
        PORT=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
        PORT1=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
        taskset -c 24-27 ./build/ae/memcached/memcached_rbv_replica ${PORT1} &
        sleep 1;
        taskset -c 1-4 ./build/ae/memcached/memcached_rbv_primary ${PORT} 3 ${PORT1} &
        sleep 1;
        taskset -c 28-47 ./build/ae/memcached/memcached_client localhost ${PORT} client.log 3 32 24 19 ${i} &
        wait; sleep 1;
      done
      mv client.log temp/run-memcached-latency_vs_pXX-rbv.log
    }
  }
  just analyze-memcached-latency_vs_pXX

analyze-memcached-latency_vs_pXX:
  #!/usr/bin/env bash
  for tgt in vanilla orthrus rbv
  do
    python scripts/memcached/parse-latency_vs_pXX.py \
      -i temp/run-memcached-latency_vs_pXX-${tgt}.log \
      -o results/memcached-latency_vs_pXX-${tgt}.json
  done

test-memcached-validation_latency_cdf: build test-memcached-prepare
  #!/usr/bin/env bash
  set -e
  echo -e '\n=== test-memcached-validation_latency_cdf ==='
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
      mv validation-latency-scee.cdf results/memcached-validation_latency-${NAME}.cdf
    } 2>&1 | tee temp/run-memcached-validation_latency_cdf-${NAME}.log
  }
  PORT=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
  worker "orthrus" \
    "taskset -c 1-8 ./build/ae/memcached/memcached_orthrus_profile ${PORT}" \
    "taskset -c 28-47 ./build/ae/memcached/memcached_client localhost ${PORT}" \
    ;
  sleep 90;
  PORT=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
  PORT1=$(shuf -i 20000-30000 -n 1); echo "Alloc New Port: ${PORT}";
  worker "rbv" \
    "taskset -c 1-16 ./build/ae/memcached/memcached_rbv_replica_profile ${PORT1}" \
    "taskset -c 25-40 ./build/ae/memcached/memcached_rbv_primary ${PORT} 3 ${PORT1}" \
    "taskset -c 28-47 ./build/ae/memcached/memcached_client localhost ${PORT}" \
    ;
