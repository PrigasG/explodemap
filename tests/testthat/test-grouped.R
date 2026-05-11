test_that("explode_grouped returns grouped_exploded_map structure", {
  x <- make_grouped_sf()

  out <- explode_grouped(
    x,
    region_col = "region",
    mode = "auto",
    plot = FALSE
  )

  expect_s3_class(out, "grouped_exploded_map")
  expect_true(all(c(
    "sf_orig", "sf_local", "sf_grouped", "sf_grouped_wgs",
    "stats", "params", "anchors", "plots", "diagnostics"
  ) %in% names(out)))

  expect_s3_class(out$sf_grouped, "sf")
  expect_equal(nrow(out$sf_grouped), nrow(x))
  expect_equal(as.integer(sf::st_crs(out$sf_grouped_wgs)$epsg), 4326)
})

test_that("explode_grouped manual mode uses supplied anchors", {
  x <- make_grouped_sf()

  anchors <- data.frame(
    region = c("R1", "R2", "R3"),
    anchor_x = c(0, 100, 200),
    anchor_y = c(0, 50, 100)
  )

  out <- explode_grouped(
    x,
    region_col = "region",
    mode = "manual",
    anchors = anchors,
    plot = FALSE
  )

  expect_s3_class(out, "grouped_exploded_map")
  expect_equal(nrow(out$anchors), 3)
})

test_that("grouped methods run invisibly", {
  x <- make_grouped_sf()

  out <- explode_grouped(
    x,
    region_col = "region",
    mode = "auto",
    plot = FALSE
  )

  expect_invisible(print(out))
  expect_invisible(plot(out, "grouped"))
  expect_invisible(plot(out, "original"))
  expect_invisible(plot(out, "local"))
  expect_invisible(plot(out, "all"))
})

test_that("explode_grouped accepts visual alias arguments", {
  x <- make_grouped_sf()

  out <- explode_grouped(
    x,
    region_col = "region",
    mode = "auto_collision",
    anchor_expand = 1.2,
    anchor_buffer = 100,
    density_scale = 50,
    block_sep = 75,
    max_iter = 2,
    plot = FALSE,
    quiet = TRUE
  )

  expect_s3_class(out, "grouped_exploded_map")
  expect_equal(out$params$kappa, 1.2)
  expect_equal(out$params$padding, 100)
  expect_equal(out$params$delta, 50)
  expect_equal(out$params$padding_sep, 75)
})
