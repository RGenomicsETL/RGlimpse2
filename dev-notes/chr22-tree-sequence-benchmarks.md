# Published chromosome-22 tree-sequence benchmarks

Status: source audit in progress; no artifact listed here is yet an ancestry
accuracy authority.

The first ancestry implementation accepts only chromosome-22 genomic
benchmarks. Published artifacts are preferred over locally invented simulations,
but publication and a `.trees` suffix are not enough: local-ancestry truth must
be recoverable from retained nodes or an exact truth sidecar.

## Acceptance contract

An admitted benchmark must have:

1. an immutable DOI or revision-pinned URL, license, byte size, and SHA-256;
2. an uncompressed kastore `.trees` artifact readable by the pinned tskit C API,
   or a native, audited decompressor that does not introduce Python;
3. an explicit GRCh37 or GRCh38 chromosome-22 coordinate contract;
4. declared target sample nodes and at least two namespaced source populations;
5. retained-node or sidecar semantics that define exact half-open ancestry
   intervals for each target haplotype;
6. generator, version, demographic model, seed, and reference-map provenance;
7. no overlap between calibration and held-out evaluation donors or seeds.

Large artifacts remain external and are downloaded into a checksum-addressed
cache. Package tests use only small, license-compatible derivatives with a
recorded derivation receipt.

## Audited leads

### Quebec simulated chromosome 22

- DOI: `10.5281/zenodo.7702392`
- title: *Simulated genomes from manuscript "On the Genes, Genealogies and
  Geographies of Quebec"*
- artifact: `simulated_chrom_22.ts.tsz`
- size: `600711594` bytes
- publisher checksum: `md5:d68932b161b455b1f32a6fdf1a3b0038`
- license: CC BY 4.0

This is a genuine published chromosome-22 population simulation at useful scale.
It is currently a scale/metadata candidate, not an ancestry-truth benchmark:
the deposited object is tszip-compressed and the documented pedigree does not
by itself define the required two-source local-ancestry labels. It is not
admitted until native decompression and source semantics are established.

### Haller et al. true-local-ancestry example

- paper DOI: `10.1111/1755-0998.12968`
- repository: `bhaller/SLiMTreeSeqPub`
- revision: `6715c28b02942bc4757c9f8bcab133ad4a0bfcfb`
- path: `examples/example 3 true local ancestry/`

This is the directly relevant published SLiM population-admixture recipe. It
permanently remembers source individuals and demonstrates ancestry extraction
from marginal-tree roots. The repository publishes the SLiM recipe and derived
ancestry CSV, but deliberately excludes the generated `.trees` file. Its
sequence is an abstract 100 Mb chromosome rather than an assembly-declared
chromosome 22. It is an algorithmic precedent, not an admitted artifact.

### ARGscape spatial SLiM tree

- DOI: `10.5281/zenodo.20090221`
- artifact: `spatial_wf.trees`
- size: `25772` bytes
- SHA-256: `02f214caa17fc55d54c73a040d777a7d4c884c1cffafcce514e163ec7b0df421`
- license: CC BY 4.0

Rtskit loads this published raw SLiM tree directly and reads its SLiM population
and individual metadata without Python. It is only a format-compatibility
witness: it is a 100 kb, one-population spatial simulation and cannot validate
chromosome-22 local ancestry.

### Published human chromosome-22 genealogies

The 1000 Genomes, SGDP, HGDP, and unified human genealogies on Zenodo provide
valuable chromosome-22 tree sequences, but they are inferred genealogies rather
than simulation truth and are generally deposited as `.trees.tsz`. They may be
used later for scale and panel-structure stress tests, never as exact ancestry
truth.

## Next admission step

Locate or obtain a raw chromosome-22 admixture `.trees` artifact with retained
source nodes and an exact sample/source manifest. If the only suitable deposit
is tszip-compressed, request or produce a provenance-preserving raw export using
an audited native path before it enters validation. Do not silently relabel an
abstract chromosome or treat inferred population metadata as known local
ancestry.
