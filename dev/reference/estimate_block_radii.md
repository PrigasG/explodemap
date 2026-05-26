# Estimate block radius for each region

Computes the 85th percentile of distances from child-unit centroids to
their region centroid. The 85th percentile is preferred over the maximum
because the maximum is sensitive to outlier units and produces
over-conservative block radii.

## Usage

``` r
estimate_block_radii(
  sf_obj,
  region_col,
  quantile_p = 0.85,
  centroid_fun = c("centroid", "point_on_surface")
)
```

## Arguments

- sf_obj:

  Projected sf object with region column

- region_col:

  Grouping column name

- quantile_p:

  Quantile for radius estimation (default 0.85)

- centroid_fun:

  "centroid" or "point_on_surface"

## Value

data.frame with columns: region, block_radius, cx, cy, n_units
