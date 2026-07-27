# Construct a typed RGlimpse2 contract condition

Construct a typed RGlimpse2 contract condition

## Usage

``` r
rglimpse2_contract_violation(
  message,
  call = NULL,
  code = "invalid_contract",
  details = list()
)
```

## Arguments

- message:

  Human-readable description.

- call:

  Call associated with the violation.

- code:

  Stable machine-readable code.

- details:

  Structured condition details.

## Value

An `rglimpse2_contract_violation` condition.
