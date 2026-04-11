# =============================================================================
# R/grouped.R — Three-Level Grouped Layout Engine (Section 12)
# =============================================================================
#
# Extends the core two-level displacement (Algorithm 1) with a third level
# for national or multi-region grouped layouts. Implements Algorithm 2 from:
#
#   "A Hierarchical Vector-Based Framework for Multi-Scale Exploded-View
#    Cartography" — George Arthur, Section 12
#
# THREE-LEVEL HIERARCHY
# ─────────────────────
# Level 1: Deterministic local explosion (Algorithm 1, unchanged)
#          Units within each parent region are displaced using the
#          centroid-driven field. Geometry guarantees (Props 1-3) apply.
#
# Level 2: Automatic anchor placement
#          Parent region centroids are displaced radially outward from
#          the national centroid to generate initial anchor positions.
#
# Level 3: Collision-aware anchor refinement
#          Overlapping anchors are iteratively repelled while a spring
#          term maintains proximity to original radial targets.
#
# ANCHOR MODES
# ─────────────
# "auto"            — Level 2 only (radial placement, no collision resolution)
# "auto_collision"  — Level 2 + Level 3 (radial + spring-repulsion solver)
# "manual"          — User-supplied anchor positions
#
# =============================================================================


# ─────────────────────────────────────────────────────────────────────────────
# BLOCK RADIUS ESTIMATION
# ─────────────────────────────────────────────────────────────────────────────

