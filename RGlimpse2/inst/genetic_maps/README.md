# Packaged genetic maps

`RGlimpse2` installs these files so chunking and reference preparation can use
an explicit map without a network download. Use `rglimpse2_genetic_map()` to
resolve one installed path and `rglimpse2_genetic_maps()` to inspect the full
inventory.

## Autosomes and chromosome X

The GRCh37 and GRCh38 autosomal, X non-PAR, X PAR1, and X PAR2 maps are copied
byte-for-byte from the `maps/` directory of the pinned GLIMPSE upstream commit
`867113849925f3100bf8ff125e2b9eb1eff51b37`. Their installed MD5 checksums and
coordinate ranges are recorded in `manifest.tsv`.

The upstream files named `chrX` cover the X non-pseudoautosomal interval;
separate `chrX_par1` and `chrX_par2` files cover the pseudoautosomal regions.

## Derived zero-recombination coordinate maps

The Y non-PAR and mitochondrial files are deliberately minimal maps with two
coordinate anchors and `0` cM at both anchors. They are not empirical
recombination maps. Two entries are required by the GLIMPSE map reader.

| Assembly | Sequence | Included coordinates | Reference sequence |
|---|---|---:|---|
| GRCh37 | Y non-PAR | 2,649,521-59,034,049 | NC_000024.9 |
| GRCh38 | Y non-PAR | 2,781,480-56,887,902 | NC_000024.10 |
| GRCh37 | mitochondrial | 1-16,569 | NC_012920.1 |
| GRCh38 | mitochondrial | 1-16,569 | NC_012920.1 |

The Y intervals are the principal non-PAR intervals between the assembly's PAR1
and PAR2 boundaries. The mitochondrial reference is the revised Cambridge
Reference Sequence used by both assemblies.

A zero-recombination map does not by itself validate Y or mitochondrial
imputation. Reference-panel construction, haploid sample declarations, input
contig naming, model calibration, and output interpretation remain explicit
scientific responsibilities.

## Maintenance

From the repository root:

```sh
Rscript RGlimpse2/tools/update-genetic-maps.R
Rscript RGlimpse2/tools/check-genetic-maps.R
```

The audit requires the packaged upstream maps to remain byte-identical to the
pinned repository maps and reconstructs the four derived maps from their
coordinate specification.
