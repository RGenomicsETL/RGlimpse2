# Phase and impute one GLIMPSE2 chunk directly from one BAM or CRAM

Invokes `GLIMPSE2_phase` once against a binary reference chunk and one
coordinate-sorted, indexed alignment. The alignment index is an explicit
input and must use a filename that HTSlib's `sam_index_load()` will
discover beside the alignment. RGlimpse2 fixes the internal phase thread
count at one so a supplied seed is not coupled to worker scheduling;
callers should parallelize independent chunks.

## Usage

``` r
rglimpse2_phase_bam(
  input_bam,
  input_index,
  reference_bin,
  output_bcf,
  executable,
  seed,
  sample_name = character(),
  sample_ploidy = integer(),
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

- input_bam:

  Absolute `.bam` or `.cram` alignment path.

- input_index:

  Absolute BAM/CRAM index path. BAM accepts adjacent `.bai` or `.csi`
  naming; CRAM accepts adjacent `.crai` naming.

- reference_bin:

  Absolute GLIMPSE2 binary reference path.

- output_bcf:

  Absolute `.bcf` output path.

- executable:

  Absolute selected `GLIMPSE2_phase` path.

- seed:

  Non-negative random seed.

- sample_name:

  Empty or one output sample name. When omitted, GLIMPSE2 derives the
  name from the alignment filename.

- sample_ploidy:

  Empty or one integer, `1L` or `2L`. If supplied without `sample_name`,
  the alignment filename stem is used for the temporary sample/ploidy
  table passed to GLIMPSE2.

- reference_fasta:

  Empty or one absolute faidx-indexed reference FASTA. Required for CRAM
  input.

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

`RGlimpse2RunResult` or an `RGlimpse2ErrorValue`.
