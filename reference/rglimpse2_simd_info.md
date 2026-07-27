# Inspect and resolve packaged GLIMPSE2 phase SIMD executables

This function does not set process-global state. Pass the same backend
to
[`rglimpse2_executables()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_executables.md)
to obtain the selected executable explicitly. AVX-512 means AVX-512F,
AVX-512BW, and AVX-512VL with enabled OS ZMM state.

## Usage

``` r
rglimpse2_simd_info(phase_backend = "auto")
```

## Arguments

- phase_backend:

  One of `"auto"`, `"scalar"`, `"avx2"`, `"avx512"`, or `"neon"`.

## Value

`RGlimpse2SimdInfo` or `RGlimpse2InputErrorValue` when the requested
backend is unavailable.
