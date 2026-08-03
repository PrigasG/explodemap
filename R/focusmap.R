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
#' @param group_palette Optional named character vector of colours for
#'   `group_col` values. Names should match group values; unmatched groups
#'   fall back to the widget palette.
#' @param context_col Optional column identifying features that should remain
#'   as geographic context rather than active focus features.
#' @param state Optional `dragmapr_state` editorial composition. Region offsets
#'   are applied before the widget data is transformed/simplified.
#' @param restore_selection When `TRUE` and `state` carries a `selected_feature`,
#'   the map opens focused on that feature (matched by `id_col` value or feature
#'   name), reproducing a saved composition's focus. Defaults to `FALSE` so the
#'   map opens in its normal idle view. No-op when the selection is empty or the
#'   feature is not found.
#' @param context_values Character vector of values in `context_col` that mark
#'   context features. Default `"context"`.
#' @param context_mode How context features are drawn: `"fade"` keeps them
#'   visible but muted, `"hide"` makes them invisible, and `"show"` draws them
#'   normally.
#' @param coordinate_system Coordinate system used by the widget. `"longlat"`
#'   transforms data to WGS84 and renders with a geographic projection.
#'   `"planar"` preserves projected coordinates and renders with a fitted
#'   planar projection. `"auto"` currently uses `"longlat"` for backwards
#'   compatibility.
#' @param context_fill Fill colour for context features when
#'   `context_mode = "fade"`.
#' @param context_opacity Fill opacity for faded context features.
#' @param context_clickable Should context features remain clickable? Default
#'   `FALSE`.
#' @param focus_preset Optional named preset for common interactive workflows.
#'   `"municipal"` tunes small-area focus, source cues, drag zoom, and dense
#'   layer performance. `"drilldown"` tunes context fading and source cues for
#'   selected-section maps. `"municipal_drilldown"` combines both. Explicit
#'   arguments supplied by the user override preset defaults.
#' @param simplify Controls geometry simplification for rendering
#'   performance. \code{TRUE} (default) applies a conservative tolerance of
#'   approximately one metre. Longitude/latitude data is simplified in a local metric
#'   projection to avoid latitude-dependent distortion. A positive number sets
#'   a custom tolerance in the data's coordinate units; longitude/latitude
#'   tolerances above 0.1 degrees are rejected as unsafe. \code{FALSE}
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
#' @param min_focus_width,min_focus_height Minimum focused feature width and
#'   height in screen pixels. When a selected feature is very small, the widget
#'   may zoom past the usual density-aware default until the lifted feature
#'   reaches these dimensions. Set to \code{0} to disable either constraint.
#' @param tiny_feature_threshold Screen-pixel size below which a selected
#'   feature receives an adaptive lift-scale boost. Set to \code{0} to disable.
#' @param tiny_feature_boost Maximum multiplier applied to \code{lift_scale}
#'   for the smallest features. Values below \code{1} are not allowed.
#' @param max_zoom Optional maximum camera zoom. If \code{NULL}, a density-aware
#'   default is used.
#' @param origin_context How the selected feature's source location should be
#'   shown while focused. The default \code{"none"} keeps focus maps visually
#'   unchanged unless this feature is explicitly enabled. \code{"socket"} keeps
#'   the source outline in the main
#'   map, \code{"inset"} shows a small overview map, \code{"both"} uses both,
#'   and \code{"none"} disables the cue.
#' @param origin_context_position Position for the overview inset:
#'   \code{"bottom-left"}, \code{"bottom-right"}, \code{"top-left"}, or
#'   \code{"top-right"}.
#' @param focus_context_opacity Fill opacity for non-selected features while a
#'   feature is focused. Lower values make tiny selected areas easier to read.
#' @param show_drag_zoom Show a widget-level drag-zoom toggle. When enabled,
#'   users can draw a marquee rectangle to zoom into dense clusters while
#'   ordinary feature clicks continue to focus the map. Shift-drag works as a
#'   shortcut even when the button is hidden.
#' @param show_group_labels Show one passive label per \code{group_col} value
#'   on the base map. Labels do not intercept pointer events, so feature
#'   click, hover, focus, and drag-zoom behavior are unchanged.
#' @param group_labels Optional named character vector or list for
#'   \code{show_group_labels}. Names should match \code{group_col} values;
#'   unmatched groups use their raw group value.
#' @param font_size Label font size in px. Default \code{14}.
#' @param show_labels Show labels on lifted shapes? Default \code{TRUE}.
#' @param show_sidebar Deprecated and has no effect. Will be removed in a
#'   future version.
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
#' \donttest{
#' poly <- function(xmin, ymin, xmax, ymax) {
#'   sf::st_polygon(list(rbind(
#'     c(xmin, ymin), c(xmax, ymin), c(xmax, ymax),
#'     c(xmin, ymax), c(xmin, ymin)
#'   )))
#' }
#'
#' counties <- sf::st_sf(
#'   NAME = c("A", "B"),
#'   region = c("North", "South"),
#'   geometry = sf::st_sfc(
#'     poly(-74.2, 40.0, -74.0, 40.2),
#'     poly(-73.9, 40.0, -73.7, 40.2),
#'     crs = 4326
#'   )
#' )
#'
#' focus_map(counties, label_col = "NAME", group_col = "region")
#' }
#'
#' @export
focus_map <- function(x,
                      label_col    = NULL,
                      id_col       = NULL,
                      group_col    = NULL,
                      group_palette = NULL,
                      context_col  = NULL,
                      state        = NULL,
                      restore_selection = FALSE,
                      context_values = "context",
                      context_mode = c("fade", "hide", "show"),
                      coordinate_system = c("auto", "longlat", "planar"),
                      context_fill = "#cfd9df",
                      context_opacity = 0.18,
                      context_clickable = FALSE,
                      focus_preset = c("none", "municipal", "drilldown", "municipal_drilldown"),
                      simplify     = TRUE,
                      fill         = "#2d6ea3",
                      fill_opacity = 0.58,
                      stroke       = "#ffffff",
                      lift_scale   = 1.16,
                      focus_padding = 40,
                      focus_size   = 0.76,
                      min_focus_width = 0,
                      min_focus_height = 0,
                      tiny_feature_threshold = 48,
                      tiny_feature_boost = 1,
                      max_zoom     = NULL,
                      origin_context = c("none", "socket", "inset", "both"),
                      origin_context_position = c("bottom-left", "bottom-right", "top-left", "top-right"),
                      focus_context_opacity = 0.3,
                      show_drag_zoom = FALSE,
                      show_group_labels = FALSE,
                      group_labels = NULL,
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

  if (!missing(show_sidebar)) {
    warning(
      "`show_sidebar` in focus_map() is not implemented and has no effect. ",
      "It will be removed in a future version of explodemap.",
      call. = FALSE
    )
  }

  focus_preset <- match.arg(focus_preset)
  preset <- focus_map_preset(focus_preset)
  if (!identical(focus_preset, "none")) {
    if (missing(context_mode) && !is.null(preset$context_mode)) context_mode <- preset$context_mode
    if (missing(context_opacity) && !is.null(preset$context_opacity)) context_opacity <- preset$context_opacity
    if (missing(focus_padding) && !is.null(preset$focus_padding)) focus_padding <- preset$focus_padding
    if (missing(focus_size) && !is.null(preset$focus_size)) focus_size <- preset$focus_size
    if (missing(min_focus_width) && !is.null(preset$min_focus_width)) min_focus_width <- preset$min_focus_width
    if (missing(min_focus_height) && !is.null(preset$min_focus_height)) min_focus_height <- preset$min_focus_height
    if (missing(tiny_feature_threshold) && !is.null(preset$tiny_feature_threshold)) tiny_feature_threshold <- preset$tiny_feature_threshold
    if (missing(tiny_feature_boost) && !is.null(preset$tiny_feature_boost)) tiny_feature_boost <- preset$tiny_feature_boost
    if (missing(max_zoom) && !is.null(preset$max_zoom)) max_zoom <- preset$max_zoom
    if (missing(origin_context) && !is.null(preset$origin_context)) origin_context <- preset$origin_context
    if (missing(origin_context_position) && !is.null(preset$origin_context_position)) origin_context_position <- preset$origin_context_position
    if (missing(focus_context_opacity) && !is.null(preset$focus_context_opacity)) focus_context_opacity <- preset$focus_context_opacity
    if (missing(show_drag_zoom) && !is.null(preset$show_drag_zoom)) show_drag_zoom <- preset$show_drag_zoom
    if (missing(performance_mode) && !is.null(preset$performance_mode)) performance_mode <- preset$performance_mode
  }

  x <- .apply_focus_state(x, state, group_col)

  initial_focus <- NULL
  if (isTRUE(restore_selection) && inherits(state, "dragmapr_state")) {
    sel <- state$selected_feature
    if (!is.null(sel) && length(sel) == 1L && !is.na(sel) && nzchar(sel)) {
      initial_focus <- as.character(sel)
    }
  }

  sf_obj <- .as_viewer_sf(x)
  .validate_sf_geometry_column(sf_obj)
  info_position <- match.arg(info_position)
  context_mode <- match.arg(context_mode)
  coordinate_system <- match.arg(coordinate_system)
  if (identical(coordinate_system, "auto")) {
    coordinate_system <- "longlat"
  }
  origin_context <- match.arg(origin_context)
  origin_context_position <- match.arg(origin_context_position)

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
      warning(
        "id_col '", id_col, "' not found in the data; falling back to row order. ",
        "In Shiny, input$<outputId>_selected$id will contain sequential integers ",
        "instead of the expected geographic identifiers.",
        call. = FALSE
      )
      id_col <- NULL
    }
  }

  if (!is.null(group_col)) {
    if (!group_col %in% names(sf_obj)) {
      warning("group_col '", group_col, "' not found; ignoring.", call. = FALSE)
      group_col <- NULL
    }
  }
  if (!is.null(context_col)) {
    if (!context_col %in% names(sf_obj)) {
      warning("context_col '", context_col, "' not found; ignoring.", call. = FALSE)
      context_col <- NULL
    }
  }
  context_values <- as.character(context_values %||% "context")
  context_values <- context_values[nzchar(context_values)]
  if (!length(context_values)) context_values <- "context"
  if (!is.numeric(context_opacity) || length(context_opacity) != 1 ||
      is.na(context_opacity)) {
    stop("`context_opacity` must be a single number.", call. = FALSE)
  }
  context_opacity <- max(0, min(1, context_opacity))
  .check_scalar_number <- function(value, name, lower = -Inf, allow_null = FALSE) {
    if (is.null(value) && isTRUE(allow_null)) {
      return(NULL)
    }
    if (!is.numeric(value) || length(value) != 1 || is.na(value)) {
      stop("`", name, "` must be a single number.", call. = FALSE)
    }
    if (value < lower) {
      stop("`", name, "` must be at least ", lower, ".", call. = FALSE)
    }
    value
  }
  min_focus_width <- .check_scalar_number(min_focus_width, "min_focus_width", lower = 0)
  min_focus_height <- .check_scalar_number(min_focus_height, "min_focus_height", lower = 0)
  tiny_feature_threshold <- .check_scalar_number(
    tiny_feature_threshold,
    "tiny_feature_threshold",
    lower = 0
  )
  tiny_feature_boost <- .check_scalar_number(tiny_feature_boost, "tiny_feature_boost", lower = 1)
  focus_context_opacity <- .check_scalar_number(
    focus_context_opacity,
    "focus_context_opacity",
    lower = 0
  )
  focus_context_opacity <- min(1, focus_context_opacity)
  if (!is.null(group_palette)) {
    if (is.null(names(group_palette)) || any(!nzchar(names(group_palette)))) {
      warning("group_palette must be a named character vector; ignoring.", call. = FALSE)
      group_palette <- NULL
    } else {
      palette_names <- names(group_palette)
      group_palette <- as.list(unname(as.character(group_palette)))
      names(group_palette) <- palette_names
    }
  }
  if (!is.null(group_labels)) {
    group_labels <- unlist(group_labels, use.names = TRUE)
    if (is.null(names(group_labels)) || any(!nzchar(names(group_labels)))) {
      warning("group_labels must be a named character vector/list; ignoring.", call. = FALSE)
      group_labels <- NULL
    } else {
      label_names <- names(group_labels)
      group_labels <- as.list(unname(as.character(group_labels)))
      names(group_labels) <- label_names
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

  # Repair before and after coordinate conversion. Some display layouts use
  # translated projected geometries that are valid for planar drawing but trip
  # s2's spherical loop checks after transformation.
  sf_obj <- .repair_widget_geometry(sf_obj)

  if (identical(coordinate_system, "longlat")) {
    # Ensure WGS 84
    if (is.na(sf::st_crs(sf_obj))) {
      sf_obj <- sf::st_set_crs(sf_obj, 4326)
    } else if (!identical(sf::st_crs(sf_obj)$epsg, 4326L)) {
      sf_obj <- sf::st_transform(sf_obj, 4326)
    }
  }

  sf_obj <- .repair_widget_geometry(sf_obj)
  sf_obj <- sf_obj[!sf::st_is_empty(sf_obj), ]

  if (nrow(sf_obj) == 0) {
    stop("No non-empty geometries remain after validation.", call. = FALSE)
  }

  # Simplify geometry for rendering performance. Keep TRUE conservative:
  # dense municipal layers can contain thousands of small polygons, and large
  # tolerances visibly flatten Census boundaries into long straight chords.
  # This does NOT affect the original data -- only the widget copy.
  # Pass simplify = FALSE to disable, or a custom numeric tolerance.
  valid_logical_simplify <- is.logical(simplify) && length(simplify) == 1L && !is.na(simplify)
  valid_numeric_simplify <- is.numeric(simplify) && length(simplify) == 1L &&
    is.finite(simplify) && simplify > 0
  if (!valid_logical_simplify && !valid_numeric_simplify) {
    stop("`simplify` must be TRUE, FALSE, or one positive finite number.", call. = FALSE)
  }
  if (is.numeric(simplify) && isTRUE(sf::st_is_longlat(sf_obj)) && simplify > 0.1) {
    stop(
      "Numeric `simplify` must not exceed 0.1 degrees for longitude/latitude data; ",
      "use TRUE, a smaller value, or pre-simplify in a projected CRS.",
      call. = FALSE
    )
  }
  if (isTRUE(simplify) || is.numeric(simplify)) {
    tolerance <- if (isTRUE(simplify)) 0.00001 else simplify
    sf_obj <- .simplify_focus_geometry(sf_obj, tolerance)
    sf_obj <- .repair_widget_geometry(sf_obj)
    sf_obj <- sf_obj[!sf::st_is_empty(sf_obj), ]
  }

  geojson_str <- .sf_to_geojson_fast(
    sf_obj = sf_obj,
    label_col = label_col,
    id_col = id_col,
    group_col = group_col,
    context_col = context_col,
    info_cols = info_cols,
    info_title = info_title,
    rfc7946 = identical(coordinate_system, "longlat")
  )

  payload <- list(
    geojson_str = geojson_str,
    options = list(
      fill         = fill,
      coordinateSystem = coordinate_system,
      groupPalette = group_palette,
      contextMode = context_mode,
      contextValues = as.list(context_values),
      contextFill = context_fill,
      contextOpacity = context_opacity,
      contextClickable = isTRUE(context_clickable),
      focusPreset = focus_preset,
      fillOpacity  = fill_opacity,
      stroke       = stroke,
      liftScale    = lift_scale,
      focusPadding = focus_padding,
      focusSize    = focus_size,
      minFocusWidth = min_focus_width,
      minFocusHeight = min_focus_height,
      tinyFeatureThreshold = tiny_feature_threshold,
      tinyFeatureBoost = tiny_feature_boost,
      maxZoom      = max_zoom,
      originContext = origin_context,
      originContextPosition = origin_context_position,
      focusContextOpacity = focus_context_opacity,
      showDragZoom = isTRUE(show_drag_zoom),
      showGroupLabels = isTRUE(show_group_labels) && !is.null(group_col),
      groupLabels = group_labels,
      fontSize     = font_size,
      showLabels   = show_labels,
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

  # Only emit initialFocus when a selection is actually being restored, so
  # default renders produce byte-for-byte identical widget options.
  if (!is.null(initial_focus)) {
    payload$options$initialFocus <- initial_focus
  }

  htmlwidgets::createWidget(
    name      = "focusmap",
    x         = payload,
    width     = width,
    height    = height,
    package   = "explodemap",
    elementId = elementId
  )
}

.simplify_focus_geometry <- function(sf_obj, tolerance) {
  if (!isTRUE(sf::st_is_longlat(sf_obj))) {
    return(sf::st_simplify(
      sf_obj,
      preserveTopology = TRUE,
      dTolerance = tolerance
    ))
  }

  bbox <- sf::st_bbox(sf_obj)
  longitude <- mean(as.numeric(bbox[c("xmin", "xmax")]))
  latitude <- mean(as.numeric(bbox[c("ymin", "ymax")]))
  if (!is.finite(longitude) || !is.finite(latitude)) {
    stop("Cannot derive a metric simplification CRS from the geometry extent.", call. = FALSE)
  }
  local_crs <- paste0(
    "+proj=aeqd +lat_0=", latitude,
    " +lon_0=", longitude,
    " +datum=WGS84 +units=m +no_defs"
  )
  original_crs <- sf::st_crs(sf_obj)
  metric_tolerance <- tolerance * 111195
  metric <- sf::st_transform(sf_obj, local_crs)
  metric <- sf::st_simplify(
    metric,
    preserveTopology = TRUE,
    dTolerance = metric_tolerance
  )
  sf::st_transform(metric, original_crs)
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

#' Focus-map Shiny proxy
#'
#' @param outputId Shiny output ID for an existing `focus_map()`.
#' @param session Shiny session. Defaults to the current reactive domain.
#' @return A `focusmap_proxy` object.
#' @export
focusMapProxy <- function(outputId, session = NULL) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The shiny package is required for focusMapProxy().", call. = FALSE)
  }
  if (is.null(session)) {
    session <- shiny::getDefaultReactiveDomain()
  }
  if (is.null(session)) {
    stop("No active Shiny session found. Supply `session` explicitly.", call. = FALSE)
  }
  structure(list(id = outputId, session = session), class = "focusmap_proxy")
}

#' @rdname focusMapProxy
#' @param proxy A `focusmap_proxy`.
#' @param show Logical; show focus labels.
#' @export
update_focus_labels <- function(proxy, show = TRUE) {
  .send_focusmap_proxy(proxy, "updateFocusLabels", list(show = isTRUE(show)))
}

#' @rdname focusMapProxy
#' @param palette Named character vector of group colours.
#' @export
update_focus_palette <- function(proxy, palette) {
  if (is.null(names(palette)) || any(!nzchar(names(palette)))) {
    stop("`palette` must be a named character vector.", call. = FALSE)
  }
  # Preserve the names: the browser keys `groupPalette` by group, so the value
  # must serialize to a JSON object ({group: colour}), not a bare array.
  pal <- as.character(palette)
  names(pal) <- names(palette)
  .send_focusmap_proxy(proxy, "updateFocusPalette", as.list(pal))
}

#' @rdname focusMapProxy
#' @param data New `sf`, `exploded_map`, or `grouped_exploded_map` data.
#' @param ... Passed to [focus_map()] when building the replacement payload.
#'
#' @details
#' `update_focus_data()` swaps the widget's geometry and rebuilds it, which
#' returns the map to its idle (unfocused) view -- a data swap is treated as a
#' fresh dataset. To keep the user focused on a feature across the swap, pass a
#' `state` and `restore_selection = TRUE` through `...`; these flow to
#' [focus_map()] and the new feature is re-focused on load:
#'
#' ```r
#' update_focus_data(proxy, new_sf, id_col = "GEOID",
#'                   state = state, restore_selection = TRUE)
#' ```
#' @export
update_focus_data <- function(proxy, data, ...) {
  widget <- focus_map(data, ...)
  .send_focusmap_proxy(proxy, "updateFocusData", widget$x)
}

.send_focusmap_proxy <- function(proxy, method, value) {
  if (!inherits(proxy, "focusmap_proxy")) {
    stop("`proxy` must be created by focusMapProxy().", call. = FALSE)
  }
  proxy$session$sendCustomMessage(
    "explodemap-focusmap-proxy",
    list(id = proxy$id, method = method, value = value)
  )
  invisible(proxy)
}

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

.apply_focus_state <- function(x, state, group_col) {
  if (is.null(state)) {
    return(x)
  }
  if (!inherits(state, "dragmapr_state")) {
    stop("`state` must be a dragmapr_state object.", call. = FALSE)
  }
  if (inherits(x, "grouped_exploded_map")) {
    return(update_exploded_layout(x, state, update_plots = FALSE))
  }
  if (!requireNamespace("dragmapr", quietly = TRUE)) {
    stop("Package 'dragmapr' is required to apply focus-map state.", call. = FALSE)
  }
  if (inherits(x, "exploded_map")) {
    region_col <- x$diagnostics$region_col %||% group_col %||%
      state$region_col %||% state$binding$region_col %||% state$level
    out <- x
    out$sf_exp <- dragmapr::apply_dragmapr_state(out$sf_exp, state, region_col = region_col)
    out$sf_exp_wgs <- sf::st_transform(out$sf_exp, 4326)
    return(out)
  }
  if (inherits(x, "sf")) {
    region_col <- group_col %||% state$region_col %||%
      state$binding$region_col %||% state$level
    if (is.null(region_col) || !nzchar(region_col)) {
      stop("`group_col` is required when applying `state` to a raw sf object.",
           call. = FALSE)
    }
    return(dragmapr::apply_dragmapr_state(x, state, region_col = region_col))
  }
  x
}

#' Repair widget geometry with planar validity checks
#' @keywords internal
.repair_widget_geometry <- function(sf_obj) {
  old_s2 <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
  suppressMessages(sf::sf_use_s2(FALSE))
  sf::st_make_valid(sf_obj)
}


#' Fast bulk GeoJSON via a single sf::st_write call
#'
#' Writes the whole sf to a temp GeoJSON file and passes the raw JSON
#' string to the widget. The JS side does \code{JSON.parse()}, which
#' avoids the \code{fromJSON → R list → toJSON} round-trip that can
#' mangle deeply nested coordinate arrays.
#' @keywords internal
.sf_to_geojson_fast <- function(sf_obj, label_col, id_col = NULL, group_col = NULL,
                                context_col = NULL, info_cols = NULL,
                                info_title = label_col, rfc7946 = TRUE) {
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

  if (!is.null(context_col)) {
    slim$context <- as.character(sf_obj[[context_col]])
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
  old_s2 <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
  suppressMessages(sf::sf_use_s2(FALSE))
  layer_options <- if (isTRUE(rfc7946)) {
    c("RFC7946=YES", "WRITE_BBOX=NO")
  } else {
    "WRITE_BBOX=NO"
  }
  suppressWarnings(
    sf::st_write(slim, tmp, driver = "GeoJSON", quiet = TRUE,
                 delete_dsn = TRUE,
                 layer_options = layer_options)
  )

  # Return raw JSON string — JS will parse it, not R.
  # encoding = "UTF-8" is required: sf::st_write produces UTF-8 GeoJSON but
  # readLines() defaults to the system locale on Windows, which silently
  # mojibakes non-ASCII feature names (accented characters, CJK, etc.).
  paste(readLines(tmp, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a
