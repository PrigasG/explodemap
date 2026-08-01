#' Diagnose grouped layout quality
#'
#' @param result A `grouped_exploded_map` object.
#' @param label_col Optional label column for approximate label overlap checks.
#' @param label_size Approximate label size in map units.
#' @return A `layout_quality_report` list.
#' @export
diagnose_layout <- function(result, label_col = NULL, label_size = NULL) {
  if (!inherits(result, "grouped_exploded_map")) {
    stop("`result` must be a grouped_exploded_map object.", call. = FALSE)
  }
  region_col <- result$diagnostics$region_col
  sf_grouped <- result$sf_grouped

  overlap <- .polygon_overlap_report(sf_grouped, region_col)
  gaps <- .group_gap_report(sf_grouped, region_col)
  displacement <- .region_displacement_report(result$sf_orig, sf_grouped, region_col)
  bbox <- sf::st_bbox(sf_grouped)
  width <- as.numeric(bbox["xmax"] - bbox["xmin"])
  height <- as.numeric(bbox["ymax"] - bbox["ymin"])
  hull_area <- as.numeric(sf::st_area(sf::st_convex_hull(sf::st_union(sf::st_geometry(sf_grouped)))))
  canvas_area <- width * height
  polygon_area <- sum(as.numeric(sf::st_area(sf_grouped)), na.rm = TRUE)
  original_bbox <- sf::st_bbox(result$sf_orig)
  original_width <- as.numeric(original_bbox["xmax"] - original_bbox["xmin"])
  original_height <- as.numeric(original_bbox["ymax"] - original_bbox["ymin"])
  original_diagonal <- sqrt(original_width^2 + original_height^2)
  label_overlaps <- .label_overlap_count(sf_grouped, label_col, label_size)
  label_count <- if (!is.null(label_col) && label_col %in% names(sf_grouped)) {
    labels <- trimws(as.character(sf_grouped[[label_col]]))
    sum(!is.na(labels) & nzchar(labels))
  } else {
    0L
  }
  possible_label_pairs <- label_count * (label_count - 1) / 2

  out <- list(
    polygon_overlap_area = overlap$total_area,
    polygon_overlap_fraction = if (polygon_area > 0) overlap$total_area / polygon_area else 0,
    overlapping_pairs = overlap$pairs,
    minimum_group_gap = gaps$minimum_group_gap,
    mean_displacement = displacement$mean,
    mean_displacement_fraction = if (original_diagonal > 0) displacement$mean / original_diagonal else 0,
    maximum_displacement = displacement$max,
    label_overlap_count = label_overlaps,
    label_overlap_fraction = if (possible_label_pairs > 0) label_overlaps / possible_label_pairs else 0,
    canvas_utilization = if (canvas_area > 0) hull_area / canvas_area else NA_real_,
    aspect_ratio = if (height > 0) width / height else NA_real_,
    mental_map_stability = displacement$stability,
    anchors = result$anchors,
    region_col = region_col,
    plot_data = list(group_gaps = gaps$pairs)
  )
  structure(out, class = c("layout_quality_report", "list"))
}

#' @export
print.layout_quality_report <- function(x, ...) {
  cat("Layout quality report\n")
  cat("  polygon overlap area: ", signif(x$polygon_overlap_area, 4), "\n", sep = "")
  cat("  overlapping pairs: ", nrow(x$overlapping_pairs), "\n", sep = "")
  cat("  minimum group gap: ", fmt_dist(x$minimum_group_gap), "\n", sep = "")
  cat("  mean displacement: ", fmt_dist(x$mean_displacement), "\n", sep = "")
  cat("  maximum displacement: ", fmt_dist(x$maximum_displacement), "\n", sep = "")
  cat("  label overlap count: ", x$label_overlap_count, "\n", sep = "")
  cat("  canvas utilization: ", sprintf("%.2f", x$canvas_utilization), "\n", sep = "")
  cat("  aspect ratio: ", sprintf("%.2f", x$aspect_ratio), "\n", sep = "")
  cat("  mental map stability: ", sprintf("%.2f", x$mental_map_stability), "\n", sep = "")
  invisible(x)
}

