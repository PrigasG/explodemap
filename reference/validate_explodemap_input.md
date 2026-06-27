# Validate explodemap input

Validate explodemap input

## Usage

``` r
validate_explodemap_input(
  x,
  group_col,
  id_col = NULL,
  label_col = NULL,
  max_features = Inf,
  max_groups = Inf,
  max_vertices = Inf,
  min_groups = 2L
)
```

## Arguments

- x:

  An `sf` object.

- group_col:

  Grouping column.

- id_col:

  Optional unique feature ID column.

- label_col:

  Optional feature label column.

- max_features, max_groups, max_vertices:

  Optional limits.

- min_groups:

  Minimum number of groups required.

## Value

An `explodemap_validation` object.
