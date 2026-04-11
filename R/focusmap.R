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
#' @param id_col Optional stable feature ID column for Shiny selection events.
#'   Defaults to row order if \code{NULL}.
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
#'   Increase this to make the lifted feature larger.
#' @param focus_padding Extra screen-space padding in pixels around the lifted
#'   feature during focus. Increase this if large lifted features feel too
#'   close to the map edge.
#' @param focus_size Target fraction of the map viewport the lifted feature
#'   may occupy. Increase this to make selected areas appear larger while
#'   preserving \code{focus_padding}.
#' @param max_zoom Optional maximum camera zoom. If \code{NULL}, a density-aware
#'   default is used.
#' @param font_size Label font size in px. Default \code{14}.
#' @param show_labels Show labels on lifted shapes? Default \code{TRUE}.
#' @param show_sidebar Show control sidebar? Default \code{TRUE}.
#' @param performance_mode Logical or \code{NULL}. If \code{NULL}, dense
#'   layers automatically use shorter camera transitions and lighter
#'   in-flight rendering. Set \code{TRUE} to force it or \code{FALSE} to
#'   disable it.
#' @param info_cols Optional character vector of columns to show in a
#'   non-blocking focus card when a feature is selected.
#' @param info_labels Optional named character vector or list for display
#'   labels in the focus card. Names should match \code{info_cols}.
#' @param info_title Optional column to use as the focus card title. Defaults
#'   to \code{label_col}.
#' @param info_position Position for the focus card: \code{"top-right"},
#'   \code{"top-left"}, \code{"bottom-right"}, or \code{"bottom-left"}.
#' @param info_card_scale Relative size for the focus card. Values above
#'   \code{1} make the card larger; values below \code{1} make it more compact.
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
                      id_col       = NULL,
                      group_col    = NULL,
                      simplify     = TRUE,
                      fill         = "#2d6ea3",
                      fill_opacity = 0.58,
                      stroke       = "#ffffff",
                      lift_scale   = 1.16,
                      focus_padding = 40,
                      focus_size   = 0.76,
                      max_zoom     = NULL,
                      font_size    = 14,
                      show_labels  = TRUE,
                      show_sidebar = TRUE,
                      performance_mode = NULL,
                      info_cols    = NULL,
                      info_labels  = NULL,
                      info_title   = NULL,
                      info_position = c("top-right", "top-left", "bottom-right", "bottom-left"),
                      info_card_scale = 1,
                      area_min     = 5000,
                      width_min    = 95,
                      height_min   = 28,
                      width        = "100%",
                      height       = "600px",
                      elementId    = NULL) {

  sf_obj <- .as_viewer_sf(x)
  info_position <- match.arg(info_position)

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

  if (!is.null(id_col)) {
    if (!id_col %in% names(sf_obj)) {
      warning("id_col '", id_col, "' not found; using row order.", call. = FALSE)
      id_col <- NULL
    }
  }

  if (!is.null(group_col)) {
    if (!group_col %in% names(sf_obj)) {
      warning("group_col '", group_col, "' not found; ignoring.", call. = FALSE)
      group_col <- NULL
    }
  }

  if (is.null(info_title)) {
    info_title <- label_col
  }
  if (!is.null(info_title) && !info_title %in% names(sf_obj)) {
    warning("info_title '", info_title, "' not found; using label_col.", call. = FALSE)
    info_title <- label_col
  }
  if (!is.null(info_cols)) {
    missing_info_cols <- setdiff(info_cols, names(sf_obj))
    if (length(missing_info_cols) > 0) {
      warning(
        "Ignoring info_cols not found in data: ",
        paste(missing_info_cols, collapse = ", "),
        call. = FALSE
      )
      info_cols <- intersect(info_cols, names(sf_obj))
    }
  }
  if (!is.null(info_labels)) {
    info_labels <- unlist(info_labels, use.names = TRUE)
    if (is.null(names(info_labels)) || any(!nzchar(names(info_labels)))) {
      warning("info_labels must be a named character vector/list; ignoring.", call. = FALSE)
      info_labels <- NULL
    } else {
      info_labels <- as.character(info_labels)
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

    tol <- if (n > 3000) {
      0.05
    } else if (n > 1500) {
      0.04
    } else if (n > 500) {
      0.03
    } else if (n > 220) {
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

  geojson_str <- .sf_to_geojson_fast(
    sf_obj = sf_obj,
    label_col = label_col,
    id_col = id_col,
    group_col = group_col,
    info_cols = info_cols,
    info_title = info_title
  )

  payload <- list(
    geojson_str = geojson_str,
    options = list(
      fill         = fill,
      fillOpacity  = fill_opacity,
      stroke       = stroke,
      liftScale    = lift_scale,
      focusPadding = focus_padding,
      focusSize    = focus_size,
      maxZoom      = max_zoom,
      fontSize     = font_size,
      showLabels   = show_labels,
      showSidebar  = show_sidebar,
      performanceMode = performance_mode,
      showInfoCard = !is.null(info_cols) && length(info_cols) > 0,
      infoPosition = info_position,
      infoCols = info_cols,
      infoKeys = make.names(info_cols %||% character()),
      infoLabels = info_labels,
      infoTitle = info_title,
      infoCardScale = info_card_scale,
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
#' @param outputId Shiny output ID.
#' @export
focusmapOutput <- function(outputId, width = "100%", height = "600px") {
  htmlwidgets::shinyWidgetOutput(outputId, "focusmap",
                                 width, height, package = "explodemap")
}

#' @rdname focus_map
#' @param expr Expression that returns a \code{focus_map()} widget.
#' @param env Environment in which to evaluate \code{expr}.
#' @param quoted Logical. Is \code{expr} already quoted?
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
.sf_to_geojson_fast <- function(sf_obj, label_col, id_col = NULL, group_col = NULL,
                                info_cols = NULL, info_title = label_col) {
  # Build a slim sf with only the columns the widget needs
  slim <- data.frame(
    feature_id = as.character(seq_len(nrow(sf_obj))),
    id         = if (is.null(id_col)) as.character(seq_len(nrow(sf_obj))) else as.character(sf_obj[[id_col]]),
    NAME       = as.character(sf_obj[[label_col]]),
    stringsAsFactors = FALSE
  )

  if (!is.null(group_col)) {
    slim$group <- as.character(sf_obj[[group_col]])
  }

  if (!is.null(info_title)) {
    slim$info_title <- as.character(sf_obj[[info_title]])
  }

  for (col in info_cols %||% character()) {
    safe_col <- make.names(col)
    slim[[paste0("info_", safe_col)]] <- as.character(sf_obj[[col]])
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
