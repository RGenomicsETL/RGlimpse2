# Read-fraction conformance fixture

Eight synthetic templates, `pair1` through `pair8`, each have two 10-base
alignments (SAM flags 99 and 147) at separate SNP positions in the
`tiny-symbolic-bam` reference interval. The mates do not overlap.

Samtools 1.22 with seed zero retains these hand-counted templates:

| Fraction | Names | Reads |
| --- | --- | ---: |
| 0.25 | pair7 | 2 |
| 0.5 | pair2, pair4, pair7 | 6 |
| 0.75 | pair1, pair2, pair4, pair6, pair7, pair8 | 12 |
| 1 | pair1–pair8 | 16 |

The indexed BAM subsets are independent imputation oracles. The CRAM contains
all 16 reads with embedded sequence (`no_ref=1`); the accompanying all-A FASTA
provides an explicit offline reference. Tests compare decoded BCF header and
record bytes, excluding only the wall-clock `fileDate` header.

Regenerate from the repository root:

```sh
Rscript RGlimpse2/tools/create-read-fraction-fixture.R /absolute/path/to/samtools
```

`dev-notes/test-read-fraction.sh` compares the actual pre-pileup loader's
read names and flags against samtools at seeds zero and 17. It also compares
native phase output at seed 17 with phase output from samtools-subsampled BAM.
Pass the HTSlib include directory, shared library, samtools executable, and
installed GLIMPSE2 binary directory as its four arguments.
