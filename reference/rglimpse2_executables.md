# Resolve packaged or explicitly supplied GLIMPSE2 executables

This function never searches `PATH`. Supply either one absolute
directory containing all four standard executable names or all four
absolute paths. With no supplied paths, only the installed package
directory is inspected; `phase_backend` then selects a portable or AVX2
phase executable.

## Usage

``` r
rglimpse2_executables(
  directory = character(),
  chunk = character(),
  split_reference = character(),
  phase = character(),
  ligate = character(),
  phase_backend = "auto"
)
```

## Arguments

- directory:

  Empty or one absolute executable directory.

- chunk:

  Absolute path to `GLIMPSE2_chunk`.

- split_reference:

  Absolute path to `GLIMPSE2_split_reference`.

- phase:

  Absolute path to the selected `GLIMPSE2_phase` executable.

- ligate:

  Absolute path to `GLIMPSE2_ligate`.

- phase_backend:

  Packaged phase backend: `"auto"`, `"scalar"`, `"avx2"`, `"avx512"`, or
  `"neon"`. It must remain `"auto"` for explicitly supplied executables.

## Value

`RGlimpse2Executables` or `RGlimpse2InputErrorValue`.
