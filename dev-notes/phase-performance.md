# GLIMPSE2_phase performance

Status: measured profile and first bit-identical optimisations (patch 0008);
further changes listed here are targets, not promises.

Benchmark: 1000G chr22 chunk 3 (`chr22:20934583-23734632`), 6,198 reference
haplotypes, 75,064 sites (35,210 common), 100 held-out samples with simulated
1x PLs, defaults (Kpbwt 2000, 5 burn-in + 15 main). Machine: i5-13500 (6P+8E),
DRAM streaming ceiling ~27 GB/s write. Truth genotypes for the 100 samples give
a concordance baseline (GLIMPSE2_concordance r2 0.981 at AF 20-50%, 0.924 at
1-5%, 0.476 below 0.1%; +-0.005 between runs with different thread counts).

## Profile before patch 0008

- Single thread: 0.28 s per individual-iteration. Imputation HMM 44%
  (backward 25%, forward 19%), phasing HMM 37%, state selection 14%.
- 14 threads: 0.94 CPU-s per individual-iteration. The forward table
  (57,650 polymorphic sites x 1,952 states x 4 B = 450 MB per haplotype pass)
  is streamed to DRAM and back; 100 samples demand ~25 GB/s against a 27 GB/s
  ceiling. Wall 588 s / 215 s / 158 s / 152 s for 1 / 4 / 8 / 14 threads,
  10.5 GB peak RSS.
- Hot lines: `imputation_hmm.cpp` forward-table loads and the 0/1 mask blends
  in `backward()`; `phasing_hmm.h` RUN_PEAK_HOM core, TRANS_HAP, and
  IMPUTE_FLAT_HET reading the ~270 MB imputeProb table; the per-bit Hvar gather
  in `conditioning_set.cpp`.

## Patch 0008 (byte-identical)

1. `imputation_hmm`: forward rows kept every `CKPT_BLOCK` (64) sites, blocks
   recomputed in the backward pass with the same arithmetic; allele split of
   alpha*beta with and/andnot masks.
2. `ref_haplotype_set::buildHapMajor` + `conditioning_set::buildCommonRows`:
   haplotype-major panel copy (built once at load) and tiled 8x8 bit transpose
   instead of one random bit read per (site, state).
3. `phasing_hmm`: TRANS_HAP in one pass with one accumulator per lane; per-site
   transitions cached; branchless mismatch multiply (x * 1.0f == x).
4. `genotype_writer`: fixed three-slot ordered set instead of a std::map per
   sample and site.
5. `haplotype_set::init_common`: the permutation compaction at each
   rare-to-common transition moves the gaps between dropped positions as blocks
   (no per-call `std::vector<bool>`, no per-element bit test). This was 23% of a
   single-sample run.
6. `haplotype_set::read_full_pbwt_av`: with <= 16 target haplotypes the prefix
   counts V are not materialised; the decode records the runs of the site and
   `pbwt_V(x)` evaluates the exact count on demand.

7. `caller::read_binary_reference_panel`: 16 MB stream buffer so the panel is
   read with a few large read calls (about 37 one-megabyte I/Os instead of
   ~300 readahead-sized ones).

Low-IOPS storage (device-mapper delay of 20 ms per I/O plus a 100 IOPS cgroup
cap, cold cache): one single-sample chunk 10.8 s (baseline) -> 5.8 s; with 14
concurrent single-sample processes each loading its own panel copy the panel
load per process is 7.1 s with the old reader and 4.9 s with the large buffer
(14 x 37 MB through 100 IOPS at ~1 MB per I/O), BAM reads 0.3-0.6 s, writes
0.2 s. Prefetching the next chunk's panel inside one sample hides ~0.6 s per
chunk and competes for the same budget. Cohort mode loads one panel per chunk
for any number of samples and is the I/O-optimal regime; single-sample mode
multiplies panel I/O by the number of samples.

Single-sample regime (one 1x BAM, this chunk): 8.35 s -> 4.56 s wall, 1.07 GB
-> 0.26 GB. Per iteration: HMM 0.18 s (phasing ~0.10, imputation ~0.065,
Hvar ~0.015), PBWT selection 0.03 s. Nothing in a single-sample run uses more
than one thread; parallelism comes from running chunks as separate processes.

