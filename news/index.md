# Changelog

## explodemap 0.5.0

### New features

- New
  [`as_sf()`](https://prigasg.github.io/explodemap/reference/as_sf.md)
  converts an `exploded_map` or `grouped_exploded_map` back to a plain
  `sf` data frame (displaced, local, or original layer) for downstream
  GIS work.
- New
  [`displacement_magnitudes()`](https://prigasg.github.io/explodemap/reference/displacement_magnitudes.md)
  reports per-feature displacement (`dx`, `dy`, `distance`) in metres.
- New
  [`compare_layouts()`](https://prigasg.github.io/explodemap/reference/compare_layouts.md)
  summarises per-feature and aggregate displacement changes between two
  layouts of the same input (e.g. parameter tuning or before/after
  refinement). It now verifies that both layouts cover the same input
  features in the same order instead of only checking class and row
  count.
- New vignette `explode-edit-render` walks the full
  explode-measure-edit- compare-render loop, including a scripted
  editorial pass via
  [`update_exploded_layout()`](https://prigasg.github.io/explodemap/reference/update_exploded_layout.md)
  and export back to `sf`.
- Added `codemeta.json` metadata.
- [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  and friends,
  [`focus_map_preset()`](https://prigasg.github.io/explodemap/reference/focus_map_preset.md),
  [`explode_state()`](https://prigasg.github.io/explodemap/reference/explode_state.md),
  and
  [`hhs_focus_map()`](https://prigasg.github.io/explodemap/reference/hhs_focus_map.md)
  are now marked `[Experimental]` in their documentation.

### Bug fixes and hardening

- [`validate_input()`](https://prigasg.github.io/explodemap/reference/validate_input.md)
  now enforces metre-based projected CRSs: inputs in non-metre map units
  (e.g. feet-based projections) are rejected with an error instead of a
  warning, so kilometre/metre labels, calibration columns, `_m` fields,
  offsets, and summaries are always in metres. The same enforcement now
  applies to
  [`apply_region_offsets()`](https://prigasg.github.io/explodemap/reference/apply_region_offsets.md),
  [`layout_children()`](https://prigasg.github.io/explodemap/reference/layout_children.md),
  and
  [`as_hhs_states()`](https://prigasg.github.io/explodemap/reference/as_hhs_states.md),
  which previously accepted projected-feet data while treating their
  metre distances as feet. Missing/empty group values are still
  rejected, and
  [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md)
  “Other” detection is NA-safe.
- `explode_grouped(allow_other = TRUE)` now honours its documentation:
  `"Other"` features are excluded from the local explosion and anchor
  placement, then recombined unchanged (original row order preserved).
- [`assign_spatial_groups()`](https://prigasg.github.io/explodemap/reference/assign_spatial_groups.md)
  rejects `groups < 2` for `method = "clusters"` instead of silently
  promoting `1` to two groups.
- `ggiraph` is restored to `Suggests`: it is used by the shipped
  `inst/examples/hhs_app.R` example.
- Geometry replacement now goes through
  [`sf::st_geometry()`](https://r-spatial.github.io/sf/reference/st_geometry.html)
  in
  [`explode_sf_core()`](https://prigasg.github.io/explodemap/reference/explode_sf_core.md),
  `.translate_by_offsets()`, and
  [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md),
  so inputs whose geometry column is not named `"geometry"` translate
  correctly.
- [`validate_input()`](https://prigasg.github.io/explodemap/reference/validate_input.md)
  rejects missing/empty group values and warns on non-metre projected
  units;
  [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md)
  “Other” detection is NA-safe.
- [`explode_section()`](https://prigasg.github.io/explodemap/reference/explode_section.md)
  errors with a targeted message when the selected section has fewer
  than two distinct `region_col` values (the `section_col` default only
  works with `section = "all"`).
- TIGER helpers: fixed `.compass()` direction mapping (was ~180° off),
  named `region_map` entries assigned to multiple regions now error,
  corrupt cache files are dropped and re-downloaded, and zip listings
  are sanity-checked.
- [`explode_sf_with_lookup()`](https://prigasg.github.io/explodemap/reference/explode_sf_with_lookup.md)
  rejects duplicated join keys; named `region_map` paths in the
  county/TIGER helpers reject counties mapped to multiple regions.
- [`export_topojson()`](https://prigasg.github.io/explodemap/reference/export_topojson.md)
  removes stale output before running mapshaper and checks the mapshaper
  exit status.
- `feature_ids()` rejects duplicated IDs;
  [`layout_offsets()`](https://prigasg.github.io/explodemap/reference/layout_offsets.md),
  [`transition_data()`](https://prigasg.github.io/explodemap/reference/transition_data.md),
  and
  [`connector_geometry()`](https://prigasg.github.io/explodemap/reference/connector_geometry.md)
  now resolve the `require_stable_id` default after `match.arg(level)`.
- [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md)
  gains `allow_other = FALSE` for parity with
  [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md).
- [`optimize_grouped_layout()`](https://prigasg.github.io/explodemap/reference/optimize_grouped_layout.md)
  rejects empty grids and invalid weights; default grid cost documented
  (81 full layouts).
- [`diagnose_layout()`](https://prigasg.github.io/explodemap/reference/diagnose_layout.md)
  per-group nearest gap considers both pair endpoints.
- [`validate_explodemap_input()`](https://prigasg.github.io/explodemap/reference/validate_explodemap_input.md)
  rejects invalid geometries and geographic (lon/lat) CRS;
  [`assign_spatial_groups()`](https://prigasg.github.io/explodemap/reference/assign_spatial_groups.md)
  validates `groups`.
- [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  and
  [`as_hhs_states()`](https://prigasg.github.io/explodemap/reference/as_hhs_states.md)
  error on a missing CRS instead of silently assuming WGS 84.
- [`layout_children()`](https://prigasg.github.io/explodemap/reference/layout_children.md)
  caps `max_iter` at 50 above 2,000 features (quadratic per-iteration
  cost) with a warning.
- Degenerate numeric inputs yield `NA` instead of `Inf`/`NaN` in implied
  gamma and ratio statistics.
- Added a real R-CMD-check workflow (macOS R 4.5, Windows release,
  Ubuntu release/devel/oldrel-1); README badge now reflects it.
- README: install block leads with the GitHub development version
  (0.5.0); `dragmapr` handoff shows Shiny state capture via
  [`d_widget_state()`](https://prigasg.github.io/dragmapr/reference/d_widget_state.html).
- `ggiraph` restored to `Suggests` (used by `inst/examples/hhs_app.R`);
  removed the stray `tests/testthat/Rplots.pdf` from version control.
- [`compare_layouts()`](https://prigasg.github.io/explodemap/reference/compare_layouts.md)
  compares primary layout classes, so mixing an `exploded_map` with a
  `grouped_exploded_map` (which inherits from it) is rejected with the
  documented class-mismatch error instead of a confusing feature-count
  error.
- Grouped geometry unions (in
  [`compute_stats()`](https://prigasg.github.io/explodemap/reference/compute_stats.md),
  [`explode_sf_core()`](https://prigasg.github.io/explodemap/reference/explode_sf_core.md),
  [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md)
  internals,
  [`estimate_block_radii()`](https://prigasg.github.io/explodemap/reference/estimate_block_radii.md),
  [`group_geometry()`](https://prigasg.github.io/explodemap/reference/original_geometry.md),
  `.region_centroids()`, `.group_gap_report()`, and
  `.hhs_region_label_points()`) resolve the active geometry column
  instead of hardcoding `"geometry"`, so inputs with a renamed geometry
  column work end to end.
- Named `region_map` assignment in
  [`.attach_regions_county()`](https://prigasg.github.io/explodemap/reference/dot-attach_regions_county.md)
  and
  [`.attach_regions_tiger()`](https://prigasg.github.io/explodemap/reference/dot-attach_regions_tiger.md)
  replaces a pre-existing `region` column instead of producing a broken
  `region.x` / `region.y` join.
- dragmapr integration is version-tolerant:
  [`apply_dragmapr_state()`](https://prigasg.github.io/dragmapr/reference/apply_dragmapr_state.html)
  is resolved at runtime (no `dragmapr::` check warning on older
  dragmapr), and dragmapr-dependent tests skip cleanly when the
  installed dragmapr predates the state API.

## explodemap 0.4.0

- Cleaned up the remaining package-prefixed API name:
  `explodemap_fingerprint()` is now
  [`e_fingerprint()`](https://prigasg.github.io/explodemap/reference/e_fingerprint.md).
  The old name is no longer exported. Object class names and persisted
  fingerprint values are unchanged.
- Updated all dragmapr integration points and the bundled Pipeline
  Studio for dragmapr’s concise `d_*` function API. The
  [`as_dragmapr_state()`](https://prigasg.github.io/explodemap/reference/as_dragmapr_state.md)
  bridge now targets
  [`dragmapr::d_state()`](https://prigasg.github.io/dragmapr/reference/d_state.html)
  while continuing to emit the unchanged `dragmapr_state` serialized
  class contract.
- Added
  [`layout_children()`](https://prigasg.github.io/explodemap/reference/layout_children.md),
  a projected-coordinate child geography solver extracted from the
  mature Bloom workflow. It performs radial geographic expansion, real
  feature bounding-box or circle collision refinement, attraction toward
  geographic targets, bearing-drift limits, optional canvas confinement,
  and final collision cleanup. Renderer-neutral base offsets and
  composed `sf` geometry are exposed through
  [`child_layout_offsets()`](https://prigasg.github.io/explodemap/reference/child_layout_offsets.md)
  and
  [`child_layout_geometry()`](https://prigasg.github.io/explodemap/reference/child_layout_offsets.md)
  so browsers no longer need to own the canonical spatial math.
- `diagnose_layout(state = )` now applies the supplied `dragmapr_state`
  before measuring polygon/label overlap, gaps, utilization,
  displacement, and stability. Before/after editorial quality
  comparisons therefore diagnose the actual composed geometry instead of
  only setting a post-drag flag.
- Added generic
  [`spatial_join_index()`](https://prigasg.github.io/explodemap/reference/spatial_join_index.md)
  and
  [`validate_spatial_join()`](https://prigasg.github.io/explodemap/reference/validate_spatial_join.md)
  contracts for stable-ID matching and structured unmatched, ambiguous,
  duplicate, and wrong-parent findings. Census aliases, CSV parsing,
  jurisdiction rules, and thematic classification intentionally remain
  application responsibilities.
- [`assign_spatial_groups()`](https://prigasg.github.io/explodemap/reference/assign_spatial_groups.md)
  now uses deterministic bounding-box centers, farthest-point
  initialization, and a local Lloyd iteration, eliminating all
  reads/writes and incidental initialization of `.Random.seed`. Geometry
  vertex counting now also supports mixed `sfc_GEOMETRY` collections.
- Synchronized the bundled Pipeline Studio with dragmapr’s
  generation-safe editor, spatial feature deletion/undo support,
  reactive-safe single-flight processing, and large-layout optimization
  guard.
- Added renderer-neutral accessors for computed layouts:
  [`original_geometry()`](https://prigasg.github.io/explodemap/reference/original_geometry.md),
  [`local_geometry()`](https://prigasg.github.io/explodemap/reference/original_geometry.md),
  [`final_geometry()`](https://prigasg.github.io/explodemap/reference/original_geometry.md),
  [`group_geometry()`](https://prigasg.github.io/explodemap/reference/original_geometry.md),
  [`anchor_table()`](https://prigasg.github.io/explodemap/reference/anchor_table.md),
  [`layout_offsets()`](https://prigasg.github.io/explodemap/reference/layout_offsets.md),
  [`transition_data()`](https://prigasg.github.io/explodemap/reference/transition_data.md),
  and
  [`connector_geometry()`](https://prigasg.github.io/explodemap/reference/connector_geometry.md).
  These provide stable geometry, movement, animation-order, and
  connector contracts without requiring downstream renderers to inspect
  layout internals.
- Feature-level handoffs now require stable identifiers by default.
  Input preparation generates deterministic geometry-and-label-based
  `unit_id` values when no source ID is supplied, so reordering features
  does not change persistent handoff identities. Legacy row-number
  fallback remains explicitly available with
  `require_stable_id = FALSE`.
- Strengthened `dragmapr` interoperability with explicit region and
  label ID metadata where supported, parameter-aware geometry
  fingerprints, and stable computed-versus-editorial offset contracts.

## explodemap 0.3.1

- Layout objective terms are now dimensionless, making objective weights
  portable across datasets and coordinate scales. Label-aware searches
  use one fixed default label size across candidate layouts, and label
  collision counts now use an indexed spatial query with missing and
  display-width-aware labels.
- Input preparation now preserves colliding source columns, reports
  collisions, surfaces invalid status and validation errors when
  printed, restores fresh session RNG state, avoids duplicate generated
  palette colours, and produces portable in-memory geometry
  fingerprints.
- Geometry vertex counting and simplification-budget searches avoid
  repeated per-feature coordinate extraction and unnecessary
  simplification passes.
- [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  now simplifies longitude/latitude widget data in a local metric
  projection and rejects unsafe custom degree tolerances.

## explodemap 0.3.0

- Release A of the Pipeline Studio extraction adds reusable
  input-preparation primitives:
  [`count_geometry_vertices()`](https://prigasg.github.io/explodemap/reference/count_geometry_vertices.md),
  [`simplify_to_vertex_budget()`](https://prigasg.github.io/explodemap/reference/simplify_to_vertex_budget.md),
  [`assign_spatial_groups()`](https://prigasg.github.io/explodemap/reference/assign_spatial_groups.md),
  [`validate_explodemap_input()`](https://prigasg.github.io/explodemap/reference/validate_explodemap_input.md),
  [`prepare_explodemap_input()`](https://prigasg.github.io/explodemap/reference/prepare_explodemap_input.md),
  [`group_palette()`](https://prigasg.github.io/explodemap/reference/group_palette.md),
  and
  [`e_fingerprint()`](https://prigasg.github.io/explodemap/reference/e_fingerprint.md).
  These functions move proven geometry, validation, palette,
  simplification, grouping, and compatibility helpers out of the app
  layer while keeping upload policy and UI orchestration in Pipeline
  Studio.
- [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  no longer emits the noisy “st_simplify does not correctly simplify
  longitude/latitude data” warning when it simplifies its WGS84 widget
  copy; the simplification is render-only and the warning is now
  suppressed. (Pass `simplify = FALSE`, or pre-simplify in a projected
  CRS, when dense layers such as municipalities look over-angular.)
- New `inst/shiny/pipeline-studio` Shiny app (shipped with both
  explodemap and dragmapr) demonstrates the full cross-package workflow
  on real US geography: the national HHS exploded map and a state county
  drill-down with diagnostics and label-aware search, the dragmapr
  draggable editor with `dragmapr_state` round-trip, and a combined
  compute -\> compose -\> render -\> persist studio. Run with
  `shiny::runApp(system.file("shiny/pipeline-studio", package = "explodemap"))`.
- Added `inst/examples/explodemap_dragmapr_pipeline.R`, a complete
  cross-package example covering layout optimization, diagnostics,
  editable state, JSON persistence,
  [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md),
  and
  [`dragmapr::render_dragged_map()`](https://prigasg.github.io/dragmapr/reference/render_dragged_map.html).
- [`as_dragmapr_state()`](https://prigasg.github.io/explodemap/reference/as_dragmapr_state.md)
  is the preferred state-first bridge to `dragmapr`, emitting a
  [`dragmapr::d_state()`](https://prigasg.github.io/dragmapr/reference/d_state.html)
  that `state =` arguments accept across
  [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md),
  [`render_dragged_map()`](https://prigasg.github.io/dragmapr/reference/render_dragged_map.html),
  and
  [`update_exploded_layout()`](https://prigasg.github.io/explodemap/reference/update_exploded_layout.md).
  The older
  [`as_dragmapr()`](https://prigasg.github.io/explodemap/reference/as_dragmapr.md)
  is now documented as legacy/low-level (still supported, not
  deprecated).
- [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  gains `restore_selection` (default `FALSE`): when `TRUE` and the
  supplied `state` carries a `selected_feature`, the map opens focused
  on that feature, reproducing a saved composition’s focus. The behavior
  is fully opt-in, so default renders are unchanged.
- New `inst/examples/state_first_workflow.R` shows the canonical
  pipeline:
  [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md)
  -\>
  [`as_dragmapr_state()`](https://prigasg.github.io/explodemap/reference/as_dragmapr_state.md)
  -\>
  [`d_edit()`](https://prigasg.github.io/dragmapr/reference/d_edit.html)
  -\> `focus_map(state = )` / `render_dragged_map(state = )`.
- [`update_focus_palette()`](https://prigasg.github.io/explodemap/reference/focusMapProxy.md)
  now preserves the palette’s names so the browser can key
  `groupPalette` by group. Previously the colours were sent as an
  unnamed array and silently ignored (the map fell back to the automatic
  palette). The focus-map proxy operations
  ([`update_focus_labels()`](https://prigasg.github.io/explodemap/reference/focusMapProxy.md),
  [`update_focus_palette()`](https://prigasg.github.io/explodemap/reference/focusMapProxy.md),
  [`update_focus_data()`](https://prigasg.github.io/explodemap/reference/focusMapProxy.md))
  now have regression tests.
- [`update_focus_data()`](https://prigasg.github.io/explodemap/reference/focusMapProxy.md)
  documents its behavior explicitly: a data swap rebuilds the widget and
  returns it to the idle view. Pass `state` and
  `restore_selection = TRUE` through `...` to keep a feature focused
  across the swap.
- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) on a
  [`diagnose_layout()`](https://prigasg.github.io/explodemap/reference/diagnose_layout.md)
  report now draws the region blocks inside the layout’s canvas frame
  (so unused space is visible) and a red segment between every
  overlapping region pair, instead of plotting bare anchor points.
- [`optimize_grouped_layout()`](https://prigasg.github.io/explodemap/reference/optimize_grouped_layout.md)
  gains `label_col` / `label_size`. When supplied, the parameter search
  becomes label-aware – each candidate is scored for approximate label
  overlaps via the `label_overlap` objective weight. Left `NULL` (the
  default) the result is identical to before.
- [`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
  now validates the active sf geometry column up front, so a malformed
  `sf` fails with the same clear message used by
  [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md)
  and
  [`explode_grouped()`](https://prigasg.github.io/explodemap/reference/explode_grouped.md)
  rather than a deep, cryptic error.

## explodemap 0.2.0

CRAN release: 2026-05-27

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
- Added the first `dragmapr_state` bridge:
  [`as_dragmapr_state()`](https://prigasg.github.io/explodemap/reference/as_dragmapr_state.md)
  exports a grouped layout as a shared editorial composition state, and
  [`update_exploded_layout()`](https://prigasg.github.io/explodemap/reference/update_exploded_layout.md)
  / `focus_map(state = ...)` can consume that state after manual
  editing.

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
