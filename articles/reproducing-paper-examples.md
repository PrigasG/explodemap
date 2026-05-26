# Reproducing the paper examples

## Overview

This vignette reproduces the key examples from:

> Arthur, G. “A Hierarchical Vector-Based Framework for Multi-Scale
> Exploded-View Cartography.”

Each section corresponds to a result in the paper and uses the package
API directly, including
[`explode_state()`](https://prigasg.github.io/explodemap/reference/explode_state.md),
[`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md),
[`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md),
[`layout_regions()`](https://prigasg.github.io/explodemap/reference/layout_regions.md),
and
[`calibration_row()`](https://prigasg.github.io/explodemap/reference/calibration_row.md).

This vignette is designed for reproduction rather than routine package
checks. Several sections download external boundary files and may take
substantial time and disk space. Heavy chunks are therefore marked
`eval = FALSE`.

Reported values should match the paper within rounding tolerance.
Externally downloaded datasets may introduce small differences if source
files change over time.

``` r

library(explodemap)
library(sf)
#> Warning: package 'sf' was built under R version 4.5.2
#> Linking to GEOS 3.13.1, GDAL 3.11.4, PROJ 9.7.0; sf_use_s2() is TRUE
library(dplyr)
#> Warning: package 'dplyr' was built under R version 4.5.2
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
```

------------------------------------------------------------------------

## 1. New Jersey — Ground-truth calibration (Section 5)

New Jersey is the calibration dataset. The known-good parameters
($`\alpha_r = 6{,}000`$ m, $`\alpha_l = 10{,}000`$ m) were established
by visual validation and are used to derive the legibility coefficients
$`\gamma_r`$ and $`\gamma_l`$.

``` r

nj <- explode_state(
  state_fips = "34", crs = 32118,
  region_map = list(
    North   = c("Bergen", "Essex", "Hudson", "Morris",
                "Passaic", "Sussex", "Union", "Warren"),
    Central = c("Hunterdon", "Mercer", "Middlesex",
                "Monmouth", "Somerset"),
    South   = c("Atlantic", "Burlington", "Camden", "Cape May",
                "Cumberland", "Gloucester", "Ocean", "Salem")
  ),
  label = "New Jersey"
)

summary(nj)
```

**Expected output (key values):**

| Quantity                                      | Value    |
|-----------------------------------------------|----------|
| n units                                       | 564      |
| n regions                                     | 3        |
| w_bar                                         | 3.94 km  |
| R_local                                       | 62.4 km  |
| n_bar                                         | 177      |
| R_local/w_bar                                 | 15.83    |
| alpha_r (derived)                             | 6,844 m  |
| alpha_l (derived)                             | 10,641 m |
| gamma_r implied (from known alpha_r = 6,000)  | 2.64     |
| gamma_l implied (from known alpha_l = 10,000) | 1.136    |

The implied $`\gamma_l = 1.136`$ from the New Jersey ground truth
becomes the recommended default for transfer to other datasets.

------------------------------------------------------------------------

## 2. Pennsylvania — Transfer test (Section 6)

Pennsylvania tests whether New Jersey-calibrated coefficients transfer
to a larger, denser dataset without retuning. The paper reports
formula-derived parameters $`\alpha_r = 20{,}174`$ m and
$`\alpha_l = 12{,}447`$ m.

The region map is defined as a reusable object so that both the transfer
run and the sensitivity analysis reference the same grouping:

``` r

pa_region_map <- list(
  Southeast    = c("Philadelphia", "Delaware", "Chester",
                   "Montgomery", "Bucks"),
  Northeast    = c("Pike", "Monroe", "Carbon", "Northampton", "Lehigh",
                   "Luzerne", "Lackawanna", "Wayne", "Susquehanna",
                   "Wyoming", "Sullivan", "Columbia", "Montour",
                   "Schuylkill", "Berks", "Bradford"),
  Central      = c("Centre", "Clinton", "Lycoming", "Tioga", "Potter",
                   "Cameron", "Elk", "Clearfield", "Jefferson", "Indiana",
                   "Blair", "Huntingdon", "Mifflin", "Snyder", "Union",
                   "Northumberland", "Juniata", "Perry", "Dauphin",
                   "Lebanon"),
  SouthCentral = c("York", "Adams", "Lancaster", "Cumberland", "Franklin",
                   "Fulton", "Bedford", "Somerset", "Cambria"),
  Southwest    = c("Allegheny", "Westmoreland", "Fayette", "Greene",
                   "Washington", "Beaver", "Butler", "Armstrong",
                   "Lawrence"),
  Northwest    = c("Erie", "Crawford", "Mercer", "Venango", "Clarion",
                   "Forest", "Warren", "McKean")
)
```

``` r

pa <- explode_state(
  state_fips = "42", crs = 26918,
  region_map = pa_region_map,
  label = "Pennsylvania"
)

summary(pa)
```

**Expected output (key values):**

| Quantity          | Value     |
|-------------------|-----------|
| n units           | 2,572     |
| n regions         | 6         |
| w_bar             | 6,725 m   |
| R_local           | 116,086 m |
| n_bar             | 449       |
| R_local/w_bar     | 17.26     |
| alpha_r (derived) | 20,174 m  |
| alpha_l (derived) | 12,447 m  |

### Sensitivity analysis

The paper reports that $`\alpha_l`$ is stable under $`\pm 15\%`$
perturbation:

``` r

alpha_l_canonical <- 12447
alpha_r_canonical <- 20174

factors <- c(0.85, 0.90, 0.95, 1.00, 1.05, 1.10, 1.15)
labels  <- c("-15%", "-10%", "-5%", "canonical", "+5%", "+10%", "+15%")

rows <- list()
for (i in seq_along(factors)) {
  run <- explode_state(
    state_fips = "42", crs = 26918,
    region_map = pa_region_map,
    alpha_r = alpha_r_canonical,
    alpha_l = round(alpha_l_canonical * factors[i]),
    plot = FALSE, export = FALSE,
    label = paste0("PA ", labels[i])
  )
  rows[[i]] <- calibration_row(run)
  rows[[i]]$label <- labels[i]
  rows[[i]]$factor <- factors[i]
}

sensitivity_df <- bind_rows(rows)
print(sensitivity_df)
```

**Expected output:**

| Label     | alpha_l | Mean displacement |
|-----------|---------|-------------------|
| -15%      | 10,580  | ~20,476 m         |
| -10%      | 11,202  | ~20,524 m         |
| -5%       | 11,825  | ~20,575 m         |
| canonical | 12,447  | ~20,630 m         |
| +5%       | 13,069  | ~20,688 m         |
| +10%      | 13,692  | ~20,749 m         |
| +15%      | 14,314  | ~20,813 m         |

Mean displacement CV across the $`\pm 15\%`$ range is $`< 0.02`$,
confirming stability.

------------------------------------------------------------------------

## 3. Cross-state calibration (Section 7)

The state registry in `inst/registries/state_registry.R` contains New
Jersey, Pennsylvania, Ohio, and New York. The calibration runner
processes all registered states and reports gamma stability.

``` r

source(system.file("registries/state_registry.R", package = "explodemap"))

calib_rows <- list()
for (key in names(state_registry)) {
  reg <- state_registry[[key]]

  result <- tryCatch(
    explode_state(
      state_fips = reg$fips, crs = reg$crs,
      region_map = reg$region_map,
      allow_other = TRUE, plot = FALSE,
      label = reg$name
    ),
    error = function(e) {
      message("ERROR: ", e$message)
      NULL
    }
  )

  if (is.null(result)) next
  calib_rows[[key]] <- calibration_row(result)
}

calib_df <- bind_rows(calib_rows)
print(calib_df)
```

**Expected output (approximate):**

| State        | n     | Regions | w_bar (km) | R_local (km) | Ratio | gamma_r | gamma_l |
|--------------|-------|---------|------------|--------------|-------|---------|---------|
| New Jersey   | 564   | 3       | 3.94       | 62.4         | 15.83 | 2.64\*  | 1.136\* |
| Pennsylvania | 2,572 | 6       | 6.73       | 116.1        | 17.26 | 3.72\*  | 1.136   |
| Ohio         | 1,602 | 5       | 7.31       | 93.1         | 12.75 | 3.00    | 1.136   |
| New York     | 1,794 | 5       | 10.04      | 97.2         | 9.68  | 3.00    | 1.136   |

\* Implied from known ground-truth parameters.

The key finding is that $`\gamma_l = 1.136`$ is stable across states,
while $`\gamma_r`$ varies more, indicating that regional clearance still
benefits from dataset-specific visual validation.

------------------------------------------------------------------------

## 4. Ohio — Extended validation (Section 7)

Ohio provides a five-region test with three competing urban cores
(Cleveland, Columbus, Cincinnati):

``` r

oh <- explode_state(
  state_fips = "39", crs = 32617,
  region_map = list(
    Northeast = c("Cuyahoga", "Summit", "Lorain", "Lake", "Medina",
                  "Portage", "Geauga", "Ashtabula", "Trumbull", "Mahoning",
                  "Columbiana", "Carroll", "Stark", "Wayne", "Holmes",
                  "Harrison", "Jefferson"),
    Northwest = c("Lucas", "Wood", "Fulton", "Williams", "Defiance",
                  "Paulding", "Henry", "Putnam", "Hancock", "Sandusky",
                  "Erie", "Ottawa", "Seneca", "Wyandot", "Crawford",
                  "Huron", "Ashland", "Richland", "Morrow", "Knox",
                  "Marion", "Hardin", "Logan", "Union", "Delaware",
                  "Allen", "Van Wert", "Auglaize", "Shelby", "Mercer"),
    Central   = c("Franklin", "Licking", "Fairfield", "Pickaway",
                  "Madison", "Fayette", "Ross", "Clark", "Greene",
                  "Montgomery", "Preble", "Darke", "Miami", "Champaign"),
    Southwest = c("Hamilton", "Butler", "Warren", "Clermont", "Clinton",
                  "Highland", "Brown", "Adams", "Scioto", "Lawrence",
                  "Gallia", "Jackson", "Pike"),
    Southeast = c("Belmont", "Monroe", "Washington", "Meigs", "Morgan",
                  "Noble", "Guernsey", "Muskingum", "Perry", "Hocking",
                  "Athens", "Tuscarawas", "Coshocton", "Vinton")
  ),
  label = "Ohio"
)

summary(oh)
plot(oh, "both")
```

**Expected output:** $`R_{\text{local}}/\bar{w} = 12.75`$, placing Ohio
in the dense-municipal cluster. All three urban cores are correctly
suppressed by the $`s_i`$ term.

------------------------------------------------------------------------

## 5. Canada — Non-US validation (Section 7)

The Canada validation tests whether the framework transfers outside the
US administrative system entirely. Data comes from Statistics Canada
2021 Census Subdivisions.

``` r

province_regions <- data.frame(
  PRUID  = c("10", "11", "12", "13", "24", "35",
             "46", "47", "48", "59", "60", "61", "62"),
  region = c(rep("Atlantic", 4), "Quebec", "Ontario",
             rep("Prairies", 3), "Pacific",
             rep("Territories", 3)),
  stringsAsFactors = FALSE
)
```

``` r

cache_file <- file.path(path.expand("~"), "explode_map_cache",
                        "canada_csds_2021.rds")

if (file.exists(cache_file)) {
  sf_raw <- readRDS(cache_file)
} else {
  url <- paste0(
    "https://www12.statcan.gc.ca/census-recensement/2021/geo/sip-pis/",
    "boundary-limites/files-fichiers/lcsd000b21a_e.zip"
  )
  tmp <- tempfile(fileext = ".zip")
  download.file(url, tmp, mode = "wb")
  dir <- file.path(tempdir(), "canada_csds")
  dir.create(dir, showWarnings = FALSE)
  unzip(tmp, exdir = dir)
  shp <- list.files(dir, "\\.shp$", recursive = TRUE, full.names = TRUE)
  sf_raw <- st_read(shp[1], quiet = TRUE)
  dir.create(dirname(cache_file), showWarnings = FALSE, recursive = TRUE)
  saveRDS(sf_raw, cache_file)
}
```

``` r

sf_proj <- sf_raw |>
  st_transform(3347) |>
  left_join(province_regions, by = "PRUID")

sf_proj$region[is.na(sf_proj$region)] <- "Other"

sf_prov <- sf_proj |>
  filter(region != "Territories")

canada <- explode_sf(
  sf_prov,
  region_col = "region",
  allow_other = TRUE,
  label = "Canada (provinces)"
)

summary(canada)
plot(canada, "both")
```

**Expected output:**

| Quantity      | Value                          |
|---------------|--------------------------------|
| n units       | ~4,800 (excluding territories) |
| n regions     | 5                              |
| R_local/w_bar | ~113                           |

The tightness ratio is an order of magnitude larger than in the US state
examples because Canadian CSDs include vast northern municipalities. The
formula-derived parameters still produce a coherent layout, illustrating
that the method can remain usable even in extreme tightness-ratio
regimes.

------------------------------------------------------------------------

## 6. HHS national grouped layout (Section 12)

The three-level extension places US states into 10 HHS region blocks
using anchor-based placement with collision refinement.

``` r

hhs_lookup <- data.frame(
  STUSPS = c(
    "CT", "ME", "MA", "NH", "RI", "VT",
    "NJ", "NY", "PR", "VI",
    "DE", "DC", "MD", "PA", "VA", "WV",
    "AL", "FL", "GA", "KY", "MS", "NC", "SC", "TN",
    "IL", "IN", "MI", "MN", "OH", "WI",
    "AR", "LA", "NM", "OK", "TX",
    "IA", "KS", "MO", "NE",
    "CO", "MT", "ND", "SD", "UT", "WY",
    "AZ", "CA", "HI", "NV", "GU", "AS", "MP",
    "AK", "ID", "OR", "WA"
  ),
  hhs_region = c(
    rep("1", 6), rep("2", 4), rep("3", 6), rep("4", 8),
    rep("5", 6), rep("6", 5), rep("7", 4), rep("8", 6),
    rep("9", 7), rep("10", 4)
  ),
  stringsAsFactors = FALSE
)
```

``` r

cache_file <- file.path(path.expand("~"), "explode_map_cache",
                        "us_states.rds")

if (file.exists(cache_file)) {
  states_sf <- readRDS(cache_file)
} else {
  url <- "https://www2.census.gov/geo/tiger/TIGER2024/STATE/tl_2024_us_state.zip"
  tmp <- tempfile(fileext = ".zip")
  download.file(url, tmp, mode = "wb", quiet = TRUE)
  dir <- file.path(tempdir(), "us_states")
  dir.create(dir, showWarnings = FALSE)
  unzip(tmp, exdir = dir)
  shp <- list.files(dir, "\\.shp$", recursive = TRUE, full.names = TRUE)
  states_sf <- st_read(shp[1], quiet = TRUE)
  dir.create(dirname(cache_file), showWarnings = FALSE, recursive = TRUE)
  saveRDS(states_sf, cache_file)
}
```

``` r

states_proj <- states_sf |>
  st_transform(5070) |>
  left_join(hhs_lookup, by = "STUSPS")

states_proj$hhs_region[is.na(states_proj$hhs_region)] <- "Other"

hhs <- explode_grouped(
  states_proj,
  region_col   = "hhs_region",
  mode         = "auto_collision",
  alpha_l      = 120000,
  p            = 1.25,
  kappa        = 1.8,
  padding      = 80000,
  delta        = 20000,
  lambda       = 0.18,
  eta          = 0.18,
  padding_sep  = 30000,
  max_iter     = 60,
  label        = "US by HHS Region"
)

print(hhs)
plot(hhs, "all")
```

**Expected output:** The anchor solver converges within 60 iterations.
All 10 HHS regions are separated with a recognisable continental
arrangement. The `auto_collision` mode produces substantially more
legible output than `auto` alone because the spring-repulsion solver
reduces block overlaps in the densely packed Northeast corridor.

------------------------------------------------------------------------

## Replication checklist

After running all sections above, verify:

New Jersey implied $`\gamma_l \approx 1.136`$ from known
$`\alpha_l = 10{,}000`$ m

Pennsylvania formula-derived $`\alpha_l = 12{,}447`$ m from
$`\gamma_l = 1.136`$

Pennsylvania sensitivity CV $`< 0.02`$ for mean displacement across
$`\pm 15\%`$

Cross-state $`R_{\text{local}}/\bar{w}`$ clusters around dense-unit and
large-unit regimes

Canada layout remains coherent at
$`R_{\text{local}}/\bar{w} \approx 113`$

HHS anchor solver converges with all 10 regions separated

All values should match those reported in the paper within rounding
tolerance.

Together, these examples cover the paper’s calibration, transfer,
cross-state, international, and grouped-layout results using the package
API.

------------------------------------------------------------------------

## Session info

``` r

sessionInfo()
#> R version 4.5.1 (2025-06-13 ucrt)
#> Platform: x86_64-w64-mingw32/x64
#> Running under: Windows 11 x64 (build 26200)
#> 
#> Matrix products: default
#>   LAPACK version 3.12.1
#> 
#> locale:
#> [1] LC_COLLATE=English_United States.utf8 
#> [2] LC_CTYPE=English_United States.utf8   
#> [3] LC_MONETARY=English_United States.utf8
#> [4] LC_NUMERIC=C                          
#> [5] LC_TIME=English_United States.utf8    
#> 
#> time zone: America/New_York
#> tzcode source: internal
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] dplyr_1.2.0      sf_1.1-0         explodemap_0.2.0
#> 
#> loaded via a namespace (and not attached):
#>  [1] jsonlite_2.0.0     compiler_4.5.1     tidyselect_1.2.1   Rcpp_1.1.1        
#>  [5] jquerylib_0.1.4    systemfonts_1.3.1  textshaping_1.0.4  yaml_2.3.12       
#>  [9] fastmap_1.2.0      R6_2.6.1           generics_0.1.4     classInt_0.4-11   
#> [13] knitr_1.51         htmlwidgets_1.6.4  tibble_3.3.1       desc_1.4.3        
#> [17] units_1.0-0        DBI_1.3.0          bslib_0.10.0       pillar_1.11.1     
#> [21] rlang_1.1.7        cachem_1.1.0       xfun_0.56          fs_1.6.6          
#> [25] sass_0.4.10        otel_0.2.0         cli_3.6.5          pkgdown_2.2.0     
#> [29] magrittr_2.0.4     class_7.3-23       digest_0.6.39      grid_4.5.1        
#> [33] lifecycle_1.0.5    vctrs_0.7.1        KernSmooth_2.23-26 proxy_0.4-29      
#> [37] evaluate_1.0.5     glue_1.8.0         ragg_1.5.0         e1071_1.7-17      
#> [41] rmarkdown_2.30     tools_4.5.1        pkgconfig_2.0.3    htmltools_0.5.9
```
