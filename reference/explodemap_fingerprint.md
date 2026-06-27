# Fingerprint explodemap geometry and grouping

Fingerprint explodemap geometry and grouping

## Usage

``` r
explodemap_fingerprint(
  x,
  id_col = NULL,
  group_col = NULL,
  include_geometry = TRUE
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

## Value

A stable MD5 fingerprint string.
