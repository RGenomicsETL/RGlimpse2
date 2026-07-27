# RGlimpse2: explicit process-isolated GLIMPSE2 operations

RGlimpse2 packages a pinned GLIMPSE2 fork and exposes one stateless
wrapper per native executable. Contract violations are typed conditions;
expected operational failures are typed values. The package never
searches `PATH`, does not construct shell command strings, and does not
overwrite outputs.

## Details

The package links GLIMPSE2 only to the htslib contract supplied and
validated by `Rduckhts`. Scalar, AVX2, AVX-512, and NEON phase
executables are separate child-process artifacts selected explicitly at
runtime. Pinned GRCh37 and GRCh38 genetic maps are available through
explicit lookup functions. No ancestry decoder or workflow state is
embedded in this package.

## See also

Useful links:

- <https://github.com/RGenomicsETL/RGlimpse2>

- <https://rgenomicsetl.github.io/RGlimpse2/>

- Report bugs at <https://github.com/RGenomicsETL/RGlimpse2/issues>

## Author

**Maintainer**: Sounkou Mahamane Toure <sounkoutoure@gmail.com>

Authors:

- Sounkou Mahamane Toure <sounkoutoure@gmail.com>

Other contributors:

- Simone Rubinacci (GLIMPSE2 upstream implementation) \[contributor,
  copyright holder\]

- Olivier Delaneau (GLIMPSE2 upstream implementation) \[contributor,
  copyright holder\]

- Evan Nemerson (SIMDe copyright holder) \[copyright holder\]