#' Plot a grouped-layout diagnostic
#'
#' Renders the region anchors as block circles inside the layout's canvas frame,
#' so unused space is visible as the gap between the blocks and the frame, and
#' draws a red segment between every overlapping region pair. The subtitle
#' summarises overlaps, label overlaps, and canvas utilization.
#'
#' @param x A `layout_quality_report` from [diagnose_layout()].
#' @param ... Unused.
#' @return A `ggplot` object.
#' @export
plot.layout_quality_report <- function(x, ...) {
  anchors <- x$anchors
  region_col <- x$region_col
  if (is.null(anchors) || !nrow(anchors)) {
    stop("No anchor data available for diagnostic plot.", call. = FALSE)
  }

  anchors$.region <- as.character(anchors[[region_col]])
  has_radius <- "block_radius" %in% names(anchors) &&
    any(is.finite(anchors$block_radius))
  pad <- if (has_radius) stats::median(anchors$block_radius, na.rm = TRUE) else 0

  p <- ggplot2::ggplot()

  # Canvas frame: the bounding box of the blocks. The empty area between the
  # block circles and this frame is the "unused space".
  frame <- data.frame(
    xmin = min(anchors$anchor_x) - pad,
    xmax = max(anchors$anchor_x) + pad,
    ymin = min(anchors$anchor_y) - pad,
    ymax = max(anchors$anchor_y) + pad
  )
  p <- p + ggplot2::geom_rect(
    data = frame,
    ggplot2::aes(xmin = .data$xmin, xmax = .data$xmax,
                 ymin = .data$ymin, ymax = .data$ymax),
    fill = "#f3f6fa", color = "#9aa7b4", linetype = "dashed"
  )

  # Block circles (true map-unit radius) so blocks and the space between them
  # read at a glance.
  if (has_radius) {
    th <- seq(0, 2 * pi, length.out = 64)
    circles <- do.call(rbind, lapply(seq_len(nrow(anchors)), function(k) {
      r <- anchors$block_radius[k]
      if (!is.finite(r) || r <= 0) return(NULL)
      data.frame(
        .region = anchors$.region[k],
        x = anchors$anchor_x[k] + r * cos(th),
        y = anchors$anchor_y[k] + r * sin(th)
      )
    }))
    if (!is.null(circles)) {
      p <- p + ggplot2::geom_polygon(
        data = circles,
        ggplot2::aes(.data$x, .data$y, group = .data[[".region"]]),
        fill = "#2d6ea3", alpha = 0.18, color = "#2d6ea3"
      )
    }
  }

  # Problematic pairs: a red segment between every overlapping region's anchors.
  pairs <- x$overlapping_pairs
  if (!is.null(pairs) && nrow(pairs) > 0) {
    idx_i <- match(as.character(pairs$region_i), anchors$.region)
    idx_j <- match(as.character(pairs$region_j), anchors$.region)
    keep <- !is.na(idx_i) & !is.na(idx_j)
    if (any(keep)) {
      seg <- data.frame(
        x = anchors$anchor_x[idx_i[keep]],
        y = anchors$anchor_y[idx_i[keep]],
        xend = anchors$anchor_x[idx_j[keep]],
        yend = anchors$anchor_y[idx_j[keep]]
      )
      p <- p + ggplot2::geom_segment(
        data = seg,
        ggplot2::aes(x = .data$x, y = .data$y, xend = .data$xend, yend = .data$yend),
        color = "#c0392b", linewidth = 0.9
      )
    }
  }

  p +
    ggplot2::geom_point(
      data = anchors,
      ggplot2::aes(.data$anchor_x, .data$anchor_y),
      size = 2.4, color = "#1b3b57"
    ) +
    ggplot2::geom_text(
      data = anchors,
      ggplot2::aes(.data$anchor_x, .data$anchor_y, label = .data[[".region"]]),
      nudge_y = pad * 0.10, size = 3
    ) +
    ggplot2::coord_equal() +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::labs(
      title = "Grouped layout diagnostics",
      subtitle = paste0(
        "overlaps=", nrow(x$overlapping_pairs),
        "  label overlaps=", x$label_overlap_count,
        "  utilization=", sprintf("%.2f", x$canvas_utilization)
      )
    )
}

