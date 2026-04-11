# Lookup-table grouping workflow ----------------------------------------------
#
# Use this pattern when geometry and grouping information live in separate
# files. Unmatched rows are labelled "Other"; set allow_other = TRUE to keep
# them in the output.
#
# Usage:
#   source(system.file("examples/lookup_workflow.R", package = "explodemap"))

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
  geoid = c("001", "002", "003", "004"),
  name = c("Alpha", "Beta", "Gamma", "Delta"),
  geometry = geom
)

lookup <- data.frame(
  geoid = c("001", "002", "003"),
  planning_region = c("North", "North", "South"),
  stringsAsFactors = FALSE
)

result <- explode_sf_with_lookup(
  units,
  join_col = "geoid",
  lookup = lookup,
  lookup_key = "geoid",
  region_col = "planning_region",
  allow_other = TRUE,
  plot = FALSE,
  label = "Lookup workflow"
)

print(result)
plot(result, "both")

