test_that("validate_input rejects missing or empty group values", {
  x <- make_test_sf()

  x_na <- x
  x_na$region[1] <- NA
  expect_error(validate_input(x_na, "region"), "missing or empty")

  x_empty <- x
  x_empty$region[1] <- ""
  expect_error(validate_input(x_empty, "region"), "missing or empty")

  x_blank <- x
  x_blank$region[1] <- "   "
  expect_error(validate_input(x_blank, "region"), "missing or empty")
})


test_that("validate_input warns on non-metre projected units", {
  x <- make_test_sf()
  expect_no_warning(validate_input(x, "region"))

  # NAD83 / Texas South Central (ftUS): projected, but not metre-based
  x_ft <- sf::st_set_crs(x, 2272)
  expect_warning(validate_input(x_ft, "region"), "instead of metres")
})


test_that("explode_sf works with a non-'geometry' geometry column", {
  x <- make_test_sf()
  names(x)[names(x) == "geometry"] <- "geom"
  sf::st_geometry(x) <- "geom"

  out <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)

  expect_s3_class(out, "exploded_map")
  expect_true("geom" %in% names(out$sf_exp))
  expect_false("geometry" %in% names(out$sf_exp))
  expect_equal(attr(out$sf_exp, "sf_column"), "geom")
  expect_equal(nrow(out$sf_exp), nrow(x))
})


test_that("explode_sf 'Other' detection is NA-safe", {
  x <- make_test_sf()
  x$region[1] <- NA

  expect_error(explode_sf(x, region_col = "region", plot = FALSE), "missing or empty")
})
