# =============================================================================
# Cross-State Calibration Example
# =============================================================================
# Runs explode_state() across multiple US states using the state registry,
# collects calibration rows, and reports gamma stability.
#
# Usage:
#   source(system.file("examples/run_calibration.R", package = "explodemap"))
# =============================================================================

library(explodemap)

# Load state registry
source(system.file("registries/state_registry.R", package = "explodemap"))

run_calibration <- function(states = names(state_registry),
                            gamma_r = 3.0, gamma_l = 1.136) {
  rows <- list()

  for (key in states) {
    reg <- state_registry[[key]]
    message("\n=== Processing: ", reg$name, " ===")

    result <- tryCatch(
      explode_state(
        state_fips = reg$fips, crs = reg$crs, region_map = reg$region_map,
        gamma_r = gamma_r, gamma_l = gamma_l,
        allow_other = TRUE, plot = FALSE, label = reg$name
      ),
      error = function(e) { message("  ERROR: ", e$message); NULL }
    )
    if (is.null(result)) next

    rows[[key]] <- calibration_row(result)
  }

  calib_df <- dplyr::bind_rows(rows)

  message("\n=== CALIBRATION TABLE ===")
  print(calib_df, row.names = FALSE)

  # Stability report
  known_r <- calib_df$gamma_r_implied[!is.na(calib_df$gamma_r_implied)]
  if (length(known_r) >= 2) {
    message("\ngamma_r across ", length(known_r), " states:")
    message("  values: ", paste(round(known_r, 3), collapse = ", "))
    message("  mean:   ", round(mean(known_r), 4))
    message("  CV:     ", round(sd(known_r) / mean(known_r), 4))
  }

  message("\nR_local/w_bar across all states:")
  message("  values: ", paste(round(calib_df$ratio, 2), collapse = ", "))
  message("  mean:   ", round(mean(calib_df$ratio, na.rm = TRUE), 2))

  invisible(calib_df)
}

# Run all configured states
calib <- run_calibration()
