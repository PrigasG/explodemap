# Core displacement algorithm (Algorithm 1 from the paper)

Applies the hierarchical centroid-driven displacement field to every
polygon. Each unit receives rigid-body translation t_i = alpha_r \*
dhat_state + alpha_l \* s_i \* dhat_local.

## Usage

``` r
explode_sf_core(
  sf_obj,
  region_col,
  alpha_r,
  alpha_l,
  p = 1.25,
  centroid_fun = c("centroid", "point_on_surface")
)
```

## Arguments

- sf_obj:

  Projected sf object with region column

- region_col:

  Grouping column name

- alpha_r:

  Regional separation magnitude (metres)

- alpha_l:

  Local expansion magnitude (metres)

- p:

  Distance scaling exponent (default 1.25)

- centroid_fun:

  "centroid" (default) or "point_on_surface"

## Value

Exploded sf object (same CRS as input)

## Details

Propositions 1-3 guarantee: exact geometry preservation, radial
ordering, and bounded displacement (\|\|t_i\|\| \<= alpha_r + alpha_l).
