# =============================================================================
# R/tiger.R — TIGER/Line download and region-attachment helpers
# =============================================================================

# Cache setup
#
# Directory resolution order:
#   1. getOption("explodemap.cache_dir")  — set this in Shiny server() to a
#      writable path on the server, e.g. options(explodemap.cache_dir = "/tmp/em")
#   2. tools::R_user_dir("explodemap", "cache")  — XDG-compliant user cache
#      (~/.cache/explodemap on Linux, ~/Library/Caches/explodemap on macOS,
#       %LOCALAPPDATA%/explodemap on Windows).
#
# Both dir creation and file writes are wrapped in tryCatch so a read-only
# or ephemeral filesystem (shinyapps.io, Posit Cloud) degrades gracefully:
# the download still works, just without caching.
.cache_dir <- function() {
  d <- getOption(
    "explodemap.cache_dir",
    tools::R_user_dir("explodemap", which = "cache")
  )
  tryCatch(
    dir.create(d, showWarnings = FALSE, recursive = TRUE),
    error = function(e) NULL
  )
  d
}
.cache_path   <- function(key) file.path(.cache_dir(), paste0(key, ".rds"))
.cache_exists <- function(key) file.exists(.cache_path(key))
.cache_load   <- function(key) readRDS(.cache_path(key))
.cache_save   <- function(key, obj) {
  # withCallingHandlers muffles the "cannot open compressed file" warning that
  # gzfile emits on Windows when the target path is unwritable. The subsequent
  # write error is still caught by the outer tryCatch so the caller always
  # gets obj back without a crash.
  tryCatch(
    withCallingHandlers(
      { saveRDS(obj, .cache_path(key)); obj },
      warning = function(w) invokeRestart("muffleWarning")
    ),
    error = function(e) {
      message(
        "explodemap: cache write failed (", conditionMessage(e),
        "); proceeding without caching."
      )
      obj
    }
  )
}

.download_file_or_stop <- function(url, dest, label) {
  dl_method <- if (isTRUE(capabilities("libcurl"))) "libcurl" else "auto"
  status <- tryCatch(
    utils::download.file(url, dest, quiet = TRUE, mode = "wb", method = dl_method),
    error = function(e) {
      stop(
        "Could not download ", label, " from the Census TIGER/Line server. ",
        "Check your internet connection and try again. ",
        "Details: ", conditionMessage(e),
        call. = FALSE
      )
    }
  )

  if (!identical(status, 0L)) {
    stop(
      "Could not download ", label, " from the Census TIGER/Line server. ",
      "Check your internet connection and try again.",
      call. = FALSE
    )
  }

  if (!file.exists(dest) || isTRUE(file.info(dest)$size == 0)) {
    stop(
      "Downloaded ", label, " but the file was empty. ",
      "The Census TIGER/Line server may be unavailable; please try again later.",
      call. = FALSE
    )
  }

  invisible(dest)
}


