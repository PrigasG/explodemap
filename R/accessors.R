#' Access geometry from a grouped exploded layout
#'
#' These accessors expose the stable geometry components of a
#' `grouped_exploded_map` without requiring applications to inspect the layout's
#' internal list structure.
#'
#' @param layout A `grouped_exploded_map`.
#'
#' @return An `sf` object.
#' @export
original_geometry <- function(layout) {
  validate_grouped_layout(layout)
  layout$sf_orig
}

#' @rdname original_geometry
#' @export
local_geometry <- function(layout) {
  validate_grouped_layout(layout)
  layout$sf_local
}

#' @rdname original_geometry
#' @export
final_geometry <- function(layout) {
  validate_grouped_layout(layout)
  layout$sf_grouped
}

#' @rdname original_geometry
#' @export
group_geometry <- function(layout) {
  validate_grouped_layout(layout)
  region_col <- layout$diagnostics$region_col
  layout$sf_grouped |>
    dplyr::group_by(dplyr::across(dplyr::all_of(region_col))) |>
    dplyr::summarise(geometry = sf::st_union(.data$geometry), .groups = "drop")
}

#' Access grouped-layout anchor data
#'
#' @param layout A `grouped_exploded_map`.
#'
#' @return A data frame with one row per group anchor.
#' @export
anchor_table <- function(layout) {
  validate_grouped_layout(layout)
  as.data.frame(layout$anchors)
}

#' Computed offsets from a grouped exploded layout
#'
#' Returns the base movement created by `explodemap`. These offsets are distinct
#' from manual/editorial offsets stored by `dragmapr`.
#'
#' @param layout A `grouped_exploded_map`.
#' @param level Either `"group"` or `"feature"`.
#' @param id_col Optional feature ID column for `level = "feature"`.
#' @param require_stable_id Require a real feature ID column for feature-level
#'   persistent handoffs. When `TRUE`, row-number fallback IDs are rejected.
#'
#' @return A data frame of computed offsets.
#' @export
layout_offsets <- function(layout,
                           level = c("group", "feature"),
                           id_col = NULL,
                           require_stable_id = identical(level, "feature")) {
  validate_grouped_layout(layout)
  level <- match.arg(level)
  region_col <- layout$diagnostics$region_col
  centroid_fun <- layout$diagnostics$centroid_fun %||% "centroid"

  if (identical(level, "group")) {
    orig <- .region_centroids(layout$sf_orig, region_col, centroid_fun)
    final <- .region_centroids(layout$sf_grouped, region_col, centroid_fun)
    out <- orig |>
      dplyr::rename(original_anchor_x = "cx", original_anchor_y = "cy") |>
      dplyr::left_join(
        final |> dplyr::rename(final_anchor_x = "cx", final_anchor_y = "cy"),
        by = region_col
      ) |>
      dplyr::mutate(
        base_dx_m = .data$final_anchor_x - .data$original_anchor_x,
        base_dy_m = .data$final_anchor_y - .data$original_anchor_y
      ) |>
      dplyr::transmute(
        parent_id = as.character(.data[[region_col]]),
        anchor_x = .data$final_anchor_x,
        anchor_y = .data$final_anchor_y,
        base_dx_m = .data$base_dx_m,
        base_dy_m = .data$base_dy_m
      ) |>
      as.data.frame()
    return(out)
  }

  require_stable_id <- isTRUE(require_stable_id)
  id_col <- resolve_feature_id_col(layout$sf_orig, id_col, require_stable_id = require_stable_id)
  orig_xy <- feature_anchor_xy(layout$sf_orig, centroid_fun)
  final_xy <- feature_anchor_xy(layout$sf_grouped, centroid_fun)
  data.frame(
    feature_id = feature_ids(layout$sf_orig, id_col, require_stable_id = require_stable_id),
    parent_id = as.character(layout$sf_orig[[region_col]]),
    original_anchor_x = orig_xy[, 1],
    original_anchor_y = orig_xy[, 2],
    final_anchor_x = final_xy[, 1],
    final_anchor_y = final_xy[, 2],
    base_dx_m = final_xy[, 1] - orig_xy[, 1],
    base_dy_m = final_xy[, 2] - orig_xy[, 2],
    stringsAsFactors = FALSE
  )
}

#' Renderer-neutral transition data
#'
#' Describes original-to-final movement for groups or features. Rendering
#' systems can use this table for SVG, MapLibre, deck.gl, or static animation
#' plans without inspecting layout internals.
#'
#' @param layout A `grouped_exploded_map`.
#' @param level Either `"group"` or `"feature"`.
#' @inheritParams layout_offsets
#' @param ordering Optional ordering column for `level = "feature"`.
#'
#' @return A data frame with movement, distance, angle, and animation order.
#' @export
transition_data <- function(layout,
                            level = c("group", "feature"),
                            id_col = NULL,
                            ordering = NULL,
                            require_stable_id = identical(level, "feature")) {
  level <- match.arg(level)
  offsets <- layout_offsets(
    layout,
    level = level,
    id_col = id_col,
    require_stable_id = require_stable_id
  )
  if (identical(level, "group")) {
    offsets$feature_id <- offsets$parent_id
    offsets$original_anchor_x <- offsets$anchor_x - offsets$base_dx_m
    offsets$original_anchor_y <- offsets$anchor_y - offsets$base_dy_m
    offsets$final_anchor_x <- offsets$anchor_x
    offsets$final_anchor_y <- offsets$anchor_y
  }
  offsets$distance_m <- sqrt(offsets$base_dx_m^2 + offsets$base_dy_m^2)
  offsets$angle_degrees <- atan2(offsets$base_dy_m, offsets$base_dx_m) * 180 / pi
  offsets$animation_order <- deterministic_order(
    offsets,
    id_col = "feature_id",
    ordering_values = feature_order_values(layout, level, ordering)
  )
  offsets[, c(
    "feature_id", "parent_id",
    "original_anchor_x", "original_anchor_y",
    "final_anchor_x", "final_anchor_y",
    "base_dx_m", "base_dy_m",
    "distance_m", "angle_degrees", "animation_order"
  )]
}

