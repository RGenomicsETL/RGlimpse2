# Direct-BAM symbolic-reference conformance fixture

This synthetic fixture contains 50 phased biallelic reference records.
Record `symbolic` has ALT `<DEL>` and is surrounded by ordinary SNPs.
The two indexed BAMs are identical except for their bases at the symbolic
record. A fixed-seed direct-BAM phase run must retain that record and return
the same imputed result from both BAMs because read likelihoods at
non-observable symbolic alleles are flat.

Regenerate with:

```sh
Rscript tools/create-symbolic-bam-fixture.R /absolute/path/to/samtools
```
