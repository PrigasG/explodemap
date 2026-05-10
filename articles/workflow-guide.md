# Choosing an explodemap workflow

## The short version

`explodemap` has four main user-facing workflows:

| Goal | Use |
|----|----|
| Explode a projected `sf` object that already has a grouping column | [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md) |
| Join a lookup table before exploding | [`explode_sf_with_lookup()`](https://prigasg.github.io/explodemap/reference/explode_sf_with_lookup.md) |
| Download and explode U.S. county subdivisions by state | [`explode_state()`](https://prigasg.github.io/explodemap/reference/explode_state.md) |
| Separate larger region blocks for national or multi-region layouts | [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md) |
| Add interactive selected-area zoom and information cards | [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md) |

The best default is usually
[`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md):
prepare a projected `sf` object, add a region column, and let the
package derive parameters from the data geometry.

## Static exploded maps

Use
[`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md)
when you already have polygon data and a grouping column:

``` r

result <- explode_sf(
  my_sf,
  region_col = "region",
  plot = FALSE
)
```

Use
[`explode_sf_with_lookup()`](https://prigasg.github.io/explodemap/reference/explode_sf_with_lookup.md)
when group membership lives in a separate table:

``` r

result <- explode_sf_with_lookup(
  my_sf,
  join_col = "GEOID",
  lookup = region_lookup,
  lookup_key = "geoid",
  region_col = "region",
  plot = FALSE
)
```

Use
[`explode_state()`](https://prigasg.github.io/explodemap/reference/explode_state.md)
when you want the package to download U.S. Census TIGER/Line county
subdivision data for a state:

``` r

result <- explode_state(
  state_fips = "34",
  crs = 32118,
  region_map = nj_regions,
  plot = FALSE
)
```

Downloaded data is cached by `tigris`, so repeated runs are faster.

## Dense municipal cores

The core two-level model is closed-form and deterministic. For very
dense municipal cores, you may still see residual crowding after the
analytical displacement. In that case, add the optional bounded
refinement pass:

``` r

result <- explode_sf(
  my_sf,
  region_col = "region",
  refine = TRUE,
  refine_min_gap = 250,
  refine_max_shift = 150,
  plot = FALSE
)
```

Use `refine = TRUE` as a finishing pass, not as the first tuning knob.
The most important parameter is `refine_max_shift`, which caps the extra
correction per feature. Start small and increase only when dense cores
still touch or visually crowd.

The default `refine_within = "region"` only refines pairs that share the
same parent region. Use `refine_within = "all"` when the remaining
crowding crosses region boundaries.

## Grouped layouts

Use
[`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md)
when the map needs an additional layout level, such as a national map
with multiple region blocks:

``` r

grouped <- explode_grouped(
  my_sf,
  region_col = "hhs_region",
  mode = "auto_collision",
  plot = FALSE
)
```

The grouped workflow has three modes:

| Mode               | Use when                                             |
|--------------------|------------------------------------------------------|
| `"auto"`           | Radial anchor placement is enough                    |
| `"auto_collision"` | Region blocks need collision-aware anchor refinement |
| `"manual"`         | You want to provide anchor coordinates yourself      |

## Interactive focus maps

Use
[`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
when the goal is exploration in Shiny or htmlwidgets, not a new static
geometry layer. It lets users click or select a feature, zoom it into a
readable viewport target, and show contextual fields in a non-blocking
information card:

``` r

focus_map(
  result,
  group_col = "region",
  info_cols = c("NAME", "GEOID"),
  focus_size = 0.76,
  focus_padding = 40,
  lift_scale = 1.16,
  info_card_scale = 1.2
)
```

For Shiny:

``` r

ui <- fluidPage(
  focusmapOutput("map", height = "700px")
)

server <- function(input, output, session) {
  output$map <- renderFocusmap({
    focus_map(munis, label_col = "NAME", info_cols = c("GEOID"))
  })
}
```

## Performance guidance

Before exploding or focusing:

- Use a projected CRS for displacement workflows.
- Use `plot = FALSE` inside apps or scripts when you only need returned
  objects.
- Use `focus_map(performance_mode = TRUE)` for dense municipal layers.
- Simplify for web display when the browser becomes the bottleneck.
- Keep downloaded TIGER/Line examples in scripts, vignettes with
  `eval = FALSE`, or `inst/examples/`, not in CRAN-running examples.
- Use TopoJSON or GeoJSON export for deployment workflows rather than
  recomputing geometry in the app server.

## Installed examples

Small local examples:

``` r

source(system.file("examples/basic_explode_sf.R", package = "explodemap"))
source(system.file("examples/collision_refinement.R", package = "explodemap"))
source(system.file("examples/lookup_workflow.R", package = "explodemap"))
source(system.file("examples/manual_parameter_tuning.R", package = "explodemap"))
```

Interactive examples that download public data:

``` r

shiny::runApp(system.file("examples/focusmap_munis_app.R", package = "explodemap"))
shiny::runApp(system.file("examples/focusmap_counties_app.R", package = "explodemap"))
```
