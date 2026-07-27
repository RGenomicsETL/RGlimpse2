# RGlimpse2 0.0.0.9000

- Add a nested R package that builds pinned GLIMPSE2 chunk, split-reference,
  phase, and ligate executables against the validated htslib contract supplied
  by `Rduckhts`.
- Add stateless wrappers with explicit paths, arguments, seeds, and resources;
  typed S7 results and operational errors; and typed contract conditions.
  Split-reference coordinates are canonicalized before output prediction,
  output paths must be distinct, and ligate lists are validated exactly as the
  native reader consumes them. Child executables are launched directly with
  `processx` argument vectors without an intermediate shell command.
- Build scalar and architecture-specific phase executables and select only
  runtime-supported AVX2, AVX-512F/BW/VL, or NEON backends.
- Add Unix and Rtools `configure` paths, pinned SIMDe headers, source-archive
  drift auditing, parallel native compilation using 2--8 detected make jobs,
  real executable help/linkage tests, and a synthetic native end-to-end
  conformance test across all supported SIMD backends.
- Add pkgdown configuration, package-development targets, and GitHub Actions
  checks for Linux, macOS, and Windows on x86_64 and ARM64.
