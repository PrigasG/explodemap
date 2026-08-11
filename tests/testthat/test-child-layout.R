test_that("layout_children returns projected renderer-neutral base movement", {
  square <- function(x, y, size = 10) {
    sf::st_polygon(list(rbind(
      c(x, y), c(x + size, y), c(x + size, y + size),
      c(x, y + size), c(x, y)
    )))
  }
  x <- sf::st_sf(
    geoid = c("a", "b", "c", "d"),
    geometry = sf::st_sfc(
      square(0, 0), square(8, 0), square(0, 8), square(8, 8),
      crs = 3857
    )
  )

  layout <- layout_children(
    x,
    id_col = "geoid",
    parent = "county-1",
    scale = 1.7,
    radial_kick = 2,
    gap = 1,
    max_bearing_drift = 0.25
  )

  expect_s3_class(layout, "explodemap_child_layout")
  expect_s3_class(child_layout_geometry(layout), "sf")
  expect_identical(child_layout_offsets(layout)$feature_id, x$geoid)
  expect_true(all(c(
    "feature_id", "parent_id", "source_x", "source_y", "target_x",
    "target_y", "base_dx_m", "base_dy_m", "distance_m",
    "bearing_original", "bearing_final", "bearing_drift", "collision_count"
  ) %in% names(layout$offsets)))
  expect_true(all(layout$offsets$bearing_drift <= 0.25 + 1e-8))
  expect_true(all(layout$offsets$distance_m > 0))

  before <- sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(x)))
  after <- sf::st_coordinates(
    sf::st_point_on_surface(sf::st_geometry(child_layout_geometry(layout)))
  )
  expect_equal(after[, 1] - before[, 1], layout$offsets$base_dx_m)
  expect_equal(after[, 2] - before[, 2], layout$offsets$base_dy_m)
})

test_that("layout_children validates stable ids and projected coordinates", {
  x <- sf::st_sf(
    id = c("a", "a"),
    geometry = sf::st_sfc(sf::st_point(c(0, 0)), sf::st_point(c(1, 1)), crs = 3857)
  )
  expect_error(layout_children(x, "id"), "unique")
  x$id <- c("a", "b")
  x <- sf::st_transform(x, 4326)
  expect_error(layout_children(x, "id"), "projected CRS")
})
