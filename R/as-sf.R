# =============================================================================
# R/as-sf.R — Geometry conversion and displacement analysis
# =============================================================================

#' Extract plain sf geometry from an exploded layout
#'
#' Converts an `exploded_map` or `grouped_exploded_map` back to a plain `sf`
#' data frame so the layout can flow into downstream GIS work (writing files,
#' spatial joins, further `sf` analysis) without carrying the layout metadata.
#'
#' @param layout An `exploded_map` or `grouped_exploded_map` object.
#' @param which Which stored geometry layer to return. For `exploded_map`:
#'   `"exploded"` (default) or `"original"`. For `grouped_exploded_map`:
#'   `"grouped"` (default), `"local"`, or `"original"`.
#'
#' @return A plain `sf` object with the selected geometry layer active. All
#'   attribute columns and the CRS are kept as stored. Layout metadata
#'   (`stats`, `params`, `plots`, `refinement`, `diagnostics`, `anchors`) is
#'   dropped. The `"exploded"`/`"grouped"` layers carry the displaced
#'   geometries; `"original"` carries the input geometries.
#' @export
#'
#' @examples
#' \donttest{
#' sq <- function(xmin, ymin, size = 1) {
#'   sf::st_polygon(list(matrix(
#'     c(xmin, ymin, xmin + size, ymin, xmin + size, ymin + size,
#'       xmin, ymin + size, xmin, ymin),
#'     ncol = 2, byrow = TRUE
#'   )))
#' }
#' x <- sf::st_sf(
#'   id = c("a1", "a2", "b1", "b2"),
#'   region = c("A", "A", "B", "B"),
#'   geometry = sf::st_sfc(sq(0, 0), sq(2, 0), sq(10, 0), sq(12, 0), crs = 3857)
#' )
#' layout <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)
#'
#' # Displaced geometries, ready for st_write() or further analysis
#' exp_sf <- as_sf(layout)
#' sf::st_crs(exp_sf)
#'
#' # The untouched input geometries
#' orig_sf <- as_sf(layout, which = "original")
#' }
as_sf <- function(layout, which = c("exploded", "original")) {
  if (inherits(layout, "grouped_exploded_map")) {
    if (identical(which, c("exploded", "original"))) {
      # Untouched generic default: resolve to the displaced layer.
      which <- "grouped"
    }
    which <- match.arg(which, c("grouped", "local", "original"))
    layer <- switch(
      which,
      grouped  = layout$sf_grouped,
      local    = layout$sf_local,
      original = layout$sf_orig
    )
  } else if (inherits(layout, "exploded_map")) {
    which <- match.arg(which)
    layer <- switch(
      which,
      exploded = layout$sf_exp,
      original = layout$sf_orig
    )
  } else {
    stop(
      "`layout` must be an `exploded_map` or `grouped_exploded_map` object.",
      call. = FALSE
    )
  }
  if (!inherits(layer, "sf")) {
    stop("The '", which, "' geometry layer is missing from `layout`.",
         call. = FALSE)
  }
  layer
}

#' Per-feature displacement magnitudes of an exploded layout
#'
#' Measures how far each feature moved from its original position by comparing
#' feature centroids before and after displacement. Useful for summarising a
#' layout and for comparing parameter choices (see [compare_layouts()]).
#'
#' @param layout An `exploded_map` or `grouped_exploded_map` object.
#'
#' @return A `data.frame` with one row per feature (in feature order) and
#'   columns `dx`, `dy` (signed displacement components) and `distance`
#'   (Euclidean displacement magnitude), all in the layout's CRS units.
#' @export
#'
#' @examples
#' \donttest{
#' sq <- function(xmin, ymin, size = 1) {
#'   sf::st_polygon(list(matrix(
#'     c(xmin, ymin, xmin + size, ymin, xmin + size, ymin + size,
#'       xmin, ymin + size, xmin, ymin),
#'     ncol = 2, byrow = TRUE
#'   )))
#' }
#' x <- sf::st_sf(
#'   id = c("a1", "a2", "b1", "b2"),
#'   region = c("A", "A", "B", "B"),
#'   geometry = sf::st_sfc(sq(0, 0), sq(2, 0), sq(10, 0), sq(12, 0), crs = 3857)
#' )
#' layout <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)
#' head(displacement_magnitudes(layout))
#' }
displacement_magnitudes <- function(layout) {
  if (inherits(layout, "grouped_exploded_map")) {
    validate_grouped_layout(layout)
    before <- layout$sf_orig
    after <- layout$sf_grouped
  } else if (inherits(layout, "exploded_map")) {
    before <- layout$sf_orig
    after <- layout$sf_exp
  } else {
    stop(
      "`layout` must be an `exploded_map` or `grouped_exploded_map` object.",
      call. = FALSE
    )
  }
  if (nrow(before) != nrow(after)) {
    stop("Original and displaced layers have different row counts.",
         call. = FALSE)
  }
  centroid_fun <- layout$diagnostics$centroid_fun %||% "centroid"
  xy_before <- sf::st_coordinates(centroid_geoms(before, centroid_fun))[, 1:2]
  xy_after <- sf::st_coordinates(centroid_geoms(after, centroid_fun))[, 1:2]
  dx <- xy_after[, 1] - xy_before[, 1]
  dy <- xy_after[, 2] - xy_before[, 2]
  data.frame(
    dx = as.numeric(dx),
    dy = as.numeric(dy),
    distance = sqrt(as.numeric(dx)^2 + as.numeric(dy)^2)
  )
}

