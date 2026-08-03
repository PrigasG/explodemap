test_that("grouped layout geometry accessors expose stable sf objects", {
  x <- make_grouped_sf()
  out <- explode_grouped(x, region_col = "region", mode = "auto", plot = FALSE)

  expect_s3_class(original_geometry(out), "sf")
  expect_s3_class(local_geometry(out), "sf")
  expect_s3_class(final_geometry(out), "sf")
  expect_s3_class(group_geometry(out), "sf")
  expect_s3_class(anchor_table(out), "data.frame")

  expect_equal(nrow(original_geometry(out)), nrow(x))
  expect_equal(nrow(final_geometry(out)), nrow(x))
  expect_equal(nrow(group_geometry(out)), length(unique(x$region)))
})

test_that("layout_offsets reports base movement at group and feature levels", {
  x <- make_grouped_sf()
  x$unit_id <- paste0("unit-", seq_len(nrow(x)))
  out <- explode_grouped(x, region_col = "region", mode = "auto", plot = FALSE)

  group_offsets <- layout_offsets(out, level = "group")
  feature_offsets <- layout_offsets(out, level = "feature", id_col = "unit_id")

  expect_named(group_offsets, c("parent_id", "anchor_x", "anchor_y", "base_dx_m", "base_dy_m"))
  expect_true(all(c(
    "feature_id", "parent_id", "original_anchor_x", "original_anchor_y",
    "final_anchor_x", "final_anchor_y", "base_dx_m", "base_dy_m"
  ) %in% names(feature_offsets)))
  expect_equal(feature_offsets$feature_id, x$unit_id)
  expect_true(any(abs(group_offsets$base_dx_m) > 0 | abs(group_offsets$base_dy_m) > 0))
})

test_that("transition_data and connector_geometry are renderer-neutral", {
  x <- make_grouped_sf()
  out <- explode_grouped(x, region_col = "region", mode = "auto", plot = FALSE)

  movement <- transition_data(out, level = "group")
  lines <- connector_geometry(out, threshold_m = 0, include_unmoved = TRUE)

  expect_true(all(c(
    "feature_id", "parent_id", "distance_m", "angle_degrees", "animation_order"
  ) %in% names(movement)))
  expect_equal(sort(movement$animation_order), seq_len(nrow(movement)))
  expect_s3_class(lines, "sf")
  expect_equal(nrow(lines), nrow(movement))
  expect_true(all(as.character(sf::st_geometry_type(lines)) == "LINESTRING"))
})
