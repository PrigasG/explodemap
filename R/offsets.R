#' Apply documented display offsets by region
#'
#' Applies rigid display offsets to all features in each named region. This is
#' intended as a reproducible finishing step for publication or dashboard
#' layouts after an exploded map has already been computed.
#'
#' @param x An `sf`, `exploded_map`, or `grouped_exploded_map` object.
#' @param offsets A data frame, or a path to a CSV file, containing one row per
#'   region and numeric offset columns.
#' @param region_col Name of the region column in `x`. For `exploded_map` and
#'   `grouped_exploded_map` objects, the value recorded in `x$diagnostics` is
#'   used when this is `NULL`.
#' @param offset_region_col Name of the region column in `offsets`.
#' @param dx_col Name of the horizontal offset column in `offsets`.
#' @param dy_col Name of the vertical offset column in `offsets`.
#' @param update_plots Logical; when `TRUE`, rebuild stored ggplot objects for
#'   exploded map objects.
#'
#' @return For an `sf` input, an `sf` object with the same attributes and CRS as
#'   `x`; geometries belonging to each listed region are translated by the
#'   supplied offsets, and the normalized offset table is stored in the
#'   `display_offsets` attribute. For an `exploded_map`, returns the same S3
#'   object structure with `sf_exp`, `sf_exp_wgs`, stored plots, and
#'   `display_offsets` updated. For a `grouped_exploded_map`, returns the same
#'   S3 object structure with `sf_grouped`, `sf_grouped_wgs`, stored plots, and
#'   `display_offsets` updated. The offsets are rigid translations, so polygon
#'   shape, area, and within-region relative geometry are preserved.
#'
#' @details Offsets are interpreted in the coordinate units of the projected
#' geometry being adjusted. The default column names `dx_m` and `dy_m` assume a
#' metric projected CRS, matching the package's exploded-map workflow.
#'
#' @examples
#' library(sf)
#' x <- st_sf(
#'   region = c("A", "B"),
#'   geometry = st_sfc(
#'     st_point(c(0, 0)),
#'     st_point(c(10, 0)),
#'     crs = 3857
#'   )
#' )
#' offsets <- data.frame(region = "B", dx_m = 5, dy_m = 2)
#' apply_region_offsets(x, offsets, region_col = "region")
#'
#' @export
apply_region_offsets <- function(x,
                                 offsets,
                                 region_col = NULL,
                                 offset_region_col = "region",
                                 dx_col = "dx_m",
                                 dy_col = "dy_m",
                                 update_plots = TRUE) {
  offsets <- .normalize_region_offsets(
    offsets = offsets,
    offset_region_col = offset_region_col,
    dx_col = dx_col,
    dy_col = dy_col
  )

  if (inherits(x, "grouped_exploded_map")) {
    region_col <- .resolve_region_col(x$sf_grouped, region_col, x$diagnostics$region_col)
    out <- x
    out$sf_grouped <- .apply_region_offsets_sf(out$sf_grouped, offsets, region_col)
    out$sf_grouped_wgs <- sf::st_transform(out$sf_grouped, 4326)
    out$display_offsets <- offsets

    if (isTRUE(update_plots) && !is.null(out$plots)) {
      out$plots <- .make_grouped_plots(
        sf_orig = out$sf_orig,
        sf_local = out$sf_local,
        sf_grouped = out$sf_grouped,
        region_col = region_col,
        title = out$diagnostics$label,
        params = out$params
      )
    }
    return(out)
  }

  if (inherits(x, "exploded_map")) {
    region_col <- .resolve_region_col(x$sf_exp, region_col, x$diagnostics$region_col)
    out <- x
    out$sf_exp <- .apply_region_offsets_sf(out$sf_exp, offsets, region_col)
    out$sf_exp_wgs <- sf::st_transform(out$sf_exp, 4326)
    out$display_offsets <- offsets

    if (isTRUE(update_plots) && !is.null(out$plots)) {
      out$plots <- .make_plots(
        sf_orig = out$sf_orig,
        sf_exp = out$sf_exp,
        region_col = region_col,
        title = out$diagnostics$label,
        params = out$params
      )
    }
    return(out)
  }

  if (inherits(x, "sf")) {
    region_col <- .resolve_region_col(x, region_col, NULL)
    out <- .apply_region_offsets_sf(x, offsets, region_col)
    attr(out, "display_offsets") <- offsets
    return(out)
  }

  stop("`x` must be an sf, exploded_map, or grouped_exploded_map object.", call. = FALSE)
}

.normalize_region_offsets <- function(offsets,
                                      offset_region_col,
                                      dx_col,
                                      dy_col) {
  if (is.character(offsets) && length(offsets) == 1L) {
    offsets <- utils::read.csv(offsets, stringsAsFactors = FALSE, check.names = FALSE)
  }

  if (!is.data.frame(offsets)) {
    stop("`offsets` must be a data frame or a path to a CSV file.", call. = FALSE)
  }

  required <- c(offset_region_col, dx_col, dy_col)
  missing <- setdiff(required, names(offsets))
  if (length(missing) > 0L) {
    stop("`offsets` is missing required column(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }

  out <- data.frame(
    region = as.character(offsets[[offset_region_col]]),
    dx_m = as.numeric(offsets[[dx_col]]),
    dy_m = as.numeric(offsets[[dy_col]]),
    stringsAsFactors = FALSE
  )

  if (anyNA(out$region) || any(out$region == "")) {
    stop("Offset region names must be non-missing and non-empty.", call. = FALSE)
  }
  if (anyNA(out$dx_m) || anyNA(out$dy_m)) {
    stop("Offset columns must be numeric and non-missing.", call. = FALSE)
  }
  if (anyDuplicated(out$region)) {
    dupes <- unique(out$region[duplicated(out$region)])
    stop("`offsets` contains duplicate region rows: ", paste(dupes, collapse = ", "), call. = FALSE)
  }

  out
}

.resolve_region_col <- function(sf_obj, region_col, fallback) {
  if (is.null(region_col)) {
    region_col <- fallback
  }
  if (is.null(region_col) || !nzchar(region_col)) {
    stop("`region_col` must be supplied for raw sf inputs.", call. = FALSE)
  }
  if (!region_col %in% names(sf_obj)) {
    stop("region_col '", region_col, "' not found in `x`.", call. = FALSE)
  }
  region_col
}

.apply_region_offsets_sf <- function(sf_obj, offsets, region_col) {
  if (is.na(sf::st_crs(sf_obj))) {
    stop("`x` has no CRS. Set a projected CRS before applying offsets.", call. = FALSE)
  }
  if (sf::st_is_longlat(sf_obj)) {
    stop("`x` is in geographic lon/lat coordinates. Project it before applying metric offsets.", call. = FALSE)
  }

  out <- sf_obj
  known_regions <- as.character(unique(out[[region_col]]))
  unknown <- setdiff(offsets$region, known_regions)
  if (length(unknown) > 0L) {
    warning(
      "Ignoring offset rows for unknown region(s): ",
      paste(unknown, collapse = ", "),
      call. = FALSE
    )
  }

  for (i in seq_len(nrow(offsets))) {
    idx <- as.character(out[[region_col]]) == offsets$region[i]
    if (!any(idx)) next
    sf::st_geometry(out)[idx] <- sf::st_geometry(out)[idx] + c(offsets$dx_m[i], offsets$dy_m[i])
  }

  sf::st_as_sf(out)
}
