[private]
test-lsmtree-warning:
  #!/usr/bin/env bash
  source env.sh
  mkdir -p temp
  if [[ ! -f temp/.lsmtree-warning ]]; then
    echo -e "======== Warning lsmtree ========"
    echo -e "\n\033[31m* Please ensure you have >= 32 cores *\033[0m\n"
    read -p "Press enter to continue"
    touch temp/.lsmtree-warning
  fi

[private]
test-lsmtree-prepare: test-lsmtree-warning
  #!/usr/bin/env bash
  source env.sh
  echo -e "======== Preparing lsmtree ========"
  mkdir -p results temp

test-lsmtree:
  just test-lsmtree-memory
  just test-lsmtree-throughput
  just test-lsmtree-validation_latency_cdf
  just test-lsmtree-latency_vs_pXX

test-lsmtree-throughput throughput="50000000": build test-lsmtree-prepare
  #!/usr/bin/env bash
  source env.sh
  set -e
  echo -e "\n======== test-lsmtree-throughput ========"
  trap 'echo -e "\n\nKilling all background jobs..."; pkill -9 -P $$ &>/dev/null; exit 130' SIGINT SIGTERM
  OUT="results/lsmtree-throughput-report.txt"; cat /dev/null > $OUT;
  function worker() {
    local NAME=$1;
    echo "${NAME} running" | tee -a $OUT
    taskset -c 1-10 ./build/ae/lsmtree/throughput/lsmtree_socket_throughput_$NAME \
      >/dev/null 2>&1 &
    sleep 1
    ./build/ae/lsmtree/throughput/lsmtree_socket_throughput_client --total-ops={{throughput}} \
      2>&1 | tee temp/run-lsmtree-throughput-${NAME}.log
    wait
    cat temp/run-lsmtree-throughput-${NAME}.log | grep "execution time" >> $OUT
  }
  worker vanilla
  worker orthrus
  worker rbv
  just analyze-lsmtree-throughput

analyze-lsmtree-throughput:
  #!/usr/bin/env bash
  source env.sh
  python3 scripts/lsmtree/parse-throughput.py \
    --input results/lsmtree-throughput-report.txt \
    --output results/lsmtree-throughput-report.txt.json

test-lsmtree-memory throughput="50000000": build test-lsmtree-prepare
  #!/usr/bin/env bash
  source env.sh
  set -e
  echo -e "\n======== test-lsmtree-memory ========"
  trap 'echo -e "\n\nKilling all background jobs..."; pkill -9 -P $$ &>/dev/null; exit 130' SIGINT SIGTERM
  function worker() {
    NAME=$1; echo =============== $NAME =============
    taskset -c 1-10 ./build/ae/lsmtree/throughput/lsmtree_socket_profile_mem_$NAME &
    sleep 1
    ./build/ae/lsmtree/throughput/lsmtree_socket_throughput_client --total-ops={{throughput}} &
    wait; sleep 1
  }
  worker vanilla
  worker orthrus
  worker rbv
  mv lsmtree-memory_status-*.log temp/
  just analyze-lsmtree-memory

analyze-lsmtree-memory:
  #!/usr/bin/env bash
  source env.sh
  set -e
  {
    echo -e "\n======== LSMTree Memory Status ========"
    python3 scripts/memory.py  \
      --input-raw temp/lsmtree-memory_status-vanilla.log \
      --input-scee temp/lsmtree-memory_status-orthrus.log \
      --input-rbv temp/lsmtree-memory_status-rbv.log;
  } 2>&1 | tee results/lsmtree-mem-report.txt

test-lsmtree-validation_latency_cdf throughput="50000000": build test-lsmtree-prepare
  #!/usr/bin/env bash
  source env.sh
  set -e
  echo -e "\n======== test-lsmtree-validation_latency_cdf ========"
  trap 'echo -e "\n\nKilling all background jobs..."; pkill -9 -P $$ &>/dev/null; exit 130' SIGINT SIGTERM
  function worker() {
    NAME=$1; echo =============== $NAME =============
    taskset -c 1-10 ./build/ae/lsmtree/throughput/lsmtree_socket_val_latency_cdf_$NAME &
    sleep 1
    ./build/ae/lsmtree/throughput/lsmtree_socket_throughput_client --total-ops={{throughput}} &
    wait && sleep 1
  }
  worker orthrus
  worker rbv
  mv lsmtree-validation_latency-*.cdf results/

test-lsmtree-latency_vs_pXX: build test-lsmtree-prepare
  #!/usr/bin/env bash
  source env.sh
  set -e
  echo -e "\n======== test-lsmtree-latency_vs_pXX ========"
  trap 'echo -e "\n\nKilling all background jobs..."; pkill -9 -P $$ &>/dev/null; exit 130' SIGINT SIGTERM
  function worker() {
    local NAME=$1
    local LOG="temp/run-lsmtree-latency_vs_pXX_${NAME}.log"; echo > $LOG
    local THROUGHPUT="100 1000 5000 10000 20000 30000 50000 70000 100000 120000 140000 160000 200000 220000 240000 260000 280000 300000 310000 320000 330000";
    for i in $THROUGHPUT; do
      echo -e "\n====>  $NAME @ $i  <===="
      echo $i >> log
      taskset -c 1-10 ./build/ae/lsmtree/latency/lsmtree_socket_latency_pXX_$NAME \
        >/dev/null 2>&1 &
      sleep 1
      ./build/ae/lsmtree/latency/lsmtree_socket_latency_pXX_client \
        --throughput $i 2>&1 | tee -a $LOG &
      wait; sleep 2
      echo -e "\n\n" >> $LOG
    done
  }
  worker vanilla
  worker orthrus
  worker rbv
  just analyze-lsmtree-latency_vs_pXX

analyze-lsmtree-latency_vs_pXX:
  #!/usr/bin/env bash
  source env.sh
  for tgt in vanilla orthrus rbv
  do
    python3 scripts/lsmtree/latency_vs_pXX_parser.py \
      -i temp/run-lsmtree-latency_vs_pXX_${tgt}.log \
      -o results/lsmtree-latency_vs_pXX-${tgt}.json
  done
