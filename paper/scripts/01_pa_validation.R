source(file.path("paper", "scripts", "00_setup.R"))
write_run_info("01_pa_validation")

reg <- paper_state_registry$PA
run_refinement <- identical(tolower(Sys.getenv("EXPLODEMAP_PAPER_RUN_REFINEMENT", "false")), "true")
run_sensitivity <- identical(tolower(Sys.getenv("EXPLODEMAP_PAPER_RUN_SENSITIVITY", "false")), "true")
run_metrics <- identical(tolower(Sys.getenv("EXPLODEMAP_PAPER_RUN_METRICS", "false")), "true")

message("Running Pennsylvania formula-derived validation...")
pa_formula <- run_state_case("PA", refine = FALSE)

parameter_table <- data.frame(
  dataset = "Pennsylvania",
  gamma_r = pa_formula$params$gamma_r,
  gamma_l = pa_formula$params$gamma_l,
  alpha_r_m = round(pa_formula$params$alpha_r),
  alpha_l_m = round(pa_formula$params$alpha_l),
  n_units = pa_formula$stats$n_units,
  n_regions = pa_formula$stats$n_regions,
  w_bar_m = round(pa_formula$stats$w_bar),
  R_local_m = round(pa_formula$stats$R_local),
  n_bar = round(pa_formula$stats$n_bar),
  ratio = round(pa_formula$stats$ratio, 2)
)

save_table(parameter_table, "pa_parameters.csv")
save_plot(pa_formula$plots$orig, "pa_original.png", width = 8, height = 6)
save_plot(pa_formula$plots$exp, "pa_formula_derived.png", width = 8, height = 6)

if (run_metrics) {
  message("Computing Pennsylvania sampled metrics...")
  pa_formula_metrics <- compute_map_metrics(pa_formula, "Pennsylvania", "formula")
  pa_formula_metrics$runtime_seconds <- attr(pa_formula, "runtime_seconds")
  save_table(pa_formula_metrics, "pa_metrics_formula.csv")
}

if (run_refinement) {
  message("Running Pennsylvania bounded refinement validation...")
  pa_refined <- run_state_case(
    "PA",
    refine = TRUE,
    refine_min_gap = 50,
    refine_max_shift = 250
  )
  save_plot(pa_refined$plots$exp, "pa_formula_refined_50m.png", width = 8, height = 6)

  if (run_metrics) {
    pa_refined_metrics <- compute_map_metrics(pa_refined, "Pennsylvania", "formula_plus_refine_50m")
    pa_refined_metrics$runtime_seconds <- attr(pa_refined, "runtime_seconds")
    save_table(pa_refined_metrics, "pa_metrics_refined_50m.csv")
  }
}

if (run_sensitivity) {
  message("Running Pennsylvania alpha_l sensitivity analysis...")
  sensitivity_factors <- c(0.85, 0.90, 0.95, 1.00, 1.05, 1.10, 1.15)
  sensitivity_rows <- lapply(sensitivity_factors, function(factor) {
    alpha_l <- round(pa_formula$params$alpha_l * factor)
    timing <- system.time({
      result <- explodemap::explode_state(
        state_fips = reg$fips,
        crs = reg$crs,
        region_map = reg$region_map,
        alpha_r = round(pa_formula$params$alpha_r),
        alpha_l = alpha_l,
        plot = FALSE,
        export = FALSE,
        label = paste0("Pennsylvania sensitivity ", factor),
        quiet = TRUE
      )
    })
    row <- if (run_metrics) {
      compute_map_metrics(result, "Pennsylvania", paste0("alpha_l_x_", factor))
    } else {
      data.frame(
        dataset = "Pennsylvania",
        stage = paste0("alpha_l_x_", factor),
        alpha_r_m = result$params$alpha_r,
        alpha_l_m = result$params$alpha_l
      )
    }
    row$factor <- factor
    row$runtime_seconds <- unname(timing[["elapsed"]])
    row
  })

  sensitivity_table <- dplyr::bind_rows(sensitivity_rows)
  save_table(sensitivity_table, "pa_sensitivity.csv")
}

message(
  "Pennsylvania validation complete. Heavy options: ",
  "EXPLODEMAP_PAPER_RUN_METRICS=", run_metrics, ", ",
  "EXPLODEMAP_PAPER_RUN_REFINEMENT=", run_refinement, ", ",
  "EXPLODEMAP_PAPER_RUN_SENSITIVITY=", run_sensitivity
)
