# =============================================================================
# R/units.R — CRS unit introspection
# =============================================================================

#' CRS units of an exploded layout or sf object
#'
#' Returns the map-unit string recorded in the coordinate reference system
#' (e.g. `"m"` for metre-based projections, `"us-ft"` for US survey feet).
#' Distance parameters throughout explodemap (`alpha_r`, `alpha_l`, gaps,
#' refinement shifts) are interpreted in these CRS units, so reporting the
#' unit string keeps downstream code honest when the CRS is not metre-based.
#'
#' @param x An `exploded_map`, `grouped_exploded_map`, `sf`, or `sfc` object.
#'
#' @return A single character string with the CRS unit, or `NA_character_` when
#'   the object has no CRS or the CRS records no usable unit.
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
#' explodemap_units(x) # "m"
#'
#' layout <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)
#' explodemap_units(layout) # "m"
#'
#' no_crs <- sf::st_set_crs(x, NA)
#' explodemap_units(no_crs) # NA
#' }
explodemap_units <- function(x) {
  if (inherits(x, "exploded_map") || inherits(x, "grouped_exploded_map")) {
    x <- x$sf_orig
  }
  if (!inherits(x, c("sf", "sfc"))) {
    stop(
      "`x` must be an `exploded_map`, `grouped_exploded_map`, `sf`, or `sfc` object.",
      call. = FALSE
    )
  }
  crs <- sf::st_crs(x)
  if (is.na(crs)) {
    return(NA_character_)
  }
  units <- crs$units
  if (is.null(units) || length(units) != 1L || is.na(units) ||
      !nzchar(trimws(units))) {
    return(NA_character_)
  }
  as.character(units)
}
