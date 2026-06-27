# Update an exploded grouped layout after manual composition

Update an exploded grouped layout after manual composition

## Usage

``` r
update_exploded_layout(
  result,
  region_offsets,
  label_offsets = NULL,
  update_plots = TRUE
)
```

## Arguments

- result:

  A `grouped_exploded_map`.

- region_offsets:

  Data frame of manual anchors (`anchor_x`, `anchor_y`) or offsets
  (`dx_m`, `dy_m`) by region.

- label_offsets:

  Optional label-offset table stored on the result.

- update_plots:

  Rebuild stored ggplots.

## Value

Updated `grouped_exploded_map`.
