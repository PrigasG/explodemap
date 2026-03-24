# =============================================================================
# R/api.R — Public API (three entry points) and S3 class
# =============================================================================

#' Explode a US state from TIGER/Line data
#'
#' Downloads municipal boundaries automatically, groups by county-to-region
#' mapping, derives parameters via Analytical Results 1-2, and returns an
#' `exploded_map` S3 object.
#'
#' @param state_fips 2-digit FIPS code (e.g. "34" for NJ)
#' @param crs Projected CRS EPSG code (metric units)
#' @param region_map Named list: region_name -> character vector of county names
#' @param gamma_r Regional clearance coefficient (default 3.0)
#' @param gamma_l Local clearance coefficient (default 1.136)
#' @param p Distance scaling exponent (default 1.25)
#' @param alpha_r Manual override for regional separation (metres); skips derivation
#' @param alpha_l Manual override for local expansion (metres); skips derivation
#' @param allow_other If TRUE, permits units mapped to "Other"
#' @param fix_invalid If TRUE, auto-repairs invalid geometries
#' @param centroid_fun "centroid" (default) or "point_on_surface"
#' @param plot Print plots on return (default TRUE)
#' @param export NULL (no export), TRUE (auto-named GeoJSON), or a file path
#' @param label Title for plots and print output
#' @return An `exploded_map` S3 object
#' @export
explode_state <- function(state_fips,
                          crs,
                          region_map,
                          gamma_r      = 3.0,
                          gamma_l      = 1.136,
                          p            = 1.25,
                          alpha_r      = NULL,
                          alpha_l      = NULL,
                          allow_other  = FALSE,
                          fix_invalid  = TRUE,
                          centroid_fun = c("centroid", "point_on_surface"),
                          plot         = TRUE,
                          export       = NULL,
                          label        = paste0("FIPS ", state_fips)) {

  message("Downloading TIGER/Line data (FIPS ", state_fips, ")...")
  sf_raw <- .download_cousub(state_fips, crs)

  message("Assigning regions...")
  sf_reg <- .attach_regions_tiger(sf_raw, state_fips, region_map)

  n_other   <- sum(sf_reg$region == "Other", na.rm = TRUE)
  n_regions <- dplyr::n_distinct(sf_reg$region[sf_reg$region != "Other"])

  if (n_regions < 2)
    stop("Fewer than 2 regions matched. Check county names in region_map.",
         call. = FALSE)
  if (n_other > 0 && !allow_other)
    stop(n_other, " units mapped to 'Other'. Fix region_map or pass allow_other = TRUE.",
         call. = FALSE)

  sf_reg <- validate_input(sf_reg, "region", allow_other, fix_invalid)

  sf_for_stats <- if (allow_other && n_other > 0)
    sf_reg[sf_reg$region != "Other", ] else sf_reg

  .run_explode(sf_reg, sf_for_stats,
               gamma_r, gamma_l, p, alpha_r, alpha_l,
               plot, export, label, "region", match.arg(centroid_fun))
}


#' Explode any sf object with an existing grouping column
#'
#' @param sf_obj Projected sf object (metric CRS)
#' @param region_col Name of the column defining groups
#' @param gamma_r Regional clearance coefficient (default 3.0)
#' @param gamma_l Local clearance coefficient (default 1.136)
#' @param p Distance scaling exponent (default 1.25)
#' @param alpha_r Manual override (metres); skips derivation
#' @param alpha_l Manual override (metres); skips derivation
#' @param allow_other If TRUE, permits "Other" units
#' @param fix_invalid If TRUE, auto-repairs invalid geometries
#' @param centroid_fun "centroid" (default) or "point_on_surface"
#' @param plot Print plots on return
#' @param export NULL, TRUE, or file path
#' @param label Title for plots
#' @return An `exploded_map` S3 object
#' @export
explode_sf <- function(sf_obj,
                       region_col   = "region",
                       gamma_r      = 3.0,
                       gamma_l      = 1.136,
                       p            = 1.25,
                       alpha_r      = NULL,
                       alpha_l      = NULL,
                       allow_other  = FALSE,
                       fix_invalid  = TRUE,
                       centroid_fun = c("centroid", "point_on_surface"),
                       plot         = TRUE,
                       export       = NULL,
                       label        = "Custom Dataset") {

  sf_obj <- validate_input(sf_obj, region_col, allow_other, fix_invalid)

  sf_for_stats <- if (allow_other && any(sf_obj[[region_col]] == "Other"))
    sf_obj[sf_obj[[region_col]] != "Other", ] else sf_obj

  .run_explode(sf_obj, sf_for_stats,
               gamma_r, gamma_l, p, alpha_r, alpha_l,
               plot, export, label, region_col, match.arg(centroid_fun))
}


