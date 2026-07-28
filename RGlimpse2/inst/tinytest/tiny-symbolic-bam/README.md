# Direct-BAM symbolic-reference conformance fixture

This synthetic fixture contains 50 phased biallelic reference records.
Record `symbolic` has ALT `<DEL>` and record `ambiguous-reference` has
REF `N`; both are surrounded by ordinary SNPs. The two indexed BAMs are
identical except for their bases at those two records. A fixed-seed
direct-BAM phase run must retain both records and return the same imputed
results from both BAMs because direct read likelihoods are flat when an
allele is not an observable A, C, G, or T sequence.

Regenerate with:

```sh
Rscript tools/create-symbolic-bam-fixture.R /absolute/path/to/samtools
```
