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


test_that("export_topojson removes stale output and reports mapshaper failure", {
  x <- make_test_sf()

  # Fake a failing mapshaper on PATH
  fake_bin <- tempfile("fakebin")
  dir.create(fake_bin)
  on_windows <- .Platform$OS.type == "windows"
  script <- file.path(fake_bin, if (on_windows) "mapshaper.bat" else "mapshaper")
  if (on_windows) {
    writeLines(c("@echo off", "echo mapshaper boom 1>&2", "exit /b 1"), script)
  } else {
    writeLines(c("#!/bin/sh", "echo 'mapshaper boom' >&2", "exit 1"), script)
    Sys.chmod(script, "755")
  }

  old_path <- Sys.getenv("PATH")
  Sys.setenv(PATH = paste(fake_bin, old_path, sep = .Platform$path.sep))
  on.exit(Sys.setenv(PATH = old_path), add = TRUE)

  out <- tempfile(fileext = ".topojson")
  writeLines("stale", out)

  expect_error(
    export_topojson(x, out, overwrite = TRUE),
    "exited with status 1"
  )
  # The stale file must be gone: a failed run must not masquerade as success
  expect_false(file.exists(out))
})
