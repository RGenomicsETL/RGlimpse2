## Test environments

- local Ubuntu 24.04, R-devel
- GitHub Actions Linux release/devel, macOS release on x86_64/ARM64, and
  Windows release on x86_64

## R CMD check results

- `R CMD check --no-manual`: 0 errors | 0 warnings | 0 notes
- `R CMD check --as-cran --no-manual`: expected incoming-feasibility
  warning/notes for a development version and private repository URLs

## Native build notes

- The source package contains a pinned GLIMPSE2 source archive, upstream SIMDe
  headers, and approximately 46 MB of compressed GRCh37/GRCh38 genetic maps.
  The maps are intentionally bundled for reproducible offline use; 50 are
  byte-identical to the pinned upstream files and four minimal derived maps are
  documented and audited by checksum.
- Installation uses GNU make and no more than two build jobs.
- htslib is not vendored. Configuration requires the exact validated headers
  and library contract installed by `Rduckhts`.
- The phase program is built as scalar plus architecture-specific executables;
  a baseline CPU/OS probe prevents unsupported binaries from being selected.
- Tests use synthetic data, temporary output directories, fixed explicit seeds,
  and one process at a time. They do not access the network.
- The local `-mno-omit-leaf-frame-pointer` NOTE is caused by R's configured
  compiler flags; RGlimpse2 does not add it.
- `Rduckhts` is resolved from the RGenomicsETL R-universe until it is
  available from CRAN.
