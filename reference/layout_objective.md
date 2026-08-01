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

  Weight for polygon overlap as a fraction of total polygon area.

- displacement:

  Weight for mean displacement as a fraction of the original layout
  diagonal.

- unused_space:

  Weight for unused canvas space.

- label_overlap:

  Weight for approximate label overlaps as a fraction of all possible
  label pairs.

## Value

Named numeric vector of objective weights.
