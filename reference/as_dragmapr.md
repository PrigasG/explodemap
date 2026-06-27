# Convert a grouped layout to a drag-edit handoff object (legacy)

Legacy / low-level handoff (superseded, but not deprecated).

This is the original handoff: it bundles the grouped geometry and the
absolute anchors into a `dragmapr_layout` list. The preferred path is
now
[`as_dragmapr_state()`](https://prigasg.github.io/explodemap/reference/as_dragmapr_state.md),
which emits a geometry-free
[`dragmapr::dragmapr_state()`](https://prigasg.github.io/dragmapr/reference/dragmapr_state.html)
– the shared editorial composition contract that `state =` arguments
accept across
[`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md),
[`render_dragged_map()`](https://prigasg.github.io/dragmapr/reference/render_dragged_map.html),
and
[`update_exploded_layout()`](https://prigasg.github.io/explodemap/reference/update_exploded_layout.md).

`as_dragmapr()` remains supported for existing offset-table / CSV
workflows and is not scheduled for removal, but new code should prefer
the state-first API.

## Usage

``` r
as_dragmapr(result)
```

## Arguments

- result:

  A `grouped_exploded_map`.

## Value

A `dragmapr_layout` list containing editable sf geometry and anchors.

## See also

[`as_dragmapr_state()`](https://prigasg.github.io/explodemap/reference/as_dragmapr_state.md)
for the preferred state-first handoff.
