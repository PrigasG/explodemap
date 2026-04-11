# Manual parameter tuning ------------------------------------------------------
#
# The default workflow derives alpha_r and alpha_l from geometry. Users can
# still override either one independently when a map needs a visual adjustment.
#
# Usage:
#   source(system.file("examples/manual_parameter_tuning.R", package = "explodemap"))

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
  square(2000, 0),
  square(10000, 0),
  square(12000, 0),
  crs = 3857
)

units <- st_sf(
  id = c("a1", "a2", "b1", "b2"),
  region = c("A", "A", "B", "B"),
  geometry = geom
)

derived <- explode_sf(units, region_col = "region", plot = FALSE)

# Increase only regional separation; keep derived local expansion.
more_region_gap <- explode_sf(
  units,
  region_col = "region",
  alpha_r = derived$params$alpha_r * 1.5,
  plot = FALSE,
  label = "More regional gap"
)

# Increase only local expansion; keep derived regional separation.
more_local_gap <- explode_sf(
  units,
  region_col = "region",
  alpha_l = derived$params$alpha_l * 1.5,
  plot = FALSE,
  label = "More local gap"
)

print(derived)
print(more_region_gap)
print(more_local_gap)

