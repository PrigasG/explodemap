# Build layout objective weights

Build layout objective weights

## Usage

``` r
layout_objective(
  overlap = 10,
  displacement = 2,
  unused_space = 1,
  label_overlap = 4
)
```

## Arguments

- overlap:

  Weight for polygon overlap area.

- displacement:

  Weight for mean displacement.

- unused_space:

  Weight for unused canvas space.

- label_overlap:

  Weight for approximate label overlaps.

## Value

Named numeric vector of objective weights.
