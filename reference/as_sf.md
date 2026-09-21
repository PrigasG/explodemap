# Extract plain sf geometry from an exploded layout

Converts an `exploded_map` or `grouped_exploded_map` back to a plain
`sf` data frame so the layout can flow into downstream GIS work (writing
files, spatial joins, further `sf` analysis) without carrying the layout
metadata.

## Usage

``` r
as_sf(layout, which = c("exploded", "original"))
```

## Arguments

- layout:

  An `exploded_map` or `grouped_exploded_map` object.

- which:

  Which stored geometry layer to return. For `exploded_map`:
  `"exploded"` (default) or `"original"`. For `grouped_exploded_map`:
  `"grouped"` (default), `"local"`, or `"original"`.

## Value

A plain `sf` object with the selected geometry layer active. All
attribute columns and the CRS are kept as stored. Layout metadata
(`stats`, `params`, `plots`, `refinement`, `diagnostics`, `anchors`) is
dropped. The `"exploded"`/`"grouped"` layers carry the displaced
geometries; `"original"` carries the input geometries.

## Examples

``` r
# \donttest{
sq <- function(xmin, ymin, size = 1) {
  sf::st_polygon(list(matrix(
    c(xmin, ymin, xmin + size, ymin, xmin + size, ymin + size,
      xmin, ymin + size, xmin, ymin),
    ncol = 2, byrow = TRUE
  )))
}
x <- sf::st_sf(
  id = c("a1", "a2", "b1", "b2"),
  region = c("A", "A", "B", "B"),
  geometry = sf::st_sfc(sq(0, 0), sq(2, 0), sq(10, 0), sq(12, 0), crs = 3857)
)
layout <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)

# Displaced geometries, ready for st_write() or further analysis
exp_sf <- as_sf(layout)
sf::st_crs(exp_sf)
#> Coordinate Reference System:
#>   User input: EPSG:3857 
#>   wkt:
#> PROJCRS["WGS 84 / Pseudo-Mercator",
#>     BASEGEOGCRS["WGS 84",
#>         ENSEMBLE["World Geodetic System 1984 ensemble",
#>             MEMBER["World Geodetic System 1984 (Transit)"],
#>             MEMBER["World Geodetic System 1984 (G730)"],
#>             MEMBER["World Geodetic System 1984 (G873)"],
#>             MEMBER["World Geodetic System 1984 (G1150)"],
#>             MEMBER["World Geodetic System 1984 (G1674)"],
#>             MEMBER["World Geodetic System 1984 (G1762)"],
#>             MEMBER["World Geodetic System 1984 (G2139)"],
#>             ELLIPSOID["WGS 84",6378137,298.257223563,
#>                 LENGTHUNIT["metre",1]],
#>             ENSEMBLEACCURACY[2.0]],
#>         PRIMEM["Greenwich",0,
#>             ANGLEUNIT["degree",0.0174532925199433]],
#>         ID["EPSG",4326]],
#>     CONVERSION["Popular Visualisation Pseudo-Mercator",
#>         METHOD["Popular Visualisation Pseudo Mercator",
#>             ID["EPSG",1024]],
#>         PARAMETER["Latitude of natural origin",0,
#>             ANGLEUNIT["degree",0.0174532925199433],
#>             ID["EPSG",8801]],
#>         PARAMETER["Longitude of natural origin",0,
#>             ANGLEUNIT["degree",0.0174532925199433],
#>             ID["EPSG",8802]],
#>         PARAMETER["False easting",0,
#>             LENGTHUNIT["metre",1],
#>             ID["EPSG",8806]],
#>         PARAMETER["False northing",0,
#>             LENGTHUNIT["metre",1],
#>             ID["EPSG",8807]]],
#>     CS[Cartesian,2],
#>         AXIS["easting (X)",east,
#>             ORDER[1],
#>             LENGTHUNIT["metre",1]],
#>         AXIS["northing (Y)",north,
#>             ORDER[2],
#>             LENGTHUNIT["metre",1]],
#>     USAGE[
#>         SCOPE["Web mapping and visualisation."],
#>         AREA["World between 85.06°S and 85.06°N."],
#>         BBOX[-85.06,-180,85.06,180]],
#>     ID["EPSG",3857]]

# The untouched input geometries
orig_sf <- as_sf(layout, which = "original")
# }
```
