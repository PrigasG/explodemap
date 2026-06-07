source(file.path("paper", "scripts", "00_setup.R"))
write_run_info("08_render_dragged_layouts")

drag_index_path <- file.path(paper_table_dir, "drag_helper_index.csv")
default_drag_cases <- if (file.exists(drag_index_path)) {
  drag_index <- utils::read.csv(drag_index_path, stringsAsFactors = FALSE)
  drag_index$case[nchar(drag_index$case) == 2]
} else {
  c(
    "NJ", "PA", "OH", "MI", "KY", "IL", "ND", "NC", "VA", "TN", "GA", "MN",
    "CA", "CO", "TX", "FL", "AZ", "IN", "MA", "MO", "NV", "NY", "OR",
    "SC", "UT", "WA"
  )
}
drag_cases_env <- Sys.getenv("EXPLODEMAP_DRAG_CASES", paste(default_drag_cases, collapse = ","))
drag_cases <- tolower(trimws(strsplit(drag_cases_env, ",", fixed = TRUE)[[1]]))
drag_cases <- drag_cases[nzchar(drag_cases)]

drag_root <- file.path(paper_output_dir, "drag_helpers")

move_region <- function(sf_obj, region, dx, dy) {
  idx <- as.character(sf_obj$drag_region) == as.character(region)
  sf::st_geometry(sf_obj)[idx] <- sf::st_geometry(sf_obj)[idx] + c(dx, dy)
  sf_obj
}

read_offsets <- function(case_key, regions) {
  offset_path <- file.path(paper_table_dir, paste0(case_key, "_drag_offsets.csv"))
  if (!file.exists(offset_path)) {
    message("No offsets for ", case_key, "; rendering original formula-derived layout.")
    return(data.frame(region = regions, dx_m = 0, dy_m = 0, stringsAsFactors = FALSE))
  }

  offsets <- utils::read.csv(offset_path, stringsAsFactors = FALSE, check.names = FALSE)
  names(offsets) <- tolower(names(offsets))
  required_cols <- c("region", "dx_m", "dy_m")
  missing_cols <- setdiff(required_cols, names(offsets))
  if (length(missing_cols) > 0) {
    stop(
      offset_path,
      " is missing column(s): ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  offsets$region <- as.character(offsets$region)
  offsets
}

render_dragged_case <- function(case_key) {
  layout_path <- file.path(drag_root, case_key, "layout.rds")
  map_path <- file.path(drag_root, case_key, "map.geojson")
  if (file.exists(layout_path)) {
    layout <- readRDS(layout_path)
  } else if (file.exists(map_path)) {
    states_fallback <- sf::st_read(map_path, quiet = TRUE)
    if (!"drag_region" %in% names(states_fallback)) {
      stop("Fallback GeoJSON for ", case_key, " has no drag_region column.", call. = FALSE)
    }
    labels_sf <- states_fallback |>
      dplyr::group_by(.data$drag_region) |>
      dplyr::summarise(geometry = sf::st_union(.data$geometry), .groups = "drop") |>
      sf::st_centroid()
    label_xy <- sf::st_coordinates(labels_sf)
    layout <- list(
      states = states_fallback,
      labels = data.frame(
        region = labels_sf$drag_region,
        label = labels_sf$drag_region,
        x = label_xy[, 1],
        y = label_xy[, 2],
        stringsAsFactors = FALSE
      ) |> dplyr::arrange(.data$region),
      region_col = "drag_region",
      title = tools::toTitleCase(case_key),
      key = case_key,
      output_prefix = paste0(case_key, "_dragged")
    )
  } else {
    stop("Missing layout and GeoJSON for ", case_key, ".", call. = FALSE)
  }

  states <- layout$states
  labels <- layout$labels
  regions <- as.character(labels$region)
  offsets <- read_offsets(case_key, regions)

  for (i in seq_len(nrow(offsets))) {
    states <- move_region(states, offsets$region[i], offsets$dx_m[i], offsets$dy_m[i])
  }

  labels <- labels |>
    dplyr::left_join(offsets, by = c("region" = "region")) |>
    dplyr::mutate(
      dx_m = dplyr::coalesce(.data$dx_m, 0),
      dy_m = dplyr::coalesce(.data$dy_m, 0),
      x = .data$x + .data$dx_m,
      y = .data$y + .data$dy_m
    )

  palette <- c(
    "#2166ac", "#d73027", "#1a9850", "#984ea3", "#ff7f00",
    "#a65628", "#f781bf", "#999999", "#33a02c", "#b2df8a",
    "#66c2a5", "#fc8d62", "#8da0cb", "#e78ac3", "#a6d854"
  )
  region_levels <- sort(unique(as.character(states$drag_region)))
  colors <- stats::setNames(rep(palette, length.out = length(region_levels)), region_levels)

  bbox <- sf::st_bbox(states)
  xpad <- (bbox[["xmax"]] - bbox[["xmin"]]) * 0.08
  ypad <- (bbox[["ymax"]] - bbox[["ymin"]]) * 0.08

  plot <- ggplot2::ggplot() +
    ggplot2::geom_sf(
      data = states,
      ggplot2::aes(fill = factor(.data$drag_region, levels = region_levels)),
      color = "white",
      linewidth = 0.2
    ) +
    ggplot2::scale_fill_manual(
      values = colors,
      breaks = region_levels,
      name = "Region"
    ) +
    ggplot2::geom_point(
      data = labels,
      ggplot2::aes(x = .data$x, y = .data$y),
      size = 2.6,
      shape = 21,
      fill = "white",
      color = "black",
      stroke = 0.7
    ) +
    ggplot2::coord_sf(
      xlim = c(bbox[["xmin"]] - xpad, bbox[["xmax"]] + xpad),
      ylim = c(bbox[["ymin"]] - ypad, bbox[["ymax"]] + ypad),
      expand = FALSE
    ) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", color = NA),
      panel.background = ggplot2::element_rect(fill = "white", color = NA),
      plot.title = ggplot2::element_text(hjust = 0.5, size = 18, margin = ggplot2::margin(b = 8)),
      plot.margin = ggplot2::margin(10, 10, 10, 10),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(face = "bold", size = 9),
      legend.text = ggplot2::element_text(size = 8),
      legend.key.height = grid::unit(0.35, "cm")
    ) +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2, byrow = TRUE)) +
    ggplot2::labs(title = layout$title)

  figure_file <- paste0(layout$output_prefix, "_layout.png")
  save_plot(plot, figure_file, width = 8, height = 6)

  used_file <- paste0(case_key, "_drag_offsets_used.csv")
  save_table(offsets, used_file)

  data.frame(
    case = case_key,
    figure = file.path("paper", "outputs", "figures", figure_file),
    offsets = file.path("paper", "outputs", "tables", used_file),
    stringsAsFactors = FALSE
  )
}

rows <- lapply(drag_cases, render_dragged_case)
render_index <- dplyr::bind_rows(rows)
render_index_path <- file.path(paper_table_dir, "dragged_layout_render_index.csv")
if (file.exists(render_index_path)) {
  existing_render_index <- utils::read.csv(render_index_path, stringsAsFactors = FALSE)
  render_index <- dplyr::bind_rows(existing_render_index, render_index) |>
    dplyr::distinct(.data$case, .keep_all = TRUE) |>
    dplyr::arrange(.data$case)
}
save_table(render_index, "dragged_layout_render_index.csv")

message("Rendered dragged layouts.")
