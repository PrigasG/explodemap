# =============================================================================
# R/focusmap.R — Interactive focus-map viewer (htmlwidget)
# =============================================================================

#' Interactive focus-map viewer
#'
#' Renders spatial features as a smooth, interactive SVG map. Click any
#' polygon to zoom in and lift it from the map with a "toast" effect;
#' right-click or press Escape to reset. Camera transitions use D3's
#' optimal zoom interpolation for fluid 60 fps motion with zero server
#' round-trips.
#'
#' Accepts raw \code{sf} objects, \code{exploded_map} results from
#' \code{\link{explode_sf}}, or \code{grouped_exploded_map} results from
#' \code{\link{explode_grouped}}. For exploded objects, the displaced
#' (WGS 84) geometry is used automatically.
#'
#' @param x An \code{sf}, \code{exploded_map}, or
#'   \code{grouped_exploded_map} object.
#' @param label_col Character. Column name for polygon labels.
#'   Auto-detected if \code{NULL}.
#' @param group_col Character. Optional column for region/group
#'   colouring. Polygons sharing a group value share a hue.
#' @param simplify Controls geometry simplification for rendering
#'   performance. \code{TRUE} (default) applies a sensible tolerance
#'   (\code{dTolerance = 0.001} in WGS 84 degrees, \eqn{\approx}
#'   100 m). A positive number sets a custom tolerance. \code{FALSE}
#'   disables simplification. Only affects the widget copy — the
#'   original data is never modified.
#' @param fill Fill colour (used when \code{group_col} is \code{NULL}).
#'   Default \code{"#2d6ea3"}.
#' @param fill_opacity Fill opacity. Default \code{0.58}.
#' @param stroke Stroke colour. Default \code{"#ffffff"}.
#' @param lift_scale Initial toast lift scale. Default \code{1.16}.
#' @param font_size Label font size in px. Default \code{14}.
#' @param show_labels Show labels on lifted shapes? Default \code{TRUE}.
#' @param show_sidebar Show control sidebar? Default \code{TRUE}.
#' @param area_min Min screen area (px^2) for label visibility.
#' @param width_min Min screen width (px) for label visibility.
#' @param height_min Min screen height (px) for label visibility.
#' @param width Widget width. Default \code{"100\%"}.
#' @param height Widget height. Default \code{"600px"}.
#' @param elementId Optional element ID.
#'
#' @return An \code{htmlwidgets} object.
#'
#' @examples
#' \dontrun{
#' focus_map(nj_counties, label_col = "NAME")
#'
#' result <- explode_sf(nj_counties, region_col = "region")
#' focus_map(result)
#' focus_map(result, group_col = "region")
#' }
#'
#' @export
focus_map <- function(x,
                      label_col    = NULL,
                      group_col    = NULL,
                      simplify     = TRUE,
                      fill         = "#2d6ea3",
                      fill_opacity = 0.58,
                      stroke       = "#ffffff",
                      lift_scale   = 1.16,
                      font_size    = 14,
                      show_labels  = TRUE,
                      show_sidebar = TRUE,
                      area_min     = 5000,
                      width_min    = 95,
                      height_min   = 28,
                      width        = "100%",
                      height       = "600px",
                      elementId    = NULL) {

  sf_obj <- .as_viewer_sf(x)

  # Auto-detect label column
  if (is.null(label_col)) {
    candidates <- c("NAME", "name", "Name", "LABEL", "label",
                    "NAMELSAD", "county", "County")
    label_col <- intersect(candidates, names(sf_obj))[1]
    if (is.na(label_col) || is.null(label_col)) {
      label_col <- names(sf_obj)[1]
    }
  }

  stopifnot_col <- function(col) {
    if (!col %in% names(sf_obj)) {
      stop("Column '", col, "' not found in the data.", call. = FALSE)
    }
  }
  stopifnot_col(label_col)

  if (!is.null(group_col)) {
    if (!group_col %in% names(sf_obj)) {
      warning("group_col '", group_col, "' not found; ignoring.", call. = FALSE)
      group_col <- NULL
    }
  }

  # Ensure WGS 84
  if (is.na(sf::st_crs(sf_obj))) {
    sf_obj <- sf::st_set_crs(sf_obj, 4326)
  } else if (!identical(sf::st_crs(sf_obj)$epsg, 4326L)) {
    sf_obj <- sf::st_transform(sf_obj, 4326)
  }

  sf_obj <- sf::st_make_valid(sf_obj)
  sf_obj <- sf_obj[!sf::st_is_empty(sf_obj), ]

  if (nrow(sf_obj) == 0) {
    stop("No non-empty geometries remain after validation.", call. = FALSE)
  }

  # Simplify geometry for rendering performance.
  # Heavier states need heavier simplification in the widget copy.
  #   < 50 features  → 0.002° (~200 m) — light touch
  #   50–150         → 0.005° (~500 m) — moderate
  #   150–220        → 0.01°  (~1 km)  — Georgia-tier
  #   > 220          → 0.02°  (~2 km)  — Texas-tier (254 counties)
  # This does NOT affect the original data — only the widget copy.
  # Pass simplify = FALSE to disable, or a custom numeric tolerance.
  if (isTRUE(simplify)) {
    n <- nrow(sf_obj)

    tol <- if (n > 220) {
      0.02
    } else if (n > 150) {
      0.01
    } else if (n > 50) {
      0.005
    } else {
      0.002
    }

    sf_obj <- sf::st_simplify(
      sf_obj,
      preserveTopology = TRUE,
      dTolerance = tol
    )
    sf_obj <- sf_obj[!sf::st_is_empty(sf_obj), ]
  } else if (is.numeric(simplify) && length(simplify) == 1 && simplify > 0) {
    sf_obj <- sf::st_simplify(
      sf_obj,
      preserveTopology = TRUE,
      dTolerance = simplify
    )
    sf_obj <- sf_obj[!sf::st_is_empty(sf_obj), ]
  }

  geojson_str <- .sf_to_geojson_fast(sf_obj, label_col, group_col)

  payload <- list(
    geojson_str = geojson_str,
    options = list(
      fill         = fill,
      fillOpacity  = fill_opacity,
      stroke       = stroke,
      liftScale    = lift_scale,
      fontSize     = font_size,
      showLabels   = show_labels,
      showSidebar  = show_sidebar,
      areaMin      = area_min,
      widthMin     = width_min,
      heightMin    = height_min,
      hasGroups    = !is.null(group_col)
    )
  )

  htmlwidgets::createWidget(
    name      = "focusmap",
    x         = payload,
    width     = width,
    height    = height,
    package   = "explodemap",
    elementId = elementId
  )
}


