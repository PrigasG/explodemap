make_test_sf <- function() {
  sq <- function(xmin, ymin, size = 1) {
    sf::st_polygon(list(matrix(
      c(
        xmin, ymin,
        xmin + size, ymin,
        xmin + size, ymin + size,
        xmin, ymin + size,
        xmin, ymin
      ),
      ncol = 2,
      byrow = TRUE
    )))
  }

  geom <- sf::st_sfc(
    sq(0, 0),   # A1
    sq(2, 0),   # A2
    sq(10, 0),  # B1
    sq(12, 0),  # B2
    crs = 3857
  )

  sf::st_sf(
    id = c("a1", "a2", "b1", "b2"),
    region = c("A", "A", "B", "B"),
    geometry = geom
  )
}

make_test_lookup <- function() {
  data.frame(
    id = c("a1", "a2", "b1"),
    region2 = c("North", "North", "South"),
    stringsAsFactors = FALSE
  )
}

make_grouped_sf <- function() {
  sq <- function(xmin, ymin, size = 1) {
    sf::st_polygon(list(matrix(
      c(
        xmin, ymin,
        xmin + size, ymin,
        xmin + size, ymin + size,
        xmin, ymin + size,
        xmin, ymin
      ),
      ncol = 2,
      byrow = TRUE
    )))
  }

  geom <- sf::st_sfc(
    sq(0, 0),
    sq(2, 0),
    sq(6, 0),
    sq(8, 0),
    sq(20, 0),
    sq(22, 0),
    crs = 3857
  )

  sf::st_sf(
    id = paste0("u", 1:6),
    region = c("R1", "R1", "R2", "R2", "R3", "R3"),
    geometry = geom
  )
}
