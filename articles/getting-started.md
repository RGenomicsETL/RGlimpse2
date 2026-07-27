# Explicit GLIMPSE2 Operations from R

## Contract

`RGlimpse2` is a thin interface to package-built GLIMPSE2 child
executables. Each public operation accepts explicit paths, output names,
intervals, seeds, and resource values. Calls do not search `PATH`,
overwrite outputs, or retain workflow state.

Resolve one coherent executable set before running operations:

``` r

library(RGlimpse2)

executables <- rglimpse2_executables(phase_backend = "auto")
if (rglimpse2_is_error(executables)) {
  stop(executables@message)
}
```

## Chunk and split the reference

``` r

chunk_result <- rglimpse2_chunk(
  input_sites = "/data/reference.sites.bcf",
  region = "chr22",
  output_chunks = "/work/chunks.chr22.txt",
  executable = executables@chunk,
  genetic_map = "/data/chr22.b38.gmap.gz",
  seed = 101L,
  threads = 2L
)
```

Each chunk table row supplies a buffered input region and contained
output region for
[`rglimpse2_split_reference()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_split_reference.md):

``` r

split_result <- rglimpse2_split_reference(
  reference_bcf = "/data/reference.bcf",
  input_region = "chr22:100000-600000",
  output_region = "chr22:150000-550000",
  output_prefix = "/work/reference",
  executable = executables@split_reference,
  genetic_map = "/data/chr22.b38.gmap.gz",
  seed = 102L,
  threads = 2L
)
```

## Phase and ligate

The current deterministic phase contract requires `threads = 1L`.
Parallelize across independent chunks rather than inside a phase child:

``` r

phase_result <- rglimpse2_phase(
  input_gl = "/data/sample.gl.bcf",
  reference_bin = split_result@outputs$reference_bin,
  output_bcf = "/work/phase.chr22.1.bcf",
  executable = executables@phase,
  seed = 103L,
  threads = 1L
)
```

After writing an ordered file containing one absolute phase-output path
per line, ligate the chunks:

``` r

ligate_result <- rglimpse2_ligate(
  input_list = "/work/phase-files.txt",
  output_bcf = "/work/phase.chr22.bcf",
  executable = executables@ligate,
  seed = 104L,
  threads = 2L
)
```

Successful operations return `RGlimpse2RunResult`. Expected missing
inputs, occupied outputs, unavailable executables, and child-process
failures return an `RGlimpse2ErrorValue` subclass. Contract violations
signal an `rglimpse2_contract_violation` condition.

## SIMD selection

``` r

info <- rglimpse2_simd_info()
info@compiled_backends
info@cpu_supported_backends
info@selected_backend
```

Automatic dispatch only selects the intersection of installed binaries
and CPU/operating-system support. Explicit `"scalar"`, `"avx2"`,
`"avx512"`, or `"neon"` requests return a typed unavailable-backend
value rather than starting an unsupported executable.
