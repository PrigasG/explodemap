# =============================================================================
# R/plot.R — Plotting helpers
# =============================================================================

#' Build standard original/exploded ggplot pair
#' @keywords internal
.make_plots <- function(sf_orig, sf_exp, region_col, title, params) {
  regions <- sort(unique(sf_orig[[region_col]]))
  pal <- stats::setNames(
    grDevices::colorRampPalette(
      c("#2166ac", "#d73027", "#1a9850", "#984ea3",
        "#ff7f00", "#a65628", "#f781bf", "#999999",
        "#33a02c", "#b2df8a")
    )(length(regions)),
    regions
  )

  subtitle <- if (!is.null(params))
    paste0("\u03b1_r=", round(params$alpha_r), "m  \u03b1_l=",
           round(params$alpha_l), "m  p=", params$p)
  else ""

  p_orig <- ggplot2::ggplot(sf_orig |> sf::st_transform(4326)) +
    ggplot2::geom_sf(ggplot2::aes(fill = .data[[region_col]]),
                     color = "white", linewidth = 0.2) +
    ggplot2::scale_fill_manual(values = pal, name = region_col) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::labs(title = paste(title, "- Original"))

  p_exp <- ggplot2::ggplot(sf_exp |> sf::st_transform(4326)) +
    ggplot2::geom_sf(ggplot2::aes(fill = .data[[region_col]]),
                     color = "white", linewidth = 0.2) +
    ggplot2::scale_fill_manual(values = pal, name = region_col) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::labs(title = paste(title, "- Exploded"), subtitle = subtitle)

  list(orig = p_orig, exp = p_exp)
}