Verification: `bcftools view -H | md5sum` identical to the previous executable
for a 10-sample single-thread run on the AVX2 build and on the portable SIMDe
build. The shared global `rng` (`common/src/utils/otools.h`) is read by all
worker threads without a lock, so multi-threaded runs are not reproducible and
byte-identity can only be asserted single-threaded.

## Review (GPT-6 Astra via pi, 2026-10-08, 19 per-hunk requests)

Applied: the phasing kernels' unconditional `* 1.0f` was reverted to the
conditional multiply (not identical if the floating-point environment sets
DAZ without FTZ, and it bought nothing); `std::uint64_t` and a `CHAR_BIT`
assertion in the transpose helper; explicit `<array>`, `<algorithm>`,
`<cstring>` and `<cassert>` includes; `pbwt_lazy_V` default-initialised and the
run buffers reserved only in lazy mode; the 16 MB reader buffer made optional
(falls back to the default buffer on `bad_alloc`); comments qualified (the
and/andnot masks equal the blend-multiply only for finite non-negative
values, which is the domain here; `pubsetbuf` behaviour is library-specific).
Noted, not changed: the haplotype-major copy doubles the common-site panel in
memory; unused tail bits of the last Hvar byte are now zero instead of stale
(never read); NaN keys have no defined `std::map` ordering either way; sample
checksums do not prove identity for every input. Visual write-ups:
profile https://claude.ai/artifact/JTQmAUgN1iv8dAvcQMNsqn, patch walkthrough
https://claude.ai/artifact/CKS8vhUsp5N4cctN7RVxcB.

## Measured under the unified oracle (patch 0009, no FMA)

Same inputs, pre-0008 tree and 0008 both built with the shipped flags:
single-sample BAM chunk 8.43 -> 4.67 s (1.81x), RSS 1.07 -> 0.29 GB; 100
samples on 1 thread 589 -> 421 s (1.40x), RSS 1.13 -> 0.36 GB; 100 samples on
14 threads 165 -> 100 s (1.65x), RSS 9.95 -> 3.39 GB. Outputs identical
(record checksums) for the single-sample and single-thread runs. Compared with
the earlier FMA-build figures (1.82x / 1.39x / 1.85x) only the 14-thread ratio
moves: without fused multiply-adds the optimised HMM is more compute-bound on
this machine's E-cores (optimised 14-thread run 82 -> 100 s), while the
bandwidth-bound baseline barely changes. The FMA build remains available with
`PHASE_SIMD_FLAGS="-mavx2 -mfma"`.

## Oracle definition

All builds now share one oracle: `-fno-fast-math -ffp-contract=off` and no
`-mfma` (patch 0009 for the in-tree makefile; the package build already had
both). Under it, on the 10-sample fixture, the in-tree default build, the
in-tree no-SIMD build, the package scalar and AVX2 executables, and the
pre-0008 tree built the same way all give record checksum
`7f52d43e73beb697736d09c42622ff58`; 0008 takes the fixture from 59.6 s to
42.8 s there. GCC contracts scalar `a*b+c` into FMA in C++ mode even under
`-std=c++17` when `-mfma` is on, which is why an explicit pin is needed and
why upstream's `-mavx2 -mfma` build is a different (self-consistent) oracle.

## Remaining targets

- Phasing HMM homozygous runs: ~85% of phasing sites are homozygous for the
  sampled haplotypes; an algebraic shortcut (diagonal emission product factored
  out, states grouped by mismatch count) would make a run of m such sites cost
  O(K + 8m) instead of O(8Km). Not bit-identical; validate with the concordance
  harness.
- AVX-512 kernels using mask registers directly from Hvar bits (the current
  AVX-512 build only changes flags).
- Phasing on posterior-pruned states; deterministic iterations instead of
  Gibbs (changes GP semantics; separate validation).
- Per-individual RNG streams for reproducible multi-threaded runs.
- Parallel PBWT selection and NUMA-aware first-touch only matter for large
  panels or multi-socket hosts.