#' Build layout objective weights
#'
#' @param overlap Weight for polygon overlap as a fraction of total polygon area.
#' @param displacement Weight for mean displacement as a fraction of the
#'   original layout diagonal.
#' @param unused_space Weight for unused canvas space.
#' @param label_overlap Weight for approximate label overlaps as a fraction of
#'   all possible label pairs.
#' @return Named numeric vector of objective weights.
#' @export
layout_objective <- function(overlap = 10,
                             displacement = 2,
                             unused_space = 1,
                             label_overlap = 4) {
  c(
    overlap = overlap,
    displacement = displacement,
    unused_space = unused_space,
    label_overlap = label_overlap
  )
}

#' Search grouped-layout parameters
#'
#' @param x Projected sf object with region column.
#' @param region_col Grouping column name.
#' @param objective Objective presets: `"no_overlap"`, `"compact"`,
#'   `"balanced"`, and/or `"stable"`.
#' @param weights Named weights from [layout_objective()].
#' @param label_col,label_size Optional label column and approximate label size.
#'   When `label_col` is supplied the search becomes label-aware: each candidate
#'   layout is scored for approximate label overlaps (weighted by the
#'   `label_overlap` term of `weights`). Left `NULL` (the default), label
#'   overlaps contribute zero, so the search result is identical to before.
#' @param grid Optional data.frame of parameter combinations.
#' @param kappa,padding,delta,padding_sep Candidate values used when `grid` is
#'   `NULL`.
#' @param ... Passed to [explode_grouped()].
#' @return A `grouped_exploded_map` with `optimization` metadata.
#' @export
optimize_grouped_layout <- function(x,
                                    region_col,
                                    objective = c("no_overlap", "compact", "balanced", "stable"),
                                    weights = layout_objective(),
                                    label_col = NULL,
                                    label_size = NULL,
                                    grid = NULL,
                                    kappa = c(1.4, 1.8, 2.2),
                                    padding = c(25000, 50000, 75000),
                                    delta = c(5000, 15000, 30000),
                                    padding_sep = c(10000, 20000, 40000),
                                    ...) {
  objective <- match.arg(objective, several.ok = TRUE)
  weights <- .objective_weights(objective, weights)
  search_label_size <- label_size
  if (is.null(search_label_size) && !is.null(label_col) && label_col %in% names(x)) {
    input_bbox <- sf::st_bbox(x)
    search_label_size <- max(
      as.numeric(input_bbox["xmax"] - input_bbox["xmin"]),
      as.numeric(input_bbox["ymax"] - input_bbox["ymin"])
    ) * 0.025
  }
  if (is.null(grid)) {
    grid <- expand.grid(
      kappa = kappa,
      padding = padding,
      delta = delta,
      padding_sep = padding_sep,
      KEEP.OUT.ATTRS = FALSE
    )
  }
  if (!is.data.frame(grid) || !all(c("kappa", "padding", "delta", "padding_sep") %in% names(grid))) {
    stop("`grid` must contain kappa, padding, delta, and padding_sep columns.", call. = FALSE)
  }

  runs <- vector("list", nrow(grid))
  scores <- numeric(nrow(grid))
  reports <- vector("list", nrow(grid))
  for (i in seq_len(nrow(grid))) {
    params <- grid[i, ]
    runs[[i]] <- explode_grouped(
      x,
      region_col = region_col,
      mode = "auto_collision",
      kappa = params$kappa,
      padding = params$padding,
      delta = params$delta,
      padding_sep = params$padding_sep,
      plot = FALSE,
      quiet = TRUE,
      ...
    )
    reports[[i]] <- diagnose_layout(
      runs[[i]],
      label_col = label_col,
      label_size = search_label_size
    )
    scores[i] <- .score_layout_report(reports[[i]], weights)
  }

  best <- which.min(scores)
  out <- runs[[best]]
  out$optimization <- list(
    objective = objective,
    weights = weights,
    label_size = search_label_size,
    grid = grid,
    scores = scores,
    best_index = best,
    best_report = reports[[best]]
  )
  out
}

