test_that("count_geometry_vertices counts polygon coordinate rows", {
  x <- make_grouped_sf()
  expect_gt(count_geometry_vertices(x), nrow(x))

  empty <- x[0, ]
  expect_equal(count_geometry_vertices(empty), 0L)
})

test_that("group_palette preserves existing assignments", {
  pal <- group_palette(c("B", "A"))
  expect_named(pal, c("A", "B"))

  updated <- group_palette(c("A", "B", "C"), existing = c(A = "#010203"))
  expect_equal(updated[["A"]], "#010203")
  expect_named(updated, c("A", "B", "C"))

  generated <- grDevices::hcl.colors(3, palette = "Dark 3")
  collision_safe <- group_palette(c("A", "B", "C"), existing = c(A = generated[[2]]))
  expect_equal(ncol(unique(grDevices::col2rgb(collision_safe, alpha = TRUE), MARGIN = 2)), 3L)
})

test_that("assign_spatial_groups is deterministic", {
  x <- make_grouped_sf()
  q <- assign_spatial_groups(x, method = "quadrants")
  expect_true("region" %in% names(q))
  expect_lte(length(unique(q$region)), 4)

  a <- assign_spatial_groups(x, method = "clusters", groups = 3, seed = 42)
  b <- assign_spatial_groups(x, method = "clusters", groups = 3, seed = 42)
  expect_equal(a$region, b$region)
})

test_that("assign_spatial_groups does not create RNG state in a fresh session", {
  x <- make_grouped_sf()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = .GlobalEnv) else NULL
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  seed_exists_after <- local({
    if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
    assign_spatial_groups(x, method = "clusters", groups = 3, seed = 42)
    exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  })
  expect_false(seed_exists_after)
})

test_that("validate_explodemap_input returns structured metrics", {
  x <- make_grouped_sf()
  x$unit_id <- paste0("id", seq_len(nrow(x)))
  check <- validate_explodemap_input(x, "region", id_col = "unit_id", label_col = "id")

  expect_s3_class(check, "explodemap_validation")
  expect_true(check$valid)
  expect_equal(check$metrics$features, nrow(x))
  expect_gt(check$metrics$vertices, 0)

  bad <- x
  bad$unit_id[2] <- bad$unit_id[1]
  check_bad <- validate_explodemap_input(bad, "region", id_col = "unit_id")
  expect_false(check_bad$valid)
  expect_true(any(grepl("unique", check_bad$errors)))
  expect_true(length(check_bad$suggestions) > 0L)

  empty <- x[0, ]
  check_empty <- validate_explodemap_input(empty, "region", min_groups = 0L)
  expect_false(check_empty$valid)
  expect_true(any(grepl("at least one feature", check_empty$errors)))
})

test_that("simplify_to_vertex_budget preserves rows and polygon geometry", {
  x <- make_grouped_sf()
  result <- simplify_to_vertex_budget(x, target_vertices = 4)

  expect_s3_class(result, "explodemap_simplification")
  expect_equal(nrow(result$data), nrow(x))
  expect_false(any(sf::st_is_empty(result$data)))
  expect_true(all(grepl("POLYGON", as.character(sf::st_geometry_type(result$data, by_geometry = TRUE)))))
  expect_lte(result$after, result$before)
  expect_lte(result$attempts, 4L)
})

test_that("prepare_explodemap_input standardizes columns transparently", {
  x <- make_grouped_sf()
  prepared <- prepare_explodemap_input(
    x,
    id_col = "id",
    label_col = "id",
    group_col = "region",
    target_crs = 3857
  )

  expect_s3_class(prepared, "explodemap_prepared_input")
  expect_true(all(c("unit_id", "unit_name", "region") %in% names(prepared$data)))
  expect_equal(as.character(prepared$data$unit_id), as.character(x$id))
  expect_true(prepared$report$validation$valid)
})

test_that("prepare_explodemap_input preserves standard-column collisions", {
  x <- make_grouped_sf()
  x$unit_id <- paste0("old-id-", seq_len(nrow(x)))
  x$unit_name <- paste0("old-name-", seq_len(nrow(x)))
  x$division <- x$region
  x$region <- paste0("old-region-", seq_len(nrow(x)))

  prepared <- prepare_explodemap_input(
    x,
    id_col = "id",
    label_col = "id",
    group_col = "division"
  )

  expect_equal(prepared$data$unit_id_source, x$unit_id)
  expect_equal(prepared$data$unit_name_source, x$unit_name)
  expect_equal(prepared$data$region_source, x$region)
  expect_equal(prepared$data$region, x$division)
  expect_equal(nrow(prepared$report$column_collisions), 3L)
  expect_equal(prepared$format_version, 2L)
})

test_that("prepared input print surfaces invalid validation", {
  x <- make_grouped_sf()
  x$id[[2]] <- x$id[[1]]
  prepared <- prepare_explodemap_input(x, id_col = "id", label_col = "id", group_col = "region")
  output <- capture.output(print(prepared))

  expect_true(any(grepl("Status:.*invalid", output)))
  expect_true(any(grepl("Errors:", output, fixed = TRUE)))
})

test_that("explodemap_fingerprint changes when grouping changes", {
  x <- make_grouped_sf()
  x$unit_id <- paste0("id", seq_len(nrow(x)))
  fp1 <- explodemap_fingerprint(x, id_col = "unit_id", group_col = "region")
  x$region[1] <- paste0(x$region[1], "-changed")
  fp2 <- explodemap_fingerprint(x, id_col = "unit_id", group_col = "region")

  expect_type(fp1, "character")
  expect_false(identical(fp1, fp2))
})

test_that("explodemap_fingerprint uses consistent fallback ID types", {
  x <- make_grouped_sf()
  x$row_id <- as.character(seq_len(nrow(x)))

  expect_equal(
    explodemap_fingerprint(x),
    explodemap_fingerprint(x, id_col = "row_id")
  )
})
