# RGlimpse2 phasing-executable dispatch information

RGlimpse2 dispatches whole child executables rather than mutating a
backend in the R process. The scalar SIMDe executable is always the
fallback. A native executable is selected only when it was built and the
package's baseline CPUID/HWCAP probe confirms CPU and operating-system
support.

## Usage

``` r
RGlimpse2SimdInfo(
  requested_backend = character(0),
  selected_backend = character(0),
  compiled_backends = character(0),
  cpu_supported_backends = character(0),
  available_backends = character(0),
  phase_executable = character(0),
  target_arch = character(0),
  target_os = character(0)
)
```

## Arguments

- requested_backend:

  Requested backend (`"auto"`, `"scalar"`, `"avx2"`, `"avx512"`, or
  `"neon"`).

- selected_backend:

  Resolved backend.

- compiled_backends:

  Backends represented by installed executables.

- cpu_supported_backends:

  Backends supported by the runtime CPU and OS.

- available_backends:

  Intersection of compiled and CPU-supported backends.

- phase_executable:

  Selected absolute executable path.

- target_arch, target_os:

  Baseline probe target identifiers.
