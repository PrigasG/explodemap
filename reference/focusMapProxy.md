# Focus-map Shiny proxy

Focus-map Shiny proxy

## Usage

``` r
focusMapProxy(outputId, session = NULL)

update_focus_labels(proxy, show = TRUE)

update_focus_palette(proxy, palette)

update_focus_data(proxy, data, ...)
```

## Arguments

- outputId:

  Shiny output ID for an existing
  [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md).

- session:

  Shiny session. Defaults to the current reactive domain.

- proxy:

  A `focusmap_proxy`.

- show:

  Logical; show focus labels.

- palette:

  Named character vector of group colours.

- data:

  New `sf`, `exploded_map`, or `grouped_exploded_map` data.

- ...:

  Passed to
  [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  when building the replacement payload.

## Value

A `focusmap_proxy` object.

## Details

`update_focus_data()` swaps the widget's geometry and rebuilds it, which
returns the map to its idle (unfocused) view – a data swap is treated as
a fresh dataset. To keep the user focused on a feature across the swap,
pass a `state` and `restore_selection = TRUE` through `...`; these flow
to
[`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
and the new feature is re-focused on load:

    update_focus_data(proxy, new_sf, id_col = "GEOID",
                      state = state, restore_selection = TRUE)
