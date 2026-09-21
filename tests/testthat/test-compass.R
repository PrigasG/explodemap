test_that(".compass_dir maps the eight winds counter-clockwise from East", {
  expect_equal(.compass_dir(1, 0), "East")
  expect_equal(.compass_dir(1, 1), "Northeast")
  expect_equal(.compass_dir(0, 1), "North")
  expect_equal(.compass_dir(-1, 1), "Northwest")
  expect_equal(.compass_dir(-1, 0), "West")
  expect_equal(.compass_dir(-1, -1), "Southwest")
  expect_equal(.compass_dir(0, -1), "South")
  expect_equal(.compass_dir(1, -1), "Southeast")
})


test_that(".attach_regions_county rejects counties assigned to multiple regions", {
  x <- make_test_sf()
  x$NAME <- c("Alpha", "Beta", "Gamma", "Delta")

  region_map <- list(
    North = c("Alpha", "Beta"),
    South = c("Beta", "Gamma")
  )

  expect_error(
    .attach_regions_county(x, region_map = region_map),
    "multiple regions"
  )
})


test_that(".attach_regions_county assigns disjoint named mappings", {
  x <- make_test_sf()
  x$NAME <- c("Alpha", "Beta", "Gamma", "Delta")

  region_map <- list(
    North = c("Alpha", "Beta"),
    South = c("Gamma", "Delta")
  )

  out <- .attach_regions_county(x, region_map = region_map, quiet = TRUE)

  expect_equal(as.character(out$region), c("North", "North", "South", "South"))
})
