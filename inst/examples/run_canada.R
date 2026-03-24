# =============================================================================
# Canada Validation Example
# =============================================================================
# Non-US validation of the exploded-view framework using Statistics Canada
# 2021 Census Subdivision (CSD) boundaries.
#
# Tests whether gamma_l = 1.136 and gamma_r = 3.0 produce coherent layouts
# outside the US administrative system.
#
# Usage:
#   source(system.file("examples/run_canada.R", package = "explodemap"))
# =============================================================================

library(explodemap)
library(sf)
library(dplyr)

# Province -> Region mapping (Statistics Canada standard)
province_regions <- data.frame(
  PRUID = c("10","11","12","13", "24", "35", "46","47","48", "59", "60","61","62"),
  region = c(rep("Atlantic", 4), "Quebec", "Ontario",
             rep("Prairies", 3), "Pacific", rep("Territories", 3)),
  stringsAsFactors = FALSE
)

# Download and preprocess
download_canada_csds <- function() {
  cache_file <- file.path(path.expand("~"), "explode_map_cache", "canada_csds_2021.rds")
  if (file.exists(cache_file)) return(readRDS(cache_file))

  url <- paste0("https://www12.statcan.gc.ca/census-recensement/2021/geo/sip-pis/",
                "boundary-limites/files-fichiers/lcsd000b21a_e.zip")
  tmp <- tempfile(fileext = ".zip")
  download.file(url, tmp, mode = "wb", quiet = FALSE)
  dir <- file.path(tempdir(), "canada_csds")
  dir.create(dir, showWarnings = FALSE)
  unzip(tmp, exdir = dir)
  shp <- list.files(dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)
  obj <- st_read(shp[1], quiet = TRUE)
  dir.create(dirname(cache_file), showWarnings = FALSE, recursive = TRUE)
  saveRDS(obj, cache_file)
  obj
}

run_canada <- function(exclude_territories = FALSE) {
  message("\n=== CANADA VALIDATION ===\n")

  sf_raw <- download_canada_csds()
  sf_proj <- sf_raw |> st_transform(3347)  # Statistics Canada Lambert

  # Attach regions via PRUID
  sf_reg <- sf_proj |>
    left_join(province_regions, by = "PRUID")
  sf_reg$region[is.na(sf_reg$region)] <- "Other"

  if (exclude_territories) {
    sf_reg <- sf_reg |> filter(region != "Territories")
    message("Territories excluded. Remaining: ", nrow(sf_reg), " units.")
  }

  # Use the core package API
  result <- explode_sf(
    sf_reg, region_col = "region",
    gamma_r = 3.0, gamma_l = 1.136,
    allow_other = TRUE,
    label = if (exclude_territories) "Canada (provinces)" else "Canada (all)"
  )

  message("\n--- Validation ---")
  message("R_local/w_bar = ", round(result$stats$ratio, 2),
          "  (US dense-municipal ref: ~15.8)")

  result
}

# Run
canada <- run_canada(exclude_territories = TRUE)
