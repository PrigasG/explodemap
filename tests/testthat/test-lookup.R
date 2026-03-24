test_that("explode_sf_with_lookup joins lookup and labels unmatched as Other", {
  x <- make_test_sf()
  lookup <- make_test_lookup()

  out <- explode_sf_with_lookup(
    x,
    join_col = "id",
    lookup = lookup,
    lookup_key = "id",
    region_col = "region2",
    allow_other = TRUE,
    plot = FALSE
  )

  expect_s3_class(out, "exploded_map")
  expect_true("region2" %in% names(out$sf_orig))
  expect_true("Other" %in% out$sf_orig$region2)
})

test_that("explode_sf_with_lookup errors on bad join column", {
  x <- make_test_sf()
  lookup <- make_test_lookup()

  expect_error(
    explode_sf_with_lookup(
      x,
      join_col = "bad_col",
      lookup = lookup,
      lookup_key = "id",
      region_col = "region2",
      plot = FALSE
    ),
    "join_col"
  )
})

test_that("explode_sf_with_lookup errors on bad lookup key", {
  x <- make_test_sf()
  lookup <- make_test_lookup()

  expect_error(
    explode_sf_with_lookup(
      x,
      join_col = "id",
      lookup = lookup,
      lookup_key = "bad_key",
      region_col = "region2",
      plot = FALSE
    ),
    "lookup_key"
  )
})
