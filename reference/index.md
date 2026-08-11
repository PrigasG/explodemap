# Package index

## Core workflow

Main entry points for generating two-level exploded-view maps from
projected sf data or state-level TIGER/Line inputs.

- [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md)
  : Explode any sf object with an existing grouping column
- [`explode_sf_with_lookup()`](https://prigasg.github.io/explodemap/reference/explode_sf_with_lookup.md)
  : Explode any sf object using an external lookup table
- [`explode_state()`](https://prigasg.github.io/explodemap/reference/explode_state.md)
  : Explode a US state from TIGER/Line data

## Interactive focus maps

htmlwidgets and Shiny helpers for selected-feature focus, labels, and
non-blocking information cards.

- [`explode_section()`](https://prigasg.github.io/explodemap/reference/explode_section.md)
  : Explode one selected section and keep the rest as context
- [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  [`focusmapOutput()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  [`renderFocusmap()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  : Interactive focus-map viewer
- [`focus_map_preset()`](https://prigasg.github.io/explodemap/reference/focus_map_preset.md)
  : Focus-map option presets
- [`focusMapProxy()`](https://prigasg.github.io/explodemap/reference/focusMapProxy.md)
  [`update_focus_labels()`](https://prigasg.github.io/explodemap/reference/focusMapProxy.md)
  [`update_focus_palette()`](https://prigasg.github.io/explodemap/reference/focusMapProxy.md)
  [`update_focus_data()`](https://prigasg.github.io/explodemap/reference/focusMapProxy.md)
  : Focus-map Shiny proxy

## Grouped layouts

Functions for three-level grouped layouts with anchor placement and
optional collision-aware refinement.

- [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md)
  : Create a three-level grouped exploded map
- [`layout_regions()`](https://prigasg.github.io/explodemap/reference/layout_regions.md)
  : Compute region anchor positions for grouped layouts
- [`estimate_block_radii()`](https://prigasg.github.io/explodemap/reference/estimate_block_radii.md)
  : Estimate block radius for each region
- [`original_geometry()`](https://prigasg.github.io/explodemap/reference/original_geometry.md)
  [`local_geometry()`](https://prigasg.github.io/explodemap/reference/original_geometry.md)
  [`final_geometry()`](https://prigasg.github.io/explodemap/reference/original_geometry.md)
  [`group_geometry()`](https://prigasg.github.io/explodemap/reference/original_geometry.md)
  : Access geometry from a grouped exploded layout
- [`anchor_table()`](https://prigasg.github.io/explodemap/reference/anchor_table.md)
  : Access grouped-layout anchor data

## Child geography layout

Compute deterministic projected child placements and extract their
renderer-neutral offsets or composed geometry.

- [`layout_children()`](https://prigasg.github.io/explodemap/reference/layout_children.md)
  : Lay out child geography around a parent
- [`child_layout_offsets()`](https://prigasg.github.io/explodemap/reference/child_layout_offsets.md)
  [`child_layout_geometry()`](https://prigasg.github.io/explodemap/reference/child_layout_offsets.md)
  : Access a child layout

## State-first composition (dragmapr bridge)

Hand a computed layout to the dragmapr editor as a reusable
dragmapr_state, then apply edited compositions back. Feature-level
handoffs use stable IDs from source columns or
prepare_explodemap_input(). as_dragmapr_state() is the preferred
handoff; as_dragmapr() is the legacy low-level handoff.

- [`as_dragmapr_state()`](https://prigasg.github.io/explodemap/reference/as_dragmapr_state.md)
  : Convert a grouped layout to a dragmapr editing state
- [`update_exploded_layout()`](https://prigasg.github.io/explodemap/reference/update_exploded_layout.md)
  : Update an exploded grouped layout after manual composition
- [`layout_offsets()`](https://prigasg.github.io/explodemap/reference/layout_offsets.md)
  : Computed offsets from a grouped exploded layout
- [`transition_data()`](https://prigasg.github.io/explodemap/reference/transition_data.md)
  : Renderer-neutral transition data
- [`connector_geometry()`](https://prigasg.github.io/explodemap/reference/connector_geometry.md)
  : Connector geometry for computed layout movement
- [`as_dragmapr()`](https://prigasg.github.io/explodemap/reference/as_dragmapr.md)
  : Convert a grouped layout to a drag-edit handoff object (legacy)

## Input preparation and app primitives

Reusable validation, simplification, grouping, palette, and fingerprint
helpers that support Shiny apps, examples, and preprocessing pipelines.

- [`validate_explodemap_input()`](https://prigasg.github.io/explodemap/reference/validate_explodemap_input.md)
  : Validate explodemap input
- [`prepare_explodemap_input()`](https://prigasg.github.io/explodemap/reference/prepare_explodemap_input.md)
  : Prepare input for grouped explodemap layouts
- [`count_geometry_vertices()`](https://prigasg.github.io/explodemap/reference/count_geometry_vertices.md)
  : Count geometry vertices
- [`simplify_to_vertex_budget()`](https://prigasg.github.io/explodemap/reference/simplify_to_vertex_budget.md)
  : Simplify geometry to a vertex budget
- [`assign_spatial_groups()`](https://prigasg.github.io/explodemap/reference/assign_spatial_groups.md)
  : Assign generated spatial groups
- [`group_palette()`](https://prigasg.github.io/explodemap/reference/group_palette.md)
  : Create a stable group palette
- [`e_fingerprint()`](https://prigasg.github.io/explodemap/reference/e_fingerprint.md)
  : Fingerprint explodemap geometry and grouping
- [`spatial_join_index()`](https://prigasg.github.io/explodemap/reference/spatial_join_index.md)
  : Build a stable spatial join index
- [`validate_spatial_join()`](https://prigasg.github.io/explodemap/reference/validate_spatial_join.md)
  : Validate an external data-to-spatial join

## Layout quality and optimization

Score a grouped layout and search for better region placements.

- [`diagnose_layout()`](https://prigasg.github.io/explodemap/reference/diagnose_layout.md)
  : Diagnose grouped layout quality
- [`plot(`*`<layout_quality_report>`*`)`](https://prigasg.github.io/explodemap/reference/plot.layout_quality_report.md)
  : Plot a grouped-layout diagnostic
- [`layout_objective()`](https://prigasg.github.io/explodemap/reference/layout_objective.md)
  : Build layout objective weights
- [`optimize_grouped_layout()`](https://prigasg.github.io/explodemap/reference/optimize_grouped_layout.md)
  : Search grouped-layout parameters

## Statistics and calibration

Tools for computing geometry statistics, deriving parameters, and
building calibration summaries across datasets.

- [`compute_stats()`](https://prigasg.github.io/explodemap/reference/compute_stats.md)
  : Compute geometry statistics for parameter derivation
- [`derive_params()`](https://prigasg.github.io/explodemap/reference/derive_params.md)
  : Derive displacement parameters from geometry statistics
- [`calibration_row()`](https://prigasg.github.io/explodemap/reference/calibration_row.md)
  : Extract calibration row from an exploded_map

## Export and cache helpers

Optional export helpers and cache management utilities.

- [`export_topojson()`](https://prigasg.github.io/explodemap/reference/export_topojson.md)
  : Export an exploded map as TopoJSON
- [`apply_region_offsets()`](https://prigasg.github.io/explodemap/reference/apply_region_offsets.md)
  : Apply documented display offsets by region
- [`read_drag_offsets()`](https://prigasg.github.io/explodemap/reference/read_drag_offsets.md)
  : Read drag-helper offset CSVs into a region offset data frame
- [`cache_list()`](https://prigasg.github.io/explodemap/reference/cache_list.md)
  : List cached datasets
- [`cache_clear()`](https://prigasg.github.io/explodemap/reference/cache_clear.md)
  : Clear explodemap download cache

## HHS reference maps

Ready-made U.S. Department of Health and Human Services region layouts,
palettes, and a one-call focus map for HHS-style placeholder shapes.

- [`hhs_layout()`](https://prigasg.github.io/explodemap/reference/hhs_layout.md)
  : Build an HHS reference layout
- [`hhs_focus_map()`](https://prigasg.github.io/explodemap/reference/hhs_focus_map.md)
  : Create a focus-map widget for HHS regions
- [`as_hhs_states()`](https://prigasg.github.io/explodemap/reference/as_hhs_states.md)
  : Standardize state polygons for HHS reference maps
- [`hhs_regions()`](https://prigasg.github.io/explodemap/reference/hhs_regions.md)
  : HHS regional assignments for states and territories
- [`hhs_region_names()`](https://prigasg.github.io/explodemap/reference/hhs_region_names.md)
  : HHS region display names
- [`hhs_display_offsets()`](https://prigasg.github.io/explodemap/reference/hhs_display_offsets.md)
  : HHS reference-layout display offsets
- [`hhs_palette()`](https://prigasg.github.io/explodemap/reference/hhs_palette.md)
  : HHS region colour palette

## Methods

S3 methods for printing, plotting, summarising, and extracting tabular
results from exploded map objects.

- [`print(`*`<exploded_map>`*`)`](https://prigasg.github.io/explodemap/reference/print.exploded_map.md)
  : Print an exploded_map object
- [`plot(`*`<exploded_map>`*`)`](https://prigasg.github.io/explodemap/reference/plot.exploded_map.md)
  : Plot an exploded_map object
- [`summary(`*`<exploded_map>`*`)`](https://prigasg.github.io/explodemap/reference/summary.exploded_map.md)
  : Summary of an exploded_map object
- [`print(`*`<grouped_exploded_map>`*`)`](https://prigasg.github.io/explodemap/reference/print.grouped_exploded_map.md)
  : Print a grouped_exploded_map object
- [`plot(`*`<grouped_exploded_map>`*`)`](https://prigasg.github.io/explodemap/reference/plot.grouped_exploded_map.md)
  : Plot a grouped_exploded_map object
- [`summary(`*`<grouped_exploded_map>`*`)`](https://prigasg.github.io/explodemap/reference/summary.grouped_exploded_map.md)
  : Summary of a grouped_exploded_map object
