# Fused copying evidence and ancestry inference

Status: design target; not implemented and not a public API promise.

This document is the architecture authority for the proposed ancestry work in
RGlimpse2. It records the model boundaries, data flow, validation obligations,
and unresolved pressures before native interfaces are added. Implemented
behavior remains authoritative in source, the ordered `patches/series`, and
executable tests.

## Objective

Extend the pinned GLIMPSE2 phase executable so that the Li--Stephens work it
already performs can also produce population-labelled reference-copying
evidence, aggregate that evidence into ancestry emissions, decode local
ancestry, and write the result into the same VCF/BCF as the phased and imputed
genotypes.

The target flow is:

```text
reference haplotype annotations
        |
GLIMPSE selected reference states
        |
alpha x beta state posterior already computed by GLIMPSE
        |
fine-panel copying evidence
        |
calibrated panel-to-ancestry emission
        |
fast unordered-diploid ancestry HMM
        |
genotype + ancestry fields in one VCF/BCF
```

"One pass" means one GLIMPSE phase invocation and no second read or second HMM
run over the genomic input. GLIMPSE's mathematically necessary forward and
backward traversals remain. A final ordered VCF/BCF writing traversal, and a
bounded transpose spool if required by sample-major inference versus
variant-major VCF layout, are not additional inference passes.

## Non-negotiable invariants

1. With ancestry disabled, GLIMPSE genotype records must remain semantically
   identical to the pinned scalar oracle.
2. Raw copying evidence is not called local ancestry. A local-ancestry claim
   requires the calibrated ancestry model and simulation evidence described
   below.
3. Fine populations are model leaves. Broad labels such as `AFR`, `EUR`, or
   `EAS` are reporting ancestors, not substitutes for populations such as
   `1KG:YRI`, `1KG:GBR`, or `1KG:JPT`.
4. Dataset-qualified identifiers prevent apparently similar panels from being
   silently equated. For example, `1KG:YRI` and `HGDP:Yoruba` are distinct
   leaves unless an explicit calibrated model relates them.
5. A reporting hierarchy and empirical panel affinity are different objects.
   Official superpopulation/geographic groupings are not treated as a
   population phylogeny.
6. Haplotype-slot exchangeability is preserved. Evidence is not averaged into
   phased haplotype tracks across Gibbs iterations without an explicit,
   validated orientation model.
7. The ancestry model, reference assignment, hierarchy, calibration, and
   output all carry one content fingerprint. A model cannot be used with a
   differently ordered reference panel.
8. No Python interpreter, Python package, `reticulate`, or Python fallback is
   part of implementation, validation, or package operation.
9. Every downstream GLIMPSE source change is an ordered patch under `patches/`
   and is included in the source-archive reconstruction audit.
10. Scalar execution is the numerical oracle. SIMD backends must satisfy the
    declared ancestry-emission tolerance as well as genotype conformance.

## Current GLIMPSE2 insertion point

For each target individual and selected conditioning set,
`phase/src/caller/caller_algorithm.cpp` invokes
`imputation_hmm::computePosteriors()` for the first target haplotype and, for a
diploid, again for the second. `phase/src/models/imputation_hmm.cpp` already
stores the scaled forward table and traverses backward while combining forward
and backward quantities to calculate allele posteriors.

At polymorphic locus `l` and selected state `k`, the normalized quantity
corresponding to

```text
gamma[l, k] proportional to alpha[l, k] * beta[l, k]
```

is the sufficient state-copying evidence. The aggregation must occur at the
same point in `imputation_hmm::backward()` at which the correctly scaled state
contribution is available. Reconstructing it later from sampled haplotypes or
from the output genotype probabilities would discard information and require a
second model run.

`conditioning_set::idxHaps_ref[k]` maps selected state `k` to the stable,
zero-based reference haplotype index. This is the join key to the ancestry model.
The selected set changes by individual and iteration, so both posterior mass
and selected-panel availability must be recorded. Raw group mass alone can
confound ancestry evidence with panel size and PBWT selection.

## Ancestry model bundle

The model is an explicit, checksummed bundle rather than hard-coded population
names. Its conceptual tables are:

### Nodes

```text
node_id       parent_id       level          label             source
1KG:YRI       1KG:AFR         population     Yoruba in Ibadan  1000G
1KG:AFR       ROOT            superpopulation African          1000G
ROOT          .               root           All               model
```

Each non-root node has exactly one reporting parent in the first implementation.
A later relatedness graph must not be smuggled into this containment relation.
Parent posterior mass is derived by summing descendant leaf mass.

### Reference assignments

```text
hap_index     leaf_id         weight
0             1KG:YRI         1
1             1KG:YRI         1
```

Multiple rows per haplotype permit probabilistic annotation, but weights for a
haplotype must be finite, non-negative, and sum to one. Hard assignments are the
first validated scope. The bundle records the expected reference haplotype
count, order fingerprint, assembly, contig naming policy, and source provenance.

### Empirical affinity/calibration

