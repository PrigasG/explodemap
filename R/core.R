# =============================================================================
# R/core.R — Core algorithm for exploded-view cartography
# =============================================================================
# Single source of truth for:
#   - Shared centroid helper (warning-free)
#   - Input validation
#   - Geometry statistics (compute_stats)
#   - Parameter derivation (Analytical Results 1 & 2)
#   - Displacement engine (explode_sf_core)
#   - Print formatting helper
# =============================================================================


# ─────────────────────────────────────────────────────────────────────────────
# SHARED CENTROID HELPER — use everywhere instead of raw st_centroid()
# ─────────────────────────────────────────────────────────────────────────────

#' Compute centroids without attribute warnings
#'
#' Wraps sf::st_centroid / sf::st_point_on_surface, operating on
#' st_geometry() rather than the full sf object. Returns an sfc column.
#'
#' @param x An sf or sfc object
#' @param centroid_fun "centroid" (default) or "point_on_surface"
#' @return sfc geometry column of point centroids
#' @keywords internal
centroid_geoms <- function(x, centroid_fun = c("centroid", "point_on_surface")) {
  centroid_fun <- match.arg(centroid_fun)
  geom <- sf::st_geometry(x)
  switch(
    centroid_fun,
    centroid         = sf::st_centroid(geom),
    point_on_surface = sf::st_point_on_surface(geom)
  )
}


# ─────────────────────────────────────────────────────────────────────────────
# INPUT VALIDATION
# ─────────────────────────────────────────────────────────────────────────────

#' Validate inputs before explosion
#'
#' Checks CRS, empty geometries, invalid geometries, region count, and
#' unmatched "Other" units. Optionally repairs invalid geometries.
#'
#' @param sf_obj sf object to validate
#' @param region_col Name of the grouping column
#' @param allow_other If TRUE, permits units labelled "Other"
#' @param fix_invalid If TRUE, attempts st_make_valid() on invalid geometries
#' @return The (possibly repaired) sf object, invisibly
#' @keywords internal
validate_input <- function(sf_obj, region_col,
                           allow_other = FALSE,
                           fix_invalid = TRUE) {
  if (!inherits(sf_obj, "sf"))
    stop("`sf_obj` must be an sf object.", call. = FALSE)
  if (!(region_col %in% names(sf_obj)))
    stop("Column '", region_col, "' not found. Available: ",
         paste(names(sf_obj), collapse = ", "), call. = FALSE)
  if (is.na(sf::st_crs(sf_obj)))
    stop("`sf_obj` has no CRS. Set one with st_set_crs() or st_transform().",
         call. = FALSE)
  if (sf::st_is_longlat(sf_obj))
    stop("`sf_obj` is in geographic (lon/lat) coordinates. ",
         "Project first with st_transform().", call. = FALSE)
  if (any(sf::st_is_empty(sf_obj)))
    stop(sum(sf::st_is_empty(sf_obj)), " empty geometries found. ",
         "Remove with sf_obj[!st_is_empty(sf_obj), ]", call. = FALSE)

  # Fix invalid geometries
  invalid <- !sf::st_is_valid(sf_obj)
  if (any(invalid, na.rm = TRUE)) {
    n_bad <- sum(invalid, na.rm = TRUE)
    if (fix_invalid) {
      message("Repairing ", n_bad, " invalid geometries with st_make_valid().")
      sf_obj <- sf::st_make_valid(sf_obj)
    } else {
      stop(n_bad, " invalid geometries found. ",
           "Pass fix_invalid = TRUE to auto-repair, or fix manually.",
           call. = FALSE)
    }
  }

  n_regions <- dplyr::n_distinct(sf_obj[[region_col]])
  if (n_regions < 2)
    stop("Only ", n_regions, " region found. Need at least 2.", call. = FALSE)

  n_other <- sum(sf_obj[[region_col]] == "Other", na.rm = TRUE)
  if (n_other > 0 && !allow_other)
    stop(n_other, " units mapped to 'Other' (unmatched). ",
         "Fix your grouping or pass allow_other = TRUE.", call. = FALSE)

  sf_obj
}


# ─────────────────────────────────────────────────────────────────────────────
# GEOMETRY STATISTICS
# ─────────────────────────────────────────────────────────────────────────────

