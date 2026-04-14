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
- [`validate_input()`](https://prigasg.github.io/explodemap/reference/validate_input.md)
  now returns visibly, making repaired geometries less fragile in
  internal workflows.

### Documentation

- Added three vignettes: getting started, grouped layouts, and paper
  replication.
- Added small installed examples for the basic `sf` workflow, optional
  collision refinement, lookup-table grouping, and manual parameter
  tuning.
- Added a workflow-selection vignette and a site-linked cheatsheet for
  release-oriented user guidance.
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
