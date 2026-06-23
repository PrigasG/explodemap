suppressPackageStartupMessages({
  library(sf)
  library(explodemap)
})

script_path <- tryCatch(
  normalizePath(sys.frame(1)$ofile, mustWork = FALSE),
  error = function(e) {
    normalizePath(file.path(getwd(), "inst", "standalone", "prep_data.R"),
                  mustWork = FALSE)
  }
)
standalone_dir <- dirname(script_path)
pkg_root <- normalizePath(file.path(standalone_dir, "..", ".."), mustWork = FALSE)
data_dir <- file.path(standalone_dir, "data")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

FORCE <- identical(tolower(Sys.getenv("PREP_FORCE", "false")), "true")
DEFAULT_CRS <- as.integer(Sys.getenv("EXPLODEMAP_STANDALONE_CRS", "2163"))

STATES <- data.frame(
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
    "al", "ak", "az", "ar", "ca",
    "co", "ct", "de", "fl", "ga",
    "hi", "id", "il", "in", "ia",
    "ks", "ky", "la", "me", "md",
    "ma", "mi", "mn", "ms", "mo",
    "mt", "ne", "nv", "nh", "nj",
    "nm", "ny", "nc", "nd", "oh",
    "ok", "or", "pa", "ri", "sc",
    "sd", "tn", "tx", "ut", "vt",
    "va", "wa", "wv", "wi", "wy"
  ),
  fips = c(
    "01", "02", "04", "05", "06",
    "08", "09", "10", "12", "13",
    "15", "16", "17", "18", "19",
    "20", "21", "22", "23", "24",
    "25", "26", "27", "28", "29",
    "30", "31", "32", "33", "34",
    "35", "36", "37", "38", "39",
    "40", "41", "42", "44", "45",
    "46", "47", "48", "49", "50",
    "51", "53", "54", "55", "56"
  ),
  stringsAsFactors = FALSE
)

`%||%` <- function(a, b) if (is.null(a)) b else a

registry_candidates <- c(
  file.path(pkg_root, "inst", "registries", "state_registry.R"),
  file.path(pkg_root, "registries", "state_registry.R")
)
state_registry <- list()
for (candidate in registry_candidates) {
  if (file.exists(candidate)) {
    registry_env <- new.env(parent = baseenv())
    sys.source(candidate, envir = registry_env)
    if (exists("state_registry", envir = registry_env, inherits = FALSE)) {
      state_registry <- get("state_registry", envir = registry_env,
                            inherits = FALSE)
      break
    }
  }
}

offset_path_for <- function(abbr) {
  candidates <- c(
    file.path(standalone_dir, "offsets", paste0(abbr, "_drag_offsets_used.csv")),
    file.path(pkg_root, "paper", "outputs", "tables",
              paste0(abbr, "_drag_offsets_used.csv"))
  )
  hits <- candidates[file.exists(candidates)]
  if (length(hits)) hits[1] else NA_character_
}

n_regions_from_offsets <- function(path) {
  if (is.na(path) || !file.exists(path)) return(NULL)
  nrow(read_drag_offsets(path, quiet = TRUE))
}

case_config <- function(abbr) {
  key <- toupper(abbr)
  row <- STATES[STATES$abbr == abbr, , drop = FALSE]
  reg <- state_registry[[key]] %||% list()
  offset_path <- offset_path_for(abbr)

  region_map <- reg$region_map %||% NULL
  if (is.function(region_map)) {
    region_map <- region_map()
  }
  level <- reg$level %||% if (!is.null(region_map)) "cousub" else "county"

  list(
    name = reg$name %||% row$name,
    fips = reg$fips %||% row$fips,
    crs = reg$crs %||% DEFAULT_CRS,
    level = level,
    region_map = region_map,
    n_regions = reg$n_regions %||% n_regions_from_offsets(offset_path),
    offset_path = offset_path
  )
}

saveRDS(STATES[, c("name", "abbr")], file.path(data_dir, "states.rds"))
message("Baking explodemap display layouts into: ", data_dir)
message("Default county CRS for unregistered states: EPSG:", DEFAULT_CRS)

for (i in seq_len(nrow(STATES))) {
  abbr <- STATES$abbr[i]
  cfg <- case_config(abbr)
  out_path <- file.path(data_dir, paste0(abbr, "_display.rds"))

  if (!FORCE && file.exists(out_path)) {
    message("  [skip] ", cfg$name)
    next
  }

  message("  [bake] ", cfg$name, " via explode_state(level = \"", cfg$level, "\")")

  tryCatch({
    result <- explode_state(
      state_fips = cfg$fips,
      crs = cfg$crs,
      region_map = cfg$region_map,
      level = cfg$level,
      n_regions = cfg$n_regions,
      allow_other = TRUE,
      plot = FALSE,
      export = FALSE,
      label = cfg$name,
      quiet = TRUE
    )

    sf_obj <- result$sf_exp
    sf_obj$drag_region <- as.character(sf_obj$region)
    sf_obj$county_label <- if ("NAMELSAD" %in% names(sf_obj)) {
      as.character(sf_obj$NAMELSAD)
    } else {
      as.character(sf_obj$NAME)
    }
    sf_obj$county_id <- if ("GEOID" %in% names(sf_obj)) {
      as.character(sf_obj$GEOID)
    } else {
      paste0(abbr, "_", seq_len(nrow(sf_obj)))
    }

    if (!is.na(cfg$offset_path) && file.exists(cfg$offset_path)) {
      offsets <- read_drag_offsets(cfg$offset_path, quiet = TRUE)
      sf_obj <- apply_region_offsets(sf_obj, offsets, region_col = "drag_region")
    } else {
      message("    [warn] no display-offset CSV found; saving formula layout")
    }

    saveRDS(sf_obj, out_path)
  }, error = function(e) {
    message("    [err]  ", conditionMessage(e))
  })
}

message("Done. Files in ", data_dir, ":")
message(paste("  -", list.files(data_dir, pattern = "\\.rds$"), collapse = "\n"))