#' Compute geometry statistics for parameter derivation
#'
#' Extracts w_bar, R_local, n_bar, n_regions, and the tightness ratio
#' from a projected sf object with a grouping column.
#'
#' @param sf_obj Projected sf object
#' @param region_col Name of the grouping column
#' @param centroid_fun "centroid" (default) or "point_on_surface"
#' @return A named list of geometry statistics
#' @export
compute_stats <- function(sf_obj, region_col,
                          centroid_fun = c("centroid", "point_on_surface")) {
  centroid_fun <- match.arg(centroid_fun)

  areas <- as.numeric(sf::st_area(sf_obj))
  w_bar <- stats::median(sqrt(4 * areas / pi), na.rm = TRUE)

  # Region centroids (warning-free)
  reg_sf <- sf_obj |>
    dplyr::group_by(dplyr::across(dplyr::all_of(region_col))) |>
    dplyr::summarise(geometry = sf::st_union(.data$geometry), .groups = "drop")
  rc <- sf::st_coordinates(centroid_geoms(reg_sf, centroid_fun))
  D_region <- if (nrow(rc) > 1) stats::median(as.numeric(stats::dist(rc))) else NA_real_

  # Unit centroids (warning-free)
  muni_c <- sf::st_coordinates(centroid_geoms(sf_obj, centroid_fun))

  # Build region centroid lookup — preserve original column name
  reg_df <- reg_sf |>
    sf::st_drop_geometry() |>
    dplyr::transmute(
      !!region_col := .data[[region_col]],
      rx = rc[, 1],
      ry = rc[, 2]
    )

  # Compute per-unit distance to region centroid
  tmp <- sf_obj |>
    sf::st_drop_geometry() |>
    dplyr::mutate(cx = muni_c[, 1], cy = muni_c[, 2]) |>
    dplyr::left_join(reg_df, by = region_col) |>
    dplyr::mutate(d = sqrt((.data$cx - .data$rx)^2 + (.data$cy - .data$ry)^2))

  d_max_tbl <- tmp |>
    dplyr::group_by(dplyr::across(dplyr::all_of(region_col))) |>
    dplyr::summarise(d_max = max(.data$d, na.rm = TRUE), .groups = "drop")
  R_local <- stats::median(d_max_tbl$d_max)

  n_regions <- dplyr::n_distinct(sf_obj[[region_col]])
  n_bar     <- stats::median(as.numeric(table(sf_obj[[region_col]])))

  # Per-region unit counts — preserve original column name
  region_summary <- sf_obj |>
    sf::st_drop_geometry() |>
    dplyr::count(.data[[region_col]], name = "n_units")

  list(
    n_units        = nrow(sf_obj),
    w_bar          = w_bar,
    R_local        = R_local,
    D_region       = D_region,
    n_regions      = n_regions,
    n_bar          = n_bar,
    ratio          = R_local / w_bar,
    per_region     = d_max_tbl,
    region_summary = region_summary
  )
}


# ─────────────────────────────────────────────────────────────────────────────
# PARAMETER DERIVATION
# ─────────────────────────────────────────────────────────────────────────────

#' Derive displacement parameters from geometry statistics
#'
#' Implements Analytical Results 1 and 2 from the paper:
#'   alpha_r = gamma_r * w_bar / (2 * sin(pi / n_regions))
#'   alpha_l = gamma_l * 2 * R_local / sqrt(n_bar)
#'
#' @param stats Output of [compute_stats()]
#' @param gamma_r Regional clearance coefficient (default 3.0)
#' @param gamma_l Local clearance coefficient (default 1.136)
#' @param p Distance scaling exponent (default 1.25)
#' @return Named list with alpha_r, alpha_l, p, gamma_r, gamma_l
#' @export
derive_params <- function(stats, gamma_r = 3.0, gamma_l = 1.136, p = 1.25) {
  if (stats$n_regions < 2)
    stop("Need at least 2 regions.", call. = FALSE)
  list(
    alpha_r = gamma_r * stats$w_bar / (2 * sin(pi / stats$n_regions)),
    alpha_l = gamma_l * 2 * stats$R_local / sqrt(stats$n_bar),
    p       = p,
    gamma_r = gamma_r,
    gamma_l = gamma_l
  )
}


# ─────────────────────────────────────────────────────────────────────────────
# DISPLACEMENT ENGINE
# ─────────────────────────────────────────────────────────────────────────────

