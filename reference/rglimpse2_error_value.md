# Construct a typed RGlimpse2 operational error

Construct a typed RGlimpse2 operational error

## Usage

``` r
rglimpse2_error_value(
  message,
  kind = c("input", "output", "process"),
  code,
  details = list(),
  source = NULL,
  operation = character(),
  status = integer()
)
```

## Arguments

- message:

  Human-readable description.

- kind:

  Operational error category.

- code:

  Stable machine-readable code.

- details:

  Structured error details.

- source:

  Optional source condition or backend value.

- operation:

  Child-process operation for process errors.

- status:

  Child-process exit status when available.

## Value

An `RGlimpse2ErrorValue` subclass.
