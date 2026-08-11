# Build a stable spatial join index

Creates a small renderer- and source-neutral lookup table for validating
external data joins against spatial features. Jurisdiction-specific
parsing and alias rules remain application responsibilities.

## Usage

``` r
spatial_join_index(x, id_col, name_col = NULL, parent_col = NULL)
```

## Arguments

- x:

  Spatial or ordinary data frame.

- id_col:

  Stable unique feature identifier column.

- name_col:

  Optional display-name column.

- parent_col:

  Optional parent identifier column.

## Value

A `spatial_join_index` data frame with `feature_id`, optional
`feature_name` and `parent_id`, and the original feature row.
