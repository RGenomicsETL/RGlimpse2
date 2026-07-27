#!/bin/sh
# Prove that the patch series exactly reconstructs the maintained upstream files.

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
pin_file="$script_dir/upstream.json"
series_file="$script_dir/series"
paths_file="$script_dir/upstream.paths"

upstream_commit=$(sed -n \
  's/.*"commit"[[:space:]]*:[[:space:]]*"\([0-9a-f]*\)".*/\1/p' \
  "$pin_file")
if [ "${#upstream_commit}" -ne 40 ]; then
  echo "ERROR: could not read the full upstream commit from $pin_file" >&2
  exit 1
fi
if ! git -C "$repo_root" cat-file -e "${upstream_commit}^{commit}"; then
  echo "ERROR: pinned upstream commit is not available: $upstream_commit" >&2
  exit 1
fi

expected_patches=$(mktemp)
actual_patches=$(mktemp)
expected_paths=$(mktemp)
actual_paths=$(mktemp)
temp_tree=$(mktemp -d)
cleanup() {
  rm -f "$expected_patches" "$actual_patches" "$expected_paths" "$actual_paths"
  rm -rf "$temp_tree"
}
trap cleanup EXIT INT HUP TERM

sed '/^[[:space:]]*\($\|#\)/d' "$series_file" | sort > "$expected_patches"
find "$script_dir" -maxdepth 1 -type f -name '*.patch' -exec basename '{}' \; \
  | sort > "$actual_patches"
if ! cmp -s "$expected_patches" "$actual_patches"; then
  echo "ERROR: patch files and patches/series disagree" >&2
  diff -u "$expected_patches" "$actual_patches" >&2 || true
  exit 1
fi

sed '/^[[:space:]]*\($\|#\)/d' "$paths_file" | sort > "$expected_paths"
git -C "$repo_root" diff --name-only "$upstream_commit" -- \
  common.mk makefile common/src chunk split_reference phase ligate \
  | sort > "$actual_paths"
if ! cmp -s "$expected_paths" "$actual_paths"; then
  echo "ERROR: maintained upstream changes and patches/upstream.paths disagree" >&2
  diff -u "$expected_paths" "$actual_paths" >&2 || true
  exit 1
fi

# A git repository gives git-apply its normal path-safety and index context,
# while the files themselves come directly from the pinned upstream commit.
git -C "$repo_root" archive "$upstream_commit" | tar -xf - -C "$temp_tree"
git -C "$temp_tree" init -q
while IFS= read -r patch_name; do
  case "$patch_name" in
    ''|'#'*) continue ;;
  esac
  git -C "$temp_tree" apply --check "$script_dir/$patch_name"
  git -C "$temp_tree" apply "$script_dir/$patch_name"
done < "$series_file"

while IFS= read -r path; do
  case "$path" in
    ''|'#'*) continue ;;
  esac
  if ! cmp -s "$temp_tree/$path" "$repo_root/$path"; then
    echo "ERROR: patched upstream file differs from the working tree: $path" >&2
    exit 1
  fi
done < "$paths_file"

printf 'Upstream patch series reproduces %s exactly.\n' "$upstream_commit"
