test_that("as_sf returns displaced geometries for exploded_map", {
  x <- make_test_sf()
  layout <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)

  out <- as_sf(layout)
  expect_s3_class(out, "sf")
  expect_equal(nrow(out), nrow(x))
  expect_equal(sf::st_crs(out), sf::st_crs(layout$sf_exp))
  expect_true(all(names(x) %in% names(out)))
  # displaced layer differs from the input geometries
  expect_false(isTRUE(all.equal(
    sf::st_geometry(out), sf::st_geometry(x),
    check.attributes = FALSE
  )))
})

test_that("as_sf(which = 'original') returns the input geometries", {
  x <- make_test_sf()
  layout <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)

  orig <- as_sf(layout, which = "original")
  expect_s3_class(orig, "sf")
  expect_true(isTRUE(all.equal(
    sf::st_geometry(orig), sf::st_geometry(x),
    check.attributes = FALSE
  )))
})

test_that("as_sf handles grouped layouts", {
  x <- make_grouped_sf()
  layout <- explode_grouped(x, region_col = "region", plot = FALSE, quiet = TRUE)

  grouped <- as_sf(layout, which = "grouped")
  expect_s3_class(grouped, "sf")
  expect_equal(nrow(grouped), nrow(x))

  # Untouched default resolves to the displaced "grouped" layer
  defaulted <- as_sf(layout)
  expect_true(isTRUE(all.equal(
    sf::st_geometry(defaulted), sf::st_geometry(grouped),
    check.attributes = FALSE
  )))

  local <- as_sf(layout, which = "local")
  expect_s3_class(local, "sf")

  orig <- as_sf(layout, which = "original")
  expect_true(isTRUE(all.equal(
    sf::st_geometry(orig), sf::st_geometry(x),
    check.attributes = FALSE
  )))
})

test_that("as_sf validates its inputs", {
  x <- make_test_sf()
  layout <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)

  expect_error(as_sf(x), "exploded_map")
  expect_error(as_sf(layout, which = "grouped"), "match.arg|should be one of")
  grouped <- explode_grouped(
    make_grouped_sf(), region_col = "region", plot = FALSE, quiet = TRUE
  )
  expect_error(as_sf(grouped, which = "exploded"), "match.arg|should be one of")
})

test_that("explodemap_units reports CRS units", {
  x <- make_test_sf()
  expect_equal(explodemap_units(x), "m")

  layout <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)
  expect_equal(explodemap_units(layout), "m")

  grouped <- explode_grouped(
    make_grouped_sf(), region_col = "region", plot = FALSE, quiet = TRUE
  )
  expect_equal(explodemap_units(grouped), "m")

  no_crs <- sf::st_set_crs(x, NA)
  expect_equal(explodemap_units(no_crs), NA_character_)

  expect_error(explodemap_units(data.frame(a = 1)), "must be an")
})

test_that("displacement_magnitudes is deterministic and zero without displacement", {
  x <- make_test_sf()
  still <- explode_sf(
    x, region_col = "region", alpha_r = 0, alpha_l = 0,
    plot = FALSE, quiet = TRUE
  )
  d <- displacement_magnitudes(still)
  expect_equal(nrow(d), nrow(x))
  expect_named(d, c("dx", "dy", "distance"))
  expect_true(all(d$distance == 0))

  layout <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)
  d2 <- displacement_magnitudes(layout)
  expect_true(all(d2$distance >= 0))
  expect_equal(
    d2$distance,
    sqrt(d2$dx^2 + d2$dy^2)
  )
  # deterministic across identical runs
  layout2 <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)
  expect_equal(displacement_magnitudes(layout2), d2)
})

test_that("compare_layouts summarises displacement changes", {
  x <- make_test_sf()
  small <- explode_sf(
    x, region_col = "region", alpha_r = 10, alpha_l = 10,
    plot = FALSE, quiet = TRUE
  )
  big <- explode_sf(
    x, region_col = "region", alpha_r = 100, alpha_l = 100,
    plot = FALSE, quiet = TRUE
  )
  cmp <- compare_layouts(small, big)

  expect_named(cmp, c("per_feature", "summary"))
  expect_equal(nrow(cmp$per_feature), nrow(x))
  expect_equal(
    cmp$per_feature$delta,
    cmp$per_feature$distance_after - cmp$per_feature$distance_before
  )
  expect_equal(cmp$summary$layout, c("before", "after"))
  expect_gt(cmp$summary$total[2], cmp$summary$total[1])
})

test_that("compare_layouts validates its inputs", {
  x <- make_test_sf()
  a <- explode_sf(x, region_col = "region", plot = FALSE, quiet = TRUE)
  g <- explode_grouped(
    make_grouped_sf(), region_col = "region", plot = FALSE, quiet = TRUE
  )
  expect_error(compare_layouts(a, g), "both be")
  expect_error(compare_layouts(x, a), "both be")
})
