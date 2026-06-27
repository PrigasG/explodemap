# Prepare input for grouped explodemap layouts

Standardizes common columns (`unit_id`, `unit_name`, and `region`) while
reporting each preparation choice.

## Usage

``` r
prepare_explodemap_input(
  x,
  group_col = NULL,
  id_col = NULL,
  label_col = NULL,
  group_method = c("column", "quadrants", "clusters", "individual"),
  cluster_count = 6L,
  target_crs = NULL,
  make_valid = TRUE,
  target_vertices = NULL,
  seed = 1L
)
```

## Arguments

- x:

  An `sf` polygon object.

- group_col, id_col, label_col:

  Optional source columns.

- group_method:

  Grouping method when `group_col` is not supplied.

- cluster_count:

  Number of clusters for generated cluster groups.

- target_crs:

  CRS for layout work. Use `NULL` to keep the source CRS.

- make_valid:

  Repair geometries with
  [`sf::st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html).

- target_vertices:

  Optional simplification budget.

- seed:

  Seed for generated clusters.

## Value

An `explodemap_prepared_input` object with `data`, `report`, `mapping`,
and `warnings`.