A separate matrix describes how an ancestry source can copy from one or more
observed reference panels. It is estimated with held-out or leave-one-out
reference copying evidence. This is the analogue of the panel-mixture pressure
made explicit by FLARE/FLARE2 and is what permits imperfect or missing leaf
references without pretending that a broad reporting parent is a homogeneous
population.

The physical TSV/binary representation is not public until a parser, a producer,
a consumer, and round-trip fixtures agree. The R layer will validate and compile
the authored model into a deterministic native input; GLIMPSE will validate the
fingerprint again before inference.

## Evidence layers

The implementation keeps three semantics distinct.

### 1. Reference-copying evidence

For target haplotype slot `h`, locus `l`, and reference leaf/panel `p`, aggregate
normalized state posterior mass over selected states whose reference
annotations include `p`:

```text
copy_mass[h, l, p] = sum_k gamma[l, k] * annotation[ref_index[k], p]
```

Also aggregate selected-state availability by panel. These are diagnostics of
the GLIMPSE conditioning model, not calibrated ancestry posteriors.

### 2. Ancestry emissions

Copying evidence is aggregated over declared genetic windows and transformed
through the calibrated panel-affinity model into likelihoods for unordered
population pairs `(p, q)`. Window definitions use the same genetic map as
GLIMPSE and are stored in the output provenance.

ARCHes averages evidence within haplotype-model windows and uses unordered
diploid population-pair emissions. RGlimpse2 follows the unphased-pair principle
because it is invariant to target haplotype-slot swaps, but its emission formula
must be validated for GLIMPSE state posteriors rather than described as an
ARCHes reimplementation.

### 3. Local-ancestry posterior and calls

A genome-wide ancestry HMM smooths window emissions. Its first exact scope has
unordered diploid leaf-pair states. Transitions allow no change or a change in
one member of the pair between adjacent windows. Initial/stationary ancestry
weights and switch parameters are explicit model values or are fitted by a
bounded, deterministic procedure.

The production transition update must exploit the one-member-change structure
rather than materialize a dense transition matrix. The performance target is
linear in windows and no worse than quadratic in the number of leaf ancestries.
A small dense implementation is retained as an independent numerical oracle.

## Hierarchy and uncertainty

The published ARCHes model does not put a population taxonomy directly into its
ancestry HMM. Its uncertainty handling comes from an unphased diploid-pair HMM,
posterior path sampling, and reporting/benchmark aggregation of fine regions to
continental levels. Its paper also reports underestimated confidence intervals.
BEAGLE's haplotype-cluster graph is a different hierarchy from a population
taxonomy.

RGlimpse2 therefore treats hierarchical uncertainty as an explicit extension:

1. infer and retain posterior mass over fine, namespaced leaf populations;
2. sum leaf mass exactly to every reporting ancestor;
3. report the deepest node whose coverage/calibration rule is satisfied;
4. retain the complete leaf posterior so a broad call does not erase
   uncertainty among descendants.

A confident parent call with diffuse child mass is valid. A parent is not used
as a catch-all latent source merely because its child reference panels are poor.
Unrepresented sources and poor panel matching are separate calibration cases.

## Haplotype orientation

GLIMPSE samples and rephases two target haplotypes during its Gibbs iterations.
The labels of the two internal haplotype slots can exchange between iterations.
Consequently, independently averaging `haplotype 1` and `haplotype 2` ancestry
vectors across main iterations can manufacture uncertainty or swap tracts.

The primary accumulated object is therefore the unordered diploid pair
emission/posterior. A phased ancestry representation may be produced only by an
orientation step that is aligned to the final phased genotype and is tested
against known-truth phase switches. LoGicAl-style `pi1`/`pi2` output depends on
this oriented result; it cannot be obtained by relabelling an unordered pair.

## Same-VCF/BCF output

Ancestry-enabled phase writes one indexed VCF/BCF containing the ordinary
GLIMPSE genotype fields plus optional ancestry data. The eventual field contract
must distinguish:

- raw reference-copying evidence and availability;
- calibrated ancestry posterior probabilities;
- unordered diploid ancestry calls;
- optional validated phased ancestry calls;
- hierarchy/model metadata and content fingerprint.

Fine-leaf ordering and parent relationships belong in structured header records.
Broad-node probabilities are derived and need not be duplicated for every
sample and marker.

Full probability vectors can be stored only at declared genetic-window anchor
records, while compact calls can be projected across member variants. An
explicit all-markers mode may be supported if its output-size contract is
acceptable. Exact FORMAT/INFO IDs remain provisional until FLARE interoperability,
htslib round trips, missing-value behavior, haploid records, and file-size tests
are executable.

GLIMPSE inference is sample-major while VCF/BCF output is variant-major. Large
ancestry vectors must not become an unbounded in-memory `samples x windows x
populations` object. If a transpose is required, workers write deterministic,
fixed-schema sample results to a bounded spool with explicit ownership; the
single writer consumes it in sample order and removes it only after an atomic
successful output close. Worker completion order must not alter bytes or
floating-point reduction order.

## Native simulation and validation framework

Validation has no Python path.

### Native components

- focused C/C++ exhaustive HMM and pedigree-mosaic generators;
- SLiM's C++ executable with authored Eidos scenarios for forward simulations;
- the stable tskit C API for `.trees` loading, traversal, simplification, and
  exact ancestry-interval extraction;