#' Connector geometry for computed layout movement
#'
#' Builds one line per moved group or feature, from the original anchor to the
#' final anchor.
#'
#' @param layout A `grouped_exploded_map`.
#' @param level Either `"group"` or `"feature"`.
#' @inheritParams layout_offsets
#' @param threshold_m Minimum movement distance to mark a connector visible.
#' @param include_unmoved Include zero-distance rows.
#'
#' @return An `sf` line layer with movement attributes.
#' @export
connector_geometry <- function(layout,
                               level = c("group", "feature"),
                               id_col = NULL,
                               threshold_m = 1,
                               include_unmoved = FALSE,
                               require_stable_id = identical(level, "feature")) {
  validate_grouped_layout(layout)
  level <- match.arg(level)
  threshold_m <- numeric_scalar(threshold_m, "`threshold_m`", min = 0)
  include_unmoved <- isTRUE(include_unmoved)
  movement <- transition_data(
    layout,
    level = level,
    id_col = id_col,
    require_stable_id = require_stable_id
  )
  movement$visible <- movement$distance_m >= threshold_m
  if (!include_unmoved) {
    movement <- movement[movement$visible, , drop = FALSE]
  }
  crs <- sf::st_crs(layout$sf_grouped)
  geom <- lapply(seq_len(nrow(movement)), function(i) {
    sf::st_linestring(matrix(
      c(
        movement$original_anchor_x[i], movement$original_anchor_y[i],
        movement$final_anchor_x[i], movement$final_anchor_y[i]
      ),
      ncol = 2,
      byrow = TRUE
    ))
  })
  movement$geometry <- sf::st_sfc(geom, crs = crs)
  sf::st_as_sf(movement)
}

validate_grouped_layout <- function(layout) {
  if (!inherits(layout, "grouped_exploded_map")) {
    stop("`layout` must be a grouped_exploded_map object.", call. = FALSE)
  }
  required <- c("sf_orig", "sf_local", "sf_grouped", "anchors", "diagnostics")
  missing <- setdiff(required, names(layout))
  if (length(missing)) {
    stop("`layout` is missing component(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  invisible(layout)
}

feature_anchor_xy <- function(x, centroid_fun) {
  sf::st_coordinates(centroid_geoms(x, centroid_fun))[, 1:2, drop = FALSE]
}

resolve_feature_id_col <- function(x, id_col = NULL, require_stable_id = FALSE) {
  if (!is.null(id_col)) {
    if (!id_col %in% names(x)) {
      stop("`id_col` column '", id_col, "' was not found.", call. = FALSE)
    }
    return(id_col)
  }
  candidates <- c("feature_id", "unit_id", "GEOID", "geoid", "id", "ID")
  hit <- candidates[candidates %in% names(x)]
  if (length(hit)) {
    return(hit[[1]])
  }
  if (isTRUE(require_stable_id)) {
    stop(
      "Feature-level output requires a stable feature ID column. ",
      "Pass `id_col` or run prepare_explodemap_input() first.",
      call. = FALSE
    )
  }
  NULL
}

feature_ids <- function(x, id_col = NULL, require_stable_id = FALSE) {
  ids <- if (is.null(id_col)) {
    if (isTRUE(require_stable_id)) {
      stop(
        "Feature-level output requires a stable feature ID column. ",
        "Pass `id_col` or run prepare_explodemap_input() first.",
        call. = FALSE
      )
    }
    as.character(seq_len(nrow(x)))
  } else {
    as.character(x[[id_col]])
  }
  if (anyNA(ids) || any(!nzchar(ids))) {
    stop("Feature IDs cannot be missing.", call. = FALSE)
  }
  ids
}

feature_order_values <- function(layout, level, ordering) {
  if (is.null(ordering)) {
    return(NULL)
  }
  if (!identical(level, "feature")) {
    return(NULL)
  }
  if (!ordering %in% names(layout$sf_orig)) {
    stop("`ordering` column '", ordering, "' was not found.", call. = FALSE)
  }
  layout$sf_orig[[ordering]]
}

deterministic_order <- function(x, id_col, ordering_values = NULL) {
  if (!is.null(ordering_values)) {
    ord <- order(ordering_values, x[[id_col]], na.last = TRUE)
  } else {
    cx <- mean(range(x$original_anchor_x, na.rm = TRUE))
    cy <- mean(range(x$original_anchor_y, na.rm = TRUE))
    angle <- atan2(x$original_anchor_y - cy, x$original_anchor_x - cx)
    ord <- order(angle, x$distance_m, x[[id_col]])
  }
  out <- integer(nrow(x))
  out[ord] <- seq_along(ord)
  out
}

numeric_scalar <- function(x, arg, min = -Inf) {
  x <- suppressWarnings(as.numeric(x))
  if (length(x) != 1L || is.na(x) || x < min) {
    stop(arg, " must be a single number >= ", min, ".", call. = FALSE)
  }
  x
}
