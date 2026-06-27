# Assign generated spatial groups

Assign generated spatial groups

## Usage

``` r
assign_spatial_groups(
  x,
  method = c("quadrants", "clusters", "individual"),
  groups = 6L,
  seed = 1L,
  group_col = "region"
)
```

## Arguments

- x:

  An `sf` object.

- method:

  One of `"quadrants"`, `"clusters"`, or `"individual"`.

- groups:

  Number of clusters for `method = "clusters"`.

- seed:

  Random seed for deterministic clustering.

- group_col:

  Name of the output grouping column.

## Value

`x` with `group_col` assigned.
