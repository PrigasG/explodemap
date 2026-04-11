# Basic explodemap workflow ----------------------------------------------------
#
# This example uses a tiny synthetic sf object, so it runs without downloads.
# It is the safest first example for users learning the package API.
#
# Usage:
#   source(system.file("examples/basic_explode_sf.R", package = "explodemap"))

library(explodemap)
library(sf)

square <- function(xmin, ymin, size = 1000) {
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
  square(0, 0),
  square(3000, 0),
  square(12000, 0),
  square(15000, 0),
  crs = 3857
)

units <- st_sf(
  id = c("a1", "a2", "b1", "b2"),
  region = c("A", "A", "B", "B"),
  geometry = geom
)

result <- explode_sf(units, region_col = "region", plot = FALSE)

print(result)
summary(result)
plot(result, "both")

