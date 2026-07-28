#!/bin/sh
# Regenerate the maintained downstream diffs against the pinned upstream tree.

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
pin_file="$script_dir/upstream.json"

upstream_commit=$(sed -n \
  's/.*"commit"[[:space:]]*:[[:space:]]*"\([0-9a-f]*\)".*/\1/p' \
  "$pin_file")
if [ "$(printf '%s\n' "$upstream_commit" | wc -l | tr -d ' ')" -ne 1 ] || \
   [ "${#upstream_commit}" -ne 40 ]; then
  echo "ERROR: could not read one full upstream commit from $pin_file" >&2
  exit 1
fi
if ! git -C "$repo_root" cat-file -e "${upstream_commit}^{commit}"; then
  echo "ERROR: pinned upstream commit is not available: $upstream_commit" >&2
  exit 1
fi

write_patch() {
  output=$1
  shift
  git -C "$repo_root" diff --binary --no-ext-diff "$upstream_commit" -- "$@" \
    > "$script_dir/$output"
  if [ ! -s "$script_dir/$output" ]; then
    echo "ERROR: generated patch is empty: $output" >&2
    exit 1
  fi
}

write_patch 0001-add-downstream-native-build-hooks.patch \
  common.mk makefile
write_patch 0002-port-phase-hmms-to-explicit-simde.patch \
  phase/src/models/imputation_hmm.cpp \
  phase/src/models/imputation_hmm.h \
  phase/src/models/phasing_hmm.h
write_patch 0003-use-portable-reference-environment-setup.patch \
  phase/src/caller/caller_initialise.cpp
write_patch 0004-handle-zero-span-genetic-maps.patch \
  phase/src/containers/haplotype_set.cpp
write_patch 0005-keep-symbolic-direct-bam-likelihoods-flat.patch \
  phase/src/io/genotype_bam_caller.cpp

printf 'Regenerated upstream patch series against %s\n' "$upstream_commit"