#' Download TIGER/Line county subdivision boundaries
#' @param fips 2-digit state FIPS code
#' @param crs Target projected CRS
#' @return sf object
#' @keywords internal
.download_cousub <- function(fips, crs) {
  if (!is.character(fips) || length(fips) != 1 || !grepl("^[0-9]{2}$", fips)) {
    stop("`state_fips` must be a 2-digit character string, such as \"34\" for New Jersey.",
         call. = FALSE)
  }

  key <- paste0("cousub_", fips)
  if (.cache_exists(key)) {
    obj <- .cache_load(key)
    if (!identical(sf::st_crs(obj)$epsg, as.integer(crs)))
      obj <- sf::st_transform(obj, crs)
    return(obj)
  }
  url <- paste0("https://www2.census.gov/geo/tiger/TIGER2025/COUSUB/",
                "tl_2025_", fips, "_cousub.zip")
  tmp <- tempfile(fileext = ".zip")
  .download_file_or_stop(url, tmp, paste0("county subdivisions for FIPS ", fips))
  dir <- file.path(tempdir(), paste0("cousub_", fips, "_", Sys.getpid()))
  dir.create(dir, showWarnings = FALSE)
  tryCatch(
    utils::unzip(tmp, exdir = dir),
    error = function(e) {
      stop(
        "Could not unzip county subdivision data for FIPS ", fips, ". ",
        "The downloaded file may be incomplete. Please try again. ",
        "Details: ", conditionMessage(e),
        call. = FALSE
      )
    }
  )
  shp <- list.files(dir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
  if (!length(shp)) {
    stop(
      "County subdivision data for FIPS ", fips, " did not contain a shapefile. ",
      "The Census download may have changed or failed.",
      call. = FALSE
    )
  }
  obj <- sf::st_read(shp[1], quiet = TRUE) |>
    dplyr::filter(.data$COUSUBFP != "00000") |>
    sf::st_transform(crs)
  .cache_save(key, obj)
}


#' Download national county name-to-FIPS lookup
#' @keywords internal
.get_national_counties <- function() {
  key <- "counties_national"
  if (.cache_exists(key)) return(.cache_load(key))
  url <- "https://www2.census.gov/geo/tiger/TIGER2025/COUNTY/tl_2025_us_county.zip"
  tmp <- tempfile(fileext = ".zip")
  .download_file_or_stop(url, tmp, "national county lookup")
  dir <- file.path(tempdir(), paste0("county_nat_", Sys.getpid()))
  dir.create(dir, showWarnings = FALSE)
  tryCatch(
    utils::unzip(tmp, exdir = dir),
    error = function(e) {
      stop(
        "Could not unzip the national county lookup. ",
        "The downloaded file may be incomplete. Please try again. ",
        "Details: ", conditionMessage(e),
        call. = FALSE
      )
    }
  )
  shp <- list.files(dir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
  if (!length(shp)) {
    stop(
      "The national county lookup download did not contain a shapefile. ",
      "The Census download may have changed or failed.",
      call. = FALSE
    )
  }
  obj <- sf::st_read(shp[1], quiet = TRUE) |>
    sf::st_drop_geometry() |>
    dplyr::select("STATEFP", "COUNTYFP", "NAME")
  .cache_save(key, obj)
}


#' Attach region labels to TIGER/Line data via county names
#' @keywords internal
.attach_regions_tiger <- function(sf_obj, fips, region_map, quiet = FALSE) {
  region_df <- dplyr::bind_rows(lapply(names(region_map), function(r)
    data.frame(county_name = region_map[[r]], region = r,
               stringsAsFactors = FALSE)))

  counties <- .get_national_counties() |>
    dplyr::filter(.data$STATEFP == fips) |>
    dplyr::select("COUNTYFP", "NAME")

  county_region <- counties |>
    dplyr::left_join(region_df, by = c("NAME" = "county_name"))

  sf_result <- sf_obj |>
    dplyr::left_join(county_region |> dplyr::select("COUNTYFP", "region"),
                     by = "COUNTYFP")

  n_matched <- sum(!is.na(sf_result$region))
  if (!quiet)
    message("Region assignment: ", n_matched, " / ", nrow(sf_result), " units matched.")

  unmatched <- counties$NAME[!counties$NAME %in% region_df$county_name]
  if (!quiet && length(unmatched) > 0)
    message("Unmatched counties: ",
            paste(utils::head(unmatched, 8), collapse = ", "),
            if (length(unmatched) > 8) paste0("... +", length(unmatched) - 8, " more"))

  sf_result$region[is.na(sf_result$region)] <- "Other"
  sf_result
}


#' Download TIGER/Line county boundaries for a single state
#' @param fips 2-digit state FIPS code
#' @param crs Target projected CRS (EPSG integer)
#' @return Projected sf object with county polygons
#' @keywords internal
.download_counties_state <- function(fips, crs) {
  if (!is.character(fips) || length(fips) != 1 || !grepl("^[0-9]{2}$", fips)) {
    stop("`state_fips` must be a 2-digit character string, such as \"47\" for Tennessee.",
         call. = FALSE)
  }

  key <- paste0("county_", fips)
  if (.cache_exists(key)) {
    obj <- .cache_load(key)
    if (!identical(sf::st_crs(obj)$epsg, as.integer(crs)))
      obj <- sf::st_transform(obj, crs)
    return(obj)
  }

  read_shp_from_zip <- function(zip_path, label) {
    d <- file.path(tempdir(), paste0("cty_", label, "_", Sys.getpid()))
    dir.create(d, showWarnings = FALSE)
    tryCatch(
      utils::unzip(zip_path, exdir = d),
      error = function(e) stop("Could not unzip ", label, ": ", conditionMessage(e), call. = FALSE)
    )
    shp <- list.files(d, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
    if (!length(shp))
      stop("No shapefile found in ", label, " download.", call. = FALSE)
    sf::st_read(shp[1], quiet = TRUE)
  }

  # Try per-state file first (smaller download)
  state_url <- paste0("https://www2.census.gov/geo/tiger/TIGER2025/COUNTY/",
                      "tl_2025_", fips, "_county.zip")
  tmp <- tempfile(fileext = ".zip")
  state_ok <- tryCatch({
    .download_file_or_stop(state_url, tmp, paste0("county boundaries for FIPS ", fips))
    TRUE
  }, error = function(e) FALSE)

  if (state_ok) {
    obj <- tryCatch(
      read_shp_from_zip(tmp, fips),
      error = function(e) NULL
    )
    if (!is.null(obj)) {
      obj <- sf::st_transform(obj, crs)
      .cache_save(key, obj)
      return(obj)
    }
  }

  # Fall back to the national county file filtered by state FIPS
  nat_key <- "counties_national_geom"
  if (.cache_exists(nat_key)) {
    nat <- .cache_load(nat_key)
  } else {
    nat_url <- "https://www2.census.gov/geo/tiger/TIGER2025/COUNTY/tl_2025_us_county.zip"
    nat_tmp <- tempfile(fileext = ".zip")
    .download_file_or_stop(nat_url, nat_tmp, "national county boundaries")
    nat <- read_shp_from_zip(nat_tmp, "national")
    .cache_save(nat_key, nat)
  }

  obj <- nat[nat$STATEFP == fips, ]
  if (!nrow(obj))
    stop("No counties found for FIPS ", fips, " in the national county file.", call. = FALSE)
  obj <- sf::st_transform(obj, crs)
  .cache_save(key, obj)
  obj
}


#' Assign regions to county-level sf data
#'
#' Two modes:
#'   - Named `region_map` (list of region -> county names): explicit assignment
#'   - `region_map = NULL`: automatic k-means clustering on projected centroids
#'
#' @param sf_obj Projected sf object with county polygons
#' @param n_regions Number of k-means regions (used only when region_map is NULL)
#' @param region_map Named list mapping region labels to county NAME vectors, or NULL
#' @param quiet Suppress messages
#' @return sf_obj with a `region` column added
#' @keywords internal
.attach_regions_county <- function(sf_obj, n_regions = NULL, region_map = NULL,
                                   quiet = FALSE) {

  # ── Named mapping path ─────────────────────────────────────────────────────
  if (!is.null(region_map)) {
    region_df <- dplyr::bind_rows(lapply(names(region_map), function(r)
      data.frame(NAME = region_map[[r]], region = r, stringsAsFactors = FALSE)))

    # sf_obj should have a NAME column from TIGER county download
    name_col <- if ("NAME" %in% names(sf_obj)) "NAME" else
      stop("County sf must have a NAME column for named region_map assignment.",
           call. = FALSE)

    sf_result <- sf_obj |>
      dplyr::left_join(region_df, by = "NAME")

    n_matched <- sum(!is.na(sf_result$region))
    if (!quiet)
      message("Region assignment: ", n_matched, " / ", nrow(sf_result),
              " counties matched.")

    unmatched <- sf_obj$NAME[!sf_obj$NAME %in% region_df$NAME]
    if (!quiet && length(unmatched) > 0)
      message("Unmatched counties: ",
              paste(utils::head(unmatched, 8), collapse = ", "),
              if (length(unmatched) > 8) paste0("... +", length(unmatched) - 8, " more"))

    sf_result$region[is.na(sf_result$region)] <- "Other"
    return(sf_result)
  }

  # ── Auto k-means path ──────────────────────────────────────────────────────
  n_counties <- nrow(sf_obj)

  # Auto-determine number of regions if not supplied
  if (is.null(n_regions)) {
    n_regions <- max(2L, min(6L, as.integer(round(sqrt(n_counties / 8)))))
    if (!quiet)
      message("Auto k-means: n_regions = ", n_regions,
              " (derived from ", n_counties, " counties; override with n_regions)")
  }

  if (n_regions < 2 || n_regions > n_counties)
    stop("`n_regions` must be between 2 and the number of counties (", n_counties, ").",
         call. = FALSE)

  centroids <- suppressWarnings(sf::st_centroid(sf_obj))
  coords    <- sf::st_coordinates(centroids)          # matrix [n, 2]

  # Scale so x and y contribute equally
  x_sd <- stats::sd(coords[, 1]); if (x_sd == 0) x_sd <- 1
  y_sd <- stats::sd(coords[, 2]); if (y_sd == 0) y_sd <- 1
  scaled <- cbind((coords[, 1] - mean(coords[, 1])) / x_sd,
                  (coords[, 2] - mean(coords[, 2])) / y_sd)

  rng_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (rng_exists) {
    rng_state <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit({
    if (rng_exists) {
      assign(".Random.seed", rng_state, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  set.seed(2026)
  km <- stats::kmeans(scaled, centers = n_regions, nstart = 50, iter.max = 100)

  # Name clusters by compass direction relative to overall centroid
  centers       <- km$centers                   # [k, 2] in scaled space
  overall_x     <- mean(centers[, 1])
  overall_y     <- mean(centers[, 2])
  rel_x         <- centers[, 1] - overall_x
  rel_y         <- centers[, 2] - overall_y

  .compass <- function(dx, dy) {
    angle <- atan2(dy, dx) * 180 / pi            # -180..180
    dirs  <- c("East","Northeast","North","Northwest",
               "West","Southwest","South","Southeast")
    idx   <- as.integer((angle + 202.5) / 45) %% 8 + 1
    dirs[idx]
  }

  raw_names  <- mapply(.compass, rel_x, rel_y)
  # Disambiguate duplicates by appending 2/3
  seen       <- table(raw_names)
  counters   <- integer(length(raw_names))
  for (nm in names(seen[seen > 1])) {
    hits <- which(raw_names == nm)
    for (i in seq_along(hits)) counters[hits[i]] <- i
  }
  region_labels <- ifelse(counters > 1,
                          paste0(raw_names, " ", counters),
                          raw_names)

  sf_obj$region <- region_labels[km$cluster]

  if (!quiet)
    message("K-means regions assigned: ",
            paste(sort(unique(sf_obj$region)), collapse = ", "))

  sf_obj
}


#' Clear explodemap download cache
#'
#' @param key Specific cache key to clear, or NULL to clear all
#' @return Invisibly returns `NULL`. The function is called for its side effect
#'   of deleting cached `.rds` files and reporting what was removed.
#' @export
cache_clear <- function(key = NULL) {
  cache_dir <- .cache_dir()
  if (is.null(key)) {
    files <- list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE)
    unlink(files)
    message("Cache cleared: ", length(files), " files removed from ", cache_dir)
  } else {
    p <- .cache_path(key)
    if (file.exists(p)) { unlink(p); message("Cleared: ", key) }
    else message("No cache found for: ", key)
  }
  invisible(NULL)
}

#' List cached datasets
#'
#' @return Invisibly returns a character vector of cached `.rds` file names.
#'   The visible output is a message listing the cache directory and file sizes,
#'   or a message that the cache is empty.
#' @export
cache_list <- function() {
  cache_dir <- .cache_dir()
  files <- list.files(cache_dir, pattern = "\\.rds$")
  if (length(files) == 0) {
    message("Cache is empty.")
  } else {
    sizes <- file.size(file.path(cache_dir, files))
    msg <- paste(sprintf("  %-40s  %.1f MB", files, sizes / 1e6), collapse = "\n")
    message("Cached datasets in ", cache_dir, ":\n", msg)
  }
  invisible(files)
}