#' Explode any sf object using an external lookup table
#'
#' Joins the lookup to `sf_obj` before exploding. Unmatched units are
#' labelled "Other".
#'
#' @param sf_obj Projected sf object
#' @param join_col Column in sf_obj to join on
#' @param lookup data.frame with join key and region column
#' @param lookup_key Column name in lookup matching join_col
#' @param region_col Column name in lookup containing region labels
#' @param ... Passed to [explode_sf()]
#' @return An `exploded_map` S3 object
#' @export
explode_sf_with_lookup <- function(sf_obj,
                                   join_col,
                                   lookup,
                                   lookup_key = join_col,
                                   region_col = "region",
                                   ...) {
  if (!join_col %in% names(sf_obj))
    stop("join_col '", join_col, "' not found in sf_obj.", call. = FALSE)
  if (!lookup_key %in% names(lookup))
    stop("lookup_key '", lookup_key, "' not found in lookup.", call. = FALSE)
  if (!region_col %in% names(lookup))
    stop("region_col '", region_col, "' not found in lookup.", call. = FALSE)

  sf_joined <- sf_obj |>
    dplyr::left_join(
      lookup |> dplyr::select(dplyr::all_of(c(lookup_key, region_col))),
      by = stats::setNames(lookup_key, join_col)
    )

  n_matched <- sum(!is.na(sf_joined[[region_col]]))
  message("Lookup join: ", n_matched, " / ", nrow(sf_joined), " units matched.")
  sf_joined[[region_col]][is.na(sf_joined[[region_col]])] <- "Other"

  explode_sf(sf_joined, region_col = region_col, ...)
}


# =============================================================================
# INTERNAL RUNNER (shared by all three entry points)
# =============================================================================

.run_explode <- function(sf_obj, sf_for_stats,
                         gamma_r, gamma_l, p,
                         alpha_r_override, alpha_l_override,
                         plot, export, label,
                         region_col, centroid_fun = "centroid") {

  stats <- compute_stats(sf_for_stats, region_col)

  # Parameter source: manual override takes priority
  if (!is.null(alpha_r_override) && !is.null(alpha_l_override)) {
    params <- list(alpha_r = alpha_r_override, alpha_l = alpha_l_override,
                   p = p, gamma_r = NA_real_, gamma_l = NA_real_)
    message("Using manual alpha_r = ", alpha_r_override,
            " m, alpha_l = ", alpha_l_override, " m")
  } else {
    params <- derive_params(stats, gamma_r, gamma_l, p)
  }

  sf_exp     <- explode_sf_core(sf_obj, region_col,
                                params$alpha_r, params$alpha_l, params$p,
                                centroid_fun)
  sf_exp_wgs <- sf::st_transform(sf_exp, 4326)

  plots <- .make_plots(sf_obj, sf_exp, region_col, label, params)
  if (plot) {
    print(plots$orig)
    print(plots$exp)
  }

  # Handle export: NULL = none, TRUE = auto-name, character = explicit path
  .handle_export(export, sf_exp_wgs, label)

  # Implied gamma values (for calibration)
  gamma_r_implied <- params$alpha_r /
    (stats$w_bar / (2 * sin(pi / stats$n_regions)))
  gamma_l_implied <- params$alpha_l /
    (2 * stats$R_local / sqrt(stats$n_bar))

  result <- list(
    sf_orig         = sf_obj,
    sf_exp          = sf_exp,
    sf_exp_wgs      = sf_exp_wgs,
    stats           = stats,
    params          = params,
    gamma_r_implied = gamma_r_implied,
    gamma_l_implied = gamma_l_implied,
    plots           = plots,
    diagnostics     = list(
      label        = label,
      region_col   = region_col,
      centroid_fun = centroid_fun
    )
  )
  structure(result, class = c("exploded_map", "list"))
}


#' Handle export logic
#' @keywords internal
.handle_export <- function(export, sf_exp_wgs, label) {
  if (is.null(export)) return(invisible(NULL))
  if (isTRUE(export)) {
    fname <- paste0("exploded_",
                    gsub("[^a-zA-Z0-9]", "_", tolower(label)), ".geojson")
  } else if (is.character(export)) {
    fname <- export
  } else {
    return(invisible(NULL))
  }
  sf::st_write(sf_exp_wgs, fname, driver = "GeoJSON",
               delete_dsn = TRUE, quiet = TRUE)
  message("Exported: ", fname)
}
