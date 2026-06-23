save_table <- function(x, filename) {
  path <- file.path(paper_table_dir, filename)
  path <- try_output_path(path)
  utils::write.csv(x, path, row.names = FALSE)
  message("Wrote table: ", path)
  invisible(path)
}

save_plot <- function(plot, filename, width = 8, height = 6, dpi = 300) {
  path <- file.path(paper_figure_dir, filename)
  path <- try_output_path(path)
  ggplot2::ggsave(path, plot, width = width, height = height, dpi = dpi)
  message("Wrote figure: ", path)
  invisible(path)
}

try_output_path <- function(path) {
  if (!file.exists(path)) {
    return(path)
  }

  probe <- try(file(path, open = "a"), silent = TRUE)
  if (inherits(probe, "try-error")) {
    ext <- tools::file_ext(path)
    stem <- sub(paste0("\\.", ext, "$"), "", path)
    suffix <- format(Sys.time(), "%Y%m%d_%H%M%S")
    fallback <- if (nzchar(ext)) {
      paste0(stem, "_", suffix, ".", ext)
    } else {
      paste0(path, "_", suffix)
    }
    message("Output appears locked; writing timestamped copy: ", fallback)
    return(fallback)
  }

  close(probe)
  path
}

count_vertices <- function(x) {
  geom <- sf::st_geometry(x)
  sum(vapply(geom, function(g) nrow(sf::st_coordinates(g)), integer(1)))
}

centroid_xy <- function(x) {
  sf::st_coordinates(sf::st_centroid(sf::st_geometry(x)))
}

compute_displacement_metrics <- function(sf_orig, sf_exp) {
  c0 <- centroid_xy(sf_orig)
  c1 <- centroid_xy(sf_exp)
  disp <- sqrt((c1[, 1] - c0[, 1])^2 + (c1[, 2] - c0[, 2])^2)

  area_orig <- as.numeric(sf::st_area(sf_orig))
  area_exp <- as.numeric(sf::st_area(sf_exp))
  area_rel_error <- abs(area_exp - area_orig) / pmax(area_orig, .Machine$double.eps)

  data.frame(
    mean_displacement_m = mean(disp, na.rm = TRUE),
    median_displacement_m = stats::median(disp, na.rm = TRUE),
    max_displacement_m = max(disp, na.rm = TRUE),
    max_area_relative_error = max(area_rel_error, na.rm = TRUE)
  )
}

compute_nearest_gap_metrics <- function(sf_obj,
                                        thresholds_m = c(0, 50, 250),
                                        max_exact_n = 1000,
                                        sample_n = 500,
                                        seed = 42) {
  n <- nrow(sf_obj)
  exact <- n <= max_exact_n

  if (exact) {
    idx <- seq_len(n)
    target <- sf_obj
  } else {
    set.seed(seed)
    idx <- sort(sample(seq_len(n), min(sample_n, n)))
    target <- sf_obj[idx, , drop = FALSE]
  }

  dmat <- as.matrix(sf::st_distance(target, sf_obj))
  for (k in seq_along(idx)) {
    dmat[k, idx[k]] <- Inf
  }
  nearest <- apply(dmat, 1, min, na.rm = TRUE)

  out <- data.frame(
    n_gap_features = length(idx),
    gap_exact = exact,
    min_nearest_gap_m = min(nearest, na.rm = TRUE),
    mean_nearest_gap_m = mean(nearest, na.rm = TRUE),
    median_nearest_gap_m = stats::median(nearest, na.rm = TRUE)
  )

  for (threshold in thresholds_m) {
    nm <- paste0("pct_within_", threshold, "m")
    out[[nm]] <- mean(nearest <= threshold, na.rm = TRUE)
  }

  out
}

compute_map_metrics <- function(result,
                                dataset,
                                stage = "formula",
                                thresholds_m = c(0, 50, 250),
                                gap_sample_n = 250) {
  sf_exp <- if (!is.null(result$sf_exp)) result$sf_exp else result$sf_grouped
  sf_orig <- result$sf_orig

  gap <- compute_nearest_gap_metrics(
    sf_exp,
    thresholds_m = thresholds_m,
    sample_n = gap_sample_n
  )
  disp <- compute_displacement_metrics(sf_orig, sf_exp)

  data.frame(
    dataset = dataset,
    stage = stage,
    n_features = nrow(sf_exp),
    vertex_count = count_vertices(sf_exp),
    n_regions = result$stats$n_regions,
    w_bar_m = result$stats$w_bar,
    R_local_m = result$stats$R_local,
    ratio = result$stats$ratio,
    alpha_r_m = result$params$alpha_r %||% NA_real_,
    alpha_l_m = result$params$alpha_l %||% NA_real_,
    p = result$params$p %||% NA_real_,
    refine = isTRUE(result$params$refine),
    refine_min_gap_m = result$params$refine_min_gap %||% NA_real_,
    refine_max_shift_m = result$params$refine_max_shift %||% NA_real_,
    gap,
    disp,
    check.names = FALSE
  )
}

run_state_case <- function(key,
                           gamma_r = 3.0,
                           gamma_l = 1.136,
                           refine = FALSE,
                           refine_min_gap = NULL,
                           refine_max_shift = NULL,
                           quiet = TRUE) {
  reg <- paper_state_registry[[key]]
  force(reg)
  region_map <- if (is.function(reg$region_map)) {
    reg$region_map()
  } else {
    reg$region_map
  }
  timing <- system.time({
    result <- explodemap::explode_state(
      state_fips = reg$fips,
      crs = reg$crs,
      region_map = region_map,
      level = reg$level %||% "cousub",
      n_regions = reg$n_regions %||% NULL,
      gamma_r = gamma_r,
      gamma_l = gamma_l,
      refine = refine,
      refine_min_gap = refine_min_gap,
      refine_max_shift = refine_max_shift,
      allow_other = TRUE,
      plot = FALSE,
      export = FALSE,
      label = reg$name,
      quiet = quiet
    )
  })
  attr(result, "runtime_seconds") <- unname(timing[["elapsed"]])
  result
}

`%||%` <- function(a, b) if (is.null(a)) b else a
