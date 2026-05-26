# Explode one selected section and keep the rest as context

`explode_section()` is a dashboard-oriented helper for exploratory maps.
It applies an exploded layout only to the requested section, then
recombines the untouched remainder of the layer as geographic context.
The result can be passed directly to
[`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
with `context_col` to fade or hide the non-selected features.

## Usage

``` r
explode_section(
  sf_obj,
  section_col,
  section,
  region_col = section_col,
  layout = c("explode", "grouped"),
  context = c("fade", "hide", "none"),
  role_col = ".explodemap_role",
  all_values = "all",
  ...
)
```

## Arguments

- sf_obj:

  Projected `sf` object.

- section_col:

  Column containing the high-level sections users choose from, such as
  `"North"`, `"Central"`, and `"South"`.

- section:

  Selected section value. Values in `all_values` explode the full layer.

- region_col:

  Column used for the explosion inside the selected section. Defaults to
  `section_col`. For municipality drill-downs, this is often a county
  column.

- layout:

  `"explode"` for
  [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md)
  or `"grouped"` for
  [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md).

- context:

  `"fade"` or `"hide"` keeps non-selected features in the returned
  object as context; `"none"` drops them.

- role_col:

  Name of the role column added to the output. Focus features are marked
  `"focus"` and context features are marked `"context"`.

- all_values:

  Values that mean "all sections". Default `"all"`.

- ...:

  Passed to
  [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md)
  or
  [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md).

## Value

An `exploded_map` or `grouped_exploded_map` object with recombined
focus/context geometry and extra diagnostics.

## Examples

``` r
# \donttest{
poly <- function(xmin, ymin, xmax, ymax) {
  sf::st_polygon(list(rbind(
    c(xmin, ymin), c(xmax, ymin), c(xmax, ymax),
    c(xmin, ymax), c(xmin, ymin)
  )))
}

municipalities <- sf::st_sf(
  NAME = c("A", "B", "C", "D"),
  nj_region = c("South", "South", "North", "North"),
  county_name = c("Atlantic", "Cape May", "Bergen", "Hudson"),
  geometry = sf::st_sfc(
    poly(0, 0, 1000, 1000),
    poly(2000, 0, 3000, 1000),
    poly(0, 2000, 1000, 3000),
    poly(2000, 2000, 3000, 3000),
    crs = 3857
  )
)

focused <- explode_section(
  municipalities,
  section_col = "nj_region",
  section = "South",
  region_col = "county_name",
  alpha_r = 1800,
  alpha_l = 1200,
  plot = FALSE,
  quiet = TRUE
)

focus_map(
  focused,
  label_col = "NAME",
  context_col = ".explodemap_role",
  context_mode = "fade"
)

{"x":{"geojson_str":"{\n\"type\": \"FeatureCollection\",\n\"name\": \"file1d204519de57\",\n\"features\": [\n{ \"type\": \"Feature\", \"properties\": { \"feature_id\": \"1\", \"id\": \"1\", \"NAME\": \"A\", \"context\": \"focus\", \"info_title\": \"A\" }, \"geometry\": { \"type\": \"Polygon\", \"coordinates\": [ [ [ -0.0161697, 0.0 ], [ -0.0071865, 0.0 ], [ -0.0071865, 0.0089832 ], [ -0.0161697, 0.0089832 ], [ -0.0161697, 0.0 ] ] ] } },\n{ \"type\": \"Feature\", \"properties\": { \"feature_id\": \"2\", \"id\": \"2\", \"NAME\": \"B\", \"context\": \"focus\", \"info_title\": \"B\" }, \"geometry\": { \"type\": \"Polygon\", \"coordinates\": [ [ [ 0.034136, 0.0 ], [ 0.0431191, 0.0 ], [ 0.0431191, 0.0089832 ], [ 0.034136, 0.0089832 ], [ 0.034136, 0.0 ] ] ] } },\n{ \"type\": \"Feature\", \"properties\": { \"feature_id\": \"3\", \"id\": \"3\", \"NAME\": \"C\", \"context\": \"context\", \"info_title\": \"C\" }, \"geometry\": { \"type\": \"Polygon\", \"coordinates\": [ [ [ 0.0, 0.0179663 ], [ 0.0089832, 0.0179663 ], [ 0.0089832, 0.0269495 ], [ 0.0, 0.0269495 ], [ 0.0, 0.0179663 ] ] ] } },\n{ \"type\": \"Feature\", \"properties\": { \"feature_id\": \"4\", \"id\": \"4\", \"NAME\": \"D\", \"context\": \"context\", \"info_title\": \"D\" }, \"geometry\": { \"type\": \"Polygon\", \"coordinates\": [ [ [ 0.0179663, 0.0179663 ], [ 0.0269495, 0.0179663 ], [ 0.0269495, 0.0269495 ], [ 0.0179663, 0.0269495 ], [ 0.0179663, 0.0179663 ] ] ] } }\n]\n}","options":{"fill":"#2d6ea3","groupPalette":null,"contextMode":"fade","contextValues":["context"],"contextFill":"#cfd9df","contextOpacity":0.18,"contextClickable":false,"focusPreset":"none","fillOpacity":0.58,"stroke":"#ffffff","liftScale":1.16,"focusPadding":40,"focusSize":0.76,"minFocusWidth":0,"minFocusHeight":0,"tinyFeatureThreshold":48,"tinyFeatureBoost":1,"maxZoom":null,"originContext":"none","originContextPosition":"bottom-left","focusContextOpacity":0.3,"showDragZoom":false,"fontSize":14,"showLabels":true,"performanceMode":null,"showInfoCard":false,"infoPosition":"top-right","infoCols":null,"infoKeys":[],"infoLabels":null,"infoTitle":"NAME","infoCardScale":1,"areaMin":5000,"widthMin":95,"heightMin":28,"hasGroups":false}},"evals":[],"jsHooks":[]}# }
```
