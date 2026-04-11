test_that("explode_sf returns exploded_map object with expected structure", {
  x <- make_test_sf()

  out <- explode_sf(x, region_col = "region", plot = FALSE)

  expect_s3_class(out, "exploded_map")
  expect_true(all(c(
    "sf_orig", "sf_exp", "sf_exp_wgs", "stats", "params",
    "gamma_r_implied", "gamma_l_implied", "plots", "refinement", "diagnostics"
  ) %in% names(out)))

  expect_s3_class(out$sf_orig, "sf")
  expect_s3_class(out$sf_exp, "sf")
  expect_equal(nrow(out$sf_orig), nrow(out$sf_exp))
  expect_equal(as.integer(sf::st_crs(out$sf_exp_wgs)$epsg), 4326)
  expect_false(out$refinement$enabled)
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

test_that("explode_sf respects partial manual alpha overrides", {
  x <- make_test_sf()

  derived <- derive_params(compute_stats(x, "region"))

  out_r <- explode_sf(
    x,
    region_col = "region",
    alpha_r = 100,
    plot = FALSE
  )
  expect_equal(out_r$params$alpha_r, 100)
  expect_equal(out_r$params$alpha_l, derived$alpha_l)

  out_l <- explode_sf(
    x,
    region_col = "region",
    alpha_l = 200,
    plot = FALSE
  )
  expect_equal(out_l$params$alpha_r, derived$alpha_r)
  expect_equal(out_l$params$alpha_l, 200)
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

test_that("explode_sf collision refinement applies bounded corrections", {
  sq <- function(xmin, ymin, size = 1) {
    sf::st_polygon(list(matrix(
      c(
        xmin, ymin,
        xmin + size, ymin,
        xmin + size, ymin + size,
        xmin, ymin + size,
        xmin, ymin
      ),
      ncol = 2,
      byrow = TRUE
    )))
  }

  x <- sf::st_sf(
    id = c("a1", "a2", "b1", "b2"),
    region = c("A", "A", "B", "B"),
    geometry = sf::st_sfc(
      sq(0, 0),
      sq(1, 0),
      sq(10, 0),
      sq(11, 0),
      crs = 3857
    )
  )

  out <- explode_sf(
    x,
    region_col = "region",
    alpha_r = 0,
    alpha_l = 0,
    refine = TRUE,
    refine_min_gap = 0.5,
    refine_max_shift = 0.2,
    refine_max_iter = 2,
    plot = FALSE
  )

  c0 <- sf::st_coordinates(centroid_geoms(x))
  c1 <- sf::st_coordinates(centroid_geoms(out$sf_exp))
  shift <- sqrt(rowSums((c1 - c0)^2))

  expect_true(out$refinement$enabled)
  expect_gt(out$refinement$corrected_pairs, 0)
  expect_lte(max(shift), 0.2 + 1e-8)
  expect_equal(out$params$refine_within, "region")
})
