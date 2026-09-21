# Compare displacement between two exploded layouts

Summarises how per-feature displacement changes between two layouts of
the same input (e.g. different `alpha_r`/`alpha_l`/`gamma` choices or
before/after collision refinement). Both layouts must be of the same
class and cover the same input features in the same row order; this is
verified by comparing the original geometries pairwise, so comparing two
unrelated layouts of equal size is an error.

## Usage

``` r
compare_layouts(before, after)
```

## Arguments

- before, after:

  `exploded_map` objects (or both `grouped_exploded_map` objects) to
  compare.

## Value

A list with two elements:

- `per_feature`: `data.frame` with one row per feature and columns
  `distance_before`, `distance_after`, and `delta` (after minus before),
  in metres.

- `summary`: `data.frame` with one row per layout (`"before"`,
  `"after"`) and columns `total`, `mean`, and `max` displacement.

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
small <- explode_sf(x, region_col = "region", alpha_r = 10, alpha_l = 10,
                    plot = FALSE, quiet = TRUE)
big <- explode_sf(x, region_col = "region", alpha_r = 100, alpha_l = 100,
                  plot = FALSE, quiet = TRUE)
cmp <- compare_layouts(small, big)
cmp$summary
#>   layout total mean max
#> 1 before    40   10  20
#> 2  after   400  100 200
# }
```
