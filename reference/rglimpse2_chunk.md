# Create deterministic GLIMPSE2 imputation chunks

Invokes `GLIMPSE2_chunk` once. All paths are explicit and the output
file must not already exist.

## Usage

``` r
rglimpse2_chunk(
  input_sites,
  region,
  output_chunks,
  executable,
  genetic_map,
  seed,
  threads = 1L,
  algorithm = c("sequential", "recursive"),
  window_cm = 2.5,
  window_mb = 2,
  window_count = 20000L,
  buffer_cm = 0.5,
  buffer_mb = 0.4,
  buffer_count = 2000L,
  sparse_maf = 0.001,
  log = character()
)
```

## Arguments

- input_sites:

  Absolute VCF/BCF sites path.

- region:

  Contig or genomic interval to split.

- output_chunks:

  Absolute output chunk-table path.

- executable:

  Absolute `GLIMPSE2_chunk` path.

- genetic_map:

  Absolute genetic-map path, such as one returned by
  [`rglimpse2_genetic_map()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_genetic_maps.md).

- seed:

  Non-negative random seed.

- threads:

  Positive worker count.

- algorithm:

  Chunking algorithm.

- window_cm, window_mb:

  Positive minimum window sizes.

- window_count:

  Positive minimum window variant count.

- buffer_cm, buffer_mb:

  Positive minimum buffer sizes.

- buffer_count:

  Positive minimum buffer variant count.

- sparse_maf:

  Rare-variant threshold in `[0, 0.5)`.

- log:

  Empty or one absolute log output path.

## Value

`RGlimpse2RunResult` or an `RGlimpse2ErrorValue`.
