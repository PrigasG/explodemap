test_that("spatial join diagnostics separate unsafe join conditions", {
  x <- data.frame(
    geoid = c("001", "002", "003"),
    name = c("Springfield", "Springfield", "Riverton"),
    county = c("A", "B", "B")
  )
  index <- spatial_join_index(
    x, id_col = "geoid", name_col = "name", parent_col = "county"
  )
  data <- data.frame(
    key = c("001", "002", "404", "002"),
    label = c("Springfield", "Springfield", "Missing", "Springfield"),
    parent = c("wrong", "B", "B", "B")
  )

  report <- validate_spatial_join(
    data, index, key_col = "key", name_col = "label", parent_col = "parent"
  )

  expect_s3_class(index, "spatial_join_index")
  expect_s3_class(report, "spatial_join_validation")
  expect_equal(report$summary$matched, 1L)
  expect_equal(report$summary$unmatched, 1L)
  expect_equal(report$summary$duplicate, 2L)
  expect_equal(report$summary$ambiguous, 3L)
  expect_equal(report$summary$wrong_parent, 1L)
  expect_equal(report$wrong_parent$.expected_parent, "A")
})

test_that("spatial_join_index rejects unstable identifiers", {
  expect_error(
    spatial_join_index(data.frame(id = c("x", "x")), "id"),
    "must be unique"
  )
})
