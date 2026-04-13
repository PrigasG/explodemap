# Create a three-level grouped exploded map

Combines Level 1 (local explosion within regions) with Level 2/3
(anchor-based region block placement). This is the full three-level
extension from Section 12 of the paper.

## Usage

``` r
explode_grouped(
  sf_obj,
  region_col,
  mode = c("auto", "auto_collision", "manual"),
  anchors = NULL,
  alpha_l = NULL,
  p = 1.25,
  gamma_l = 1.136,
  kappa = 1.8,
  padding = 50000,
  delta = 15000,
  lambda = 0.18,
  eta = 0.18,
  padding_sep = 20000,
  max_iter = 60,
  fix_invalid = TRUE,
  centroid_fun = c("centroid", "point_on_surface"),
  plot = TRUE,
  export = NULL,
  label = "Grouped Layout"
)
```

## Arguments

- sf_obj:

  Projected sf object with region column

- region_col:

  Grouping column name

- mode:

  "auto", "auto_collision", or "manual"

- anchors:

  For mode = "manual": data.frame with anchor positions

- alpha_l:

  Local expansion parameter for Level 1 (metres)

- p:

  Distance scaling exponent (default 1.25)

- gamma_l:

  Local clearance coefficient (default 1.136); used if alpha_l is NULL

- kappa:

  Radial expansion factor (default 1.8)

- padding:

  Base padding (default 50000)

- delta:

  Log-density scaling (default 15000)

- lambda:

  Spring coefficient (default 0.18)

- eta:

  Repulsion step (default 0.18)

- padding_sep:

  Minimum block separation (default 20000)

- max_iter:

  Max collision iterations (default 60)

- fix_invalid:

  Auto-repair invalid geometries (default TRUE)

- centroid_fun:

  "centroid" or "point_on_surface"

- plot:

  Print plots (default TRUE)

- export:

  NULL, TRUE, or file path

- label:

  Title for plots

## Value

A `grouped_exploded_map` S3 object (inherits from `exploded_map`)

## Details

The guarantees of Propositions 1-3 apply strictly at Level 1. Higher
levels preserve structural grouping and directional correspondence
rather than topological coverage.
