test_that("export_topojson errors clearly when mapshaper is missing", {
  skip_if(nzchar(Sys.which("mapshaper")), "mapshaper is installed")

  x <- make_test_sf()

  expect_error(
    export_topojson(x, tempfile(fileext = ".topojson")),
    "mapshaper"
  )
})


test_that("export_topojson validates simplify", {
  x <- make_test_sf()

  expect_error(
    .build_mapshaper_args("in.geojson", "out.topojson", simplify = 0),
    "between 0 and 1"
  )

  expect_error(
    .build_mapshaper_args("in.geojson", "out.topojson", simplify = 1),
    "between 0 and 1"
  )
})
