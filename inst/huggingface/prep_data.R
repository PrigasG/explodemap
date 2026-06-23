# =============================================================================
# prep_data.R — Bake Census boundary data into .rds for the explodemap gallery
# =============================================================================
#
# Runs ONCE at Docker build time (and on demand locally). It downloads the
# cartographic-boundary layers the gallery needs and saves them as plain .rds
# so the running app has ZERO network dependency and an instant cold start.
#
#   <ABBR>_counties.rds   counties for each demo state
#   <ABBR>_munis.rds      county subdivisions (+ county name) for each demo state
#   us_states.rds         national states in EPSG:5070 with an HHS region column
#
# Output dir resolves from APP_DATA_DIR, else <this-script-dir>/data.
# Re-running is cheap: existing, loadable files are skipped unless FORCE=TRUE.
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tigris)
})

options(tigris_use_cache = TRUE)

YEAR  <- 2024
FORCE <- tolower(Sys.getenv("PREP_FORCE", "false")) %in% c("1", "true", "yes")

# All 50 US states — used by the Counties tab dropdown.
COUNTY_STATES <- data.frame(
  name = c(
    "Alabama", "Alaska", "Arizona", "Arkansas", "California",
    "Colorado", "Connecticut", "Delaware", "Florida", "Georgia",
    "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa",
    "Kansas", "Kentucky", "Louisiana", "Maine", "Maryland",
    "Massachusetts", "Michigan", "Minnesota", "Mississippi", "Missouri",
    "Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey",
    "New Mexico", "New York", "North Carolina", "North Dakota", "Ohio",
    "Oklahoma", "Oregon", "Pennsylvania", "Rhode Island", "South Carolina",
    "South Dakota", "Tennessee", "Texas", "Utah", "Vermont",
    "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
  ),
  abbr = c(
    "AL", "AK", "AZ", "AR", "CA",
    "CO", "CT", "DE", "FL", "GA",
    "HI", "ID", "IL", "IN", "IA",
    "KS", "KY", "LA", "ME", "MD",
    "MA", "MI", "MN", "MS", "MO",
    "MT", "NE", "NV", "NH", "NJ",
    "NM", "NY", "NC", "ND", "OH",
    "OK", "OR", "PA", "RI", "SC",
    "SD", "TN", "TX", "UT", "VT",
    "VA", "WA", "WV", "WI", "WY"
  ),
  stringsAsFactors = FALSE
)

# Municipality-friendly states — used by Municipalities and Drill-down dropdowns.
# These are the states where county subdivisions meaningfully tile the state.
DEMO_STATES <- data.frame(
  name = c("New Jersey", "Pennsylvania", "New York", "Ohio", "Michigan",
           "Minnesota", "Wisconsin", "Illinois", "Texas", "Georgia"),
  abbr = c("NJ", "PA", "NY", "OH", "MI",
           "MN", "WI", "IL", "TX", "GA"),
  stringsAsFactors = FALSE
)

# State -> HHS region (used by the national grouped-layout tab).
HHS_LOOKUP <- data.frame(
  STUSPS = c(
    "CT", "ME", "MA", "NH", "RI", "VT",
    "NJ", "NY", "PR", "VI",
    "DE", "DC", "MD", "PA", "VA", "WV",
    "AL", "FL", "GA", "KY", "MS", "NC", "SC", "TN",
    "IL", "IN", "MI", "MN", "OH", "WI",
    "AR", "LA", "NM", "OK", "TX",
    "IA", "KS", "MO", "NE",
    "CO", "MT", "ND", "SD", "UT", "WY",
    "AZ", "CA", "HI", "NV", "GU", "AS", "MP",
    "AK", "ID", "OR", "WA"
  ),
  hhs_region = c(
    rep("1", 6), rep("2", 4), rep("3", 6), rep("4", 8),
    rep("5", 6), rep("6", 5), rep("7", 4), rep("8", 6),
    rep("9", 7), rep("10", 4)
  ),
  stringsAsFactors = FALSE
)

# -----------------------------------------------------------------------------
# Resolve and create output directory
# -----------------------------------------------------------------------------
resolve_data_dir <- function() {
  env_dir <- Sys.getenv("APP_DATA_DIR", "")
  if (nzchar(env_dir)) return(env_dir)

  # Directory of this script (works under Rscript and source()).
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  script_path <- if (length(file_arg)) {
    sub("^--file=", "", file_arg[1])
  } else if (!is.null(sys.frames()[[1]]$ofile)) {
    sys.frames()[[1]]$ofile
  } else {
    file.path(getwd(), "prep_data.R")
  }
  file.path(dirname(normalizePath(script_path, mustWork = FALSE)), "data")
}

DATA_DIR <- resolve_data_dir()
dir.create(DATA_DIR, showWarnings = FALSE, recursive = TRUE)
message("Baking gallery data into: ", DATA_DIR)

# A target is "done" only if the file exists AND loads to a non-empty sf.
is_ready <- function(path) {
  if (FORCE || !file.exists(path)) return(FALSE)
  ok <- tryCatch({
    obj <- readRDS(path)
    inherits(obj, "sf") && nrow(obj) > 0
  }, error = function(e) FALSE)
  ok
}

