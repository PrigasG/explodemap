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

  Optional dragmapr state. Reserved for post-drag diagnostics; when
  supplied, the report records that manual state was considered.

## Value

A `layout_quality_report` list.
