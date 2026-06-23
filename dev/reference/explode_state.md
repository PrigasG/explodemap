# Explode a US state from TIGER/Line data

Downloads administrative boundaries automatically, groups them into
regions, derives displacement parameters via Analytical Results 1-2, and
returns an `exploded_map` S3 object.

## Usage

``` r
explode_state(
  state_fips = NULL,
  crs = NULL,
  region_map = NULL,
  level = c("cousub", "county"),
  n_regions = NULL,
  sf_data = NULL,
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
  label = if (!is.null(state_fips)) paste0("FIPS ", state_fips) else "Custom Dataset",
  quiet = FALSE
)
```

## Arguments

- state_fips:

  2-digit FIPS code (e.g. `"34"` for NJ). Required for automatic
  downloads; optional when `sf_data` is supplied.

- crs:

  Projected CRS EPSG code (metric units, e.g. `32111`). Required for
  automatic downloads; when `sf_data` is supplied the data must already
  be in a projected metric CRS and `crs` is used only for re-projection
  if the current CRS differs.

- region_map:

  Named list mapping region labels to county/COUSUB name vectors (e.g.
  `list(North = c("Bergen", "Essex"), South = c(...))`. For
  `level = "county"` this is optional; omit it to use automatic k-means
  region assignment. For `level = "cousub"` it is required.

- level:

  Boundary level: `"cousub"` (county subdivisions, default) or
  `"county"` (county polygons).

- n_regions:

  For `level = "county"` with automatic k-means assignment: integer
  number of regions. If `NULL` (default), the count is derived
  automatically as `max(2, min(6, round(sqrt(n_counties / 8))))`.
  Ignored when `region_map` is supplied.

- sf_data:

  Optional pre-projected `sf` polygon object to use instead of
  downloading from TIGER/Line. Must already have a metric projected CRS.
  For `level = "county"` with named `region_map`, the object must
  contain a `NAME` column with county names.

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

  `"centroid"` (default) or `"point_on_surface"`

- plot:

  Print plots on return (default TRUE). Automatically suppressed when
  called inside a live Shiny session; use
  [`plot.exploded_map()`](https://prigasg.github.io/explodemap/dev/reference/plot.exploded_map.md)
  inside `renderPlot()` instead.

- export:

  NULL (no export), TRUE (auto-named GeoJSON), or a file path

- label:

  Title for plots and print output

- quiet:

  If `TRUE`, suppress all
  [`message()`](https://rdrr.io/r/base/message.html) output (useful
  inside Shiny `reactive()` and `observe()` where messages are invisible
  to users). Default `FALSE`.

## Value

An `exploded_map` S3 object

## Details

Two boundary levels are supported via the `level` argument:

- `"cousub"` (default) — Census county subdivision (COUSUB) units. Best
  for the northeastern and midwestern states where municipalities tile
  the state completely. Requires a named `region_map`.

- `"county"` — county-level boundaries. Works well for all 50 states.
  `region_map` is optional: when omitted, regions are assigned
  automatically by k-means clustering on county centroids. Pass
  `n_regions` to override the automatic cluster count.

You can bypass the TIGER/Line download entirely by passing a
pre-projected `sf` object via `sf_data`. The `state_fips` argument is
then only used for the default `label`; it may be omitted if you supply
your own label.
