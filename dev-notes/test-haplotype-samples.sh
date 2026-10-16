#!/usr/bin/env bash
# Run in a development container with a C++17 compiler, HTSlib and Boost.
set -euo pipefail
cd "$(dirname "$0")/.."
sample_test_dir=$(mktemp -d "${TMPDIR:-/tmp}/rglimpse-samples.XXXXXX")
trap 'rm -rf "$sample_test_dir"' EXIT
"${CXX:-c++}" -std=c++17 -O1 -fno-fast-math -ffp-contract=off \
    -ffunction-sections -fdata-sections -Iphase/src -Iligate/src -Icommon/src \
    dev-notes/test-haplotype-samples.cpp common/src/objects/genotype.cpp \
    ligate/src/ligater/ligater_algorithm.cpp ligate/src/ligater/ligater_management.cpp \
    -Wl,--gc-sections -lhts -lboost_program_options -lboost_serialization -lboost_iostreams \
    -lz -pthread -o "$sample_test_dir/test"
"$sample_test_dir/test"
