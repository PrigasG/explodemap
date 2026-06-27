# Search grouped-layout parameters

Search grouped-layout parameters

## Usage

``` r
optimize_grouped_layout(
  x,
  region_col,
  objective = c("no_overlap", "compact", "balanced", "stable"),
  weights = layout_objective(),
  label_col = NULL,
  label_size = NULL,
  grid = NULL,
  kappa = c(1.4, 1.8, 2.2),
  padding = c(25000, 50000, 75000),
  delta = c(5000, 15000, 30000),
  padding_sep = c(10000, 20000, 40000),
  ...
)
```

## Arguments

- x:

  Projected sf object with region column.

- region_col:

  Grouping column name.

- objective:

  Objective presets: `"no_overlap"`, `"compact"`, `"balanced"`, and/or
  `"stable"`.

- weights:

  Named weights from
  [`layout_objective()`](https://prigasg.github.io/explodemap/reference/layout_objective.md).

- label_col, label_size:

  Optional label column and approximate label size. When `label_col` is
  supplied the search becomes label-aware: each candidate layout is
  scored for approximate label overlaps (weighted by the `label_overlap`
  term of `weights`). Left `NULL` (the default), label overlaps
  contribute zero, so the search result is identical to before.

- grid:

  Optional data.frame of parameter combinations.

- kappa, padding, delta, padding_sep:

  Candidate values used when `grid` is `NULL`.

- ...:

  Passed to
  [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md).

## Value

A `grouped_exploded_map` with `optimization` metadata.
