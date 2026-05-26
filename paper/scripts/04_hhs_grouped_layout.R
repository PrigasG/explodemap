source(file.path("paper", "scripts", "00_setup.R"))
write_run_info("04_hhs_grouped_layout")
run_metrics <- identical(tolower(Sys.getenv("EXPLODEMAP_PAPER_RUN_METRICS", "false")), "true")

hhs_lookup <- data.frame(
  STUSPS = c(
    "CT", "ME", "MA", "NH", "RI", "VT",
    "NJ", "NY", "PR", "VI",
    "DE", "DC", "MD", "PA", "VA", "WV",
    "AL", "FL", "GA", "KY", "MS", "NC", "SC", "TN",
    "IL", "IN", "MI", "MN", "OH", "WI",
    "AR", "LA", "NM", "OK", "TX",
    "IA", "KS", "MO", "NE",
    "CO", "MT", "ND", "SD", "UT", "WY",
    "AZ", "CA", "HI", "NV", "GU", "AS", "MP",
    "AK", "ID", "OR", "WA"
  ),
  hhs_region = c(
    rep("1", 6), rep("2", 4), rep("3", 6), rep("4", 8),
    rep("5", 6), rep("6", 5), rep("7", 4), rep("8", 6),
    rep("9", 7), rep("10", 4)
  ),
  stringsAsFactors = FALSE
)

download_us_states <- function() {
  cache_file <- file.path(path.expand("~"), "explode_map_cache", "us_states_2024.rds")
  if (file.exists(cache_file)) {
    return(readRDS(cache_file))
  }

  url <- "https://www2.census.gov/geo/tiger/TIGER2024/STATE/tl_2024_us_state.zip"
  tmp <- tempfile(fileext = ".zip")
  utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
  dir <- file.path(tempdir(), "us_states")
  dir.create(dir, showWarnings = FALSE)
  utils::unzip(tmp, exdir = dir)
  shp <- list.files(dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)
  states_sf <- sf::st_read(shp[1], quiet = TRUE)
  dir.create(dirname(cache_file), showWarnings = FALSE, recursive = TRUE)
  saveRDS(states_sf, cache_file)
  states_sf
}

run_hhs_mode <- function(mode) {
  states_proj <- download_us_states() |>
    sf::st_transform(5070) |>
    dplyr::left_join(hhs_lookup, by = "STUSPS")

  states_proj$hhs_region[is.na(states_proj$hhs_region)] <- "Other"

  timing <- system.time({
    result <- explodemap::explode_grouped(
      states_proj,
      region_col = "hhs_region",
      mode = mode,
      alpha_l = 120000,
      p = 1.25,
      kappa = 1.8,
      padding = 80000,
      delta = 20000,
      lambda = 0.18,
      eta = 0.18,
      padding_sep = 30000,
      max_iter = 60,
      plot = FALSE,
      export = FALSE,
      label = paste("US by HHS Region", mode),
      quiet = TRUE
    )
  })
  attr(result, "runtime_seconds") <- unname(timing[["elapsed"]])
  result
}

make_hhs_labeled_plot <- function(result) {
  make_hhs_plot(result, labeled = TRUE)
}

make_hhs_plot <- function(result, labeled = FALSE) {
  region_col <- result$diagnostics$region_col
  display <- prepare_hhs_display(result)
  sf_display <- display$sf
  anchor_display <- display$anchors

  hhs_levels <- as.character(1:10)
  sf_display[[region_col]] <- factor(as.character(sf_display[[region_col]]), levels = hhs_levels)
  anchor_display[[region_col]] <- factor(as.character(anchor_display[[region_col]]), levels = hhs_levels)

  hhs_colors <- stats::setNames(
    c(
      "#2166ac", "#d73027", "#1a9850", "#984ea3", "#ff7f00",
      "#a65628", "#f781bf", "#999999", "#33a02c", "#b2df8a"
    ),
    hhs_levels
  )

  p <- ggplot2::ggplot(sf_display) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data[[region_col]]),
      color = "white",
      linewidth = 0.35
    ) +
    ggplot2::scale_fill_manual(
      values = hhs_colors,
      breaks = hhs_levels,
      drop = FALSE,
      name = "HHS region"
    ) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::labs(
      title = paste("US by HHS Region", result$params$mode),
      subtitle = paste0(
        "mode=", result$params$mode,
        "  alpha_l=", round(result$params$alpha_l), "m",
        "  p=", result$params$p
      )
    )

  if (!labeled) {
    return(p)
  }

  p +
    ggplot2::geom_point(
      data = anchor_display,
      ggplot2::aes(x = .data$label_x, y = .data$label_y),
      inherit.aes = FALSE,
      size = 5,
      shape = 21,
      fill = "white",
      color = "black",
      stroke = 1
    ) +
    ggplot2::geom_text(
      data = anchor_display,
      ggplot2::aes(x = .data$label_x, y = .data$label_y, label = .data$label),
      inherit.aes = FALSE,
      size = 3.2,
      fontface = "bold"
    )
}

prepare_hhs_display <- function(result) {
  region_col <- result$diagnostics$region_col
  sf_display <- result$sf_grouped
  anchor_display <- result$anchors |>
    dplyr::filter(.data[[region_col]] %in% as.character(1:10)) |>
    dplyr::mutate(
      label_x = .data$anchor_x,
      label_y = .data$anchor_y,
      label = as.character(as.integer(.data[[region_col]]))
    )

  anchor_display <- anchor_display |>
    dplyr::arrange(as.integer(as.character(.data[[region_col]])))

  list(sf = sf_display, anchors = anchor_display)
}

message("Running HHS auto layout...")
hhs_auto <- run_hhs_mode("auto")
message("Running HHS auto_collision layout...")
hhs_collision <- run_hhs_mode("auto_collision")

hhs_metric_row <- function(result, stage) {
  row <- data.frame(
    dataset = "HHS states and territories",
    stage = stage,
    n_features = nrow(result$sf_grouped),
    vertex_count = count_vertices(result$sf_grouped),
    n_regions = result$stats$n_regions,
    w_bar_m = result$stats$w_bar,
    R_local_m = result$stats$R_local,
    ratio = result$stats$ratio,
    alpha_l_m = result$params$alpha_l,
    p = result$params$p,
    mode = result$params$mode,
    runtime_seconds = attr(result, "runtime_seconds")
  )
  if (run_metrics) {
    row <- cbind(
      row,
      compute_nearest_gap_metrics(result$sf_grouped, sample_n = 250),
      compute_displacement_metrics(result$sf_orig, result$sf_grouped)
    )
  }
  row
}

hhs_metrics <- dplyr::bind_rows(
  hhs_metric_row(hhs_auto, "auto"),
  hhs_metric_row(hhs_collision, "auto_collision")
)

save_table(hhs_metrics, "hhs_metrics.csv")
save_table(hhs_auto$anchors, "hhs_anchors_auto.csv")
save_table(hhs_collision$anchors, "hhs_anchors_auto_collision.csv")
save_plot(make_hhs_plot(hhs_auto), "hhs_auto.png", width = 9, height = 6)
save_plot(make_hhs_plot(hhs_collision), "hhs_auto_collision.png", width = 9, height = 6)
save_plot(make_hhs_labeled_plot(hhs_auto), "hhs_auto_labeled.png", width = 9, height = 6)
save_plot(make_hhs_labeled_plot(hhs_collision), "hhs_auto_collision_labeled.png", width = 9, height = 6)

message("HHS grouped validation complete.")
