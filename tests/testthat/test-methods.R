test_that("print, summary, plot, and calibration_row work for exploded_map", {
  x <- make_test_sf()
  out <- explode_sf(x, region_col = "region", plot = FALSE)

  expect_invisible(print(out))
  expect_invisible(summary(out))
  expect_invisible(plot(out, "exploded"))
  expect_invisible(plot(out, "original"))
  expect_invisible(plot(out, "both"))

  row <- calibration_row(out)
  expect_s3_class(row, "data.frame")
  expect_equal(nrow(row), 1)
  expect_true(all(c(
    "label", "n_units", "n_regions", "w_bar_km", "R_local_km",
    "ratio", "alpha_r", "alpha_l", "gamma_r_implied", "gamma_l_implied"
  ) %in% names(row)))
})

test_that("calibration_row errors for non-exploded_map input", {
  expect_error(
    calibration_row(list()),
    "exploded_map"
  )
})
