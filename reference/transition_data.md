# Renderer-neutral transition data

Describes original-to-final movement for groups or features. Rendering
systems can use this table for SVG, MapLibre, deck.gl, or static
animation plans without inspecting layout internals.

## Usage

``` r
transition_data(
  layout,
  level = c("group", "feature"),
  id_col = NULL,
  ordering = NULL,
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

- ordering:

  Optional ordering column for `level = "feature"`.

- require_stable_id:

  Require a real feature ID column for feature-level persistent
  handoffs. When `TRUE`, row-number fallback IDs are rejected.

## Value

A data frame with movement, distance, angle, and animation order.
