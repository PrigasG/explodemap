# =============================================================================
# R/tiger.R — TIGER/Line download and region-attachment helpers
# =============================================================================

# Cache setup
.cache_dir <- function() {
  d <- file.path(path.expand("~"), "explode_map_cache")
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
  d
}
.cache_path   <- function(key) file.path(.cache_dir(), paste0(key, ".rds"))
.cache_exists <- function(key) file.exists(.cache_path(key))
.cache_load   <- function(key) readRDS(.cache_path(key))
.cache_save   <- function(key, obj) { saveRDS(obj, .cache_path(key)); obj }


#' Download TIGER/Line county subdivision boundaries
#' @param fips 2-digit state FIPS code
#' @param crs Target projected CRS
#' @return sf object
#' @keywords internal
.download_cousub <- function(fips, crs) {
  key <- paste0("cousub_", fips)
  if (.cache_exists(key)) {
    obj <- .cache_load(key)
    if (!identical(sf::st_crs(obj)$epsg, as.integer(crs)))
      obj <- sf::st_transform(obj, crs)
    return(obj)
  }
  url <- paste0("https://www2.census.gov/geo/tiger/TIGER2024/COUSUB/",
                "tl_2024_", fips, "_cousub.zip")
  tmp <- tempfile(fileext = ".zip")
  utils::download.file(url, tmp, quiet = TRUE, mode = "wb")
  dir <- file.path(tempdir(), paste0("cousub_", fips, "_", Sys.getpid()))
  dir.create(dir, showWarnings = FALSE)
  utils::unzip(tmp, exdir = dir)
  shp <- list.files(dir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
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
  url <- "https://www2.census.gov/geo/tiger/TIGER2024/COUNTY/tl_2024_us_county.zip"
  tmp <- tempfile(fileext = ".zip")
  utils::download.file(url, tmp, quiet = TRUE, mode = "wb")
  dir <- file.path(tempdir(), paste0("county_nat_", Sys.getpid()))
  dir.create(dir, showWarnings = FALSE)
  utils::unzip(tmp, exdir = dir)
  shp <- list.files(dir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
  obj <- sf::st_read(shp[1], quiet = TRUE) |>
    sf::st_drop_geometry() |>
    dplyr::select("STATEFP", "COUNTYFP", "NAME")
  .cache_save(key, obj)
}


#' Attach region labels to TIGER/Line data via county names
#' @keywords internal
.attach_regions_tiger <- function(sf_obj, fips, region_map) {
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
  message("Region assignment: ", n_matched, " / ", nrow(sf_result), " units matched.")

  unmatched <- counties$NAME[!counties$NAME %in% region_df$county_name]
  if (length(unmatched) > 0)
    message("Unmatched counties: ",
            paste(utils::head(unmatched, 8), collapse = ", "),
            if (length(unmatched) > 8) paste0("... +", length(unmatched) - 8, " more"))

  sf_result$region[is.na(sf_result$region)] <- "Other"
  sf_result
}


#' Clear explodemap download cache
#'
#' @param key Specific cache key to clear, or NULL to clear all
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
