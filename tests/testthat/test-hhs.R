test_that("HHS metadata helpers return keyed region data", {
  regions <- hhs_regions()

  expect_true(all(c("state_name", "STUSPS", "hhs_region", "hhs_region_name") %in% names(regions)))
  expect_equal(nrow(regions), 56)
  expect_equal(regions$hhs_region[regions$STUSPS == "TX"], "6")
  expect_equal(hhs_region_names()[["6"]], "6 - Dallas")
  expect_equal(hhs_region_names(short = TRUE)[["6"]], "HHS 6")
  expect_equal(names(hhs_palette()), as.character(1:10))
  expect_equal(names(hhs_display_offsets()), c("region", "dx_m", "dy_m"))
})

test_that("as_hhs_states adds HHS fields from STUSPS", {
  states <- make_hhs_state_sf()

  out <- as_hhs_states(states)

  expect_s3_class(out, "sf")
  expect_equal(out$hhs_region, c("1", "6"))
  expect_equal(out$state_label, c("Maine", "Texas"))
  expect_equal(out$state_geoid, c("23", "48"))
})

test_that("hhs_layout applies documented offsets", {
  states <- make_hhs_state_sf()

  plain <- hhs_layout(states, apply_offsets = FALSE)
  shifted <- hhs_layout(states, apply_offsets = TRUE)

  expect_equal(nrow(plain$states), 2)
  expect_equal(nrow(shifted$labels), 2)
  expect_false(identical(sf::st_bbox(plain$states), sf::st_bbox(shifted$states)))
})

test_that("hhs_focus_map returns a grouped focus widget", {
  states <- make_hhs_state_sf()

  widget <- hhs_focus_map(states, apply_offsets = FALSE, width = "100%", height = "400px")

  expect_s3_class(widget, "htmlwidget")
  expect_equal(widget$x$options$groupPalette, as.list(hhs_palette()))
  expect_true(widget$x$options$showGroupLabels)
  expect_equal(widget$x$options$groupLabels[["1"]], "HHS 1")
  expect_equal(widget$x$options$coordinateSystem, "planar")
})
