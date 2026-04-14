# Compute region anchor positions for grouped layouts

Implements the anchor layout procedure from Section 12. Supports three
modes: automatic radial placement, automatic with collision resolution,
and manual user-specified anchors.

## Usage

``` r
layout_regions(
  sf_obj,
  region_col,
  mode = c("auto", "auto_collision", "manual"),
  anchors = NULL,
  kappa = 1.8,
  padding = 50000,
  delta = 15000,
  lambda = 0.18,
  eta = 0.18,
  padding_sep = 20000,
  max_iter = 60,
  quantile_p = 0.85,
  centroid_fun = c("centroid", "point_on_surface")
)
```

## Arguments

- sf_obj:

  Projected sf object with region column

- region_col:

  Grouping column name

- mode:

  "auto" (radial only), "auto_collision" (radial + solver), or "manual"

- anchors:

  For mode = "manual": data.frame with columns (region_col, anchor_x,
  anchor_y)

- kappa:

  Radial expansion factor (default 1.8)

- padding:

  Base padding in map units (default 50000)

- delta:

  Log-density scaling factor (default 15000)

- lambda:

  Spring coefficient for collision solver (default 0.18)

- eta:

  Repulsion step size for collision solver (default 0.18)

- padding_sep:

  Minimum separation between blocks (default 20000)

- max_iter:

  Max iterations for collision solver (default 60)

- quantile_p:

  Quantile for block radius estimation (default 0.85)

- centroid_fun:

  "centroid" or "point_on_surface"

## Value

data.frame with region, anchor_x, anchor_y, block_radius, n_units