- R for orchestration, manifests, metrics, and reports;
- `vcfppR` and `Rduckhts` for deterministic VCF/BCF/GL construction and indexing.

A future standalone `Rtskit` package is a direct C binding to the tskit C API and
is of general interest, but RGlimpse2 must not require it at runtime. Validation
may use it when available while retaining native command-line truth extraction
as an independent path.

### Truth authority

Each simulation produces one checksummed `.trees` file as the ancestry and
pedigree truth authority. Genotypes, low-coverage likelihoods, ancestry BED/TSV,
and evaluation inputs are derived from that same artifact. Real-panel mosaic
simulations use held-out 1000 Genomes/HGDP haplotypes, the packaged genetic map,
and explicit donor tracts; reference/test leakage is prohibited.

### Validation tiers

1. **Exact kernel fixtures**
   - enumerate tiny HMM state paths;
   - compare state, panel, pair, and hierarchy posteriors;
   - test normalization, zero evidence, missing panels, haploids, and slot swaps;
   - require ancestry-disabled genotype non-regression;
   - compare scalar and every runtime-supported SIMD backend.

2. **Held-out real-panel mosaics**
   - construct exact ancestry tracts from 1000 Genomes and HGDP donors;
   - simulate low coverage across a declared coverage grid;
   - vary admixture time, proportions, tract length, and phase uncertainty;
   - test balanced and severely unequal panel sizes;
   - remove the true leaf panel and retain sister/proxy panels;
   - introduce bounded label noise and missing likelihoods.

3. **Forward population simulations**
   - use pinned SLiM/Eidos scenarios and tskit tree-sequence recording;
   - include unseen or poorly represented populations and hierarchical sisters;
   - preserve exact local ancestry from founder/population metadata.

4. **External scientific comparisons**
   - use kalis as a Li--Stephens copying-posterior oracle without copying its
     GPL-3 source into this MIT fork;
   - compare decoded local ancestry with pinned FLARE on compatible inputs;
   - propagate calibrated phased probabilities and genotype likelihoods through
     LoGicAl and measure ancestry-specific allele-frequency error.

### Required metrics

At leaf and every reporting level:

- log loss, Brier score, calibration curves, and coverage;
- unordered diploid local concordance;
- hierarchical distance of incorrect calls;
- tract and breakpoint accuracy;
- global ancestry bias and RMSE;
- LoGicAl ancestry-specific allele-frequency bias/RMSE;
- genotype dosage, GP calibration, and imputation accuracy non-regression;
- elapsed time, peak memory, spool size, and final bytes per sample/window/leaf.

Performance reports record revision, model hash, simulator pin, seed, hardware,
threads, input dimensions, and output dimensions. No accuracy or speed claim is
made from package tiny fixtures alone.

## Planned patch boundaries

The numbering is provisional until each patch exists, but logical boundaries
must remain reviewable:

1. `0005`: parse and validate reference annotations; expose normalized selected
   state contributions from the imputation backward pass; emit raw copying and
   availability evidence without changing genotype output.
2. `0006`: define deterministic genetic-window aggregation and same-VCF/BCF
   storage with model/hierarchy provenance.
3. `0007`: add the exact unordered-pair oracle and optimized ancestry decoder.
4. `0008`: add hierarchy roll-up, calibrated resolution calls, and optional
   phased orientation only after its truth tests pass.

Each patch updates `patches/series`, `patches/upstream.paths`, regeneration,
source archive, NEWS, and native tests together.

## Attribution and pinned references

Design and validation must cite and pin the exact revisions used as oracles:

- Wang et al. (2021), ARCHes, DOI `10.1186/s12859-021-04350-x`;
- Aslett and Christ (2024), kalis, DOI `10.1186/s12859-024-05688-8`;
- Browning laboratory FLARE and the FLARE2 preprint,
  DOI `10.1101/2025.10.13.681993`;
- Wang and Zöllner (2025), LoGicAl;
- tskit C API and SLiM releases used by simulation receipts.

External code is not copied merely because it is relevant. Algorithmic
adaptation, source reuse, and oracle comparison are distinguished explicitly,
with license notices and provenance for any incorporated source.

## Open pressures requiring executable evidence

- Whether GLIMPSE's selected-state posterior is best calibrated as direct panel
  mass, panel-size-corrected evidence, or through a learned affinity transform.
- The ancestry window width and whether fixed-cM, fixed-marker, or adaptive
  windows best preserve low-coverage information.
- Whether phased orientation can be stable enough for per-haplotype posterior
  output across Gibbs iterations.
- Whether anchor-only posterior FORMAT fields interoperate cleanly enough with
  FLARE- and LoGicAl-oriented consumers.
- How much hierarchy should affect inference versus only uncertainty-aware
  reporting.
- Whether bounded EM fitting of ancestry proportions/switch rates improves
  calibration without reproducing ARCHes's reported overfitting pressure.

These are not hidden defaults or future public arguments. Each becomes an API
choice only after a counterexample, an implemented alternative, and simulation
evidence establish the distinction.
