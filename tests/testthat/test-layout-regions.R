test_that("layout_regions returns anchors for auto mode", {
  x <- make_grouped_sf()

  anchors <- layout_regions(x, region_col = "region", mode = "auto")

  expect_s3_class(anchors, "data.frame")
  expect_true(all(c("region", "anchor_x", "anchor_y", "block_radius", "n_units") %in% names(anchors)))
  expect_equal(nrow(anchors), 3)
})

test_that("layout_regions manual mode requires anchor columns", {
  x <- make_grouped_sf()

  bad_anchors <- data.frame(region = c("R1", "R2", "R3"))

  expect_error(
    layout_regions(x, region_col = "region", mode = "manual", anchors = bad_anchors),
    "anchor_x"
  )
})

test_that("layout_regions manual mode merges supplied anchors", {
  x <- make_grouped_sf()

  anchors_in <- data.frame(
    region = c("R1", "R2", "R3"),
    anchor_x = c(0, 100, 200),
    anchor_y = c(0, 50, 100)
  )

  anchors <- layout_regions(
    x,
    region_col = "region",
    mode = "manual",
    anchors = anchors_in
  )

  expect_equal(anchors$anchor_x, c(0, 100, 200))
  expect_equal(anchors$anchor_y, c(0, 50, 100))
})

test_that("layout_regions manual mode requires anchors for every region", {
  x <- make_grouped_sf()

  anchors_in <- data.frame(
    region = c("R1", "R2"),
    anchor_x = c(0, 100),
    anchor_y = c(0, 50)
  )

  expect_error(
    layout_regions(
      x,
      region_col = "region",
      mode = "manual",
      anchors = anchors_in
    ),
    "Missing manual anchors"
  )
})

test_that("layout_regions collision mode is deterministic for coincident anchors", {
  block_df <- data.frame(
    region = c("R1", "R2"),
    anchor_x = c(0, 0),
    anchor_y = c(0, 0),
    target_x = c(0, 0),
    target_y = c(0, 0),
    block_radius = c(10, 10)
  )

  a <- .refine_anchors(block_df, max_iter = 2)
  b <- .refine_anchors(block_df, max_iter = 2)

  expect_equal(a$anchor_x, b$anchor_x)
  expect_equal(a$anchor_y, b$anchor_y)
})
