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

## Details

Overlapping exact allele records orient each diploid sample
independently. Each chunk supplies one local phase set per sample; input
PS annotations are rejected. Adjacent chunks on one contig must start at
increasing record positions and share identical ordered allele records.
Nested extents fail when the right chunk ends before the left chunk.
`FORMAT/PS` identifies the resulting phase set; absent or tied
informative overlap starts a separate set for that sample. Haploid,
missing and unphased genotypes have no PS. `FORMAT/LIGATE_FLIP` records
an applied allele-pair swap, and `INFO/LIGATE_CHUNK` is the one-based
selected input-list entry. GP, DS, biological annotations and original
HS/HSC draw scopes are retained. HS inputs are GLIMPSE2 phase outputs
with complete phased diploid GT; missing or unphased diploid GT with HS
is outside that producer contract. Ligation does not join independently
sampled chunks into a joint draw.
