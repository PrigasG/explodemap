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
if (FALSE) { # \dontrun{
focused <- explode_section(
  municipalities,
  section_col = "nj_region",
  section = "South",
  region_col = "county_name",
  alpha_r = 1800,
  alpha_l = 1200,
  plot = FALSE
)

focus_map(
  focused,
  label_col = "NAME",
  context_col = ".explodemap_role",
  context_mode = "fade"
)
} # }
```