#' Convert a grouped layout to a drag-edit handoff object (legacy)
#'
#' @description
#' Legacy / low-level handoff (superseded, but not deprecated).
#'
#' This is the original handoff: it bundles the grouped geometry and
#' the absolute anchors into a `dragmapr_layout` list. The preferred path is now
#' [as_dragmapr_state()], which emits a geometry-free `dragmapr::dragmapr_state()`
#' -- the shared editorial composition contract that `state =` arguments accept
#' across `focus_map()`, `render_dragged_map()`, and `update_exploded_layout()`.
#'
#' `as_dragmapr()` remains supported for existing offset-table / CSV workflows
#' and is not scheduled for removal, but new code should prefer the state-first
#' API.
#'
#' @param result A `grouped_exploded_map`.
#' @return A `dragmapr_layout` list containing editable sf geometry and anchors.
#' @seealso [as_dragmapr_state()] for the preferred state-first handoff.
#' @export
as_dragmapr <- function(result) {
  if (!inherits(result, "grouped_exploded_map")) {
    stop("`result` must be a grouped_exploded_map object.", call. = FALSE)
  }
  structure(
    list(
      sf = result$sf_grouped,
      region_offsets = result$anchors,
      label_offsets = result$label_offsets %||% NULL,
      region_col = result$diagnostics$region_col
    ),
    class = c("dragmapr_layout", "list")
  )
}

#' Convert a grouped layout to a dragmapr editing state
#'
#' Produces a `dragmapr::dragmapr_state()` -- the shared editorial composition
#' contract -- from a `grouped_exploded_map`. Unlike [as_dragmapr()], which
#' bundles geometry and absolute anchors into a handoff list, this emits the
#' geometry-free *state* that the interactive editor and static renderers
#' consume: the exploded anchors (`anchor_x`/`anchor_y`) are converted to the
#' metre deltas (`dx_m`/`dy_m`) relative to the current region centroids that
#' `dragmapr` expects, and the projected CRS plus a provenance `geometry_id`
#' are recorded so the state can be reapplied safely in a later session.
#'
#' Keep `layout` (the computed geometry + diagnostics, i.e. `result`) and
#' `state` (this editorial overlay) separate. The layout can be recomputed
#' freely while the state preserves manual edits, which is what makes the
#' `compute -> compose -> render` workflow reproducible.
#'
#' @param result A `grouped_exploded_map`.
#' @param geometry_id Optional single string identifying the source geometry.
#'   Defaults to the layout label in `result$diagnostics$label`.
#' @param level Optional geography-level label. Defaults to the region column.
#' @return A `dragmapr_state` (see `dragmapr::dragmapr_state()`).
#' @export
as_dragmapr_state <- function(result, geometry_id = NULL, level = NULL) {
  if (!inherits(result, "grouped_exploded_map")) {
    stop("`result` must be a grouped_exploded_map object.", call. = FALSE)
  }
  if (!requireNamespace("dragmapr", quietly = TRUE)) {
    stop(
      "Package 'dragmapr' is required for as_dragmapr_state(); ",
      "install it to produce dragmapr state objects.",
      call. = FALSE
    )
  }
  if (!"dragmapr_state" %in% getNamespaceExports("dragmapr")) {
    stop(
      "as_dragmapr_state() requires a version of dragmapr that exports ",
      "dragmapr_state(). Install/update dragmapr before using this bridge.",
      call. = FALSE
    )
  }
  region_col <- result$diagnostics$region_col
  level <- level %||% region_col
  geometry_id <- geometry_id %||% result$diagnostics$label

  anchors <- result$anchors
  region_offsets <- if (is.null(anchors) ||
                        !all(c(region_col, "anchor_x", "anchor_y") %in% names(anchors))) {
    data.frame(region = character(), dx_m = numeric(), dy_m = numeric(),
               stringsAsFactors = FALSE)
  } else {
    current <- .region_centroids(
      result$sf_grouped, region_col, result$diagnostics$centroid_fun
    )
    anchors |>
      dplyr::select(dplyr::all_of(c(region_col, "anchor_x", "anchor_y"))) |>
      dplyr::left_join(current, by = region_col) |>
      dplyr::transmute(
        region = as.character(.data[[region_col]]),
        dx_m = .data$anchor_x - .data$cx,
        dy_m = .data$anchor_y - .data$cy
      ) |>
      as.data.frame()
  }

  crs <- tryCatch(sf::st_crs(result$sf_grouped), error = function(e) NULL)
  crs_arg <- if (is.null(crs) || is.na(crs)) NULL else crs

  dragmapr_state <- getExportedValue("dragmapr", "dragmapr_state")
  dragmapr_state(
    level = level,
    region_offsets = region_offsets,
    label_offsets = result$label_offsets %||% NULL,
    crs = crs_arg,
    geometry_id = geometry_id
  )
}

