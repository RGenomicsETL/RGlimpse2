# RGlimpse2

[![R-CMD-check](https://github.com/RGenomicsETL/RGlimpse2/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/RGenomicsETL/RGlimpse2/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/RGenomicsETL/RGlimpse2/actions/workflows/pkgdown.yaml/badge.svg)](https://rgenomicsetl.github.io/RGlimpse2/)
[![R-universe](https://RGenomicsETL.r-universe.dev/RGlimpse2/badges/version)](https://RGenomicsETL.r-universe.dev/RGlimpse2)

`RGlimpse2` is the R package in the RGenomicsETL GLIMPSE2 fork. It
builds and installs the pinned `GLIMPSE2_chunk`,
`GLIMPSE2_split_reference`, `GLIMPSE2_phase`, and `GLIMPSE2_ligate`
programs, then invokes one child executable per operation through direct
`processx` argument vectors.

## Installation

Install development builds from the RGenomicsETL R-universe:

``` r

install.packages(
  "RGlimpse2",
  repos = c(
    RGenomicsETL = "https://rgenomicsetl.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  )
)
```

Source installation requires GNU make, a C++17 compiler, and the Boost
`iostreams`, `program_options`, and `serialization` libraries. Rtools45
ships these requirements for Windows. Linux distributions and Homebrew
provide them as ordinary development packages.

## Packaged genetic maps

GRCh37 and GRCh38 autosomal, X non-PAR, X PAR1, and X PAR2 maps are
installed with the package. Minimal zero-recombination coordinate maps
are also provided for Y non-PAR and mitochondrial sequence:

``` r

library(RGlimpse2)

rglimpse2_genetic_map("GRCh38", "22")
rglimpse2_genetic_map("GRCh38", "X", region = "par1")
rglimpse2_genetic_map("GRCh38", "Y")
rglimpse2_genetic_map("GRCh38", "MT")
head(rglimpse2_genetic_maps())
```

The Y and mitochondrial files contain two anchors at `0` cM because
GLIMPSE requires at least two map entries. They are not empirical
recombination maps or claims that Y or mitochondrial imputation is
validated.

## One explicit operation at a time

Resolve the installed executables and run an operation with explicit
inputs, outputs, interval, seed, and resources:

``` r

library(RGlimpse2)

executables <- rglimpse2_executables(phase_backend = "auto")
if (rglimpse2_is_error(executables)) {
  stop(executables@message)
}

genetic_map <- rglimpse2_genetic_map("GRCh38", "22")

chunks <- rglimpse2_chunk(
  input_sites = "/data/reference.sites.bcf",
  region = "chr22",
  output_chunks = "/work/chunks.chr22.txt",
  executable = executables@chunk,
  genetic_map = genetic_map,
  seed = 20260727L,
  threads = 2L
)
```

The split-reference, phase, and ligate wrappers follow the same
contract. They do not search `PATH`, overwrite an output, build shell
command strings, or retain workflow state. Invalid calls signal typed
`rglimpse2_contract_violation` conditions; expected operational failures
are returned as typed S7 error values.

## One htslib authority

The package does not vendor or discover another htslib. During
configuration it requires:

``` r

Rduckhts::rduckhts_htslib_config(validate = TRUE)
```

Every executable is built with the returned headers and exact library
contract. Runtime executable discovery revalidates the packaged build
version against the htslib version supplied and loaded by `Rduckhts`.

## Runtime phase dispatch

`GLIMPSE2_phase` is built as complete, process-isolated executables:

- x86_64: scalar SIMDe, AVX2, and AVX-512F/BW/VL;
- ARM: scalar SIMDe and NEON.

A baseline C probe checks CPU features and operating-system vector state
before `"auto"` selects a binary. Explicit backend selection supports
conformance and reproducibility testing without process-global dispatch
state.

``` r

rglimpse2_simd_info()
scalar <- rglimpse2_executables(phase_backend = "scalar")
```

The package’s native end-to-end test runs all four real GLIMPSE2
operations on a synthetic BCF fixture and requires byte-identical
fixed-seed phase output from every runtime-supported backend.

## Building this fork

The upstream GLIMPSE2 tree remains the repository root. The R package is
nested under `RGlimpse2/`:

``` sh
make r-package-bootstrap
make r-package-check
```

Reference-panel copying evidence is an inference diagnostic. `RGlimpse2`
does not call it local ancestry; that claim requires a separately
calibrated and validated decoder.
