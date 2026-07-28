# Build one GLIMPSE2 binary reference chunk

Invokes `GLIMPSE2_split_reference` once. `output_region` must be
contained within `input_region`; both regions must name the same contig.
Before the child process starts, RGlimpse2 scans the requested reference
region and rejects records whose allele count is not exactly two.
Reference preparation must split or otherwise resolve multiallelic
records before this call.

## Usage

``` r
rglimpse2_split_reference(
  reference_bcf,
  input_region,
  output_region,
  output_prefix,
  executable,
  genetic_map,
  seed,
  threads = 1L,
  sparse_maf = 0.001,
  keep_monomorphic_ref_sites = FALSE,
  log = character()
)
```

## Arguments

- reference_bcf:

  Absolute phased reference VCF/BCF path.

- input_region:

  Buffered region in `contig:start-end` form.

- output_region:

  Unbuffered region in `contig:start-end` form.

- output_prefix:

  Absolute output prefix. GLIMPSE2 appends the normalized input region
  and `.bin`.

- executable:

  Absolute `GLIMPSE2_split_reference` path.

- genetic_map:

  Absolute genetic-map path, such as one returned by
  [`rglimpse2_genetic_map()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_genetic_maps.md).

- seed:

  Non-negative random seed.

- threads:

  Positive worker count.

- sparse_maf:

  Rare-variant threshold in `[0, 0.5)`.

- keep_monomorphic_ref_sites:

  Whether to retain monomorphic reference records.

- log:

  Empty or one absolute log output path.

## Value

`RGlimpse2RunResult` or an `RGlimpse2ErrorValue`.
