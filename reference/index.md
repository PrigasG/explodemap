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

- [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  [`focusmapOutput()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  [`renderFocusmap()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  : Interactive focus-map viewer

## Grouped layouts

Functions for three-level grouped layouts with anchor placement and
optional collision-aware refinement.

- [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md)
  : Create a three-level grouped exploded map
- [`layout_regions()`](https://prigasg.github.io/explodemap/reference/layout_regions.md)
  : Compute region anchor positions for grouped layouts
- [`estimate_block_radii()`](https://prigasg.github.io/explodemap/reference/estimate_block_radii.md)
  : Estimate block radius for each region

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
- [`cache_list()`](https://prigasg.github.io/explodemap/reference/cache_list.md)
  : List cached datasets
- [`cache_clear()`](https://prigasg.github.io/explodemap/reference/cache_clear.md)
  : Clear explodemap download cache

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