#' Update an exploded grouped layout after manual composition
#'
#' @param result A `grouped_exploded_map`.
#' @param region_offsets Data frame of manual anchors (`anchor_x`, `anchor_y`)
#'   or offsets (`dx_m`, `dy_m`) by region.
#' @param label_offsets Optional label-offset table stored on the result.
#' @param update_plots Rebuild stored ggplots.
#' @return Updated `grouped_exploded_map`.
#' @export
update_exploded_layout <- function(result,
                                   region_offsets,
                                   label_offsets = NULL,
                                   update_plots = TRUE) {
  if (!inherits(result, "grouped_exploded_map")) {
    stop("`result` must be a grouped_exploded_map object.", call. = FALSE)
  }
  region_col <- result$diagnostics$region_col
  if (inherits(region_offsets, "dragmapr_layout")) {
    label_offsets <- label_offsets %||% region_offsets$label_offsets
    region_offsets <- region_offsets$region_offsets
  }
  if (inherits(region_offsets, "dragmapr_state")) {
    label_offsets <- label_offsets %||% region_offsets$label_offsets
    region_offsets <- region_offsets$region_offsets
  }
  if (!is.data.frame(region_offsets)) {
    stop("`region_offsets` must be a data.frame, dragmapr_layout, or dragmapr_state.",
         call. = FALSE)
  }

  out <- result
  if (all(c(region_col, "anchor_x", "anchor_y") %in% names(region_offsets))) {
    current <- .region_centroids(out$sf_grouped, region_col, out$diagnostics$centroid_fun)
    offsets <- region_offsets |>
      dplyr::select(dplyr::all_of(c(region_col, "anchor_x", "anchor_y"))) |>
      dplyr::left_join(current, by = region_col) |>
      dplyr::transmute(
        region = .data[[region_col]],
        dx_m = .data$anchor_x - .data$cx,
        dy_m = .data$anchor_y - .data$cy
      )
    out <- apply_region_offsets(out, offsets, update_plots = FALSE)
    out$anchors <- out$anchors |>
      dplyr::select(-dplyr::any_of(c("anchor_x", "anchor_y"))) |>
      dplyr::left_join(
        region_offsets |> dplyr::select(dplyr::all_of(c(region_col, "anchor_x", "anchor_y"))),
        by = region_col
      )
  } else {
    out <- apply_region_offsets(out, region_offsets, update_plots = FALSE)
    if (all(c("region", "dx_m", "dy_m") %in% names(region_offsets)) &&
        !is.null(out$anchors) &&
        all(c(region_col, "anchor_x", "anchor_y") %in% names(out$anchors))) {
      anchor_offsets <- region_offsets |>
        dplyr::transmute(
          !!region_col := as.character(.data$region),
          dx_m = .data$dx_m,
          dy_m = .data$dy_m
        )
      out$anchors <- out$anchors |>
        dplyr::left_join(anchor_offsets, by = region_col) |>
        dplyr::mutate(
          anchor_x = .data$anchor_x + dplyr::coalesce(.data$dx_m, 0),
          anchor_y = .data$anchor_y + dplyr::coalesce(.data$dy_m, 0)
        ) |>
        dplyr::select(-dplyr::any_of(c("dx_m", "dy_m")))
    }
  }

  out$label_offsets <- label_offsets
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
  out
}

