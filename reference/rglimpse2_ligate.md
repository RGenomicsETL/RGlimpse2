# Ligate ordered GLIMPSE2 chunk outputs

Invokes `GLIMPSE2_ligate` once. The input list must contain exactly one
existing absolute VCF/BCF path per line in chromosome order. Blank lines
and surrounding whitespace are rejected because the native reader treats
them as part of a path.

## Usage

``` r
rglimpse2_ligate(
  input_list,
  output_bcf,
  executable,
  seed,
  threads = 1L,
  log = character()
)
```

## Arguments

- input_list:

  Absolute text-file path containing ordered chunk paths.

- output_bcf:

  Absolute output `.bcf`, `.vcf`, or `.vcf.gz` path.

- executable:

  Absolute `GLIMPSE2_ligate` path.

- seed:

  Non-negative random seed.

- threads:

  Positive worker count.

- log:

  Empty or one absolute log output path.

## Value

`RGlimpse2RunResult` or an `RGlimpse2ErrorValue`.
