#!/bin/sh
# Build the packaged GLIMPSE2 child executables with R's native toolchain.

set -eu

platform=${1:-unix}
case "$platform" in
  unix)
    exeext=
    ;;
  windows)
    exeext=.exe
    ;;
  *)
    echo "ERROR: unsupported configure platform: $platform" >&2
    exit 1
    ;;
esac

if [ -z "${R_HOME:-}" ]; then
  R_HOME=$(R RHOME)
fi
if [ "$platform" = windows ]; then
  R_HOME=$(cygpath -u "$R_HOME")
  r_command="${R_HOME}/bin/R.exe"
  rscript_command="${R_HOME}/bin/Rscript.exe"
else
  r_command="${R_HOME}/bin/R"
  rscript_command="${R_HOME}/bin/Rscript"
fi
if [ ! -x "$r_command" ] || [ ! -x "$rscript_command" ]; then
  echo "ERROR: R_HOME does not identify a usable R installation: $R_HOME" >&2
  exit 1
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
package_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
archive="$package_root/tools/glimpse2-source.tar.xz"
boost_archive="$package_root/tools/boost-source.tar.xz"
build_root="$package_root/tools/glimpse2-build"
boost_root="$build_root/boost"
bin_dir="$package_root/inst/glimpse2/bin"

if [ ! -f "$archive" ]; then
  echo "ERROR: missing pinned GLIMPSE2 source archive: $archive" >&2
  exit 1
fi
if [ ! -f "$boost_archive" ]; then
  echo "ERROR: missing pinned Boost source archive: $boost_archive" >&2
  exit 1
fi

make_command=$("$r_command" CMD config MAKE)
if [ -z "$make_command" ]; then
  echo "ERROR: R CMD config MAKE returned an empty command" >&2
  exit 1
fi
if [ "$platform" = windows ]; then
  make_jobs=4
  local_soft=$("$r_command" CMD config LOCAL_SOFT)
  case "$(printf '%s' "$local_soft" | tr '[:upper:]' '[:lower:]')" in
    *aarch64*|*arm64*|*a64*) target_arch=aarch64 ;;
    *) target_arch=x86_64 ;;
  esac
else
  make_jobs=$("$rscript_command" -e '
    cores <- suppressWarnings(parallel::detectCores(logical = FALSE))
    if (is.na(cores)) cores <- suppressWarnings(parallel::detectCores())
    if (is.na(cores)) cores <- 2L
    cat(max(2L, min(8L, as.integer(cores))))
  ')
  # shellcheck disable=SC2016
  # The dollar sign belongs to the R expression and must not expand in the shell.
  target_arch=$("$rscript_command" -e 'cat(tolower(R.version$arch))')
fi
echo "Building GLIMPSE2 with $make_jobs parallel make jobs"
if [ -z "$target_arch" ]; then
  echo "ERROR: R did not report a target architecture" >&2
  exit 1
fi
rm -f \
  "$bin_dir/GLIMPSE2_chunk" "$bin_dir/GLIMPSE2_chunk.exe" \
  "$bin_dir/GLIMPSE2_split_reference" "$bin_dir/GLIMPSE2_split_reference.exe" \
  "$bin_dir/GLIMPSE2_phase" "$bin_dir/GLIMPSE2_phase.exe" \
  "$bin_dir/GLIMPSE2_phase_avx2" "$bin_dir/GLIMPSE2_phase_avx2.exe" \
  "$bin_dir/GLIMPSE2_phase_avx512" "$bin_dir/GLIMPSE2_phase_avx512.exe" \
  "$bin_dir/GLIMPSE2_phase_neon" "$bin_dir/GLIMPSE2_phase_neon.exe" \
  "$bin_dir/GLIMPSE2_ligate" "$bin_dir/GLIMPSE2_ligate.exe"
target_platform=$(
  "$rscript_command" -e 'cat(tolower(R.version$platform))'
)
target_compiler=$(
  "$r_command" CMD config CXX17
)
case "$target_platform $target_compiler ${CC:-} ${CXX:-}" in
  *emscripten*|*wasm*|*em++*|*emcc*)
    rm -rf "$build_root"
    rm -f "$package_root/inst/glimpse2/htslib-version"
    echo "RGlimpse2 configure: WebAssembly has no child-process executable runtime"
    exit 0
    ;;
esac

rm -rf "$build_root"
mkdir -p "$build_root" "$bin_dir"
trap 'rm -rf "$build_root"' EXIT INT HUP TERM

tar -xJf "$archive" -C "$build_root"
"$rscript_command" "$package_root/tools/build-boost-source.R" \
  "$boost_archive" "$boost_root"
RGLIMPSE2_BOOST_ROOT=$boost_root
export RGLIMPSE2_BOOST_ROOT
"$rscript_command" "$package_root/tools/write-make-config.R" \
  "$build_root/rglimpse2-scalar.mk" scalar \
  "$package_root/inst/glimpse2/htslib-version"

run_make() {
  # R CMD config MAKE may include implementation-specific arguments.
  # shellcheck disable=SC2086
  $make_command "$@"
}

build_program() {
  project=$1
  target="bin/GLIMPSE2_${project}${exeext}"
  run_make -j"$make_jobs" -C "$build_root/$project" \
    -f makefile -f ../rglimpse2-scalar.mk EXEEXT="$exeext" "$target"
  cp "$build_root/$project/$target" "$bin_dir/GLIMPSE2_${project}${exeext}"
  chmod 755 "$bin_dir/GLIMPSE2_${project}${exeext}"
}

build_program chunk
build_program split_reference
build_program ligate

build_phase_backend() {
  config=$1
  destination=$2
  run_make -C "$build_root/phase" -f makefile -f "$config" \
    EXEEXT="$exeext" clean
  run_make -j"$make_jobs" -C "$build_root/phase" \
    -f makefile -f "$config" EXEEXT="$exeext" \
    "bin/GLIMPSE2_phase${exeext}"
  cp "$build_root/phase/bin/GLIMPSE2_phase${exeext}" \
    "$bin_dir/${destination}${exeext}"
  chmod 755 "$bin_dir/${destination}${exeext}"
}

build_phase_backend ../rglimpse2-scalar.mk GLIMPSE2_phase

case "$target_arch" in
  x86_64|amd64)
    "$rscript_command" "$package_root/tools/write-make-config.R" \
      "$build_root/rglimpse2-avx2.mk" avx2
    build_phase_backend ../rglimpse2-avx2.mk GLIMPSE2_phase_avx2
    "$rscript_command" "$package_root/tools/write-make-config.R" \
      "$build_root/rglimpse2-avx512.mk" avx512
    build_phase_backend ../rglimpse2-avx512.mk GLIMPSE2_phase_avx512
    ;;
  aarch64|arm64|arm*)
    "$rscript_command" "$package_root/tools/write-make-config.R" \
      "$build_root/rglimpse2-neon.mk" neon
    build_phase_backend ../rglimpse2-neon.mk GLIMPSE2_phase_neon
    ;;
  *)
    echo "RGlimpse2 configure: only scalar phase is available on $target_arch"
    ;;
esac

for executable in \
  GLIMPSE2_chunk GLIMPSE2_split_reference GLIMPSE2_phase GLIMPSE2_ligate
do
  if [ ! -x "$bin_dir/${executable}${exeext}" ]; then
    echo "ERROR: native build did not produce ${executable}${exeext}" >&2
    exit 1
  fi
done

echo "RGlimpse2 configure: installed native executables in $bin_dir"
