#' Lay out child geography around a parent
#'
#' Computes a renderer-neutral child expansion in projected map units. Child
#' features move radially away from the parent anchor, then a bounded
#' axis-aligned bounding-box or circle solver separates collisions while an
#' attraction term and bearing guard preserve the source geography's mental
#' map. The returned base offsets are algorithmic movement; manual/editorial
#' movement belongs in a `dragmapr_state` and can be composed downstream.
#'
#' @param x Projected polygon `sf` object containing child features.
#' @param id_col Stable unique feature identifier column.
#' @param parent Optional single parent identifier recorded in the output.
#' @param parent_geometry Optional parent `sf`, `sfc`, or `sfg` geometry whose
#'   representative point anchors the expansion. Defaults to the union of `x`.
#' @param scale Radial expansion multiplier applied to source vectors.
#' @param radial_kick Additional outward movement in projected map units.
#'   Defaults to two percent of the child layer's bounding-box diagonal.
#' @param gap Minimum separation in projected map units. Defaults to one
#'   percent of the child layer's bounding-box diagonal.
#' @param collision Collision approximation: feature bounding boxes or
#'   centroid circles derived from those boxes.
#' @param attraction Fraction of the remaining distance to the geographic
#'   target applied during each refinement iteration.
#' @param max_bearing_drift Maximum angular drift from the source bearing, in
#'   radians.
#' @param bounds Optional bounding box supplied as an `sf`/`sfc` object,
#'   `st_bbox`, or numeric `c(xmin, ymin, xmax, ymax)`.
#' @param max_iter Maximum collision-refinement iterations.
#'
#' @return An `explodemap_child_layout` with `offsets`, composed `geometry`,
#'   source geometry, diagnostics, and parameters. `offsets` contains stable
#'   IDs, source/final anchors, base offsets, distance, bearing, bearing drift,
#'   and residual collision counts.
#' @export
layout_children <- function(x,
                            id_col,
                            parent = NULL,
                            parent_geometry = NULL,
                            scale = 1.6,
                            radial_kick = NULL,
                            gap = NULL,
                            collision = c("bbox", "circle"),
                            attraction = 0.08,
                            max_bearing_drift = 0.22,
                            bounds = NULL,
                            max_iter = 180L) {
  if (!inherits(x, "sf")) {
    stop("`x` must be an sf object.", call. = FALSE)
  }
  if (!is.character(id_col) || length(id_col) != 1L || is.na(id_col) ||
      !nzchar(id_col) || !id_col %in% names(x)) {
    stop("`id_col` must name one column in `x`.", call. = FALSE)
  }
  ids <- as.character(x[[id_col]])
  if (anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids)) {
    stop("`id_col` must contain unique, non-missing identifiers.", call. = FALSE)
  }
  if (nrow(x) == 0L) {
    stop("`x` must contain at least one feature.", call. = FALSE)
  }
  crs <- sf::st_crs(x)
  if (is.na(crs)) {
    stop("`x` must declare a projected CRS.", call. = FALSE)
  }
  if (isTRUE(sf::st_is_longlat(x))) {
    stop("`x` must use a projected CRS; longitude/latitude is not supported.",
         call. = FALSE)
  }
  collision <- match.arg(collision)
  scale <- child_numeric_scalar(scale, "scale", min = 0)
  attraction <- child_numeric_scalar(attraction, "attraction", min = 0, max = 1)
  max_bearing_drift <- child_numeric_scalar(
    max_bearing_drift, "max_bearing_drift", min = 0, max = pi
  )
  max_iter <- suppressWarnings(as.integer(max_iter))
  if (length(max_iter) != 1L || is.na(max_iter) || max_iter < 1L) {
    stop("`max_iter` must be a positive whole number.", call. = FALSE)
  }
  parent <- if (is.null(parent)) "parent" else as.character(parent)
  if (length(parent) != 1L || is.na(parent) || !nzchar(parent)) {
    stop("`parent` must be NULL or one non-empty identifier.", call. = FALSE)
  }

  layer_bbox <- sf::st_bbox(x)
  diagonal <- sqrt(
    as.numeric(layer_bbox["xmax"] - layer_bbox["xmin"])^2 +
      as.numeric(layer_bbox["ymax"] - layer_bbox["ymin"])^2
  )
  if (!is.finite(diagonal) || diagonal <= 0) diagonal <- 1
  radial_kick <- child_numeric_scalar(radial_kick %||% (diagonal * 0.02),
                                      "radial_kick", min = 0)
  gap <- child_numeric_scalar(gap %||% (diagonal * 0.01), "gap", min = 0)
  bounds <- child_layout_bounds(bounds, crs)

  parent_geom <- child_parent_geometry(parent_geometry, x)
  parent_crs <- sf::st_crs(parent_geom)
  if (!is.na(parent_crs) && parent_crs != crs) {
    stop("`parent_geometry` and `x` must use the same CRS.", call. = FALSE)
  }
  anchor <- suppressWarnings(
    sf::st_coordinates(sf::st_point_on_surface(sf::st_union(parent_geom)))
  )[1L, 1:2]
  source <- suppressWarnings(
    sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(x)))
  )[, 1:2, drop = FALSE]
  vectors <- sweep(source, 2L, anchor, "-")
  radii <- sqrt(rowSums(vectors^2))
  zero <- !is.finite(radii) | radii == 0
  if (any(zero)) {
    angles <- 2 * pi * (match(ids[zero], sort(ids)) - 1L) / max(1L, nrow(x))
    vectors[zero, ] <- cbind(cos(angles), sin(angles))
    radii[zero] <- 1
  }
  unit <- vectors / radii
  targets <- sweep(vectors * scale + unit * radial_kick, 2L, anchor, "+")

  boxes <- t(vapply(seq_len(nrow(x)), function(i) {
    bb <- sf::st_bbox(sf::st_geometry(x)[i])
    c(width = as.numeric(bb["xmax"] - bb["xmin"]),
      height = as.numeric(bb["ymax"] - bb["ymin"]))
  }, numeric(2)))
  boxes[!is.finite(boxes) | boxes <= 0] <- diagonal * 1e-6
  positions <- targets
  refined <- child_refine_positions(
    positions = positions,
    targets = targets,
    source_vectors = vectors,
    anchor = anchor,
    sizes = boxes,
    ids = ids,
    collision = collision,
    gap = gap,
    attraction = attraction,
    max_bearing_drift = max_bearing_drift,
    bounds = bounds,
    max_iter = max_iter
  )
  positions <- refined$positions
  final_collisions <- child_collision_counts(
    positions, boxes, collision = collision, gap = gap
  )
  base <- positions - source
  source_bearing <- atan2(vectors[, 2], vectors[, 1])
  final_vectors <- sweep(positions, 2L, anchor, "-")
  final_bearing <- atan2(final_vectors[, 2], final_vectors[, 1])
  drift <- abs(child_angle_difference(final_bearing, source_bearing))
  offsets <- data.frame(
    feature_id = ids,
    parent_id = rep(parent, length(ids)),
    source_x = source[, 1],
    source_y = source[, 2],
    target_x = positions[, 1],
    target_y = positions[, 2],
    base_dx_m = base[, 1],
    base_dy_m = base[, 2],
    distance_m = sqrt(rowSums(base^2)),
    bearing_original = source_bearing,
    bearing_final = final_bearing,
    bearing_drift = drift,
    collision_count = final_collisions,
    stringsAsFactors = FALSE
  )

  geometry <- x
  shifted <- lapply(seq_len(nrow(x)), function(i) {
    sf::st_geometry(x)[[i]] + c(base[i, 1], base[i, 2])
  })
  sf::st_geometry(geometry) <- sf::st_sfc(shifted, crs = crs)
  structure(
    list(
      offsets = offsets,
      geometry = sf::st_as_sf(geometry),
      source = x,
      parent_geometry = parent_geom,
      diagnostics = list(
        iterations = refined$iterations,
        residual_collisions = sum(final_collisions) / 2,
        maximum_bearing_drift = max(drift, na.rm = TRUE)
      ),
      params = list(
        id_col = id_col,
        scale = scale,
        radial_kick = radial_kick,
        gap = gap,
        collision = collision,
        attraction = attraction,
        max_bearing_drift = max_bearing_drift,
        bounds = bounds,
        max_iter = max_iter
      )
    ),
    class = c("explodemap_child_layout", "list")
  )
}

