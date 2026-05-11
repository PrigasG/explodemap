test_that("focus_map carries named group palettes into widget options", {
  x <- make_test_sf()
  pal <- c(A = "#111111", B = "#222222")

  widget <- focus_map(
    x,
    label_col = "id",
    group_col = "region",
    group_palette = pal,
    simplify = FALSE
  )

  expect_s3_class(widget, "htmlwidget")
  expect_equal(widget$x$options$groupPalette, as.list(pal))
  expect_true(widget$x$options$hasGroups)
})

test_that("focus_map ignores unnamed group palettes with a warning", {
  x <- make_test_sf()

  expect_warning(
    widget <- focus_map(
      x,
      label_col = "id",
      group_col = "region",
      group_palette = c("#111111", "#222222"),
      simplify = FALSE
    ),
    "group_palette must be a named character vector"
  )

  expect_null(widget$x$options$groupPalette)
})

test_that("focus_map accepts partial group palettes", {
  x <- make_test_sf()

  widget <- focus_map(
    x,
    label_col = "id",
    group_col = "region",
    group_palette = c(A = "#111111"),
    simplify = FALSE
  )

  expect_equal(widget$x$options$groupPalette, list(A = "#111111"))
})

test_that("focus_map carries adaptive tiny-feature focus options", {
  x <- make_test_sf()

  widget <- focus_map(
    x,
    label_col = "id",
    simplify = FALSE,
    min_focus_width = 120,
    min_focus_height = 90,
    tiny_feature_threshold = 45,
    tiny_feature_boost = 1.6
  )

  expect_equal(widget$x$options$minFocusWidth, 120)
  expect_equal(widget$x$options$minFocusHeight, 90)
  expect_equal(widget$x$options$tinyFeatureThreshold, 45)
  expect_equal(widget$x$options$tinyFeatureBoost, 1.6)
})

test_that("focus_map validates adaptive tiny-feature focus options", {
  x <- make_test_sf()

  expect_error(
    focus_map(x, label_col = "id", min_focus_width = -1, simplify = FALSE),
    "min_focus_width"
  )
  expect_error(
    focus_map(x, label_col = "id", min_focus_height = -1, simplify = FALSE),
    "min_focus_height"
  )
  expect_error(
    focus_map(x, label_col = "id", tiny_feature_threshold = -1, simplify = FALSE),
    "tiny_feature_threshold"
  )
  expect_error(
    focus_map(x, label_col = "id", tiny_feature_boost = 0.8, simplify = FALSE),
    "tiny_feature_boost"
  )
})

test_that("focus_map carries origin context options", {
  x <- make_test_sf()

  default_widget <- focus_map(x, label_col = "id", simplify = FALSE)
  expect_equal(default_widget$x$options$originContext, "none")

  widget <- focus_map(
    x,
    label_col = "id",
    simplify = FALSE,
    origin_context = "inset",
    origin_context_position = "top-left",
    focus_context_opacity = 0.15
  )

  expect_equal(widget$x$options$originContext, "inset")
  expect_equal(widget$x$options$originContextPosition, "top-left")
  expect_equal(widget$x$options$focusContextOpacity, 0.15)
})

test_that("focus_map carries drag zoom visibility option", {
  x <- make_test_sf()

  default_widget <- focus_map(x, label_col = "id", simplify = FALSE)
  expect_false(default_widget$x$options$showDragZoom)

  widget <- focus_map(
    x,
    label_col = "id",
    simplify = FALSE,
    show_drag_zoom = TRUE
  )

  expect_true(widget$x$options$showDragZoom)
})

test_that("focus_map_preset returns municipal and drilldown options", {
  municipal <- focus_map_preset("municipal")
  expect_equal(municipal$min_focus_width, 260)
  expect_equal(municipal$origin_context, "both")
  expect_true(municipal$show_drag_zoom)

  drilldown <- focus_map_preset("drilldown")
  expect_equal(drilldown$context_mode, "fade")
  expect_false(drilldown$context_clickable)

  combined <- focus_map_preset("municipal_drilldown")
  expect_equal(combined$context_mode, "fade")
  expect_equal(combined$origin_context, "both")
})

test_that("focus_map applies presets without overriding explicit arguments", {
  x <- make_test_sf()

  widget <- focus_map(
    x,
    label_col = "id",
    simplify = FALSE,
    focus_preset = "municipal",
    min_focus_width = 180,
    show_drag_zoom = FALSE
  )

  expect_equal(widget$x$options$focusPreset, "municipal")
  expect_equal(widget$x$options$minFocusWidth, 180)
  expect_false(widget$x$options$showDragZoom)
  expect_equal(widget$x$options$originContext, "both")
  expect_equal(widget$x$options$tinyFeatureBoost, 1.35)
})
