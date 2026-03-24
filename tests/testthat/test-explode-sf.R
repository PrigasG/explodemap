test_that("explode_sf returns exploded_map object with expected structure", {
  x <- make_test_sf()

  out <- explode_sf(x, region_col = "region", plot = FALSE)

  expect_s3_class(out, "exploded_map")
  expect_true(all(c(
    "sf_orig", "sf_exp", "sf_exp_wgs", "stats", "params",
    "gamma_r_implied", "gamma_l_implied", "plots", "diagnostics"
  ) %in% names(out)))

  expect_s3_class(out$sf_orig, "sf")
  expect_s3_class(out$sf_exp, "sf")
  expect_equal(nrow(out$sf_orig), nrow(out$sf_exp))
  expect_equal(as.integer(sf::st_crs(out$sf_exp_wgs)$epsg), 4326)
})

test_that("explode_sf respects manual alpha overrides", {
  x <- make_test_sf()

  out <- explode_sf(
    x,
    region_col = "region",
    alpha_r = 100,
    alpha_l = 200,
    plot = FALSE
  )

  expect_equal(out$params$alpha_r, 100)
  expect_equal(out$params$alpha_l, 200)
  expect_equal(out$params$p, 1.25)
})

test_that("explode_sf errors on missing grouping column", {
  x <- make_test_sf()

  expect_error(
    explode_sf(x, region_col = "does_not_exist", plot = FALSE),
    "not found"
  )
})

test_that("explode_sf errors on geographic CRS", {
  x <- make_test_sf() |> sf::st_transform(4326)

  expect_error(
    explode_sf(x, region_col = "region", plot = FALSE),
    "Project first"
  )
})

test_that("explode_sf errors when Other is present and not allowed", {
  x <- make_test_sf()
  x$region[1] <- "Other"

  expect_error(
    explode_sf(x, region_col = "region", allow_other = FALSE, plot = FALSE),
    "Other"
  )
})

test_that("explode_sf allows Other when allow_other is TRUE", {
  x <- make_test_sf()
  x$region[1] <- "Other"

  out <- explode_sf(x, region_col = "region", allow_other = TRUE, plot = FALSE)

  expect_s3_class(out, "exploded_map")
})
