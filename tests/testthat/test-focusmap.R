fake_proxy_session <- function() {
  env <- new.env()
  env$sent <- list()
  session <- list(
    sendCustomMessage = function(type, message) {
      env$sent[[length(env$sent) + 1L]] <- list(type = type, message = message)
    }
  )
  list(session = session, env = env)
}

test_that("focusMapProxy validates its inputs", {
  skip_if_not_installed("shiny")
  expect_error(update_focus_labels(list(), show = FALSE), "focusMapProxy")

  fake <- fake_proxy_session()
  proxy <- focusMapProxy("map", session = fake$session)
  expect_s3_class(proxy, "focusmap_proxy")
  expect_equal(proxy$id, "map")
})

test_that("focus-map proxy ops send the right messages", {
  skip_if_not_installed("shiny")
  fake <- fake_proxy_session()
  proxy <- focusMapProxy("map", session = fake$session)

  update_focus_labels(proxy, show = FALSE)
  update_focus_palette(proxy, c(A = "#111111", B = "#222222"))
  update_focus_data(proxy, make_test_sf(), label_col = "id", group_col = "region",
                    simplify = FALSE)

  sent <- fake$env$sent
  expect_length(sent, 3)
  expect_true(all(vapply(sent, function(s) s$type, "") == "explodemap-focusmap-proxy"))
  expect_true(all(vapply(sent, function(s) s$message$id, "") == "map"))

  labels_msg <- sent[[1]]$message
  expect_equal(labels_msg$method, "updateFocusLabels")
  expect_false(labels_msg$value$show)

  # Regression: the palette must keep its names so the browser can key
  # groupPalette by group (a bare array would silently drop custom colours).
  palette_msg <- sent[[2]]$message
  expect_equal(palette_msg$method, "updateFocusPalette")
  expect_equal(palette_msg$value$A, "#111111")
  expect_equal(palette_msg$value$B, "#222222")

  data_msg <- sent[[3]]$message
  expect_equal(data_msg$method, "updateFocusData")
  expect_true(is.list(data_msg$value$options))
  expect_type(data_msg$value$geojson_str, "character")
})

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

test_that("focus_map TRUE simplification stays conservative for dense layers", {
  skip_if_not_installed("jsonlite")

  wavy_poly <- function(x0) {
    xs <- seq(0, 0.08, length.out = 40)
    top <- cbind(x0 + xs, 0.02 + sin(seq(0, 4 * pi, length.out = 40)) * 0.004)
    bottom <- cbind(x0 + rev(xs), rep(0, length(xs)))
    sf::st_polygon(list(rbind(top, bottom, top[1, ])))
  }

  x <- sf::st_sf(
    id = seq_len(520),
    geometry = sf::st_sfc(lapply(seq_len(520), function(i) wavy_poly(i * 0.1)), crs = 4326)
  )

  widget <- focus_map(x, label_col = "id", simplify = TRUE)
  geo <- jsonlite::fromJSON(widget$x$geojson_str, simplifyVector = FALSE)

  count_points <- function(coords) {
    count <- 0L
    walk <- function(z) {
      if (is.list(z) && length(z) && is.numeric(z[[1]])) {
        count <<- count + 1L
      } else if (is.list(z)) {
        for (item in z) walk(item)
      }
    }
    walk(coords)
    count
  }

  first_count <- count_points(geo$features[[1]]$geometry$coordinates)
  expect_gt(first_count, 40)
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

test_that("focus_map restore_selection carries a stable id_col selection", {
  skip_if_not_installed("dragmapr")
  x <- make_test_sf()

  # selected_feature is a stable id ("b1") that is NOT a label or group value,
  # so it can only resolve through properties.id (the id_col path).
  state <- dragmapr::dragmapr_state(
    region_offsets = data.frame(region = c("A", "B"), dx_m = 0, dy_m = 0),
    selected_feature = "b1"
  )

  widget <- focus_map(
    x,
    label_col = "region",
    id_col = "id",
    group_col = "region",
    state = state,
    restore_selection = TRUE,
    simplify = FALSE
  )

  # R plumbing: the selection reaches the widget payload.
  expect_equal(widget$x$options$initialFocus, "b1")
  # The id_col value is stored as properties.id, so the JS match (which now
  # includes p.id) can resolve it. "b1" is unique to the id property here.
  expect_match(widget$x$geojson_str, "b1", fixed = TRUE)

  # Default (opt-out) carries no initial focus.
  plain <- focus_map(
    x,
    label_col = "region",
    id_col = "id",
    group_col = "region",
    state = state,
    simplify = FALSE
  )
  expect_null(plain$x$options$initialFocus)
})

test_that("focus_map carries named group labels into widget options", {
  x <- make_test_sf()
  labels <- c(A = "Region A", B = "Region B")

  widget <- focus_map(
    x,
    label_col = "id",
    group_col = "region",
    group_labels = labels,
    show_group_labels = TRUE,
    simplify = FALSE
  )

  expect_true(widget$x$options$showGroupLabels)
  expect_equal(widget$x$options$groupLabels, as.list(labels))
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

test_that("focus_map carries planar coordinate-system option", {
  x <- sf::st_transform(make_test_sf(), 3857)

  widget <- focus_map(
    x,
    label_col = "id",
    coordinate_system = "planar",
    simplify = FALSE
  )

  expect_s3_class(widget, "htmlwidget")
  expect_equal(widget$x$options$coordinateSystem, "planar")
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

test_that("focusMapProxy validates palette names", {
  fake_session <- new.env(parent = emptyenv())
  fake_session$sendCustomMessage <- function(type, message) invisible(NULL)
  proxy <- focusMapProxy("map", session = fake_session)

  expect_s3_class(proxy, "focusmap_proxy")
  expect_error(update_focus_palette(proxy, c("#111111")), "named character vector")
  expect_invisible(update_focus_labels(proxy, show = FALSE))
})

test_that("focus_map accepts dragmapr_state for grouped layouts", {
  skip_if_not_installed("dragmapr")
  skip_if_not("dragmapr_state" %in% getNamespaceExports("dragmapr"))
  x <- make_grouped_sf()
  layout <- explode_grouped(x, region_col = "region", mode = "auto", plot = FALSE)
  state <- as_dragmapr_state(layout)
  state$region_offsets$dx_m[state$region_offsets$region == "R2"] <- 20

  widget <- focus_map(
    layout,
    label_col = "id",
    group_col = "region",
    state = state,
    simplify = FALSE
  )

  expect_s3_class(widget, "htmlwidget")
})