#' @rdname focus_map
#' @export
focusmapOutput <- function(outputId, width = "100%", height = "600px") {
  htmlwidgets::shinyWidgetOutput(outputId, "focusmap",
                                 width, height, package = "explodemap")
}

#' @rdname focus_map
#' @export
renderFocusmap <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) expr <- substitute(expr)
  htmlwidgets::shinyRenderWidget(expr, focusmapOutput, env, quoted = TRUE)
}


# ── internal helpers ─────────────────────────────────────────────────────────

#' @keywords internal
.as_viewer_sf <- function(x) {
  if (inherits(x, "grouped_exploded_map")) {
    if (!is.null(x$sf_grouped_wgs)) return(x$sf_grouped_wgs)
    stop("grouped_exploded_map has no sf_grouped_wgs component.", call. = FALSE)
  }
  if (inherits(x, "exploded_map")) {
    if (!is.null(x$sf_exp_wgs)) return(x$sf_exp_wgs)
    stop("exploded_map has no sf_exp_wgs component.", call. = FALSE)
  }
  if (inherits(x, "sf")) return(x)
  stop("x must be an sf, exploded_map, or grouped_exploded_map.", call. = FALSE)
}


#' Fast bulk GeoJSON via a single sf::st_write call
#'
#' Writes the whole sf to a temp GeoJSON file and passes the raw JSON
#' string to the widget. The JS side does \code{JSON.parse()}, which
#' avoids the \code{fromJSON → R list → toJSON} round-trip that can
#' mangle deeply nested coordinate arrays.
#' @keywords internal
.sf_to_geojson_fast <- function(sf_obj, label_col, group_col = NULL) {
  # Build a slim sf with only the columns the widget needs
  slim <- data.frame(
    feature_id = as.character(seq_len(nrow(sf_obj))),
    NAME       = as.character(sf_obj[[label_col]]),
    stringsAsFactors = FALSE
  )

  if (!is.null(group_col)) {
    slim$group <- as.character(sf_obj[[group_col]])
  }

  slim <- sf::st_sf(slim, geometry = sf::st_geometry(sf_obj))

  tmp <- tempfile(fileext = ".geojson")
  on.exit(unlink(tmp), add = TRUE)

  # RFC7946=YES forces counter-clockwise exterior rings, which is what
  # D3's spherical geometry engine expects. Without this, GDAL may write
  # clockwise rings (OGC convention), causing D3 to interpret each polygon
  # as its spherical complement — "everything on Earth except this county."
  # That is the blue-square bug.
  sf::st_write(slim, tmp, driver = "GeoJSON", quiet = TRUE,
               delete_dsn = TRUE,
               layer_options = c("RFC7946=YES", "WRITE_BBOX=NO"))

  # Return raw JSON string — JS will parse it, not R
  paste(readLines(tmp, warn = FALSE), collapse = "\n")
}

#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a
