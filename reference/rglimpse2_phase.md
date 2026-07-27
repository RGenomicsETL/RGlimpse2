# Phase and impute one GLIMPSE2 chunk from genotype likelihoods

Invokes `GLIMPSE2_phase` once against a binary reference chunk.
RGlimpse2 currently requires one internal phase thread so a fixed seed
is not coupled to worker scheduling; parallelism belongs across
independent chunks.

## Usage

``` r
rglimpse2_phase(
  input_gl,
  reference_bin,
  output_bcf,
  executable,
  seed,
  threads = 1L,
  sample_ploidy = character(),
  input_field = c("PL", "GL"),
  burnin = 5L,
  main = 15L,
  ne = 100000L,
  pbwt_depth = 12L,
  pbwt_modulo_cm = 0.1,
  k_init = 1000L,
  k_pbwt = 2000L,
  impute_reference_only_variants = FALSE,
  use_gl_indels = FALSE,
  log = character()
)
```

## Arguments

- input_gl:

  Absolute VCF/BCF genotype-likelihood path.

- reference_bin:

  Absolute GLIMPSE2 binary reference path.

- output_bcf:

  Absolute `.bcf`, `.vcf`, or `.vcf.gz` output path.

- executable:

  Absolute selected `GLIMPSE2_phase` path.

- seed:

  Non-negative random seed.

- threads:

  Must be `1L` under the current deterministic contract.

- sample_ploidy:

  Empty or one absolute sample/ploidy table path.

- input_field:

  Genotype likelihood field, `"PL"` or `"GL"`.

- burnin:

  Number of burn-in iterations.

- main:

  Number of main iterations, at most 15.

- ne:

  Positive effective diploid population size.

- pbwt_depth:

  Positive PBWT neighbour depth.

- pbwt_modulo_cm:

  Positive PBWT selection spacing in cM.

- k_init, k_pbwt:

  Positive conditioning-state limits.

- impute_reference_only_variants:

  Whether to admit sporadically absent target likelihood records from
  the reference.

- use_gl_indels:

  Whether to consume input likelihoods at indels rather than use the
  default flat-likelihood scaffold behavior.

- log:

  Empty or one absolute log output path.

## Value

`RGlimpse2RunResult` or an `RGlimpse2ErrorValue`.
