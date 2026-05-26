# Export an exploded map as TopoJSON

Converts an `sf`, `exploded_map`, or `grouped_exploded_map` object to
TopoJSON using the external `mapshaper` command-line tool. The input is
first written as a temporary GeoJSON file, then converted by mapshaper.

## Usage

``` r
export_topojson(x, file, simplify = NULL, overwrite = FALSE)
```

## Arguments

- x:

  An `sf`, `exploded_map`, or `grouped_exploded_map` object. For
  `exploded_map` objects, the WGS84 exploded geometry (`sf_exp_wgs`) is
  exported. For `grouped_exploded_map` objects, the WGS84 grouped
  geometry (`sf_grouped_wgs`) is exported.

- file:

  Output file path. Should end in `.topojson` or `.json`.

- simplify:

  Optional simplification proportion passed to `mapshaper -simplify`.
  Must be a single number between 0 and 1 (exclusive). For example,
  `simplify = 0.5` retains 50% of vertices. Default is `NULL` (no
  simplification). Note that simplification modifies polygon geometry
  and therefore breaks the exact geometry preservation guarantee of
  Proposition 1.

- overwrite:

  Logical; if `TRUE`, overwrite `file` if it already exists. Default is
  `FALSE`.

## Value

Invisibly returns the output file path.

## Details

This is intended as a convenience helper for downstream tools such as
Power BI, D3.js, and Observable that prefer or require TopoJSON input.

This function requires the external `mapshaper` command-line tool to be
installed and available on the system path. It can be installed with:

    npm install -g mapshaper

The `mapshaper` tool is not an R package dependency; it is invoked via
[`system2()`](https://rdrr.io/r/base/system2.html). If mapshaper is not
found, the function errors with an informative message.

## Examples

``` r
if (FALSE) { # \dontrun{
# Two-level export
result <- explode_sf(my_sf, region_col = "region", plot = FALSE)
export_topojson(result, "exploded.topojson")

# Three-level grouped export
grp <- explode_grouped(my_sf, region_col = "region", plot = FALSE)
export_topojson(grp, "grouped.topojson")

# With simplification (breaks Proposition 1 guarantee)
export_topojson(result, "simplified.topojson", simplify = 0.5)

# Raw sf object
export_topojson(my_sf, "raw.topojson", overwrite = TRUE)
} # }
```
