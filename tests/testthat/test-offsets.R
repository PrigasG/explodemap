test_that("apply_region_offsets translates raw sf regions", {
  x <- make_test_sf()
  offsets <- data.frame(
    region = c("A", "B"),
    dx_m = c(10, 0),
    dy_m = c(0, 5)
  )

  out <- apply_region_offsets(x, offsets, region_col = "region")

  expect_s3_class(out, "sf")
  expect_equal(attr(out, "display_offsets"), offsets)

  before <- sf::st_coordinates(centroid_geoms(x))
  after <- sf::st_coordinates(centroid_geoms(out))

  expect_equal(after[x$region == "A", "X"], before[x$region == "A", "X"] + 10)
  expect_equal(after[x$region == "A", "Y"], before[x$region == "A", "Y"])
  expect_equal(after[x$region == "B", "X"], before[x$region == "B", "X"])
  expect_equal(after[x$region == "B", "Y"], before[x$region == "B", "Y"] + 5)
})

test_that("apply_region_offsets updates exploded_map outputs", {
  x <- make_test_sf()
  exploded <- explode_sf(x, region_col = "region", plot = FALSE)

  offsets <- data.frame(region = "A", dx_m = 100, dy_m = -50)
  out <- apply_region_offsets(exploded, offsets)

  expect_s3_class(out, "exploded_map")
  expect_equal(out$display_offsets, offsets)
  expect_s3_class(out$sf_exp_wgs, "sf")

  before <- sf::st_coordinates(centroid_geoms(exploded$sf_exp))
  after <- sf::st_coordinates(centroid_geoms(out$sf_exp))

  expect_equal(after[out$sf_exp$region == "A", "X"], before[exploded$sf_exp$region == "A", "X"] + 100)
  expect_equal(after[out$sf_exp$region == "A", "Y"], before[exploded$sf_exp$region == "A", "Y"] - 50)
  expect_equal(after[out$sf_exp$region == "B", ], before[exploded$sf_exp$region == "B", ])
})

test_that("apply_region_offsets updates grouped_exploded_map outputs", {
  x <- make_grouped_sf()
  grouped <- explode_grouped(
    x,
    region_col = "region",
    alpha_l = 100,
    mode = "auto",
    plot = FALSE
  )

  offsets <- data.frame(region = "R2", dx_m = -25, dy_m = 40)
  out <- apply_region_offsets(grouped, offsets)

  expect_s3_class(out, "grouped_exploded_map")
  expect_equal(out$display_offsets, offsets)
  expect_s3_class(out$sf_grouped_wgs, "sf")

  before <- sf::st_coordinates(centroid_geoms(grouped$sf_grouped))
  after <- sf::st_coordinates(centroid_geoms(out$sf_grouped))

  expect_equal(after[out$sf_grouped$region == "R2", "X"], before[grouped$sf_grouped$region == "R2", "X"] - 25)
  expect_equal(after[out$sf_grouped$region == "R2", "Y"], before[grouped$sf_grouped$region == "R2", "Y"] + 40)
})
