# Apply documented display offsets by region

Applies rigid display offsets to all features in each named region. This
is intended as a reproducible finishing step for publication or
dashboard layouts after an exploded map has already been computed.

## Usage

``` r
apply_region_offsets(
  x,
  offsets,
  region_col = NULL,
  offset_region_col = "region",
  dx_col = "dx_m",
  dy_col = "dy_m",
  update_plots = TRUE
)
```

## Arguments

- x:

  An `sf`, `exploded_map`, or `grouped_exploded_map` object.

- offsets:

  A data frame, or a path to a CSV file, containing one row per region
  and numeric offset columns.

- region_col:

  Name of the region column in `x`. For `exploded_map` and
  `grouped_exploded_map` objects, the value recorded in `x$diagnostics`
  is used when this is `NULL`.

- offset_region_col:

  Name of the region column in `offsets`.

- dx_col:

  Name of the horizontal offset column in `offsets`.

- dy_col:

  Name of the vertical offset column in `offsets`.

- update_plots:

  Logical; when `TRUE`, rebuild stored ggplot objects for exploded map
  objects.

## Value

For an `sf` input, an `sf` object with the same attributes and CRS as
`x`; geometries belonging to each listed region are translated by the
supplied offsets, and the normalized offset table is stored in the
`display_offsets` attribute. For an `exploded_map`, returns the same S3
object structure with `sf_exp`, `sf_exp_wgs`, stored plots, and
`display_offsets` updated. For a `grouped_exploded_map`, returns the
same S3 object structure with `sf_grouped`, `sf_grouped_wgs`, stored
plots, and `display_offsets` updated. The offsets are rigid
translations, so polygon shape, area, and within-region relative
geometry are preserved.

## Details

Offsets are interpreted in the coordinate units of the projected
geometry being adjusted. The default column names `dx_m` and `dy_m`
assume a metric projected CRS, matching the package's exploded-map
workflow.

## Examples

``` r
library(sf)
#> Warning: package 'sf' was built under R version 4.5.2
#> Linking to GEOS 3.13.1, GDAL 3.11.4, PROJ 9.7.0; sf_use_s2() is TRUE
x <- st_sf(
  region = c("A", "B"),
  geometry = st_sfc(
    st_point(c(0, 0)),
    st_point(c(10, 0)),
    crs = 3857
  )
)
offsets <- data.frame(region = "B", dx_m = 5, dy_m = 2)
apply_region_offsets(x, offsets, region_col = "region")
#> Simple feature collection with 2 features and 1 field
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 0 ymin: 0 xmax: 15 ymax: 2
#> Projected CRS: WGS 84 / Pseudo-Mercator
#>   region     geometry
#> 1      A  POINT (0 0)
#> 2      B POINT (15 2)
```
