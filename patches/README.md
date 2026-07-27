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
4. safe PBWT grouping for zero-span Y non-PAR and mitochondrial maps.

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
