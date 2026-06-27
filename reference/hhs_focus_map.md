# Create a focus-map widget for HHS regions

Create a focus-map widget for HHS regions

## Usage

``` r
hhs_focus_map(
  states,
  apply_offsets = TRUE,
  show_region_labels = TRUE,
  show_drag_zoom = TRUE,
  show_labels = TRUE,
  ...
)
```

## Arguments

- states:

  An `sf` object of state or territory polygons.

- apply_offsets:

  Logical. Apply
  [`hhs_display_offsets()`](https://prigasg.github.io/explodemap/reference/hhs_display_offsets.md)
  before drawing?

- show_region_labels:

  Logical. Show one passive HHS label per region.

- show_drag_zoom:

  Logical. Show the drag-to-zoom button.

- show_labels:

  Logical. Show labels on lifted states/territories.

- ...:

  Additional arguments passed to
  [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md).

## Value

An `htmlwidgets` focus-map widget.