#' Access a child layout
#'
#' @param layout An `explodemap_child_layout` from [layout_children()].
#' @return `child_layout_offsets()` returns the renderer-neutral offset table;
#'   `child_layout_geometry()` returns the composed projected `sf` geometry.
#' @export
child_layout_offsets <- function(layout) {
  validate_child_layout(layout)
  layout$offsets
}

#' @rdname child_layout_offsets
#' @export
child_layout_geometry <- function(layout) {
  validate_child_layout(layout)
  layout$geometry
}

#' @export
print.explodemap_child_layout <- function(x, ...) {
  cat("explodemap child layout\n")
  cat("  features: ", nrow(x$offsets), "\n", sep = "")
  cat("  iterations: ", x$diagnostics$iterations, "\n", sep = "")
  cat("  residual collisions: ", x$diagnostics$residual_collisions, "\n", sep = "")
  invisible(x)
}

validate_child_layout <- function(layout) {
  if (!inherits(layout, "explodemap_child_layout") ||
      !is.data.frame(layout$offsets) || !inherits(layout$geometry, "sf")) {
    stop("`layout` must be created by layout_children().", call. = FALSE)
  }
  invisible(layout)
}

child_numeric_scalar <- function(x, arg, min = -Inf, max = Inf) {
  x <- suppressWarnings(as.numeric(x))
  if (length(x) != 1L || !is.finite(x) || x < min || x > max) {
    stop("`", arg, "` must be one finite number between ", min, " and ", max,
         ".", call. = FALSE)
  }
  x
}

