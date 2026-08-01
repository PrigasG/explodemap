test_that("diagnose_layout reports grouped layout metrics", {
  x <- make_grouped_sf()
  out <- explode_grouped(x, region_col = "region", mode = "auto", plot = FALSE)

  report <- diagnose_layout(out, label_col = "id")

  expect_s3_class(report, "layout_quality_report")
  expect_true(all(c(
    "polygon_overlap_area", "overlapping_pairs", "minimum_group_gap",
    "mean_displacement", "maximum_displacement", "label_overlap_count",
    "canvas_utilization", "aspect_ratio", "mental_map_stability",
    "polygon_overlap_fraction", "mean_displacement_fraction",
    "label_overlap_fraction"
  ) %in% names(report)))
  expect_true(is.numeric(report$polygon_overlap_area))
  expect_true(is.data.frame(report$overlapping_pairs))
  expect_true(all(c(
    report$polygon_overlap_fraction,
    report$mean_displacement_fraction,
    report$label_overlap_fraction
  ) >= 0))
})

test_that("layout score uses dimensionless report terms", {
  report_a <- list(
    polygon_overlap_fraction = 0.1,
    mean_displacement_fraction = 0.2,
    canvas_utilization = 0.7,
    label_overlap_fraction = 0.05,
    polygon_overlap_area = 1e8,
    mean_displacement = 1e4,
    label_overlap_count = 10L
  )
  report_b <- report_a
  report_b$polygon_overlap_area <- 1e12
  report_b$mean_displacement <- 1e7
  report_b$label_overlap_count <- 1000L

  expect_equal(
    .score_layout_report(report_a, layout_objective()),
    .score_layout_report(report_b, layout_objective())
  )
})

test_that("label overlap scoring excludes missing labels", {
  x <- make_grouped_sf()
  x$id <- c("A", NA_character_, "界", rep(NA_character_, nrow(x) - 3L))
  count <- .label_overlap_count(x, "id", label_size = 1e6)

  expect_equal(count, 1L)
})

test_that("plot.layout_quality_report builds a ggplot", {
  x <- make_grouped_sf()
  out <- explode_grouped(x, region_col = "region", mode = "auto", plot = FALSE)
  report <- diagnose_layout(out, label_col = "id")

  p <- plot(report)
  expect_s3_class(p, "ggplot")
  # The plot must build (exercises the rect/circle/segment/point/text layers).
  expect_s3_class(ggplot2::ggplot_build(p), "ggplot_built")
})

test_that("optimize_grouped_layout is label-aware only when label_col is given", {
  x <- make_grouped_sf()
  grid <- data.frame(kappa = 1.6, padding = 20, delta = 5, padding_sep = 10)

  plain <- optimize_grouped_layout(x, region_col = "region", grid = grid, max_iter = 2)
  labelled <- optimize_grouped_layout(
    x, region_col = "region", grid = grid, max_iter = 2,
    label_col = "id"
  )

  # Without a label column, label overlaps are not scored (count stays 0).
  expect_equal(plain$optimization$best_report$label_overlap_count, 0L)
  # With a label column, the count is computed (and feeds the score).
  expect_true(is.numeric(labelled$optimization$best_report$label_overlap_count))
  input_bbox <- sf::st_bbox(x)
  expected_size <- max(
    as.numeric(input_bbox["xmax"] - input_bbox["xmin"]),
    as.numeric(input_bbox["ymax"] - input_bbox["ymin"])
  ) * 0.025
  expect_equal(labelled$optimization$label_size, expected_size)
})

test_that("optimize_grouped_layout returns best grouped layout with metadata", {
  x <- make_grouped_sf()
  grid <- data.frame(
    kappa = c(1.2, 1.6),
    padding = c(10, 20),
    delta = c(5, 5),
    padding_sep = c(5, 10)
  )

  out <- optimize_grouped_layout(
    x,
    region_col = "region",
    grid = grid,
    max_iter = 2
  )

  expect_s3_class(out, "grouped_exploded_map")
  expect_equal(length(out$optimization$scores), nrow(grid))
  expect_true(out$optimization$best_index %in% seq_len(nrow(grid)))
})

test_that("drag handoff and update_exploded_layout preserve grouped object", {
  x <- make_grouped_sf()
  out <- explode_grouped(x, region_col = "region", mode = "auto", plot = FALSE)
  drag <- as_dragmapr(out)

  expect_s3_class(drag, "dragmapr_layout")
  anchors <- drag$region_offsets
  anchors$anchor_x <- anchors$anchor_x + 10

  updated <- update_exploded_layout(out, anchors)
  expect_s3_class(updated, "grouped_exploded_map")
  expect_equal(updated$anchors$anchor_x, anchors$anchor_x)
})

test_that("dragmapr_state handoff round-trips through grouped layout", {
  skip_if_not_installed("dragmapr")
  skip_if_not("dragmapr_state" %in% getNamespaceExports("dragmapr"))
  x <- make_grouped_sf()
  out <- explode_grouped(x, region_col = "region", mode = "auto", plot = FALSE)

  state <- as_dragmapr_state(out, geometry_id = "test-layout")
  expect_s3_class(state, "dragmapr_state")
  expect_equal(state$geometry_id, "test-layout")
  expect_equal(names(state$region_offsets), c("region", "dx_m", "dy_m"))

  state$region_offsets$dx_m[state$region_offsets$region == "R2"] <- 20
  updated <- update_exploded_layout(out, state)

  expect_s3_class(updated, "grouped_exploded_map")
  expect_equal(updated$label_offsets, state$label_offsets)
  expect_equal(
    updated$anchors$anchor_x[updated$anchors$region == "R2"],
    out$anchors$anchor_x[out$anchors$region == "R2"] + 20
  )
  expect_false(identical(sf::st_bbox(updated$sf_grouped), sf::st_bbox(out$sf_grouped)))
})

test_that("explode_grouped can preserve initial manual anchors", {
  x <- make_grouped_sf()
  out <- explode_grouped(x, region_col = "region", mode = "auto", plot = FALSE)
  anchors <- out$anchors
  anchors$anchor_y <- anchors$anchor_y + 25

  updated <- explode_grouped(
    x,
    region_col = "region",
    mode = "auto",
    initial_layout = anchors,
    preserve_manual = TRUE,
    plot = FALSE
  )

  expect_equal(updated$anchors$anchor_y, anchors$anchor_y)
})
