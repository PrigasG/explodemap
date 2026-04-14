# explodemap

`explodemap` provides tools for hierarchical exploded-view cartography
of dense administrative boundary data.

The package generates exploded maps by applying rigid-body translations
to polygon geometries, separating units within and across regions while
preserving each feature’s internal geometry exactly. It supports both
the two-level core workflow described in the paper and a three-level
grouped layout extension for larger multi-region or national displays.

The methodology implemented here is described in:

> Arthur, G. *A Hierarchical Vector-Based Framework for Multi-Scale
> Exploded-View Cartography: Centroid-Driven Spatial Displacement for
> Dense Administrative Maps.*

## Installation

``` r
# Install from a local package source directory
devtools::install_local("path/to/explodemap")

# Or install from a tarball
install.packages("explodemap_0.2.0.tar.gz", repos = NULL, type = "source")
```

## What the package does

`explodemap` supports four main workflows:

- explode any projected sf polygon dataset using a grouping column
- explode U.S. municipal or county subdivision data directly from
  TIGER/Line via
  [`explode_state()`](https://prigasg.github.io/explodemap/reference/explode_state.md)
- generate three-level grouped layouts for national or multi-region
  displays using
  [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md)
- add interactive selected-area focus, labels, and information cards
  using
  [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  in htmlwidgets or Shiny

The package also includes analytical parameter derivation, cross-dataset
calibration helpers, optional bounded collision refinement for dense
municipal cores, and optional TopoJSON export for downstream tools such
as Power BI.

For a compact overview, see the
[cheatsheet](https://prigasg.github.io/explodemap/cheatsheet/explodemap-cheatsheet.pdf)
and the [workflow
guide](https://prigasg.github.io/explodemap/articles/workflow-guide.html).

## Quick start

``` r
library(sf)
library(explodemap)

sq <- function(xmin, ymin, size = 1000) {
  st_polygon(list(matrix(
    c(
      xmin, ymin,
      xmin + size, ymin,
      xmin + size, ymin + size,
      xmin, ymin + size,
      xmin, ymin
    ),
    ncol = 2,
    byrow = TRUE
  )))
}

geom <- st_sfc(
  sq(0, 0), sq(3000, 0),      # Region A
  sq(12000, 0), sq(15000, 0), # Region B
  crs = 3857
)

x <- st_sf(
  id = c("a1", "a2", "b1", "b2"),
  region = c("A", "A", "B", "B"),
  geometry = geom
)

result <- explode_sf(x, region_col = "region", plot = FALSE)

print(result)
plot(result, "both")
```

## Core entry points

### Explode any projected `sf` object

``` r
result <- explode_sf(my_sf, region_col = "district")
```

### Explode a US state from TIGER/Line

``` r
nj <- explode_state(
  state_fips = "34", crs = 32118,
  region_map = list(
    North   = c("Bergen","Essex","Hudson","Morris","Passaic","Sussex","Union","Warren"),
    Central = c("Hunterdon","Mercer","Middlesex","Monmouth","Somerset"),
    South   = c("Atlantic","Burlington","Camden","Cape May","Cumberland",
                "Gloucester","Ocean","Salem")
  ),
  label = "New Jersey"
)
```

### Explode using an external lookup table

``` r
groups <- read.csv("region_assignments.csv")

result <- explode_sf_with_lookup(
  my_sf, join_col = "GEOID", lookup = groups,
  lookup_key = "geoid", region_col = "region"
)
```

## Grouped layouts

For larger layouts where region blocks need to be separated at an
additional level, use
[`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md):

``` r
result <- explode_grouped(
  states_sf, region_col = "hhs_region",
  mode = "auto_collision",
  label = "US by HHS Region"
)
```

Anchor modes:

- `"auto"`: radial anchor placement
- `"auto_collision"`: radial placement with iterative collision-aware
  refinement
- `"manual"`: user-supplied positions

## Working with results

Two-level outputs are returned as exploded_map objects. Grouped layouts
are returned as grouped_exploded_map objects.

Common methods and helpers include:

``` r
print(result)           # Geometry stats and parameters
summary(result)         # Full diagnostic with implied gammas
plot(result)            # Exploded map
plot(result, "both")    # Original + exploded
calibration_row(result) # One-row data.frame for calibration tables
```

Grouped layouts also support:

``` r
plot(result, "all")       # original + local + grouped
```

## Mathematical guarantees

For the two-level core workflow, the package implements the analytical
parameter formulas described in the paper:

- alpha_r = gamma_r \* w_bar / (2 \* sin(pi / n_regions))
- alpha_l = gamma_l \* 2 \* R_local / sqrt(n_bar)

Default coefficients are:

- gamma_r = 3.0
- gamma_l = 1.136
- p = 1.25

All geometric quantities other than the gamma coefficients are computed
from the dataset itself. The gamma coefficients are dimensionless
legibility constants calibrated on New Jersey and validated across
multiple U.S. states and a Canada example.

For the two-level core, the paper states three key properties:

| Property          | Guarantee                                               | Scope       |
|-------------------|---------------------------------------------------------|-------------|
| **Proposition 1** | Internal geometry preserved exactly (rigid translation) | Per feature |
| **Proposition 2** | Radial ordering within regions preserved                | Per region  |
| **Proposition 3** | Max displacement bounded by α_r + α_l                   | Global      |

The grouped three-level extension preserves structural grouping and
directional correspondence at higher levels rather than topological
coverage.

## Parameters

Two-level parameters derived automatically via Analytical Results 1–2:

- `alpha_r = gamma_r * w_bar / (2 * sin(pi / n_regions))` — regional
  separation
- `alpha_l = gamma_l * 2 * R_local / sqrt(n_bar)` — local expansion

Defaults: `gamma_r = 3.0`, `gamma_l = 1.136`, `p = 1.25`

All quantities except `gamma_r` and `gamma_l` are computed from the
dataset geometry. The gamma coefficients are dimensionless legibility
constants calibrated from the paper examples and intended as practical
defaults. You can override `alpha_r` and `alpha_l` independently when a
particular map needs more or less visual separation.

For very dense municipal cores, you can add a bounded
collision-refinement pass after the analytical displacement:

``` r
refined <- explode_sf(
  my_sf,
  region_col = "district",
  refine = TRUE,
  refine_min_gap = 250,
  refine_max_shift = 150
)
```

This optional layer nudges close same-region neighbors apart while
capping the extra correction per feature. Use `refine_within = "all"` if
the remaining crowding crosses region boundaries.

## Examples

Small examples that run without external downloads are installed with
the package:

``` r
source(system.file("examples/basic_explode_sf.R", package = "explodemap"))
source(system.file("examples/collision_refinement.R", package = "explodemap"))
source(system.file("examples/lookup_workflow.R", package = "explodemap"))
source(system.file("examples/manual_parameter_tuning.R", package = "explodemap"))
```

Paper-scale examples that download public boundary data are also
available:

``` r
source(system.file("examples/run_calibration.R", package = "explodemap"))
source(system.file("examples/run_canada.R", package = "explodemap"))
source(system.file("examples/run_hhs.R", package = "explodemap"))
```

Interactive focus-map examples are installed as app scripts:

``` r
shiny::runApp(system.file("examples/focusmap_munis_app.R", package = "explodemap"))
shiny::runApp(system.file("examples/focusmap_counties_app.R", package = "explodemap"))
```

## Export

`explodemap` can optionally export `TopoJSON` through the external
`mapshaper` command-line tool:

``` r
export_topojson(result, "exploded.topojson")
```

This is useful for downstream tools such as Power BI. To use it, install
mapshaper separately:

``` bash
npm install -g mapshaper
```

## Vignettes

``` r
vignette("getting-started", package = "explodemap")
vignette("grouped-layouts", package = "explodemap")
```

## Citation

If you use this package in academic work, please cite:

> Arthur, G. (2026). A hierarchical vector-based framework for
> multi-scale exploded-view cartography. *Working paper*.
