test_that("explode_section explodes selected section and keeps context", {
  x <- make_test_sf()
  x$subregion <- x$id

  out <- explode_section(
    x,
    section_col = "region",
    section = "A",
    region_col = "subregion",
    alpha_r = 10,
    alpha_l = 5,
    plot = FALSE,
    quiet = TRUE
  )

  expect_s3_class(out, "exploded_map")
  expect_equal(nrow(out$sf_exp), nrow(x))
  expect_equal(sum(out$sf_exp$.explodemap_role == "focus"), 2)
  expect_equal(sum(out$sf_exp$.explodemap_role == "context"), 2)
  expect_equal(out$diagnostics$n_focus, 2)
  expect_equal(out$diagnostics$n_context, 2)
})

test_that("explode_section can drop context", {
  x <- make_test_sf()
  x$subregion <- x$id

  out <- explode_section(
    x,
    section_col = "region",
    section = "A",
    region_col = "subregion",
    context = "none",
    alpha_r = 10,
    alpha_l = 5,
    plot = FALSE,
    quiet = TRUE
  )

  expect_equal(nrow(out$sf_exp), 2)
  expect_true(all(out$sf_exp$.explodemap_role == "focus"))
})

test_that("focus_map carries context options into widget payload", {
  x <- make_test_sf()
  x$.explodemap_role <- c("focus", "focus", "context", "context")

  widget <- focus_map(
    x,
    label_col = "id",
    context_col = ".explodemap_role",
    context_mode = "fade",
    context_opacity = 0.2,
    simplify = FALSE
  )

  expect_equal(widget$x$options$contextMode, "fade")
  expect_equal(widget$x$options$contextValues, list("context"))
  expect_equal(widget$x$options$contextOpacity, 0.2)
  expect_match(widget$x$geojson_str, '"context"')
})
