source(file.path("paper", "scripts", "00_setup.R"))
write_run_info("09_pa_displacement_vectors")

message("Rendering Pennsylvania displacement vector field...")

pa_formula <- run_state_case("PA", refine = FALSE)

orig_cent <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(pa_formula$sf_orig)))
exp_cent <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(pa_formula$sf_exp)))

region_col <- pa_formula$diagnostics$region_col
vector_df <- data.frame(
  region = as.character(pa_formula$sf_orig[[region_col]]),
  x = orig_cent[, 1],
  y = orig_cent[, 2],
  xend = exp_cent[, 1],
  yend = exp_cent[, 2],
  stringsAsFactors = FALSE
)

region_levels <- sort(unique(vector_df$region))
palette <- c("#2166ac", "#d73027", "#1a9850", "#984ea3", "#ff7f00", "#a65628")
region_colors <- stats::setNames(rep(palette, length.out = length(region_levels)), region_levels)

both_bbox <- sf::st_bbox(dplyr::bind_rows(
  pa_formula$sf_orig |> dplyr::mutate(.layout = "Original"),
  pa_formula$sf_exp |> dplyr::mutate(.layout = "Exploded")
))
xpad <- (both_bbox[["xmax"]] - both_bbox[["xmin"]]) * 0.08
ypad <- (both_bbox[["ymax"]] - both_bbox[["ymin"]]) * 0.08

plot <- ggplot2::ggplot() +
  ggplot2::geom_sf(
    data = pa_formula$sf_orig,
    fill = "grey90",
    color = "grey70",
    linewidth = 0.06,
    alpha = 0.55
  ) +
  ggplot2::geom_segment(
    data = vector_df,
    ggplot2::aes(
      x = .data$x,
      y = .data$y,
      xend = .data$xend,
      yend = .data$yend,
      color = factor(.data$region, levels = region_levels)
    ),
    arrow = ggplot2::arrow(length = grid::unit(0.045, "cm"), type = "closed"),
    linewidth = 0.18,
    alpha = 0.55
  ) +
  ggplot2::geom_sf(
    data = pa_formula$sf_exp,
    ggplot2::aes(fill = factor(.data[[region_col]], levels = region_levels)),
    color = "white",
    linewidth = 0.06,
    alpha = 0.82
  ) +
  ggplot2::scale_fill_manual(
    values = region_colors,
    breaks = region_levels,
    name = "Exploded region"
  ) +
  ggplot2::scale_color_manual(
    values = region_colors,
    breaks = region_levels,
    name = "Displacement vector"
  ) +
  ggplot2::coord_sf(
    xlim = c(both_bbox[["xmin"]] - xpad, both_bbox[["xmax"]] + xpad),
    ylim = c(both_bbox[["ymin"]] - ypad, both_bbox[["ymax"]] + ypad),
    expand = FALSE
  ) +
  ggplot2::theme_void(base_size = 11) +
  ggplot2::theme(
    plot.background = ggplot2::element_rect(fill = "white", color = NA),
    panel.background = ggplot2::element_rect(fill = "white", color = NA),
    legend.position = "bottom",
    legend.title = ggplot2::element_text(face = "bold", size = 9),
    legend.text = ggplot2::element_text(size = 8),
    legend.key.height = grid::unit(0.35, "cm")
  ) +
  ggplot2::guides(
    fill = ggplot2::guide_legend(nrow = 2, byrow = TRUE),
    color = ggplot2::guide_legend(nrow = 2, byrow = TRUE)
  ) +
  ggplot2::labs(
    title = "Pennsylvania Displacement Vectors",
    subtitle = "Arrows connect original municipal centroids to their formula-derived exploded positions."
  )

save_plot(plot, "pa_displacement_vectors.png", width = 9, height = 6)

message("Rendered Pennsylvania displacement vector field.")