#' Estimate block radius for each region
#'
#' Computes the 85th percentile of distances from child-unit centroids to
#' their region centroid. The 85th percentile is preferred over the maximum
#' because the maximum is sensitive to outlier units and produces
#' over-conservative block radii.
#'
#' @param sf_obj Projected sf object with region column
#' @param region_col Grouping column name
#' @param quantile_p Quantile for radius estimation (default 0.85)
#' @param centroid_fun "centroid" or "point_on_surface"
#' @return data.frame with columns: region, block_radius, cx, cy, n_units
#' @export
estimate_block_radii <- function(sf_obj, region_col,
                                 quantile_p = 0.85,
                                 centroid_fun = c("centroid", "point_on_surface")) {
  centroid_fun <- match.arg(centroid_fun)

  reg_sf <- sf_obj |>
    dplyr::group_by(dplyr::across(dplyr::all_of(region_col))) |>
    dplyr::summarise(geometry = sf::st_union(.data$geometry), .groups = "drop")

  rc <- sf::st_coordinates(centroid_geoms(reg_sf, centroid_fun))

  reg_df <- data.frame(
    region = reg_sf[[region_col]],
    rx = rc[, 1],
    ry = rc[, 2],
    stringsAsFactors = FALSE
  )
  names(reg_df)[1] <- region_col

  unit_xy <- sf::st_coordinates(centroid_geoms(sf_obj, centroid_fun))

  tmp <- sf_obj |>
    sf::st_drop_geometry() |>
    dplyr::mutate(
      .cx = unit_xy[, 1],
      .cy = unit_xy[, 2]
    ) |>
    dplyr::left_join(reg_df, by = region_col) |>
    dplyr::mutate(
      .dist = sqrt((.data$.cx - .data$rx)^2 + (.data$.cy - .data$ry)^2)
    )

  out <- tmp |>
    dplyr::group_by(dplyr::across(dplyr::all_of(region_col))) |>
    dplyr::summarise(
      block_radius = as.numeric(stats::quantile(.data$.dist, probs = quantile_p, na.rm = TRUE)),
      n_units = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::left_join(reg_df, by = region_col)

  names(out)[names(out) == "rx"] <- "cx"
  names(out)[names(out) == "ry"] <- "cy"

  out
}


# ─────────────────────────────────────────────────────────────────────────────
# ANCHOR GENERATION
# ─────────────────────────────────────────────────────────────────────────────

#' Generate initial radial anchors from the national centroid
#' @keywords internal
.generate_anchors <- function(block_df, nat_centroid,
                              kappa = 1.8,
                              padding = 50000,
                              delta = 15000) {
  stopifnot(all(c("cx", "cy", "block_radius", "n_units") %in% names(block_df)))

  dx <- block_df$cx - nat_centroid[1]
  dy <- block_df$cy - nat_centroid[2]
  r0 <- sqrt(dx^2 + dy^2)

  # Handle regions whose centroid is exactly at the national centroid
  zero_idx <- which(r0 == 0 | is.na(r0))
  if (length(zero_idx) > 0) {
    angles0 <- seq(0, 2 * pi, length.out = length(zero_idx) + 1)[seq_along(zero_idx)]
    dx[zero_idx] <- cos(angles0)
    dy[zero_idx] <- sin(angles0)
    r0[zero_idx] <- 1
  }

  ux <- dx / r0
  uy <- dy / r0

  target_r <- kappa * r0 + padding + delta * log1p(block_df$n_units)

  block_df$anchor_x <- nat_centroid[1] + ux * target_r
  block_df$anchor_y <- nat_centroid[2] + uy * target_r
  block_df$target_x <- block_df$anchor_x
  block_df$target_y <- block_df$anchor_y
  block_df
}


# ─────────────────────────────────────────────────────────────────────────────
# COLLISION-AWARE ANCHOR REFINEMENT
# ─────────────────────────────────────────────────────────────────────────────

#' Refine anchors with pairwise repulsion plus spring return
#' @keywords internal
.refine_anchors <- function(block_df,
                            lambda = 0.18,
                            eta = 0.18,
                            padding_sep = 20000,
                            max_iter = 60) {
  stopifnot(all(c("anchor_x", "anchor_y", "block_radius", "target_x", "target_y") %in% names(block_df)))

  n <- nrow(block_df)
  if (n <= 1) {
    block_df$.converged <- TRUE
    block_df$.iterations <- 0L
    return(block_df)
  }

  converged <- FALSE
  iter <- 0L

  for (iter in seq_len(max_iter)) {
    moved <- FALSE

    # spring-to-target term
    block_df$anchor_x <- block_df$anchor_x + lambda * (block_df$target_x - block_df$anchor_x)
    block_df$anchor_y <- block_df$anchor_y + lambda * (block_df$target_y - block_df$anchor_y)

    for (i in seq_len(n - 1)) {
      for (j in seq.int(i + 1, n)) {
        dx <- block_df$anchor_x[j] - block_df$anchor_x[i]
        dy <- block_df$anchor_y[j] - block_df$anchor_y[i]
        d <- sqrt(dx^2 + dy^2)

        min_sep <- block_df$block_radius[i] + block_df$block_radius[j] + padding_sep

        if (is.na(d) || d == 0) {
          theta <- ((i * 73856093 + j * 19349663) %% 360) * pi / 180
          dx <- cos(theta)
          dy <- sin(theta)
          d <- 1
        }

        if (d < min_sep) {
          overlap <- min_sep - d
          ux <- dx / d
          uy <- dy / d
          step <- 0.5 * eta * overlap

          block_df$anchor_x[i] <- block_df$anchor_x[i] - step * ux
          block_df$anchor_y[i] <- block_df$anchor_y[i] - step * uy
          block_df$anchor_x[j] <- block_df$anchor_x[j] + step * ux
          block_df$anchor_y[j] <- block_df$anchor_y[j] + step * uy

          moved <- TRUE
        }
      }
    }

    if (!moved) {
      converged <- TRUE
      break
    }
  }

  block_df$.converged <- converged
  block_df$.iterations <- iter
  block_df
}


# ─────────────────────────────────────────────────────────────────────────────
# ANCHOR LAYOUT ORCHESTRATOR
# ─────────────────────────────────────────────────────────────────────────────

#' Compute region anchor positions for grouped layouts
#'
#' Implements the anchor layout procedure from Section 12.
#' Supports three modes: automatic radial placement, automatic with
#' collision resolution, and manual user-specified anchors.
#'
#' @param sf_obj Projected sf object with region column
#' @param region_col Grouping column name
#' @param mode "auto" (radial only), "auto_collision" (radial + solver), or "manual"
#' @param anchors For mode = "manual": data.frame with columns (region_col, anchor_x, anchor_y)
#' @param kappa Radial expansion factor (default 1.8)
#' @param padding Base padding in map units (default 50000)
#' @param delta Log-density scaling factor (default 15000)
#' @param lambda Spring coefficient for collision solver (default 0.18)
#' @param eta Repulsion step size for collision solver (default 0.18)
#' @param padding_sep Minimum separation between blocks (default 20000)
#' @param max_iter Max iterations for collision solver (default 60)
#' @param quantile_p Quantile for block radius estimation (default 0.85)
#' @param centroid_fun "centroid" or "point_on_surface"
#' @return data.frame with region, anchor_x, anchor_y, block_radius, n_units
#' @export
layout_regions <- function(sf_obj, region_col,
                           mode = c("auto", "auto_collision", "manual"),
                           anchors = NULL,
                           kappa = 1.8,
                           padding = 50000,
                           delta = 15000,
                           lambda = 0.18,
                           eta = 0.18,
                           padding_sep = 20000,
                           max_iter = 60,
                           quantile_p = 0.85,
                           centroid_fun = c("centroid", "point_on_surface")) {
  mode <- match.arg(mode)
  centroid_fun <- match.arg(centroid_fun)

  if (mode == "manual") {
    if (is.null(anchors)) {
      stop("mode = 'manual' requires an `anchors` data.frame.", call. = FALSE)
    }
    if (!all(c(region_col, "anchor_x", "anchor_y") %in% names(anchors))) {
      stop("`anchors` must contain columns: ", region_col, ", anchor_x, anchor_y",
           call. = FALSE)
    }
    if (anyDuplicated(anchors[[region_col]]) > 0) {
      stop("`anchors` must contain at most one row per region.", call. = FALSE)
    }

    block_df <- estimate_block_radii(sf_obj, region_col, quantile_p, centroid_fun)

    result <- block_df |>
      dplyr::left_join(
        anchors |>
          dplyr::select(dplyr::all_of(c(region_col, "anchor_x", "anchor_y"))),
        by = region_col
      )

    missing_anchor <- is.na(result$anchor_x) | is.na(result$anchor_y)
    if (any(missing_anchor)) {
      stop(
        "Missing manual anchors for region(s): ",
        paste(result[[region_col]][missing_anchor], collapse = ", "),
        call. = FALSE
      )
    }

    return(result)
  }

  block_df <- estimate_block_radii(sf_obj, region_col, quantile_p, centroid_fun)

  nat_centroid <- sf::st_coordinates(
    centroid_geoms(sf::st_union(sf::st_geometry(sf_obj)), centroid_fun)
  )[1, ]

  block_df <- .generate_anchors(block_df, nat_centroid, kappa, padding, delta)

  if (mode == "auto_collision") {
    block_df <- .refine_anchors(block_df, lambda, eta, padding_sep, max_iter)

    if (!is.null(block_df$.converged)) {
      if (isTRUE(block_df$.converged[1])) {
        message("Anchor solver converged in ", block_df$.iterations[1], " iterations.")
      } else {
        message(
          "Anchor solver reached max iterations (", max_iter,
          "). Layout may have residual overlaps."
        )
      }
    }
  }

  block_df
}


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API: GROUPED EXPLODED MAP
# ─────────────────────────────────────────────────────────────────────────────

#' Create a three-level grouped exploded map
#'
#' Combines Level 1 (local explosion within regions) with Level 2/3
#' (anchor-based region block placement). This is the full three-level
#' extension from Section 12 of the paper.
#'
#' The guarantees of Propositions 1-3 apply strictly at Level 1.
#' Higher levels preserve structural grouping and directional correspondence
#' rather than topological coverage.
#'
#' @param sf_obj Projected sf object with region column
#' @param region_col Grouping column name
#' @param mode "auto", "auto_collision", or "manual"
#' @param anchors For mode = "manual": data.frame with anchor positions
#' @param alpha_l Local expansion parameter for Level 1 (metres)
#' @param p Distance scaling exponent (default 1.25)
#' @param gamma_l Local clearance coefficient (default 1.136); used if alpha_l is NULL
#' @param kappa Radial expansion factor (default 1.8)
#' @param padding Base padding (default 50000)
#' @param delta Log-density scaling (default 15000)
#' @param lambda Spring coefficient (default 0.18)
#' @param eta Repulsion step (default 0.18)
#' @param padding_sep Minimum block separation (default 20000)
#' @param max_iter Max collision iterations (default 60)
#' @param fix_invalid Auto-repair invalid geometries (default TRUE)
#' @param centroid_fun "centroid" or "point_on_surface"
#' @param plot Print plots (default TRUE)
#' @param export NULL, TRUE, or file path
#' @param label Title for plots
#' @return A `grouped_exploded_map` S3 object (inherits from `exploded_map`)
#' @export
explode_grouped <- function(sf_obj, region_col,
                            mode         = c("auto", "auto_collision", "manual"),
                            anchors      = NULL,
                            alpha_l      = NULL,
                            p            = 1.25,
                            gamma_l      = 1.136,
                            kappa        = 1.8,
                            padding      = 50000,
                            delta        = 15000,
                            lambda       = 0.18,
                            eta          = 0.18,
                            padding_sep  = 20000,
                            max_iter     = 60,
                            fix_invalid  = TRUE,
                            centroid_fun = c("centroid", "point_on_surface"),
                            plot         = TRUE,
                            export       = NULL,
                            label        = "Grouped Layout") {
  mode <- match.arg(mode)
  centroid_fun <- match.arg(centroid_fun)

  sf_obj <- validate_input(
    sf_obj,
    region_col,
    allow_other = TRUE,
    fix_invalid = fix_invalid
  )

  sf_clean <- sf_obj[sf_obj[[region_col]] != "Other", ]
  stats <- compute_stats(sf_clean, region_col, centroid_fun = centroid_fun)

  if (is.null(alpha_l)) {
    alpha_l <- gamma_l * 2 * stats$R_local / sqrt(stats$n_bar)
  }

  message("Level 1: Applying local explosion (alpha_l = ", round(alpha_l), " m)...")
  sf_local <- explode_sf_core(
    sf_obj,
    region_col,
    alpha_r = 0,
    alpha_l = alpha_l,
    p = p,
    centroid_fun = centroid_fun
  )

  message(
    "Level 2", if (mode == "auto_collision") "/3" else "",
    ": Computing anchor positions (mode = ", mode, ")..."
  )

  anchor_df <- layout_regions(
    sf_local,
    region_col,
    mode = mode,
    anchors = anchors,
    kappa = kappa,
    padding = padding,
    delta = delta,
    lambda = lambda,
    eta = eta,
    padding_sep = padding_sep,
    max_iter = max_iter,
    centroid_fun = centroid_fun
  )

  message("Applying anchor displacement...")

  reg_sf <- sf_local |>
    dplyr::group_by(dplyr::across(dplyr::all_of(region_col))) |>
    dplyr::summarise(geometry = sf::st_union(.data$geometry), .groups = "drop")

  rc_now <- sf::st_coordinates(centroid_geoms(reg_sf, centroid_fun))

  current_centroids <- data.frame(
    region = reg_sf[[region_col]],
    cx_now = rc_now[, 1],
    cy_now = rc_now[, 2],
    stringsAsFactors = FALSE
  )
  names(current_centroids)[1] <- region_col

  anchor_offsets <- anchor_df |>
    dplyr::select(dplyr::all_of(c(region_col, "anchor_x", "anchor_y"))) |>
    dplyr::left_join(current_centroids, by = region_col) |>
    dplyr::mutate(
      off_x = .data$anchor_x - .data$cx_now,
      off_y = .data$anchor_y - .data$cy_now
    )

  orig_crs <- sf::st_crs(sf_local)
  unit_regions <- sf_local[[region_col]]

  offset_lookup <- stats::setNames(
    split(anchor_offsets[, c("off_x", "off_y")], anchor_offsets[[region_col]]),
    anchor_offsets[[region_col]]
  )

  new_geoms <- purrr::map2(
    sf::st_geometry(sf_local),
    unit_regions,
    function(geom, reg) {
      offs <- offset_lookup[[reg]]
      if (is.null(offs)) return(geom)
      geom + c(offs$off_x[1], offs$off_y[1])
    }
  )

  sf_grouped <- sf_local
  sf_grouped$geometry <- sf::st_sfc(new_geoms, crs = orig_crs)
  sf_grouped <- sf::st_as_sf(sf_grouped)
  sf_grouped_wgs <- sf::st_transform(sf_grouped, 4326)

  params <- list(
    alpha_l = alpha_l,
    p = p,
    gamma_l = gamma_l,
    mode = mode,
    kappa = kappa,
    padding = padding,
    delta = delta,
    lambda = lambda,
    eta = eta
  )

  plots <- .make_grouped_plots(
    sf_orig = sf_obj,
    sf_local = sf_local,
    sf_grouped = sf_grouped,
    region_col = region_col,
    title = label,
    params = params
  )

  if (plot) {
    print(plots$grouped)
  }

  .handle_export(export, sf_grouped_wgs, label)

  result <- list(
    sf_orig        = sf_obj,
    sf_local       = sf_local,
    sf_grouped     = sf_grouped,
    sf_grouped_wgs = sf_grouped_wgs,
    stats          = stats,
    params         = params,
    anchors        = anchor_df,
    plots          = plots,
    diagnostics    = list(
      label        = label,
      region_col   = region_col,
      centroid_fun = centroid_fun,
      mode         = mode
    )
  )

  structure(result, class = c("grouped_exploded_map", "exploded_map", "list"))
}


# ─────────────────────────────────────────────────────────────────────────────
# PLOTTING FOR GROUPED LAYOUTS
# ─────────────────────────────────────────────────────────────────────────────

#' Build plots for grouped layouts
#' @keywords internal
.make_grouped_plots <- function(sf_orig, sf_local, sf_grouped, region_col, title, params) {
  regions <- sort(unique(sf_orig[[region_col]]))

  pal <- stats::setNames(
    grDevices::colorRampPalette(
      c(
        "#2166ac", "#d73027", "#1a9850", "#984ea3",
        "#ff7f00", "#a65628", "#f781bf", "#999999",
        "#33a02c", "#b2df8a"
      )
    )(length(regions)),
    regions
  )

  subtitle <- paste0(
    "mode=", params$mode,
    "  \u03b1_l=", round(params$alpha_l), "m",
    "  p=", params$p
  )

  p_orig <- ggplot2::ggplot(sf::st_transform(sf_orig, 4326)) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data[[region_col]]),
      color = "white",
      linewidth = 0.2
    ) +
    ggplot2::scale_fill_manual(values = pal, name = region_col) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::labs(title = paste(title, "- Original"))

  p_local <- ggplot2::ggplot(sf::st_transform(sf_local, 4326)) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data[[region_col]]),
      color = "white",
      linewidth = 0.2
    ) +
    ggplot2::scale_fill_manual(values = pal, name = region_col) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::labs(title = paste(title, "- Local"))

  p_grouped <- ggplot2::ggplot(sf::st_transform(sf_grouped, 4326)) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data[[region_col]]),
      color = "white",
      linewidth = 0.2
    ) +
    ggplot2::scale_fill_manual(values = pal, name = region_col) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::labs(title = paste(title, "- Grouped"), subtitle = subtitle)

  list(
    orig = p_orig,
    local = p_local,
    grouped = p_grouped
  )
}