child_parent_geometry <- function(parent_geometry, x) {
  if (is.null(parent_geometry)) {
    return(sf::st_union(sf::st_geometry(x)))
  }
  if (inherits(parent_geometry, "sf")) return(sf::st_geometry(parent_geometry))
  if (inherits(parent_geometry, "sfc")) return(parent_geometry)
  if (inherits(parent_geometry, "sfg")) {
    return(sf::st_sfc(parent_geometry, crs = sf::st_crs(x)))
  }
  stop("`parent_geometry` must be NULL, sf, sfc, or sfg geometry.", call. = FALSE)
}

child_layout_bounds <- function(bounds, crs) {
  if (is.null(bounds)) return(NULL)
  if (inherits(bounds, "sf") || inherits(bounds, "sfc") || inherits(bounds, "sfg")) {
    bounds <- sf::st_bbox(bounds)
  }
  if (inherits(bounds, "bbox")) {
    bounds <- as.numeric(bounds[c("xmin", "ymin", "xmax", "ymax")])
  }
  bounds <- suppressWarnings(as.numeric(bounds))
  if (length(bounds) != 4L || any(!is.finite(bounds)) ||
      bounds[1] >= bounds[3] || bounds[2] >= bounds[4]) {
    stop("`bounds` must define finite xmin, ymin, xmax, and ymax values.",
         call. = FALSE)
  }
  stats::setNames(bounds, c("xmin", "ymin", "xmax", "ymax"))
}

child_refine_positions <- function(positions, targets, source_vectors, anchor,
                                   sizes, ids, collision, gap, attraction,
                                   max_bearing_drift, bounds, max_iter) {
  iterations <- 0L
  for (iter in seq_len(max_iter)) {
    iterations <- iter
    correction <- matrix(0, nrow(positions), 2L)
    collisions <- 0L
    for (i in seq_len(nrow(positions) - 1L)) {
      for (j in (i + 1L):nrow(positions)) {
        push <- child_collision_push(
          positions[i, ], positions[j, ], sizes[i, ], sizes[j, ],
          collision = collision, gap = gap, ids = ids[c(i, j)]
        )
        if (is.null(push)) next
        correction[i, ] <- correction[i, ] - push / 2
        correction[j, ] <- correction[j, ] + push / 2
        collisions <- collisions + 1L
      }
    }
    if (collisions == 0L) break
    positions <- positions + correction
    positions <- positions + attraction * (targets - positions)
    positions <- child_limit_bearing(
      positions, source_vectors, anchor, max_bearing_drift
    )
    positions <- child_confine_positions(positions, sizes, bounds)
  }
  # Finish with separation-only passes. Attraction is intentionally omitted so
  # the final geographic pull cannot reintroduce a collision.
  for (iter in seq_len(max(5L, ceiling(max_iter / 4)))) {
    correction <- matrix(0, nrow(positions), 2L)
    collisions <- 0L
    for (i in seq_len(nrow(positions) - 1L)) {
      for (j in (i + 1L):nrow(positions)) {
        push <- child_collision_push(
          positions[i, ], positions[j, ], sizes[i, ], sizes[j, ],
          collision = collision, gap = gap, ids = ids[c(i, j)]
        )
        if (is.null(push)) next
        correction[i, ] <- correction[i, ] - push / 2
        correction[j, ] <- correction[j, ] + push / 2
        collisions <- collisions + 1L
      }
    }
    if (collisions == 0L) break
    positions <- child_confine_positions(positions + correction, sizes, bounds)
  }
  list(positions = positions, iterations = iterations)
}

