# Development targets

This directory records concise development targets. These notes are not public
API promises or validated scientific claims.

## Current engineering targets

- Keep the nested R package reproducible against the pinned GLIMPSE2 and SIMDe
  sources.
- Maintain the upstream patch series and cross-platform executable conformance.
- Preserve explicit, stateless GLIMPSE2 operation contracts and exact artifact
  handling.

## Scientific development boundary

The approved design target is fused population-labelled copying evidence,
calibrated ancestry emission, and an uncertainty-aware ancestry decoder in the
same GLIMPSE2 VCF/BCF invocation. The current package does not implement or
claim this behavior.

[`ancestry-emission.md`](ancestry-emission.md) is the architecture authority for
that work. It separates raw copying evidence from local ancestry, defines the
fine-population hierarchy and unphased diploid uncertainty contract, and records
the native, Python-free simulation gates required before scientific claims.
[`chr22-tree-sequence-benchmarks.md`](chr22-tree-sequence-benchmarks.md) records
the acceptance contract and audit status of published chromosome-22 simulation
artifacts; listed leads are not truth benchmarks until they satisfy that
contract.

Add focused notes here only when implementation work begins. Keep product,
deployment, and unrelated pipeline plans outside this repository.
