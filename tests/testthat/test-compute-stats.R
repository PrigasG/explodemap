test_that("compute_stats returns expected fields and positive values", {
  x <- make_test_sf()

  s <- compute_stats(x, "region")

  expect_type(s, "list")
  expect_true(all(c("w_bar", "R_local", "n_bar", "n_regions", "ratio") %in% names(s)))
  expect_equal(s$n_regions, 2)
  expect_equal(s$n_bar, 2)
  expect_true(s$w_bar > 0)
  expect_true(s$R_local >= 0)
  expect_true(s$ratio >= 0)
})
