# A typed RGlimpse2 operational error value

Invalid calls signal
[`rglimpse2_contract_violation()`](https://rgenomicsetl.github.io/RGlimpse2/reference/rglimpse2_contract_violation.md)
conditions. Expected missing inputs, occupied outputs, unavailable
executables, and child-process failures are returned as values so
callers can branch without parsing messages.

## Usage

``` r
RGlimpse2ErrorValue(
  message = character(0),
  code = character(0),
  details = list(),
  source = NULL
)

RGlimpse2InputErrorValue(
  message = character(0),
  code = character(0),
  details = list(),
  source = NULL
)

RGlimpse2OutputErrorValue(
  message = character(0),
  code = character(0),
  details = list(),
  source = NULL
)

RGlimpse2ProcessErrorValue(
  message = character(0),
  code = character(0),
  details = list(),
  source = NULL,
  operation = character(0),
  status = integer(0)
)
```

## Arguments

- message:

  Human-readable description.

- code:

  Stable machine-readable code.

- details:

  Structured error details.

- source:

  Optional source condition or backend value.

- operation:

  Stable child-process operation identifier.

- status:

  Child-process exit status when available.