.polygon_overlap_report <- function(sf_obj, region_col) {
  n <- nrow(sf_obj)
  pairs <- data.frame(i = integer(), j = integer(), region_i = character(),
                      region_j = character(), overlap_area = numeric())
  total <- 0
  if (n < 2) return(list(total_area = total, pairs = pairs))
  geom <- sf::st_geometry(sf_obj)
  hits <- sf::st_intersects(geom, geom)
  for (i in seq_len(n - 1L)) {
    js <- hits[[i]]
    js <- js[js > i]
    for (j in js) {
      area <- suppressWarnings(as.numeric(sf::st_area(sf::st_intersection(geom[i], geom[j]))))
      area <- sum(area[is.finite(area)], na.rm = TRUE)
      if (area <= 0) next
      pairs <- rbind(pairs, data.frame(
        i = i,
        j = j,
        region_i = as.character(sf_obj[[region_col]][i]),
        region_j = as.character(sf_obj[[region_col]][j]),
        overlap_area = area
      ))
      total <- total + area
    }
  }
  rownames(pairs) <- NULL
  list(total_area = total, pairs = pairs)
}

.group_gap_report <- function(sf_obj, region_col) {
  reg <- sf_obj |>
    dplyr::group_by(dplyr::across(dplyr::all_of(region_col))) |>
    dplyr::summarise(geometry = sf::st_union(.data$geometry), .groups = "drop")
  n <- nrow(reg)
  pairs <- data.frame(region_i = character(), region_j = character(), gap = numeric())
  if (n < 2) return(list(minimum_group_gap = NA_real_, pairs = pairs))
  geom <- sf::st_geometry(reg)
  for (i in seq_len(n - 1L)) {
    for (j in seq.int(i + 1L, n)) {
      gap <- as.numeric(sf::st_distance(geom[i], geom[j], by_element = TRUE))
      pairs <- rbind(pairs, data.frame(
        region_i = as.character(reg[[region_col]][i]),
        region_j = as.character(reg[[region_col]][j]),
        gap = gap
      ))
    }
  }
  rownames(pairs) <- NULL
  list(minimum_group_gap = min(pairs$gap, na.rm = TRUE), pairs = pairs)
}

.region_displacement_report <- function(sf_orig, sf_grouped, region_col) {
  orig <- .region_centroids(sf_orig, region_col, "centroid")
  grouped <- .region_centroids(sf_grouped, region_col, "centroid")
  df <- orig |>
    dplyr::rename(cx_orig = "cx", cy_orig = "cy") |>
    dplyr::left_join(
      grouped |> dplyr::rename(cx_grouped = "cx", cy_grouped = "cy"),
      by = region_col
    ) |>
    dplyr::mutate(d = sqrt((.data$cx_grouped - .data$cx_orig)^2 +
                             (.data$cy_grouped - .data$cy_orig)^2))
  max_d <- max(df$d, na.rm = TRUE)
  mean_d <- mean(df$d, na.rm = TRUE)
  list(
    mean = mean_d,
    max = max_d,
    stability = if (is.finite(max_d) && max_d > 0) 1 / (1 + mean_d / max_d) else 1,
    details = df
  )
}