#' Compare displacement between two exploded layouts
#'
#' Summarises how per-feature displacement changes between two layouts of the
#' same input (e.g. different `alpha_r`/`alpha_l`/`gamma` choices or
#' before/after collision refinement). Both layouts must be of the same class
#' and cover the same features in the same row order.
#'
#' @param before,after `exploded_map` objects (or both
#'   `grouped_exploded_map` objects) to compare.
#'
#' @return A list with two elements:
#' * `per_feature`: `data.frame` with one row per feature and columns
#'   `distance_before`, `distance_after`, and `delta` (after minus before),
#'   in the layout's CRS units.
#' * `summary`: `data.frame` with one row per layout (`"before"`, `"after"`)
#'   and columns `total`, `mean`, and `max` displacement.
#' @export
#'
#' @examples
#' \donttest{
#' sq <- function(xmin, ymin, size = 1) {
#'   sf::st_polygon(list(matrix(
#'     c(xmin, ymin, xmin + size, ymin, xmin + size, ymin + size,
#'       xmin, ymin + size, xmin, ymin),
#'     ncol = 2, byrow = TRUE
#'   )))
#' }
#' x <- sf::st_sf(
#'   id = c("a1", "a2", "b1", "b2"),
#'   region = c("A", "A", "B", "B"),
#'   geometry = sf::st_sfc(sq(0, 0), sq(2, 0), sq(10, 0), sq(12, 0), crs = 3857)
#' )
#' small <- explode_sf(x, region_col = "region", alpha_r = 10, alpha_l = 10,
#'                     plot = FALSE, quiet = TRUE)
#' big <- explode_sf(x, region_col = "region", alpha_r = 100, alpha_l = 100,
#'                   plot = FALSE, quiet = TRUE)
#' cmp <- compare_layouts(small, big)
#' cmp$summary
#' }
compare_layouts <- function(before, after) {
  # Compare primary classes: grouped_exploded_map inherits from exploded_map,
  # so inherits() alone cannot tell the two layouts apart.
  primary_class <- function(x) class(x)[1]
  cls_before <- primary_class(before)
  cls_after <- primary_class(after)
  cls_ok <- cls_before %in% c("exploded_map", "grouped_exploded_map") &&
    identical(cls_before, cls_after)
  if (!cls_ok) {
    stop(
      "`before` and `after` must both be `exploded_map` objects or both be ",
      "`grouped_exploded_map` objects.",
      call. = FALSE
    )
  }
  d_before <- displacement_magnitudes(before)$distance
  d_after <- displacement_magnitudes(after)$distance
  if (length(d_before) != length(d_after)) {
    stop("`before` and `after` cover different numbers of features.",
         call. = FALSE)
  }
  per_feature <- data.frame(
    distance_before = d_before,
    distance_after = d_after,
    delta = d_after - d_before
  )
  summary <- data.frame(
    layout = c("before", "after"),
    total = c(sum(d_before), sum(d_after)),
    mean = c(mean(d_before), mean(d_after)),
    max = c(max(d_before), max(d_after)),
    stringsAsFactors = FALSE
  )
  list(per_feature = per_feature, summary = summary)
}
