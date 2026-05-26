source(file.path("paper", "scripts", "00_setup.R"))
write_run_info("06_hhs_render_dragged_layout")

helper_dir <- file.path(paper_output_dir, "hhs_drag_helper")
layout_path <- file.path(helper_dir, "hhs_manual_layout.rds")
offset_path <- file.path(paper_table_dir, "hhs_drag_offsets.csv")

if (!file.exists(layout_path)) {
  stop(
    "Run paper/scripts/05_hhs_drag_helper.R before rendering the dragged HHS layout.",
    call. = FALSE
  )
}

layout <- readRDS(layout_path)
states <- layout$states
labels <- layout$labels
base_states <- states
base_labels <- labels

if (file.exists(offset_path)) {
  offsets <- utils::read.csv(offset_path, stringsAsFactors = FALSE)
  names(offsets) <- tolower(names(offsets))
  required_cols <- c("region", "dx_m", "dy_m")
  missing_cols <- setdiff(required_cols, names(offsets))
  if (length(missing_cols) > 0) {
    stop(
      "Offset file is missing column(s): ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }
  offsets$region <- as.character(offsets$region)
} else {
  offsets <- data.frame(
    region = as.character(1:10),
    dx_m = 0,
    dy_m = 0,
    stringsAsFactors = FALSE
  )
  message("No hhs_drag_offsets.csv found; rendering the original manual layout.")
}

move_region <- function(sf_obj, region, dx, dy) {
  idx <- as.character(sf_obj$hhs_region) == region
  sf::st_geometry(sf_obj)[idx] <- sf::st_geometry(sf_obj)[idx] + c(dx, dy)
  sf_obj
}

for (i in seq_len(nrow(offsets))) {
  states <- move_region(
    states,
    region = offsets$region[i],
    dx = offsets$dx_m[i],
    dy = offsets$dy_m[i]
  )
}

labels <- labels |>
  dplyr::left_join(offsets, by = c("region" = "region")) |>
  dplyr::mutate(
    dx_m = dplyr::coalesce(.data$dx_m, 0),
    dy_m = dplyr::coalesce(.data$dy_m, 0),
    x = .data$x + .data$dx_m,
    y = .data$y + .data$dy_m
  ) |>
  dplyr::arrange(as.integer(.data$region))

hhs_colors <- stats::setNames(
  c(
    "#A89A83", "#C764A6", "#2B4970", "#DF514F", "#309396",
    "#70A255", "#F2BE42", "#8459A0", "#872722", "#3579B0"
  ),
  as.character(1:10)
)
hhs_region_names <- stats::setNames(
  paste0(
    as.character(1:10),
    " - ",
    c(
      "Boston", "New York", "Philadelphia", "Atlanta", "Chicago",
      "Dallas", "Kansas City", "Denver", "San Francisco", "Seattle"
    )
  ),
  as.character(1:10)
)

bbox <- sf::st_bbox(states)
xpad <- (bbox[["xmax"]] - bbox[["xmin"]]) * 0.15
ypad <- (bbox[["ymax"]] - bbox[["ymin"]]) * 0.15

plot <- ggplot2::ggplot() +
  ggplot2::geom_sf(
    data = states,
    ggplot2::aes(fill = factor(.data$hhs_region, levels = as.character(1:10))),
    color = "white",
    linewidth = 1.1
  ) +
  ggplot2::scale_fill_manual(
    values = hhs_colors,
    breaks = as.character(1:10),
    labels = hhs_region_names,
    name = "HHS region",
    guide = "none"
  ) +
  ggplot2::geom_point(
    data = labels,
    ggplot2::aes(x = .data$x, y = .data$y),
    size = 6.5,
    shape = 21,
    fill = "white",
    color = "black",
    stroke = 1.4
  ) +
  ggplot2::geom_text(
    data = labels,
    ggplot2::aes(x = .data$x, y = .data$y, label = .data$region),
    size = 3.8,
    fontface = "bold"
  ) +
  ggplot2::coord_sf(
    xlim = c(bbox[["xmin"]] - xpad, bbox[["xmax"]] + xpad),
    ylim = c(bbox[["ymin"]] - ypad, bbox[["ymax"]] + ypad),
    expand = FALSE
  ) +
  ggplot2::theme_void(base_size = 11) +
  ggplot2::theme(
    plot.background = ggplot2::element_rect(fill = "white", color = NA),
    panel.background = ggplot2::element_rect(fill = "white", color = NA)
  ) +
  ggplot2::labs(title = "US Map by HHS Regions")

save_plot(plot, "hhs_dragged_layout.png", width = 9, height = 6)
save_table(offsets, "hhs_drag_offsets_used.csv")

movement <- base_labels |>
  dplyr::rename(x0 = .data$x, y0 = .data$y) |>
  dplyr::left_join(
    labels |>
      dplyr::rename(x1 = .data$x, y1 = .data$y),
    by = "region"
  ) |>
  dplyr::mutate(
    moved = sqrt((.data$x1 - .data$x0)^2 + (.data$y1 - .data$y0)^2) > 0
  )

movement_bbox <- sf::st_bbox(dplyr::bind_rows(
  base_states |> dplyr::mutate(.layout = "base"),
  states |> dplyr::mutate(.layout = "final")
))
movement_xpad <- (movement_bbox[["xmax"]] - movement_bbox[["xmin"]]) * 0.15
movement_ypad <- (movement_bbox[["ymax"]] - movement_bbox[["ymin"]]) * 0.15

movement_plot <- ggplot2::ggplot() +
  ggplot2::geom_sf(
    data = base_states,
    fill = "grey85",
    color = "white",
    linewidth = 0.7,
    alpha = 0.45
  ) +
  ggplot2::geom_sf(
    data = states,
    ggplot2::aes(fill = factor(.data$hhs_region, levels = as.character(1:10))),
    color = "white",
    linewidth = 0.9,
    alpha = 0.9
  ) +
  ggplot2::scale_fill_manual(
    values = hhs_colors,
    breaks = as.character(1:10),
    labels = hhs_region_names,
    name = "Final HHS region",
    guide = "none"
  ) +
  ggplot2::geom_segment(
    data = movement |> dplyr::filter(.data$moved),
    ggplot2::aes(x = .data$x0, y = .data$y0, xend = .data$x1, yend = .data$y1),
    arrow = ggplot2::arrow(length = grid::unit(0.18, "cm"), type = "closed"),
    linewidth = 0.6,
    color = "black",
    alpha = 0.75
  ) +
  ggplot2::geom_point(
    data = base_labels,
    ggplot2::aes(x = .data$x, y = .data$y),
    size = 2.2,
    shape = 21,
    fill = "white",
    color = "grey25",
    stroke = 0.8
  ) +
  ggplot2::geom_point(
    data = labels,
    ggplot2::aes(x = .data$x, y = .data$y),
    size = 5.8,
    shape = 21,
    fill = "white",
    color = "black",
    stroke = 1.3
  ) +
  ggplot2::geom_text(
    data = labels,
    ggplot2::aes(x = .data$x, y = .data$y, label = .data$region),
    size = 3.5,
    fontface = "bold"
  ) +
  ggplot2::coord_sf(
    xlim = c(movement_bbox[["xmin"]] - movement_xpad, movement_bbox[["xmax"]] + movement_xpad),
    ylim = c(movement_bbox[["ymin"]] - movement_ypad, movement_bbox[["ymax"]] + movement_ypad),
    expand = FALSE
  ) +
  ggplot2::theme_void(base_size = 11) +
  ggplot2::theme(
    plot.background = ggplot2::element_rect(fill = "white", color = NA),
    panel.background = ggplot2::element_rect(fill = "white", color = NA)
  ) +
  ggplot2::labs(
    title = "Documented HHS Display Offsets",
    subtitle = "Grey shapes show the pre-offset manual layout; arrows show region-level display translations."
  )

save_plot(movement_plot, "hhs_display_offsets.png", width = 9, height = 6)

message("Rendered HHS dragged layout.")