.region_centroids <- function(sf_obj, region_col, centroid_fun = "centroid") {
  reg <- sf_obj |>
    dplyr::group_by(dplyr::across(dplyr::all_of(region_col))) |>
    dplyr::summarise(geometry = sf::st_union(.data$geometry), .groups = "drop")
  xy <- sf::st_coordinates(centroid_geoms(reg, centroid_fun))
  out <- data.frame(
    region = reg[[region_col]],
    cx = xy[, 1],
    cy = xy[, 2],
    stringsAsFactors = FALSE
  )
  names(out)[1] <- region_col
  out
}

.label_overlap_count <- function(sf_obj, label_col, label_size) {
  if (is.null(label_col) || !label_col %in% names(sf_obj) || nrow(sf_obj) < 2) return(0L)
  bb <- sf::st_bbox(sf_obj)
  if (is.null(label_size)) {
    label_size <- max(as.numeric(bb["xmax"] - bb["xmin"]), as.numeric(bb["ymax"] - bb["ymin"])) * 0.025
  }
  xy <- sf::st_coordinates(centroid_geoms(sf_obj, "point_on_surface"))
  labels <- trimws(as.character(sf_obj[[label_col]]))
  keep <- !is.na(labels) & nzchar(labels)
  if (sum(keep) < 2L) return(0L)
  labels <- labels[keep]
  xy <- xy[keep, 1:2, drop = FALSE]
  widths <- pmax(nchar(labels, type = "width", keepNA = TRUE), 1L) * label_size * 0.55
  half_widths <- widths / 2
  half_heights <- rep(label_size / 2, length(labels))
  boxes <- lapply(seq_along(labels), function(i) {
    xmin <- xy[i, 1] - half_widths[[i]]
    xmax <- xy[i, 1] + half_widths[[i]]
    ymin <- xy[i, 2] - half_heights[[i]]
    ymax <- xy[i, 2] + half_heights[[i]]
    sf::st_polygon(list(rbind(
      c(xmin, ymin), c(xmax, ymin), c(xmax, ymax),
      c(xmin, ymax), c(xmin, ymin)
    )))
  })
  box_geometry <- sf::st_sfc(boxes, crs = sf::st_crs(sf_obj))
  intersections <- sf::st_intersects(box_geometry, sparse = TRUE)
  as.integer(sum(vapply(
    seq_along(intersections),
    function(i) sum(intersections[[i]] > i),
    integer(1)
  )))
}

.objective_weights <- function(objective, weights) {
  out <- weights
  if ("no_overlap" %in% objective) out["overlap"] <- out["overlap"] * 2
  if ("compact" %in% objective) out["unused_space"] <- out["unused_space"] * 2
  if ("stable" %in% objective) out["displacement"] <- out["displacement"] * 2
  if ("balanced" %in% objective) out["unused_space"] <- out["unused_space"] * 1.5
  out
}

.score_layout_report <- function(report, weights) {
  vals <- c(
    overlap = ifelse(is.finite(report$polygon_overlap_fraction), report$polygon_overlap_fraction, 0),
    displacement = ifelse(is.finite(report$mean_displacement_fraction), report$mean_displacement_fraction, 0),
    unused_space = ifelse(is.finite(report$canvas_utilization), 1 - report$canvas_utilization, 1),
    label_overlap = ifelse(is.finite(report$label_overlap_fraction), report$label_overlap_fraction, 0)
  )
  sum(vals[names(weights)] * weights, na.rm = TRUE)
}
