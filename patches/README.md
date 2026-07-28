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
   contain only haploid samples.

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
