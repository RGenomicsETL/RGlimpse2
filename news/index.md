# Changelog

## RGlimpse2 0.0.0.9001

- Add
  [`rglimpse2_phase_bam()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_phase_bam.md)
  for deterministic direct phasing and imputation from one explicitly
  indexed BAM or CRAM.

- The R package interface is now distributed under GPL-2 or later;
  bundled upstream components retain their original licences and
  notices.

- Give every typed operational error the same optional child-process
  operation and status properties. This preserves the error-value
  contract when binary build systems install and check separate copies
  of the package.

- Add a nested R package that builds pinned GLIMPSE2 chunk,
  split-reference, phase, and ligate executables against the validated
  htslib contract supplied by `Rduckhts`.

- Bundle the pinned GRCh37 and GRCh38 autosomal and chromosome X genetic
  maps, plus explicit zero-recombination coordinate maps for Y non-PAR
  and mitochondrial sequence, with audited lookup helpers and
  provenance. Map lookup accepts chromosome names with or without `chr`
  and treats `M`, `MT`, `chrM`, and `chrMT` as mitochondrial aliases.

- Handle zero-span maps safely in phase PBWT grouping. Replace
  executable test doubles with reproducible `vcfppR`-generated BCF
  reference/target pairs that run the real chunk, split-reference,
  phase, and ligate executables across autosomal, Y, and mitochondrial
  contig aliases.

- Add stateless wrappers with explicit paths, arguments, seeds, and
  resources; typed S7 results and operational errors; and typed contract
  conditions. Split-reference coordinates are canonicalized before
  output prediction, output paths must be distinct, and ligate lists are
  validated exactly as the native reader consumes them. Child
  executables are launched directly with `processx` argument vectors
  without an intermediate shell command.

- Build scalar and architecture-specific phase executables and select
  only runtime-supported AVX2, AVX-512F/BW/VL, or NEON backends.

- Add Unix and Rtools `configure` paths, pinned SIMDe headers,
  source-archive drift auditing, and a checksummed Boost 1.90.0
  build-only source closure so the executables no longer depend on
  separately installed Boost headers or libraries. Use parallel native
  compilation with 2–8 detected make jobs, real executable help/linkage
  tests, and a synthetic native end-to-end conformance test across all
  supported SIMD backends.

- Add pkgdown configuration, package-development targets, release checks
  for Linux, macOS, and Windows, and Linux R-devel coverage. WebAssembly
  installs retain map and metadata APIs but explicitly omit GLIMPSE2
  child executables because that runtime cannot launch the required
  native processes.
