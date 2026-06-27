# Count geometry vertices

Counts coordinate rows in an `sf` or `sfc` object. This is a lightweight
utility for upload limits, performance warnings, simplification
decisions, and diagnostics.

## Usage

``` r
count_geometry_vertices(x)
```

## Arguments

- x:

  An `sf`, `sfc`, or geometry object accepted by
  [`sf::st_geometry()`](https://r-spatial.github.io/sf/reference/st_geometry.html).

## Value

A single numeric vertex count.
