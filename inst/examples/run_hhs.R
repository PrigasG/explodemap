# =============================================================================
# HHS Grouped Layout Example
# =============================================================================
# Three-level national grouped layout using HHS regions.
# Demonstrates auto and auto_collision anchor modes.
#
# Usage:
#   source(system.file("examples/run_hhs.R", package = "explodemap"))
# =============================================================================

library(explodemap)
library(sf)
library(dplyr)

# HHS Region assignments (50 states + DC + territories)
hhs_lookup <- data.frame(
  STUSPS = c(
    "CT","ME","MA","NH","RI","VT",             # Region 1
    "NJ","NY","PR","VI",                       # Region 2
    "DE","DC","MD","PA","VA","WV",             # Region 3
    "AL","FL","GA","KY","MS","NC","SC","TN",   # Region 4
    "IL","IN","MI","MN","OH","WI",             # Region 5
    "AR","LA","NM","OK","TX",                  # Region 6
    "IA","KS","MO","NE",                       # Region 7
    "CO","MT","ND","SD","UT","WY",             # Region 8
    "AZ","CA","HI","NV","GU","AS","MP",        # Region 9
    "AK","ID","OR","WA"                        # Region 10
  ),
  hhs_region = c(
    rep("1", 6), rep("2", 4), rep("3", 6), rep("4", 8),
    rep("5", 6), rep("6", 5), rep("7", 4), rep("8", 6),
    rep("9", 7), rep("10", 4)
  ),
  stringsAsFactors = FALSE
)

run_hhs <- function(mode = "auto_collision") {
  message("\n=== HHS GROUPED LAYOUT ===\n")

  # Download state boundaries (use TIGER/Line states)
  cache_file <- file.path(path.expand("~"), "explode_map_cache", "us_states.rds")
  if (file.exists(cache_file)) {
    states_sf <- readRDS(cache_file)
  } else {
    url <- "https://www2.census.gov/geo/tiger/TIGER2024/STATE/tl_2024_us_state.zip"
    tmp <- tempfile(fileext = ".zip")
    download.file(url, tmp, mode = "wb", quiet = TRUE)
    dir <- file.path(tempdir(), "us_states")
    dir.create(dir, showWarnings = FALSE)
    unzip(tmp, exdir = dir)
    shp <- list.files(dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)
    states_sf <- st_read(shp[1], quiet = TRUE)
    dir.create(dirname(cache_file), showWarnings = FALSE, recursive = TRUE)
    saveRDS(states_sf, cache_file)
  }

  # Project to Albers Equal Area and attach HHS regions
  states_proj <- states_sf |>
    st_transform(5070) |>
    left_join(hhs_lookup, by = "STUSPS")

  states_proj$hhs_region[is.na(states_proj$hhs_region)] <- "Other"

  # Run grouped explosion
  result <- explode_grouped(
    states_proj, region_col = "hhs_region",
    mode = mode,
    alpha_l = 120000, p = 1.25,
    kappa = 1.8, padding = 80000, delta = 20000,
    lambda = 0.18, eta = 0.18,
    padding_sep = 30000, max_iter = 60,
    label = paste("US by HHS Region (", mode, ")")
  )

  result
}

# Run with collision-aware anchors
hhs <- run_hhs("auto_collision")
