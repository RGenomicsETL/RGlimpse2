# RGlimpse2 0.0.0.9004

- Make the phase executables faster and far lighter without changing any
  output: the imputation forward table is checkpointed every 64 sites and
  recomputed block by block in cache, the backward pass splits alpha*beta by
  allele with and/andnot masks, the conditioning bitmatrix is built by
  transposing rows of a haplotype-major panel copy, the phasing segment
  transition runs in one pass, per-site transitions are cached, and output
  rounding no longer allocates. The sparse-PBWT selection compacts its
  permutation with block moves and, for runs with few target haplotypes,
  evaluates prefix counts from the run table instead of materialising them,
  which matters for single-sample runs; the binary reference panel is read
  through a 16 MB stream buffer so IOPS-throttled storage sees a few large
  reads per chunk instead of hundreds. Outputs are byte-identical to the
  previous executables on the AVX2 and portable paths (verified on x86-64
  Linux with GCC 13 in the default floating-point environment); per-thread
  memory drops from about 730 MB to about 30 MB on a 2000-state, 57k-site
  chunk, while the haplotype-major panel copy adds a second copy of the
  common-site panel (n_ref_haps x n_com_sites bits, 26 MB for 6198 haplotypes
  and 35k common sites).
- Remove the phasing kernels' unconditional multiply introduced during the
  same work after review: a conditional multiply is kept so results do not
  depend on the denormal mode of the floating-point environment.

# RGlimpse2 0.0.0.9003

- Include the pthread header directly in threaded native callers so Rtools
  ARM64 builds do not depend on a transitive header.

# RGlimpse2 0.0.0.9002

- Preserve biallelic symbolic and ambiguous reference records during direct-BAM
  phasing without attempting a read-level call, and declare `GP` with VCF
  `Number=G` for ploidy-correct likelihood cardinality.

# RGlimpse2 0.0.0.9001

- Add `rglimpse2_phase_bam()` for deterministic direct phasing and imputation
  from one explicitly indexed BAM or CRAM.
- Add `rglimpse2_phase_bams()` for one native multi-sample
  `GLIMPSE2_phase --bam-list` call with explicit indexed alignments, sample
  names, and mixed haploid/diploid ploidy. Private BAM/ploidy tables are
  removed after the call, and the BCF plus its CSI index are published without
  replacement only after successful staging.
- Make `rglimpse2_split_reference()` return a typed
  `non_biallelic_reference` input error before starting GLIMPSE2 when the
  requested reference region contains unsplit records.
- Keep biallelic symbolic and other non-observable reference variants in
  direct-BAM imputation with flat read likelihoods instead of routing them
  through the SNP caller.
- Ligate overlapping all-haploid chunks using the one-value-per-sample GT
  stride returned by HTSlib while preserving mixed and diploid phase matching.

- The R package interface is now distributed under GPL-2 or later; bundled
  upstream components retain their original licences and notices.
- Give every typed operational error the same optional child-process operation
  and status properties. This preserves the error-value contract when binary
  build systems install and check separate copies of the package.

- Add a nested R package that builds pinned GLIMPSE2 chunk, split-reference,
  phase, and ligate executables against the validated htslib contract supplied
  by `Rduckhts`.
- Bundle the pinned GRCh37 and GRCh38 autosomal and chromosome X genetic maps,
  plus explicit zero-recombination coordinate maps for Y non-PAR and
  mitochondrial sequence, with audited lookup helpers and provenance. Map
  lookup accepts chromosome names with or without `chr` and treats `M`, `MT`,
  `chrM`, and `chrMT` as mitochondrial aliases.
- Handle zero-span maps safely in phase PBWT grouping. Replace executable test
  doubles with reproducible `vcfppR`-generated BCF reference/target pairs that
  run the real chunk, split-reference, phase, and ligate executables across
  autosomal, Y, and mitochondrial contig aliases.
- Add stateless wrappers with explicit paths, arguments, seeds, and resources;
  typed S7 results and operational errors; and typed contract conditions.
  Split-reference coordinates are canonicalized before output prediction,
  output paths must be distinct, and ligate lists are validated exactly as the
  native reader consumes them. Child executables are launched directly with
  `processx` argument vectors without an intermediate shell command.
- Build scalar and architecture-specific phase executables and select only
  runtime-supported AVX2, AVX-512F/BW/VL, or NEON backends.
- Add Unix and Rtools `configure` paths, pinned SIMDe headers, source-archive
  drift auditing, and a checksummed Boost 1.90.0 build-only source closure so
  the executables no longer depend on separately installed Boost headers or
  libraries. Use parallel native compilation with 2--8 detected make jobs,
  real executable help/linkage tests, and a synthetic native end-to-end
  conformance test across all supported SIMD backends.
- Add pkgdown configuration, package-development targets, release checks for
  Linux, macOS, and Windows, and Linux R-devel coverage. WebAssembly installs
  retain map and metadata APIs but explicitly omit GLIMPSE2 child executables
  because that runtime cannot launch the required native processes.
