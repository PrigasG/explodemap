# Computed offsets from a grouped exploded layout

Returns the base movement created by `explodemap`. These offsets are
distinct from manual/editorial offsets stored by `dragmapr`.

## Usage

``` r
layout_offsets(
  layout,
  level = c("group", "feature"),
  id_col = NULL,
  require_stable_id = identical(level, "feature")
)
```

## Arguments

- layout:

  A `grouped_exploded_map`.

- level:

  Either `"group"` or `"feature"`.

- id_col:

  Optional feature ID column for `level = "feature"`.

- require_stable_id:

  Require a real feature ID column for feature-level persistent
  handoffs. When `TRUE`, row-number fallback IDs are rejected.

## Value

A data frame of computed offsets.
