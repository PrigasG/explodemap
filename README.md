

# explodemap

Hierarchical exploded-view cartography for dense administrative maps.

A deterministic, O(n) framework for generating exploded-view maps that
separate geographic units using a hierarchical centroid-driven displacement
field while preserving each feature's geometry exactly.

Implements the methodology from:

> Arthur, G. "A Hierarchical Vector-Based Framework for Multi-Scale
> Exploded-View Cartography: Centroid-Driven Spatial Displacement for
> Dense Administrative Maps."

## Installation

```r
# From source
devtools::install_local("path/to/explodemap")

# Or install from a tarball
install.packages("explodemap_0.2.0.tar.gz", repos = NULL, type = "source")
```

## Quick start

```r
library(sf)
library(explodemap)

# Four squares in two regions
sq <- function(xmin, ymin, size = 1) {
  st_polygon(list(matrix(
    c(xmin, ymin, xmin+size, ymin, xmin+size, ymin+size, xmin, ymin+size, xmin, ymin),
    ncol = 2, byrow = TRUE)))
}

x <- st_sf(
  id     = c("a1", "a2", "b1", "b2"),
  region = c("A", "A", "B", "B"),
  geometry = st_sfc(sq(0,0), sq(2,0), sq(10,0), sq(12,0), crs = 3857)
)

result <- explode_sf(x, region_col = "region")
plot(result, "both")
```

## Three entry points

### 1. Any sf object with a grouping column

```r
result <- explode_sf(my_sf, region_col = "district")
```

### 2. US state from TIGER/Line

```r
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

### 3. External lookup table

```r
groups <- read.csv("region_assignments.csv")
result <- explode_sf_with_lookup(
  my_sf, join_col = "GEOID", lookup = groups,
  lookup_key = "geoid", region_col = "region"
)
```

## Three-level grouped layouts

For national-scale displays with region blocks (e.g., HHS regions):

```r
result <- explode_grouped(
  states_sf, region_col = "hhs_region",
  mode = "auto_collision",
  label = "US by HHS Region"
)
```

Anchor modes: `"auto"` (radial placement), `"auto_collision"` (radial +
spring-repulsion solver), `"manual"` (user-supplied positions).

## S3 methods

```r
print(result)           # Geometry stats and parameters
summary(result)         # Full diagnostic with implied gammas
plot(result)            # Exploded map
plot(result, "both")    # Original + exploded
calibration_row(result) # One-row data.frame for calibration tables
```

## Mathematical guarantees

| Property | Guarantee | Scope |
|----------|-----------|-------|
| **Proposition 1** | Internal geometry preserved exactly (rigid translation) | Per feature |
| **Proposition 2** | Radial ordering within regions preserved | Per region |
| **Proposition 3** | Max displacement bounded by α_r + α_l | Global |

## Parameters

Two-level parameters derived automatically via Analytical Results 1–2:

- `alpha_r = gamma_r * w_bar / (2 * sin(pi / n_regions))` — regional separation
- `alpha_l = gamma_l * 2 * R_local / sqrt(n_bar)` — local expansion

Defaults: `gamma_r = 3.0`, `gamma_l = 1.136`, `p = 1.25`

All quantities except `gamma_r` and `gamma_l` are computed from the dataset
geometry. The gamma coefficients are dimensionless legibility constants
calibrated on NJ and validated across multiple US states and Canada.

## Package structure

```
R/
  core.R      — Validation, stats, parameter derivation, displacement engine
  api.R       — Three public entry points + internal runner + S3 constructor
  grouped.R   — Three-level grouped layout engine (Section 12)
  methods.R   — print/plot/summary/calibration_row for S3 objects
  plot.R      — ggplot rendering helpers
  tiger.R     — TIGER/Line download, caching, region attachment
inst/
  registries/ — State registry with known-good values (NJ, PA, OH, NY)
  examples/   — Cross-state calibration, Canada validation, HHS grouped layout
vignettes/
  getting-started.Rmd  — Two-level core workflow
  grouped-layouts.Rmd  — Three-level anchor-based extension
```

## Vignettes

```r
vignette("getting-started", package = "explodemap")
vignette("grouped-layouts", package = "explodemap")
```

## Citation

If you use this package in academic work, please cite:

> Arthur, G. (2026). A hierarchical vector-based framework for multi-scale
> exploded-view cartography. *Working paper*.
