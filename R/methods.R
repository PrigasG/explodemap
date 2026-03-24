# =============================================================================
# R/methods.R — S3 methods for exploded_map and grouped_exploded_map objects
# =============================================================================

#' Print an exploded_map object
#' @param x An `exploded_map` object
#' @param ... Ignored
#' @export
print.exploded_map <- function(x, ...) {
  stats  <- x$stats
  params <- x$params
  diag   <- x$diagnostics

  cat("\n-- ", diag$label, " ", paste(rep("-", 40), collapse = ""), "\n", sep = "")
  cat("  n units   : ", format(stats$n_units, big.mark = ","), "\n")
  cat("  n regions : ", stats$n_regions, "\n")
  cat("  w_bar     : ", fmt_dist(stats$w_bar), "\n")
  cat("  R_local   : ", fmt_dist(stats$R_local), "\n")
  cat("  n_bar     : ", round(stats$n_bar), "\n")
  cat("  R_local/w : ", round(stats$ratio, 2), "\n")
  cat("  alpha_r   : ", fmt_dist(params$alpha_r), "\n")
  cat("  alpha_l   : ", fmt_dist(params$alpha_l), "\n")
  cat("  p         : ", params$p, "\n")
  cat("  max ||t|| : ", fmt_dist(params$alpha_r + params$alpha_l),
      "  (Proposition 3 bound)\n")
  invisible(x)
}

#' Plot an exploded_map object
#' @param x An `exploded_map` object
#' @param which "exploded" (default), "original", or "both"
#' @param ... Ignored
#' @export
plot.exploded_map <- function(x, which = c("exploded", "original", "both"), ...) {
  which <- match.arg(which)
  if (which == "original" || which == "both") print(x$plots$orig)
  if (which == "exploded" || which == "both") print(x$plots$exp)
  invisible(x)
}

#' Summary of an exploded_map object
#' @param object An `exploded_map` object
#' @param ... Ignored
#' @export
summary.exploded_map <- function(object, ...) {
  stats  <- object$stats
  params <- object$params

  cat("\nExploded Map Summary\n")
  cat("====================\n")
  cat("Dataset:     ", object$diagnostics$label, "\n")
  cat("Units:       ", format(stats$n_units, big.mark = ","), "\n")
  cat("Regions:     ", stats$n_regions, "\n")
  cat("Grouped by:  ", object$diagnostics$region_col, "\n\n")
  cat("Geometry Statistics\n")
  cat("  Characteristic diameter (w_bar): ", fmt_dist(stats$w_bar), "\n")
  cat("  Regional radius (R_local):       ", fmt_dist(stats$R_local), "\n")
  cat("  Median units/region (n_bar):     ", round(stats$n_bar), "\n")
  cat("  Tightness ratio (R_local/w_bar): ", round(stats$ratio, 2), "\n\n")
  cat("Parameters\n")
  cat("  alpha_r: ", fmt_dist(params$alpha_r), "  (regional separation)\n")
  cat("  alpha_l: ", fmt_dist(params$alpha_l), "  (local expansion)\n")
  cat("  p:       ", params$p, "\n\n")
  cat("Implied Gamma Coefficients\n")
  cat("  gamma_r: ", round(object$gamma_r_implied, 4), "\n")
  cat("  gamma_l: ", round(object$gamma_l_implied, 4), "\n")
  invisible(object)
}

#' Extract calibration row from an exploded_map
#'
#' Returns a one-row data.frame suitable for binding across datasets
#' to build a calibration table.
#'
#' @param x An `exploded_map` object
#' @return A one-row data.frame
#' @export
calibration_row <- function(x) {
  if (!inherits(x, "exploded_map"))
    stop("Input must be an exploded_map object.", call. = FALSE)
  stats  <- x$stats
  params <- x$params
  data.frame(
    label           = x$diagnostics$label,
    n_units         = stats$n_units,
    n_regions       = stats$n_regions,
    w_bar_km        = round(stats$w_bar / 1000, 2),
    R_local_km      = round(stats$R_local / 1000, 1),
    ratio           = round(stats$ratio, 2),
    alpha_r         = round(params$alpha_r),
    alpha_l         = round(params$alpha_l),
    gamma_r_implied = round(x$gamma_r_implied, 4),
    gamma_l_implied = round(x$gamma_l_implied, 4),
    stringsAsFactors = FALSE
  )
}

# =============================================================================
# GROUPED EXPLODED MAP S3 METHODS
# =============================================================================

#' Print a grouped_exploded_map object
#' @param x A `grouped_exploded_map` object
#' @param ... Ignored
#' @export
print.grouped_exploded_map <- function(x, ...) {
  stats  <- x$stats
  params <- x$params
  diag   <- x$diagnostics

  cat("\n-- ", diag$label, " (grouped) ", paste(rep("-", 30), collapse = ""), "\n", sep = "")
  cat("  n units   : ", format(stats$n_units, big.mark = ","), "\n")
  cat("  n regions : ", stats$n_regions, "\n")
  cat("  mode      : ", params$mode, "\n")
  cat("  alpha_l   : ", fmt_dist(params$alpha_l), "\n")
  cat("  p         : ", params$p, "\n")
  if (params$mode != "manual") {
    cat("  kappa     : ", params$kappa, "\n")
    cat("  padding   : ", fmt_dist(params$padding), "\n")
  }
  if (params$mode == "auto_collision") {
    cat("  lambda    : ", params$lambda, "\n")
    cat("  eta       : ", params$eta, "\n")
  }
  invisible(x)
}

#' Plot a grouped_exploded_map object
#' @param x A `grouped_exploded_map` object
#' @param which "grouped" (default), "original", "local", or "all"
#' @param ... Ignored
#' @export
plot.grouped_exploded_map <- function(x, which = c("grouped", "original", "local", "all"), ...) {
  which <- match.arg(which)
  if (which == "original" || which == "all") print(x$plots$orig)
  if (which == "local"    || which == "all") {
    if (!is.null(x$plots$local)) print(x$plots$local)
  }
  if (which == "grouped"  || which == "all") print(x$plots$grouped)
  invisible(x)
}

#' Summary of a grouped_exploded_map object
#' @param object A `grouped_exploded_map` object
#' @param ... Ignored
#' @export
summary.grouped_exploded_map <- function(object, ...) {
  stats  <- object$stats
  params <- object$params

  cat("\nGrouped Exploded Map Summary\n")
  cat("============================\n")
  cat("Dataset:     ", object$diagnostics$label, "\n")
  cat("Units:       ", format(stats$n_units, big.mark = ","), "\n")
  cat("Regions:     ", stats$n_regions, "\n")
  cat("Grouped by:  ", object$diagnostics$region_col, "\n")
  cat("Anchor mode: ", params$mode, "\n\n")
  cat("Level 1 Parameters\n")
  cat("  alpha_l: ", fmt_dist(params$alpha_l), "  (local expansion)\n")
  cat("  p:       ", params$p, "\n\n")
  if (params$mode != "manual") {
    cat("Anchor Parameters\n")
    cat("  kappa:       ", params$kappa, "\n")
    cat("  padding:     ", fmt_dist(params$padding), "\n")
    cat("  delta:       ", fmt_dist(params$delta), "\n")
    if (params$mode == "auto_collision") {
      cat("  lambda:      ", params$lambda, "\n")
      cat("  eta:         ", params$eta, "\n")
    }
  }
  if (!is.null(object$anchors)) {
    cat("\nAnchor Radii\n")
    print(object$anchors[, c(object$diagnostics$region_col,
                             "block_radius", "n_units")],
          row.names = FALSE)
  }
  invisible(object)
}
