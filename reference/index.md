# Package index

## Executable discovery and dispatch

- [`rglimpse2_executables()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_executables.md)
  : Resolve packaged or explicitly supplied GLIMPSE2 executables
- [`rglimpse2_simd_info()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_simd_info.md)
  : Inspect and resolve packaged GLIMPSE2 phase SIMD executables
- [`RGlimpse2Executables()`](https://rgenomicsetl.github.io/RGlimpse2/reference/RGlimpse2Executables.md)
  : Explicit GLIMPSE2 child executables
- [`RGlimpse2SimdInfo()`](https://rgenomicsetl.github.io/RGlimpse2/reference/RGlimpse2SimdInfo.md)
  : RGlimpse2 phasing-executable dispatch information

## Reference assets

- [`rglimpse2_genetic_maps()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_genetic_maps.md)
  [`rglimpse2_genetic_map()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_genetic_maps.md)
  : Resolve packaged GRCh37 or GRCh38 genetic maps

## GLIMPSE2 operations

- [`rglimpse2_chunk()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_chunk.md)
  : Create deterministic GLIMPSE2 imputation chunks
- [`rglimpse2_split_reference()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_split_reference.md)
  : Build one GLIMPSE2 binary reference chunk
- [`rglimpse2_phase()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_phase.md)
  : Phase and impute one GLIMPSE2 chunk from genotype likelihoods
- [`rglimpse2_phase_bam()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_phase_bam.md)
  : Phase and impute one GLIMPSE2 chunk directly from one BAM or CRAM
- [`rglimpse2_phase_bams()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_phase_bams.md)
  : Phase and impute one GLIMPSE2 chunk directly from several BAMs or
  CRAMs
- [`rglimpse2_ligate()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_ligate.md)
  : Ligate ordered GLIMPSE2 chunk outputs

## Results and errors

- [`RGlimpse2RunResult()`](https://rgenomicsetl.github.io/RGlimpse2/reference/RGlimpse2RunResult.md)
  : A completed RGlimpse2 child-process operation
- [`RGlimpse2ErrorValue()`](https://rgenomicsetl.github.io/RGlimpse2/reference/RGlimpse2ErrorValue.md)
  [`RGlimpse2InputErrorValue()`](https://rgenomicsetl.github.io/RGlimpse2/reference/RGlimpse2ErrorValue.md)
  [`RGlimpse2OutputErrorValue()`](https://rgenomicsetl.github.io/RGlimpse2/reference/RGlimpse2ErrorValue.md)
  [`RGlimpse2ProcessErrorValue()`](https://rgenomicsetl.github.io/RGlimpse2/reference/RGlimpse2ErrorValue.md)
  : A typed RGlimpse2 operational error value
- [`rglimpse2_error_value()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_error_value.md)
  : Construct a typed RGlimpse2 operational error
- [`rglimpse2_is_error()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_is_error.md)
  : Test whether a value is an RGlimpse2 operational error
- [`rglimpse2_contract_violation()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_contract_violation.md)
  : Construct a typed RGlimpse2 contract condition
