# Compute geometry statistics for parameter derivation

Extracts w_bar, R_local, n_bar, n_regions, and the tightness ratio from
a projected sf object with a grouping column.

## Usage

``` r
compute_stats(
  sf_obj,
  region_col,
  centroid_fun = c("centroid", "point_on_surface")
)
```

## Arguments

- sf_obj:

  Projected sf object

- region_col:

  Name of the grouping column

- centroid_fun:

  "centroid" (default) or "point_on_surface"

## Value

A named list of geometry statistics
