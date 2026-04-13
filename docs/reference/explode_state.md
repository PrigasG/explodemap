# Explode a US state from TIGER/Line data

Downloads municipal boundaries automatically, groups by county-to-region
mapping, derives parameters via Analytical Results 1-2, and returns an
`exploded_map` S3 object.

## Usage

``` r
explode_state(
  state_fips,
  crs,
  region_map,
  gamma_r = 3,
  gamma_l = 1.136,
  p = 1.25,
  alpha_r = NULL,
  alpha_l = NULL,
  refine = FALSE,
  refine_min_gap = NULL,
  refine_max_shift = NULL,
  refine_max_iter = 20,
  refine_step = 0.5,
  refine_within = c("region", "all"),
  allow_other = FALSE,
  fix_invalid = TRUE,
  centroid_fun = c("centroid", "point_on_surface"),
  plot = TRUE,
  export = NULL,
  label = paste0("FIPS ", state_fips)
)
```

## Arguments

- state_fips:

  2-digit FIPS code (e.g. "34" for NJ)

- crs:

  Projected CRS EPSG code (metric units)

- region_map:

  Named list: region_name -\> character vector of county names

- gamma_r:

  Regional clearance coefficient (default 3.0)

- gamma_l:

  Local clearance coefficient (default 1.136)

- p:

  Distance scaling exponent (default 1.25)

- alpha_r:

  Optional manual override for regional separation (metres). May be
  supplied independently of `alpha_l`.

- alpha_l:

  Optional manual override for local expansion (metres). May be supplied
  independently of `alpha_r`.

- refine:

  If TRUE, apply a bounded collision-refinement pass after the
  analytical displacement. Default is FALSE.

- refine_min_gap:

  Optional minimum boundary-to-boundary gap in map units. If NULL and
  `refine = TRUE`, uses 2% of the characteristic diameter.

- refine_max_shift:

  Optional maximum correction per feature in map units. If NULL and
  `refine = TRUE`, uses 10% of `alpha_r + alpha_l`.

- refine_max_iter:

  Maximum refinement iterations.

- refine_step:

  Fraction of each gap deficit corrected per iteration.

- refine_within:

  Refine pairs within each `"region"` (default) or across `"all"`
  features.

- allow_other:

  If TRUE, permits units mapped to "Other"

- fix_invalid:

  If TRUE, auto-repairs invalid geometries

- centroid_fun:

  "centroid" (default) or "point_on_surface"

- plot:

  Print plots on return (default TRUE)

- export:

  NULL (no export), TRUE (auto-named GeoJSON), or a file path

- label:

  Title for plots and print output

## Value

An `exploded_map` S3 object
