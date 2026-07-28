# Phase and impute one GLIMPSE2 chunk directly from several BAMs or CRAMs

Invokes `GLIMPSE2_phase` once with its native `--bam-list` input.
Genotype likelihoods are computed from every alignment inside that
process; no intermediate likelihood VCF or BCF is written. The BAM list
and the complete sample/ploidy file are private temporary inputs removed
before this function returns.

## Usage

``` r
rglimpse2_phase_bams(
  alignments,
  reference_bin,
  output_bcf,
  executable,
  seed,
  reference_fasta = character(),
  reference_fasta_index = character(),
  mapq = 10L,
  baseq = 10L,
  max_depth = 40L,
  call_indels = FALSE,
  keep_orphan_reads = FALSE,
  ignore_orientation = FALSE,
  check_proper_pairing = FALSE,
  keep_failed_qc = FALSE,
  keep_duplicates = FALSE,
  burnin = 5L,
  main = 15L,
  ne = 100000L,
  pbwt_depth = 12L,
  pbwt_modulo_cm = 0.1,
  k_init = 1000L,
  k_pbwt = 2000L,
  log = character()
)
```

## Arguments

- alignments:

  A non-empty data frame with one row per sample and columns:
  `input_bam` (character absolute `.bam` or `.cram` path), `input_index`
  (character absolute adjacent index path), `sample_name` (character
  unique sample name without whitespace), and `sample_ploidy` (numeric
  integer value `1` or `2`). Alignment paths cannot contain whitespace
  because `GLIMPSE2_phase --bam-list` uses a whitespace-delimited native
  format.

- reference_bin:

  Absolute GLIMPSE2 binary reference path.

- output_bcf:

  Absolute `.bcf` output path.

- executable:

  Absolute selected `GLIMPSE2_phase` path.

- seed:

  Non-negative random seed.

- reference_fasta:

  Empty or one absolute faidx-indexed reference FASTA. Required when any
  row in `alignments` is a CRAM.

- reference_fasta_index:

  Empty or one absolute FASTA index path. Required with
  `reference_fasta` and must be `paste0(reference_fasta, ".fai")`, which
  is the path HTSlib will discover.

- mapq:

  Minimum read mapping quality.

- baseq:

  Minimum base quality.

- max_depth:

  Maximum reads retained at one site before downsampling.

- call_indels:

  Whether to compute genotype likelihoods at reference indels. The
  default leaves indel likelihoods flat while retaining the reference
  haplotype scaffold.

- keep_orphan_reads:

  Whether to keep paired reads whose mate is unmapped.

- ignore_orientation:

  Whether to ignore mate-pair orientation.

- check_proper_pairing:

  Whether to discard reads not marked as properly paired.

- keep_failed_qc:

  Whether to keep reads marked as failed sequencing QC.

- keep_duplicates:

  Whether to keep reads marked as duplicates.

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

- log:

  Empty or one absolute log output path.

## Value

`RGlimpse2RunResult` with `output_bcf` and `output_index` paths, or an
`RGlimpse2ErrorValue`.

## Details

RGlimpse2 fixes the internal phase thread count at one so a supplied
seed is not coupled to worker scheduling. The final BCF and its CSI
index are published without replacing existing paths only after the
child process succeeds.
