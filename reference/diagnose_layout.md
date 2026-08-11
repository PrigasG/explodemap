# Diagnose grouped layout quality

Diagnose grouped layout quality

## Usage

``` r
diagnose_layout(result, label_col = NULL, label_size = NULL, state = NULL)
```

## Arguments

- result:

  A `grouped_exploded_map` object.

- label_col:

  Optional label column for approximate label overlap checks.

- label_size:

  Approximate label size in map units.

- state:

  Optional `dragmapr_state`. When supplied, its manual offsets are
  applied to the grouped layout before every geometry, label, gap, and
  displacement diagnostic is calculated.

## Value

A `layout_quality_report` list.
