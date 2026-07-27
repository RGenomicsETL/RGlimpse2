#!/bin/sh
# Verify that staged phase executables respect their advertised ISA boundary.

set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: check-phase-assembly.sh BIN_DIRECTORY /ABSOLUTE/PATH/TO/OBJDUMP" >&2
  exit 2
fi
bin_dir=$1
objdump=$2
case "$bin_dir" in
  /*) ;;
  *) echo "ERROR: BIN_DIRECTORY must be absolute" >&2; exit 2 ;;
esac
case "$objdump" in
  /*) ;;
  *) echo "ERROR: OBJDUMP must be absolute" >&2; exit 2 ;;
esac
if [ ! -x "$objdump" ]; then
  echo "ERROR: objdump is unavailable: $objdump" >&2
  exit 1
fi

scalar="$bin_dir/GLIMPSE2_phase"
avx2="$bin_dir/GLIMPSE2_phase_avx2"
avx512="$bin_dir/GLIMPSE2_phase_avx512"
if [ ! -x "$scalar" ]; then
  echo "ERROR: scalar phase executable is unavailable: $scalar" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT HUP TERM
"$objdump" -d "$scalar" > "$tmp/scalar.asm"
if grep -Eq '%(ymm|zmm)[0-9]+' "$tmp/scalar.asm"; then
  echo "ERROR: scalar phase executable contains YMM/ZMM instructions" >&2
  exit 1
fi

if [ -x "$avx2" ]; then
  "$objdump" -d "$avx2" > "$tmp/avx2.asm"
  if ! grep -Eq '%ymm[0-9]+' "$tmp/avx2.asm"; then
    echo "ERROR: AVX2 phase executable contains no YMM instructions" >&2
    exit 1
  fi
fi

if [ -x "$avx512" ]; then
  "$objdump" -d "$avx512" > "$tmp/avx512.asm"
  if ! grep -Eq '%zmm[0-9]+' "$tmp/avx512.asm"; then
    echo "ERROR: AVX-512 phase executable contains no ZMM instructions" >&2
    exit 1
  fi
fi

echo "Phase assembly audit passed."
