# Connector geometry for computed layout movement

Builds one line per moved group or feature, from the original anchor to
the final anchor.

## Usage

``` r
connector_geometry(
  layout,
  level = c("group", "feature"),
  id_col = NULL,
  threshold_m = 1,
  include_unmoved = FALSE,
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

- threshold_m:

  Minimum movement distance to mark a connector visible.

- include_unmoved:

  Include zero-distance rows.

- require_stable_id:

  Require a real feature ID column for feature-level persistent
  handoffs. When `TRUE`, row-number fallback IDs are rejected.

## Value

An `sf` line layer with movement attributes.
