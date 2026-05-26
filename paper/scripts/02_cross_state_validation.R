source(file.path("paper", "scripts", "00_setup.R"))
write_run_info("02_cross_state_validation")

states_env <- Sys.getenv("EXPLODEMAP_PAPER_STATES", "NJ,PA,OH,MI,KY,IL,ND,NC,VA")
states <- trimws(strsplit(states_env, ",", fixed = TRUE)[[1]])
run_metrics <- identical(tolower(Sys.getenv("EXPLODEMAP_PAPER_RUN_METRICS", "false")), "true")
run_figures <- !identical(tolower(Sys.getenv("EXPLODEMAP_PAPER_RUN_FIGURES", "true")), "false")

message("Running cross-state formula-derived validation: ", paste(states, collapse = ", "))

rows <- list()
calibration_rows <- list()
manual_rows <- list()

for (key in states) {
  reg <- paper_state_registry[[key]]
  message("Processing ", reg$name, "...")

  result <- run_state_case(key, refine = FALSE)

  row <- data.frame(
    dataset = reg$name,
    stage = "formula",
    n_features = nrow(result$sf_exp),
    vertex_count = count_vertices(result$sf_exp),
    n_regions = result$stats$n_regions,
    w_bar_m = result$stats$w_bar,
    R_local_m = result$stats$R_local,
    ratio = result$stats$ratio,
    alpha_r_m = result$params$alpha_r,
    alpha_l_m = result$params$alpha_l,
    p = result$params$p,
    runtime_seconds = attr(result, "runtime_seconds")
  )

  if (run_metrics) {
    row <- cbind(row, compute_nearest_gap_metrics(result$sf_exp, sample_n = 250))
    row <- cbind(row, compute_displacement_metrics(result$sf_orig, result$sf_exp))
  }

  rows[[key]] <- row

  calibration_rows[[key]] <- explodemap::calibration_row(result)

  manual_rows[[key]] <- data.frame(
    state = key,
    dataset = reg$name,
    manual_alpha_r_m = reg$manual_alpha_r,
    manual_alpha_l_m = reg$manual_alpha_l,
    manual_protocol = reg$manual_protocol,
    formula_alpha_r_m = round(result$params$alpha_r),
    formula_alpha_l_m = round(result$params$alpha_l),
    implied_gamma_r_from_manual = if (!is.na(reg$manual_alpha_r)) {
      reg$manual_alpha_r / (result$stats$w_bar / (2 * sin(pi / result$stats$n_regions)))
    } else {
      NA_real_
    },
    implied_gamma_l_from_manual = if (!is.na(reg$manual_alpha_l)) {
      reg$manual_alpha_l / (2 * result$stats$R_local / sqrt(result$stats$n_bar))
    } else {
      NA_real_
    }
  )

  if (run_figures) {
    save_plot(result$plots$exp, paste0(tolower(key), "_formula_derived.png"), width = 8, height = 6)
  }
}

cross_state_metrics <- dplyr::bind_rows(rows)
calibration_table <- dplyr::bind_rows(calibration_rows)
manual_calibration <- dplyr::bind_rows(manual_rows)

gamma_summary <- data.frame(
  coefficient = c("gamma_r_manual", "gamma_l_manual"),
  n = c(
    sum(!is.na(manual_calibration$implied_gamma_r_from_manual)),
    sum(!is.na(manual_calibration$implied_gamma_l_from_manual))
  ),
  mean = c(
    mean(manual_calibration$implied_gamma_r_from_manual, na.rm = TRUE),
    mean(manual_calibration$implied_gamma_l_from_manual, na.rm = TRUE)
  ),
  sd = c(
    stats::sd(manual_calibration$implied_gamma_r_from_manual, na.rm = TRUE),
    stats::sd(manual_calibration$implied_gamma_l_from_manual, na.rm = TRUE)
  )
)
gamma_summary$cv <- gamma_summary$sd / gamma_summary$mean

save_table(cross_state_metrics, "cross_state_metrics.csv")
save_table(calibration_table, "cross_state_calibration_rows.csv")
save_table(manual_calibration, "manual_calibration_protocol.csv")
save_table(gamma_summary, "gamma_summary.csv")

message("Cross-state validation complete.")
