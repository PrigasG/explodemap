# Fingerprint explodemap geometry and grouping

Fingerprint explodemap geometry and grouping

## Usage

``` r
e_fingerprint(
  x,
  id_col = NULL,
  group_col = NULL,
  include_geometry = TRUE,
  include_parameters = TRUE,
  require_stable_id = FALSE
)
```

## Arguments

- x:

  An `sf` object or grouped explodemap layout.

- id_col:

  Optional feature ID column.

- group_col:

  Optional group column.

- include_geometry:

  Include EWKB geometry bytes.

- include_parameters:

  Include layout parameters and package version when `x` is a grouped
  explodemap layout.

- require_stable_id:

  Require a real feature ID column instead of row-number fallback IDs.

## Value

A stable MD5 fingerprint string.