# -----------------------------------------------------------------------------
# Counties for one state
# -----------------------------------------------------------------------------
bake_counties <- function(abbr) {
  out_path <- file.path(DATA_DIR, paste0(abbr, "_counties.rds"))
  if (is_ready(out_path)) {
    message("  [skip] ", basename(out_path))
    return(invisible(out_path))
  }
  message("  [get ] counties: ", abbr)

  out <- tigris::counties(state = abbr, year = YEAR, cb = TRUE, class = "sf") |>
    sf::st_make_valid() |>
    dplyr::filter(!sf::st_is_empty(.data$geometry)) |>
    dplyr::mutate(
      county_label = dplyr::coalesce(.data$NAMELSAD, .data$NAME),
      county_geoid = .data$GEOID,
      county_id    = paste0(.data$STATEFP, .data$COUNTYFP)
    )

  if (!nrow(out)) stop("No counties returned for ", abbr, call. = FALSE)
  saveRDS(out, out_path)
  invisible(out_path)
}

# -----------------------------------------------------------------------------
# County subdivisions (+ parent county name) for one state
# -----------------------------------------------------------------------------
bake_munis <- function(abbr) {
  out_path <- file.path(DATA_DIR, paste0(abbr, "_munis.rds"))
  if (is_ready(out_path)) {
    message("  [skip] ", basename(out_path))
    return(invisible(out_path))
  }
  message("  [get ] subdivisions: ", abbr)

  munis <- tigris::county_subdivisions(
    state = abbr, year = YEAR, cb = TRUE, class = "sf"
  ) |>
    sf::st_make_valid() |>
    dplyr::filter(!sf::st_is_empty(.data$geometry))

  counties <- tigris::counties(state = abbr, year = YEAR, cb = TRUE, class = "sf") |>
    sf::st_drop_geometry() |>
    dplyr::transmute(
      STATEFP     = as.character(.data$STATEFP),
      COUNTYFP    = as.character(.data$COUNTYFP),
      county_name = dplyr::coalesce(.data$NAMELSAD, .data$NAME)
    )

  out <- munis |>
    dplyr::mutate(
      STATEFP  = as.character(.data$STATEFP),
      COUNTYFP = as.character(.data$COUNTYFP),
      COUSUBFP = as.character(.data$COUSUBFP)
    ) |>
    dplyr::left_join(counties, by = c("STATEFP", "COUNTYFP")) |>
    dplyr::mutate(
      muni_label  = dplyr::coalesce(.data$NAMELSAD, .data$NAME),
      muni_id     = paste0(.data$STATEFP, .data$COUNTYFP, .data$COUSUBFP),
      muni_geoid  = .data$GEOID,
      county_name = dplyr::coalesce(.data$county_name, paste0("County ", .data$COUNTYFP))
    )

  if (!nrow(out)) stop("No county subdivisions returned for ", abbr, call. = FALSE)
  saveRDS(out, out_path)
  invisible(out_path)
}

# -----------------------------------------------------------------------------
# National states with HHS region (EPSG:5070, ready for explode_grouped)
# -----------------------------------------------------------------------------
bake_hhs_states <- function() {
  out_path <- file.path(DATA_DIR, "us_states.rds")
  if (is_ready(out_path)) {
    message("  [skip] ", basename(out_path))
    return(invisible(out_path))
  }
  message("  [get ] national states (cb)")

  states_sf <- tigris::states(year = YEAR, cb = TRUE, class = "sf") |>
    sf::st_make_valid() |>
    sf::st_transform(5070) |>
    dplyr::left_join(HHS_LOOKUP, by = "STUSPS") |>
    dplyr::filter(!is.na(.data$hhs_region)) |>
    dplyr::mutate(
      hhs_region  = as.character(.data$hhs_region),
      state_label = dplyr::coalesce(.data$NAME, .data$STUSPS),
      state_geoid = .data$GEOID
    )

  if (!nrow(states_sf)) stop("No national states returned.", call. = FALSE)
  saveRDS(states_sf, out_path)
  invisible(out_path)
}

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------
# Counties for all 50 states (County tab).
for (abbr in COUNTY_STATES$abbr) {
  bake_counties(abbr)
}
# Municipality subdivisions only for the muni-friendly subset (Municipalities
# and Drill-down tabs). Skipping western/southern states saves substantial
# Docker build time without affecting the Counties tab.
for (abbr in DEMO_STATES$abbr) {
  bake_munis(abbr)
}
bake_hhs_states()

# Persist lookups so the app never has to redefine them.
saveRDS(COUNTY_STATES, file.path(DATA_DIR, "county_states.rds"))
saveRDS(DEMO_STATES,   file.path(DATA_DIR, "demo_states.rds"))
saveRDS(HHS_LOOKUP,    file.path(DATA_DIR, "hhs_lookup.rds"))

message("Done. Files in ", DATA_DIR, ":")
message(paste(" -", list.files(DATA_DIR, pattern = "\\.rds$"), collapse = "\n"))
