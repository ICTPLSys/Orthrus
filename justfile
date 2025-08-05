set dotenv-load := true

common_flags := "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON -G Ninja"
common_flags_debug := common_flags + " -DCMAKE_BUILD_TYPE=Debug"
common_flags_release := common_flags + " -DCMAKE_BUILD_TYPE=Release"

CMAKE := "cmake"

prepare:
  #!/usr/bin/env bash
  echo $PROJ
  git fetch --all
  git pull
  git submodule update --init

config: prepare
  {{CMAKE}} -B build -S . {{common_flags_release}} -DENABLE_LSMTREE=ON

config-debug: prepare
  {{CMAKE}} -B build -S . {{common_flags_debug}} -DENABLE_LSMTREE=ON

build:
  {{CMAKE}} --build build -j

import "scripts/memcached/memcached.just"
import "scripts/phoenix/phoenix.just"
import "scripts/masstree/masstree.just"
import "scripts/lsmtree/lsmtree.just"


test-all: config build
  #!/usr/bin/env bash
  set -e
  echo -e "======== Warning: Run All Tests ========"
  read -p "Press enter to clear previous test results (if exists)"
  rm temp results -rf
  mkdir -p temp results
  echo -e "\n\033[31m* Please ensure you have >= 48 cores *\033[0m\n"
  read -p "Press enter to continue"

  # Disable all warnings
  touch temp/.unattended
  touch temp/.lsmtree-warning
  touch temp/.masstree-warning
  touch temp/.phoenix-warning
  touch temp/.memcached-warning

  just test-masstree
  just test-memcached
  just test-lsmtree
  just test-phoenix

  just generate_all_results


generate_all_results:
  #!/usr/bin/env bash
  mkdir -p results/img

  echo -e "\n\033[31m* Please ensure fault_injection.tar.gz placed in results folder *\033[0m\n"
  read -p "Press enter to continue"

  cd results && tar -xzvf fault_injection.tar.gz && cd ..
  python3 scripts/tail-latency.py
  python3 scripts/validation-latency.py
  python3 scripts/throughput.py
  python3 scripts/detection-rate.py

  mv *.pdf *.png results/img/

  echo "All test results generated."
  echo "You can find test outputs in `results/img` folder:"
  echo "Fig.6:  throughput.{pdf|png}"
  echo "Fig.7:  tail-latency.{pdf|png}"
  echo "Fig.8:  validation-cdf.{pdf|png}"
  echo "Fig.9:  detection-rate.{pdf|png}"
