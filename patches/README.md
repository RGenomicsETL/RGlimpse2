# RGlimpse2 upstream patch series

RGlimpse2 preserves the GLIMPSE2 source tree at the repository root and keeps
all downstream changes to the pinned upstream sources as an explicit patch
series. The upstream authority is commit
`867113849925f3100bf8ff125e2b9eb1eff51b37`, recorded in
[`upstream.json`](upstream.json).

The patches in [`series`](series) are applied in order:

1. downstream native-build hooks and executable suffix support;
2. the mechanical port of phase HMM intrinsics to explicit pinned SIMDe APIs;
3. portable reference-environment setup on Windows;
4. safe PBWT grouping for zero-span Y non-PAR and mitochondrial maps;
5. flat direct-alignment likelihoods for symbolic and other non-observable
   decomposed single-ALT reference records; and
6. genotype-stride-aware overlap processing for cohorts whose ligated chunks
   contain only haploid samples; and
7. direct pthread declarations in the threaded phase and reference-splitting
   callers; and
8. bit-identical phase kernel optimisations: a checkpointed imputation forward
   table recomputed block by block in cache, and/andnot allele masks in the
   backward pass, a haplotype-major panel copy with a tiled 8x8 bit transpose
   for the conditioning bitmatrix, a single-pass segment transition in the
   phasing HMM with cached per-site transitions, allocation-free output
   rounding, and a sparse-PBWT selection that compacts the permutation with
   block moves and, for few target haplotypes, evaluates prefix counts from
   the run table instead of materialising them, and a 16 MB stream buffer for
   the binary panel so throttled storage sees a few large reads per panel.

9. one numerical oracle for every build: the in-tree compiler flags pin
   `-fno-fast-math -ffp-contract=off` and the AVX2 path is compiled without
   `-mfma`, matching the package build, so scalar and SIMD executables from
   either build produce the same bytes (`PHASE_SIMD_FLAGS="-mavx2 -mfma"`
   restores upstream's faster, numerically different build).

10. direct-alignment likelihood corrections adapted from upstream
    [PR #323](https://github.com/odelaneau/GLIMPSE/pull/323), preserving the
    non-observable-allele contract of patch 5, and complementary flat-site
    heterozygous haplotypes from upstream commit
    [`a18059b`](https://github.com/odelaneau/GLIMPSE/commit/a18059b72d249d32d067fd2a85e830350d7f3f45).

11. opt-in dense retention of actual post-burn-in, post-rephasing allele
    samples, packed in FORMAT/HS with a chunk-local INFO/HSC draw scope.
    Ligation swaps both allele bits in every draw when it swaps GT and
    preserves HSC; it does not join independently sampled chunks into global
    draws. Checkpoint input/output and BGEN are explicitly unsupported with
    sample export; existing default behavior is preserved.

Patches 1-7 are frozen at commit `095ebfeb09305ddb47237d04da37dcece9a707e8`.
Patch 8 captures that base through `685da6457a673fad7d89932f3cd130fd02903395`;
patch 9 captures the build flags through `5f7e69792b3755ac7c9faa694f94a0b42d405ae4`.
Patch 10 is frozen at `2f79f47711da474f6565546d51274c84ae8b4010`;
patch 11 is a diff against that commit. Layers may touch files that
earlier patches already changed.

Run `dev-notes/test-upstream-correctness.sh` for patch 10's native regression
checks; it requires a C++17 compiler and HTSlib/Boost development libraries.

`Single-ALT` describes the representation consumed by GLIMPSE2. A multiallelic
source site must be decomposed into one record per ALT before reference splitting;
the wrapper does not select one ALT and discard the others.

The fifth patch keeps those variants in the haplotype scaffold while preventing
read bases from being interpreted as likelihoods for an allele that the
SNP/indel caller cannot observe. They are therefore imputed from surrounding
SNP-anchored haplotype copying, consistent with the GLIMPSE structural-variant
imputation design described in
[PMC11951665](https://pmc.ncbi.nlm.nih.gov/articles/PMC11951665/).

The sixth patch derives the FORMAT/GT stride from each overlap record and skips
phase-switch estimation when the record contains one genotype value per sample.
Diploid and mixed-ploidy overlap behavior remains unchanged.

The R package source archive is generated from the resulting patched tree. It
also contains the pinned SIMDe headers, but not this maintenance ledger.

## Audit

From the repository root:

```sh
patches/check.sh
```

The audit reconstructs the pinned upstream tree in a temporary directory,
applies every patch in order, checks that the reconstructed files are byte-for-
byte identical to the working tree, and rejects unlisted changes in the
maintained upstream source scope.

## Updating patches

After intentionally changing an upstream file listed in `upstream.paths`:

```sh
patches/update.sh
patches/check.sh
Rscript RGlimpse2/bootstrap.R
Rscript RGlimpse2/tools/check-source-archive.R
```

Patch files are generated from the pinned upstream commit; do not hand-edit
them. Add a new logical patch and update `series`, `upstream.paths`, and the
update script when introducing a new category of upstream divergence.
