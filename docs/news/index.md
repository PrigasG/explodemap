# Changelog

## explodemap 0.2.0

### New features

- Added a three-level grouped layout engine via
  [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md),
  supporting `"auto"`, `"auto_collision"`, and `"manual"` anchor modes
  for multi-region and national-scale layouts.
- Added
  [`layout_regions()`](https://prigasg.github.io/explodemap/reference/layout_regions.md)
  to compute region anchors as a standalone step for custom
  grouped-layout workflows.
- Added
  [`estimate_block_radii()`](https://prigasg.github.io/explodemap/reference/estimate_block_radii.md)
  to estimate per-region block radii using the 85th percentile of
  unit-to-centroid distances.
- Added
  [`export_topojson()`](https://prigasg.github.io/explodemap/reference/export_topojson.md)
  for optional TopoJSON export via the external `mapshaper` CLI tool,
  for downstream tools such as Power BI.
- Added
  [`summary.grouped_exploded_map()`](https://prigasg.github.io/explodemap/reference/summary.grouped_exploded_map.md)
  for grouped-layout diagnostics, including local displacement
  parameters, anchor parameters, and block radii.
- Added optional bounded collision refinement to
  [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md)
  and
  [`explode_state()`](https://prigasg.github.io/explodemap/reference/explode_state.md)
  for dense municipal cores, with diagnostics stored in the returned
  `refinement` component.
- Added
  [`explode_section()`](https://prigasg.github.io/explodemap/reference/explode_section.md)
  for drill-down dashboards that explode one selected section while
  keeping the remaining geography as faded or hidden context for
  [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md).

### Improvements

- Centroid handling was refactored throughout the package to avoid `sf`
  attribute warnings during centroid calculations.
- [`compute_stats()`](https://prigasg.github.io/explodemap/reference/compute_stats.md)
  now accepts `centroid_fun` so geometry statistics and displacement use
  the same centroid semantics.
- [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md)
  and
  [`explode_state()`](https://prigasg.github.io/explodemap/reference/explode_state.md)
  now respect partial manual overrides: users may set only `alpha_r` or
  only `alpha_l` while deriving the other parameter from geometry.
- Direction vectors and distance scaling now handle true zero-distance
  cases without suppressing sub-metre coordinate differences.
- Grouped anchor collision refinement is now deterministic for
  coincident anchors, improving reproducibility.
- Manual grouped anchors now validate that every region has one anchor
  and that regions are not duplicated in the anchor table.
- Grouped objects now inherit from both `grouped_exploded_map` and
  `exploded_map`, improving method consistency.
- Grouped S3 methods were consolidated and cleaned up for more
  consistent printing, plotting, and summary output.
- Distance formatting in diagnostic output now adapts between metres and
  kilometres, improving readability for both small synthetic examples
  and real-world datasets.
- Focus maps now support non-blocking info cards, selected-area sizing
  controls, and denser-layer performance tuning for Shiny workflows.
- Focus maps now support named `group_palette` values, allowing Shiny
  apps to align widget colouring with dashboard legends or
  domain-specific palettes.
- Focus maps now support context features via `context_col`,
  `context_mode`, `context_opacity`, and `context_clickable`, enabling
  selected-region focus maps with muted background geography.
- Focus maps now support adaptive tiny-feature focus controls via
  `min_focus_width`, `min_focus_height`, `tiny_feature_threshold`, and
  `tiny_feature_boost`, improving municipal drill-down maps with very
  small selected polygons.
- Focus maps now support selected-feature origin context via
  `origin_context` and `origin_context_position`, including an overview
  inset that keeps small municipal focus views anchored to the broader
  geography. The cue is opt-in by default.
- Focus maps now expose `focus_context_opacity` to tune how strongly the
  non-selected background geography recedes during focused views.
- Focus maps now support opt-in drag zoom via `show_drag_zoom`. Users
  can use the button or Shift-drag to draw a marquee rectangle and
  smoothly zoom into dense clusters before selecting individual
  features.
- Drag zoom behaves as a navigation layer over focus maps: plain clicks
  still focus polygons while the toggle is active, and turning the tool
  off no longer resets the current focus.
- [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md)
  now accepts visual aliases (`anchor_expand`, `anchor_buffer`,
  `density_scale`, and `block_sep`) for the corresponding grouped-layout
  solver controls.
- Shiny workflows now have quieter geometry builders, automatic plot
  suppression safeguards, and selection events for linked side panels.
- Public-facing dashboard examples now show clear Shiny validation
  messages for failed boundary downloads, empty data, map-generation
  failures, and widget-rendering failures.
- TIGER/Line downloads and TopoJSON export now fail with clearer,
  actionable error messages when external services, files, or tools are
  unavailable.
- [`validate_input()`](https://prigasg.github.io/explodemap/reference/validate_input.md)
  now returns visibly, making repaired geometries less fragile in
  internal workflows.

### Documentation

- Added three vignettes: getting started, grouped layouts, and paper
  replication.
- Added small installed examples for the basic `sf` workflow, optional
  collision refinement, lookup-table grouping, and manual parameter
  tuning.
- Added a workflow-selection vignette for release-oriented user
  guidance.
- Added Shiny-oriented guidance for exploding a visible section while
  preserving the rest of the map as context in
  [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md).
- Added an `inst/CITATION` entry for academic citation.
- Added pkgdown site configuration and GitHub Pages support.

------------------------------------------------------------------------

## explodemap 0.1.0

### Initial release

- Added the core two-level displacement engine for exploded-view
  cartography of dense administrative boundary data.
- Added three public entry points:
  [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md),
  [`explode_sf_with_lookup()`](https://prigasg.github.io/explodemap/reference/explode_sf_with_lookup.md),
  and
  [`explode_state()`](https://prigasg.github.io/explodemap/reference/explode_state.md).
- Added analytical parameter derivation via
  [`derive_params()`](https://prigasg.github.io/explodemap/reference/derive_params.md),
  implementing Analytical Results 1 and 2.
- Added geometry statistics via
  [`compute_stats()`](https://prigasg.github.io/explodemap/reference/compute_stats.md).
- Added the `exploded_map` S3 class with
  [`print()`](https://rdrr.io/r/base/print.html),
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html), and
  [`summary()`](https://rdrr.io/r/base/summary.html) methods.
- Added
  [`calibration_row()`](https://prigasg.github.io/explodemap/reference/calibration_row.md)
  for cross-dataset calibration tables.
- Added TIGER/Line download and caching support via
  [`explode_state()`](https://prigasg.github.io/explodemap/reference/explode_state.md).
- Added a state registry with New Jersey, Pennsylvania, Ohio, and New
  York configurations.
- Added example workflows for cross-state calibration, Canada
  validation, and HHS grouped layouts.