child_collision_push <- function(a, b, size_a, size_b, collision, gap, ids) {
  delta <- b - a
  if (identical(collision, "circle")) {
    ra <- sqrt(sum(size_a^2)) / 2
    rb <- sqrt(sum(size_b^2)) / 2
    distance <- sqrt(sum(delta^2))
    overlap <- ra + rb + gap - distance
    if (!is.finite(overlap) || overlap <= 0) return(NULL)
    direction <- if (distance > 0) delta / distance else {
      angle <- if (ids[1] < ids[2]) 0 else pi
      c(cos(angle), sin(angle))
    }
    return(direction * overlap)
  }
  overlap_x <- (size_a[1] + size_b[1]) / 2 + gap - abs(delta[1])
  overlap_y <- (size_a[2] + size_b[2]) / 2 + gap - abs(delta[2])
  if (!is.finite(overlap_x) || !is.finite(overlap_y) ||
      overlap_x <= 0 || overlap_y <= 0) return(NULL)
  if (overlap_x <= overlap_y) {
    sign_x <- if (delta[1] == 0) if (ids[1] < ids[2]) 1 else -1 else sign(delta[1])
    c(sign_x * overlap_x, 0)
  } else {
    sign_y <- if (delta[2] == 0) if (ids[1] < ids[2]) 1 else -1 else sign(delta[2])
    c(0, sign_y * overlap_y)
  }
}

child_limit_bearing <- function(positions, source_vectors, anchor, max_drift) {
  if (max_drift >= pi) return(positions)
  vectors <- sweep(positions, 2L, anchor, "-")
  radius <- sqrt(rowSums(vectors^2))
  source_angle <- atan2(source_vectors[, 2], source_vectors[, 1])
  angle <- atan2(vectors[, 2], vectors[, 1])
  difference <- child_angle_difference(angle, source_angle)
  angle <- source_angle + pmax(-max_drift, pmin(max_drift, difference))
  sweep(cbind(radius * cos(angle), radius * sin(angle)), 2L, anchor, "+")
}

child_angle_difference <- function(a, b) {
  atan2(sin(a - b), cos(a - b))
}

child_confine_positions <- function(positions, sizes, bounds) {
  if (is.null(bounds)) return(positions)
  positions[, 1] <- pmax(bounds["xmin"] + sizes[, 1] / 2,
                          pmin(bounds["xmax"] - sizes[, 1] / 2, positions[, 1]))
  positions[, 2] <- pmax(bounds["ymin"] + sizes[, 2] / 2,
                          pmin(bounds["ymax"] - sizes[, 2] / 2, positions[, 2]))
  positions
}

child_collision_counts <- function(positions, sizes, collision, gap) {
  counts <- integer(nrow(positions))
  if (nrow(positions) < 2L) return(counts)
  for (i in seq_len(nrow(positions) - 1L)) {
    for (j in (i + 1L):nrow(positions)) {
      hit <- !is.null(child_collision_push(
        positions[i, ], positions[j, ], sizes[i, ], sizes[j, ],
        collision = collision, gap = gap, ids = c(as.character(i), as.character(j))
      ))
      if (hit) counts[c(i, j)] <- counts[c(i, j)] + 1L
    }
  }
  counts
}
