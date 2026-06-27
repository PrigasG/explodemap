# Convert a grouped layout to a dragmapr editing state

Produces a
[`dragmapr::dragmapr_state()`](https://prigasg.github.io/dragmapr/reference/dragmapr_state.html)
– the shared editorial composition contract – from a
`grouped_exploded_map`. Unlike
[`as_dragmapr()`](https://prigasg.github.io/explodemap/reference/as_dragmapr.md),
which bundles geometry and absolute anchors into a handoff list, this
emits the geometry-free *state* that the interactive editor and static
renderers consume: the exploded anchors (`anchor_x`/`anchor_y`) are
converted to the metre deltas (`dx_m`/`dy_m`) relative to the current
region centroids that `dragmapr` expects, and the projected CRS plus a
provenance `geometry_id` are recorded so the state can be reapplied
safely in a later session.

## Usage

``` r
as_dragmapr_state(result, geometry_id = NULL, level = NULL)
```

## Arguments

- result:

  A `grouped_exploded_map`.

- geometry_id:

  Optional single string identifying the source geometry. Defaults to
  the layout label in `result$diagnostics$label`.

- level:

  Optional geography-level label. Defaults to the region column.

## Value

A `dragmapr_state` (see
[`dragmapr::dragmapr_state()`](https://prigasg.github.io/dragmapr/reference/dragmapr_state.html)).

## Details

Keep `layout` (the computed geometry + diagnostics, i.e. `result`) and
`state` (this editorial overlay) separate. The layout can be recomputed
freely while the state preserves manual edits, which is what makes the
`compute -> compose -> render` workflow reproducible.
