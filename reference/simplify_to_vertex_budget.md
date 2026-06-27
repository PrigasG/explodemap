# Simplify geometry to a vertex budget

Simplify geometry to a vertex budget

## Usage

``` r
simplify_to_vertex_budget(
  x,
  target_vertices = 350000,
  max_tolerance = NULL,
  preserve_features = TRUE,
  preserve_topology = TRUE
)
```

## Arguments

- x:

  An `sf` object.

- target_vertices:

  Desired maximum vertex count.

- max_tolerance:

  Optional maximum simplification tolerance.

- preserve_features:

  Require row count, non-empty geometries, and polygon geometry types to
  be preserved.

- preserve_topology:

  Passed to
  [`sf::st_simplify()`](https://r-spatial.github.io/sf/reference/geos_unary.html).

## Value

An `explodemap_simplification` object.
