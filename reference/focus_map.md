# Interactive focus-map viewer

Renders spatial features as a smooth, interactive SVG map. Click any
polygon to zoom in and lift it from the map with a "toast" effect;
right-click or press Escape to reset. Camera transitions use D3's
optimal zoom interpolation for fluid 60 fps motion with zero server
round-trips.

## Usage

``` r
focus_map(
  x,
  label_col = NULL,
  id_col = NULL,
  group_col = NULL,
  simplify = TRUE,
  fill = "#2d6ea3",
  fill_opacity = 0.58,
  stroke = "#ffffff",
  lift_scale = 1.16,
  focus_padding = 40,
  focus_size = 0.76,
  max_zoom = NULL,
  font_size = 14,
  show_labels = TRUE,
  show_sidebar = TRUE,
  performance_mode = NULL,
  info_cols = NULL,
  info_labels = NULL,
  info_title = NULL,
  info_position = c("top-right", "top-left", "bottom-right", "bottom-left"),
  info_card_scale = 1,
  area_min = 5000,
  width_min = 95,
  height_min = 28,
  width = "100%",
  height = "600px",
  elementId = NULL
)

focusmapOutput(outputId, width = "100%", height = "600px")

renderFocusmap(expr, env = parent.frame(), quoted = FALSE)
```

## Arguments

- x:

  An `sf`, `exploded_map`, or `grouped_exploded_map` object.

- label_col:

  Character. Column name for polygon labels. Auto-detected if `NULL`.

- id_col:

  Optional stable feature ID column for Shiny selection events. Defaults
  to row order if `NULL`.

- group_col:

  Character. Optional column for region/group colouring. Polygons
  sharing a group value share a hue.

- simplify:

  Controls geometry simplification for rendering performance. `TRUE`
  (default) applies a sensible tolerance (`dTolerance = 0.001` in WGS 84
  degrees, \\\approx\\ 100 m). A positive number sets a custom
  tolerance. `FALSE` disables simplification. Only affects the widget
  copy — the original data is never modified.

- fill:

  Fill colour (used when `group_col` is `NULL`). Default `"#2d6ea3"`.

- fill_opacity:

  Fill opacity. Default `0.58`.

- stroke:

  Stroke colour. Default `"#ffffff"`.

- lift_scale:

  Initial toast lift scale. Default `1.16`. Increase this to make the
  lifted feature larger.

- focus_padding:

  Extra screen-space padding in pixels around the lifted feature during
  focus. Increase this if large lifted features feel too close to the
  map edge.

- focus_size:

  Target fraction of the map viewport the lifted feature may occupy.
  Increase this to make selected areas appear larger while preserving
  `focus_padding`.

- max_zoom:

  Optional maximum camera zoom. If `NULL`, a density-aware default is
  used.

- font_size:

  Label font size in px. Default `14`.

- show_labels:

  Show labels on lifted shapes? Default `TRUE`.

- show_sidebar:

  Show control sidebar? Default `TRUE`.

- performance_mode:

  Logical or `NULL`. If `NULL`, dense layers automatically use shorter
  camera transitions and lighter in-flight rendering. Set `TRUE` to
  force it or `FALSE` to disable it.

- info_cols:

  Optional character vector of columns to show in a non-blocking focus
  card when a feature is selected.

- info_labels:

  Optional named character vector or list for display labels in the
  focus card. Names should match `info_cols`.

- info_title:

  Optional column to use as the focus card title. Defaults to
  `label_col`.

- info_position:

  Position for the focus card: `"top-right"`, `"top-left"`,
  `"bottom-right"`, or `"bottom-left"`.

- info_card_scale:

  Relative size for the focus card. Values above `1` make the card
  larger; values below `1` make it more compact.

- area_min:

  Min screen area (px^2) for label visibility.

- width_min:

  Min screen width (px) for label visibility.

- height_min:

  Min screen height (px) for label visibility.

- width:

  Widget width. Default `"100%"`.

- height:

  Widget height. Default `"600px"`.

- elementId:

  Optional element ID.

- outputId:

  Shiny output ID.

- expr:

  Expression that returns a `focus_map()` widget.

- env:

  Environment in which to evaluate `expr`.

- quoted:

  Logical. Is `expr` already quoted?

## Value

An `htmlwidgets` object.

## Details

Accepts raw `sf` objects, `exploded_map` results from
[`explode_sf`](https://prigasg.github.io/explodemap/reference/explode_sf.md),
or `grouped_exploded_map` results from
[`explode_grouped`](https://prigasg.github.io/explodemap/reference/explode_grouped.md).
For exploded objects, the displaced (WGS 84) geometry is used
automatically.

## Examples

``` r
if (FALSE) { # \dontrun{
focus_map(nj_counties, label_col = "NAME")

result <- explode_sf(nj_counties, region_col = "region")
focus_map(result)
focus_map(result, group_col = "region")
} # }
```