#' Core displacement algorithm (Algorithm 1 from the paper)
#'
#' Applies the hierarchical centroid-driven displacement field to every polygon.
#' Each unit receives rigid-body translation t_i = alpha_r * dhat_state + alpha_l * s_i * dhat_local.
#'
#' Propositions 1-3 guarantee: exact geometry preservation, radial ordering, and
#' bounded displacement (||t_i|| <= alpha_r + alpha_l).
#'
#' @param sf_obj Projected sf object with region column
#' @param region_col Grouping column name
#' @param alpha_r Regional separation magnitude (metres)
#' @param alpha_l Local expansion magnitude (metres)
#' @param p Distance scaling exponent (default 1.25)
#' @param centroid_fun "centroid" (default) or "point_on_surface"
#' @return Exploded sf object (same CRS as input)
#' @keywords internal
explode_sf_core <- function(sf_obj, region_col,
                            alpha_r, alpha_l, p = 1.25,
                            centroid_fun = c("centroid", "point_on_surface")) {
  centroid_fun <- match.arg(centroid_fun)
  orig_crs <- sf::st_crs(sf_obj)

  # State centroid (global frame) — warning-free
  Cs <- sf::st_coordinates(
    centroid_geoms(sf::st_union(sf_obj), centroid_fun)
  )[1, ]

  # Region centroids — warning-free
  reg_sf <- sf_obj |>
    dplyr::group_by(dplyr::across(dplyr::all_of(region_col))) |>
    dplyr::summarise(geometry = sf::st_union(.data$geometry), .groups = "drop")
  rc <- sf::st_coordinates(centroid_geoms(reg_sf, centroid_fun))

  reg_df <- reg_sf |>
    sf::st_drop_geometry() |>
    dplyr::transmute(
      !!region_col := .data[[region_col]],
      rx = rc[, 1],
      ry = rc[, 2]
    )

  # Unit centroids — warning-free
  muni_c <- sf::st_coordinates(centroid_geoms(sf_obj, centroid_fun))

  # Build displacement dataframe
  df <- sf_obj |>
    sf::st_drop_geometry() |>
    dplyr::mutate(cx = muni_c[, 1], cy = muni_c[, 2]) |>
    dplyr::left_join(reg_df, by = region_col) |>
    dplyr::mutate(
      # Regional direction: Cs -> Cr (vector from state centroid to region centroid)
      dr_x = .data$rx - Cs[1], dr_y = .data$ry - Cs[2],
      dr_len   = sqrt(.data$dr_x^2 + .data$dr_y^2),
      dhat_r_x = .data$dr_x / pmax(.data$dr_len, 1),
      dhat_r_y = .data$dr_y / pmax(.data$dr_len, 1),
      # Local direction: Cr -> Ci (vector from region centroid to unit centroid)
      dl_x = .data$cx - .data$rx, dl_y = .data$cy - .data$ry,
      dl_len   = sqrt(.data$dl_x^2 + .data$dl_y^2),
      dhat_l_x = .data$dl_x / pmax(.data$dl_len, 1),
      dhat_l_y = .data$dl_y / pmax(.data$dl_len, 1)
    )

  # d_max per region (for s_i normalization)
  d_max_tbl <- df |>
    dplyr::group_by(dplyr::across(dplyr::all_of(region_col))) |>
    dplyr::summarise(d_max = max(.data$dl_len, na.rm = TRUE), .groups = "drop")

  # Compute s_i and displacement offsets
  df <- df |>
    dplyr::left_join(d_max_tbl, by = region_col) |>
    dplyr::mutate(
      s_i   = (.data$dl_len / pmax(.data$d_max, 1))^p,
      x_off = alpha_r * .data$dhat_r_x + alpha_l * .data$s_i * .data$dhat_l_x,
      y_off = alpha_r * .data$dhat_r_y + alpha_l * .data$s_i * .data$dhat_l_y
    )

  # Apply rigid-body translation (Proposition 1)
  sf_exp <- sf_obj
  sf_exp$geometry <- sf::st_sfc(
    purrr::pmap(list(sf_obj$geometry, df$x_off, df$y_off),
                function(g, dx, dy) g + c(dx, dy)),
    crs = orig_crs
  )
  sf::st_as_sf(sf_exp)
}


# ─────────────────────────────────────────────────────────────────────────────
# PRINT FORMATTING HELPER
# ─────────────────────────────────────────────────────────────────────────────

#' Format a distance in metres as a human-readable km string
#'
#' Adapts precision to magnitude: "23.6 km" for large values,
#' "0.067 km" for small ones, so tiny test geometries don't show "0 km".
#'
#' @param x_m Distance in metres
#' @return Character string
#' @keywords internal
fmt_dist <- function(x_m) {
  if (is.na(x_m)) return("NA")
  x_km <- x_m / 1000
  if (x_km >= 10)    return(sprintf("%.0f km", x_km))
  if (x_km >= 1)     return(sprintf("%.1f km", x_km))
  if (x_km >= 0.01)  return(sprintf("%.3f km", x_km))
  return(sprintf("%.1f m", x_m))
}
