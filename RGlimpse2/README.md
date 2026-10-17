
<!-- README.md is generated from README.Rmd. Please edit README.Rmd. -->

# RGlimpse2

[![R-CMD-check](https://github.com/RGenomicsETL/RGlimpse2/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/RGenomicsETL/RGlimpse2/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/RGenomicsETL/RGlimpse2/actions/workflows/pkgdown.yaml/badge.svg)](https://rgenomicsetl.github.io/RGlimpse2/)
[![R-universe](https://RGenomicsETL.r-universe.dev/RGlimpse2/badges/version)](https://RGenomicsETL.r-universe.dev/RGlimpse2)

`RGlimpse2` runs GLIMPSE2 genotype imputation and phasing for
low-coverage whole-genome sequencing from R. It builds and installs the
pinned `GLIMPSE2_chunk`, `GLIMPSE2_split_reference`, `GLIMPSE2_phase`,
and `GLIMPSE2_ligate` programs, then invokes one child executable per
operation through direct `processx` argument vectors.

## Installation

Install development builds from the RGenomicsETL R-universe:

``` r
install.packages(
  "RGlimpse2",
  repos = c(
    RGenomicsETL = "https://rgenomicsetl.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  )
)
```

Source installation requires GNU make, a C++17 compiler, and the Boost
`iostreams`, `program_options`, and `serialization` libraries. Rtools45
ships these requirements for Windows. Linux distributions and Homebrew
provide them as ordinary development packages.

## Packaged genetic maps

GRCh37 and GRCh38 autosomal, X non-PAR, X PAR1, and X PAR2 maps are
installed with the package. Minimal zero-recombination coordinate maps
are also provided for Y non-PAR and mitochondrial sequence:

``` r
library(RGlimpse2)

rglimpse2_genetic_map("GRCh38", "22")
rglimpse2_genetic_map("GRCh38", "X", region = "par1")
rglimpse2_genetic_map("GRCh37", "Y")
rglimpse2_genetic_map("GRCh38", "Y")
rglimpse2_genetic_map("GRCh37", "chrM")
rglimpse2_genetic_map("GRCh38", "MT")
head(rglimpse2_genetic_maps())
```

| Assembly | Map | Coordinates |
|----|----|---:|
| GRCh37 | Y non-PAR | 2,649,521-59,034,049 |
| GRCh38 | Y non-PAR | 2,781,480-56,887,902 |
| GRCh37 | mitochondrial (`M`, `MT`, `chrM`, or `chrMT`) | 1-16,569 |
| GRCh38 | mitochondrial (`M`, `MT`, `chrM`, or `chrMT`) | 1-16,569 |

The Y files are explicitly named `chrY_nonpar.*.gmap.gz`. The Y and
mitochondrial files contain two anchors at `0` cM because GLIMPSE
requires at least two map entries. The native conformance tests run
small haploid BCF reference/target pairs through chunk, split-reference,
phase, and ligate using `Y`, `chrY`, `M`, `MT`, `chrM`, and `chrMT`.
This proves contig-label mechanics, not scientific calibration of Y or
mitochondrial imputation.

## One explicit operation at a time

Resolve the installed executables and run an operation with explicit
inputs, outputs, interval, seed, and resources:

``` r
library(RGlimpse2)

executables <- rglimpse2_executables(phase_backend = "auto")
if (rglimpse2_is_error(executables)) {
  stop(executables@message)
}

genetic_map <- rglimpse2_genetic_map("GRCh38", "22")

chunks <- rglimpse2_chunk(
  input_sites = "/data/reference.sites.bcf",
  region = "chr22",
  output_chunks = "/work/chunks.chr22.txt",
  executable = executables@chunk,
  genetic_map = genetic_map,
  seed = 20260727L,
  threads = 2L
)
```

Direct BAM/CRAM phasing uses the same selected phase executable. The
alignment index is supplied explicitly and must use an adjacent filename
that HTSlib will discover:

``` r
imputed <- rglimpse2_phase_bam(
  input_bam = "/data/sample.bam",
  input_index = "/data/sample.bam.bai",
  reference_bin = "/reference/chr22_100000_5000000.bin",
  output_bcf = "/work/sample.chr22.01.bcf",
  executable = executables@phase,
  seed = 20260728L,
  sample_name = "sample",
  sample_ploidy = 2L
)
```

Several samples, including mixed haploid and diploid samples, can be
passed to one native phase process without writing an intermediate
likelihood file:

``` r
alignments <- data.frame(
  input_bam = c("/data/sample-male.bam", "/data/sample-female.bam"),
  input_index = c(
    "/data/sample-male.bam.bai",
    "/data/sample-female.bam.bai"
  ),
  sample_name = c("sample-male", "sample-female"),
  sample_ploidy = c(1L, 2L)
)

imputed_cohort <- rglimpse2_phase_bams(
  alignments = alignments,
  reference_bin = "/reference/chrX_3000000_7000000.bin",
  output_bcf = "/work/cohort.chrX.01.bcf",
  executable = executables@phase,
  seed = 20260728L
)
```

CRAM input additionally requires an explicit reference FASTA and its
adjacent `.fai`. SNP likelihoods are called directly from the alignment
by default; `call_indels = TRUE` enables the GLIMPSE2 indel calling
model. Biallelic symbolic and other non-observable reference alleles
remain in the haplotype scaffold with flat read likelihoods.

Set `haplotype_samples = TRUE` in any phase wrapper to retain and export
the actual allele samples after rephasing in each main iteration.
`FORMAT/HS` packs two allele bits per draw: bits `2*d` and `2*d+1` are
the first and second haplotypes for zero-based main iteration `d`.
`NMAIN` gives the draw count (1–15); haploid second bits are zero. Dense
retention costs four bytes per input site and sample, including chunk
buffers, independently of the draw count within this bound. Export
leaves the existing GT/DS/GP calculations and random-number sequence
unchanged.

These samples preserve GLIMPSE2’s linked rephasing of alleles sampled
from per-site imputation marginals. They are not sampled
reference-copying paths or soft per-haplotype probabilities. `INFO/HSC`
identifies the input/output chunk intervals; draw indices are local to
that scope. Ligation preserves `HSC` and swaps both allele bits of every
diploid draw when it swaps GT. It rejects HS chunks with different
`NMAIN` counts or mixtures of chunks with and without samples. A
consumer must retain scope and must not concatenate the same iteration
index across independently sampled chunks into a global draw. HS
ligation consumes GLIMPSE2 phase output, whose diploid GT is complete
and phased. HS with missing or unphased diploid GT is outside this
producer contract; haploid allele samples remain unchanged. The same
ligater accepts ordinary diploid VCF/BCF chunks, including converted
QUILT2 NIPT maternal/fetal samples and categorical multiallelic
genotypes. Each input chunk supplies one local phase set per sample.
Input PS annotations are rejected, and adjacent chunks on one contig
must have strictly increasing first record positions and share identical
ordered allele records. Nested chunk extents are unsupported and fail
when the right chunk ends before the left chunk. `FORMAT/PS` records
per-sample phase sets: missing or tied informative overlap starts a
separate set, while haploid, missing and unphased genotypes have no PS.
`FORMAT/LIGATE_FLIP` records applied pair swaps and `INFO/LIGATE_CHUNK`
selects the original ordered input chunk for each complete output
record. Consumers use this source to retain matching posterior evidence;
GP/DS and biological parent-origin probabilities keep their original
allele semantics. The native export option requires VCF/BCF and rejects
checkpoint input/output.

The split-reference, phase, and ligate wrappers follow the same
contract. They do not search `PATH`, overwrite an output, build shell
command strings, or retain workflow state. Invalid calls signal typed
`rglimpse2_contract_violation` conditions; expected operational failures
are returned as typed S7 error values. Split-reference rejects unsplit
records with more or fewer than two alleles in the requested input
region before starting the native process; reference preparation owns
deterministic multiallelic decomposition.

## One htslib authority

The package does not vendor or discover another htslib. During
configuration it requires:

``` r
Rduckhts::rduckhts_htslib_config(validate = TRUE)
```

Every executable is built with the returned headers and exact library
contract. Runtime executable discovery revalidates the packaged build
version against the htslib version supplied and loaded by `Rduckhts`.

## Runtime phase dispatch

`GLIMPSE2_phase` is built as complete, process-isolated executables:

- x86_64: scalar SIMDe, AVX2, and AVX-512F/BW/VL;
- ARM: scalar SIMDe and NEON.

A baseline C probe checks CPU features and operating-system vector state
before `"auto"` selects a binary. Explicit backend selection supports
conformance and reproducibility testing without process-global dispatch
state.

``` r
rglimpse2_simd_info()
scalar <- rglimpse2_executables(phase_backend = "scalar")
```

The native tests run all four packaged GLIMPSE2 programs against eight
tiny `vcfppR`-generated and `Rduckhts`-indexed BCF reference/target
pairs. They cover `1`/`chr1`, `Y`/`chrY`, and `M`/`MT`/`chrM`/`chrMT`,
including haploid Y and mitochondrial targets, and require identical
fixed-seed phase records from every runtime-supported backend. No
executable test doubles are used.

## Building this fork

The upstream GLIMPSE2 tree remains the repository root. The R package is
nested under `RGlimpse2/`:

``` sh
make r-package-bootstrap
make r-package-check
```

Reference-panel copying evidence is an inference diagnostic. `RGlimpse2`
does not call it local ancestry; that claim requires a separately
calibrated and validated decoder.
