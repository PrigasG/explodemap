# Optional collision refinement for dense municipal cores.
#
# Keep refine = FALSE for the pure analytical explodemap. Turn it on when
# dense same-region polygons still touch or visually crowd after displacement.
# This toy example sets alpha_r = alpha_l = 0 to isolate the refinement pass.

library(sf)
library(explodemap)

sq <- function(xmin, ymin, size = 1) {
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

dense_sf <- st_sf(
  id = c("a1", "a2", "a3", "b1", "b2", "b3"),
  region = c("A", "A", "A", "B", "B", "B"),
  geometry = st_sfc(
    sq(0, 0), sq(1, 0), sq(0, 1),
    sq(8, 0), sq(9, 0), sq(8, 1),
    crs = 3857
  )
)

result <- explode_sf(
  dense_sf,
  region_col = "region",
  alpha_r = 0,
  alpha_l = 0,
  refine = TRUE,
  refine_min_gap = 1.25,
  refine_max_shift = 0.5,
  refine_within = "region",
  plot = FALSE,
  label = "Dense example with refinement"
)

summary(result)
plot(result, "both")
