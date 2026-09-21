# Per-feature displacement magnitudes of an exploded layout

Measures how far each feature moved from its original position by
comparing feature centroids before and after displacement. Useful for
summarising a layout and for comparing parameter choices (see
[`compare_layouts()`](https://prigasg.github.io/explodemap/reference/compare_layouts.md)).

## Usage

``` r
displacement_magnitudes(layout)
```

## Arguments

- layout:

  An `exploded_map` or `grouped_exploded_map` object.

## Value

A `data.frame` with one row per feature (in feature order) and columns
`dx`, `dy` (signed displacement components) and `distance` (Euclidean
displacement magnitude), all in metres.

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
head(displacement_magnitudes(layout))
#>            dx dy   distance
#> 1 -3.29911536  0 3.29911536
#> 2 -0.08602214  0 0.08602214
#> 3  0.08602214  0 0.08602214
#> 4  3.29911536  0 3.29911536
# }
```
