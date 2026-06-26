# explodemap + dragmapr roadmap

This roadmap captures the package boundary revealed by Pipeline Studio. The
packages should own reusable geometry and editable-state behavior; Pipeline
Studio should own upload policy, navigation, overlays, and the public demo
journey.

## Release A: proven primitives

Export small, workflow-neutral functions that are already used by multiple
parts of the bridge app.

### explodemap

- `count_geometry_vertices(x)`
- `simplify_to_vertex_budget(x, target_vertices = 350000, ...)`
- `assign_spatial_groups(x, method = c("quadrants", "clusters", "individual"), ...)`
- `validate_explodemap_input(x, group_col, id_col = NULL, label_col = NULL, ...)`
- `prepare_explodemap_input(x, ...)`
- `group_palette(groups, palette = "Dark 3", existing = NULL)`
- `explodemap_fingerprint(x, id_col = NULL, group_col = NULL, include_geometry = TRUE)`

Validation and preparation should return structured S3 objects with
`format_version = 1L`, metrics, warnings, errors, and print methods. Preparation
must be transparent: report CRS changes, ID choices, grouping choices,
simplification tolerance, geometry repairs, and clustering seeds.

### dragmapr

- `dragmapr_state_diff(draft, canonical, tolerance = 1, compare = "composition")`
- `dragmapr_state_equal(a, b, tolerance = 1, compare = "composition")`
- stronger `validate_dragmapr_state(state, x = NULL, layout = NULL, geometry_id = NULL, strict = TRUE)`
- `summary.dragmapr_state()`
- first-class palette arguments for `dragmapr_widget(..., region_palette = palette)` and `updateDragmapr(..., region_palette = palette)`

State comparison should distinguish composition changes from interaction-only
changes such as selection or viewport updates.

## Release B: app refactor

Refactor Pipeline Studio to consume Release A primitives. The app should lose
local copies of vertex counting, simplification, spatial grouping, validation,
fingerprinting, palette generation, and state diff helpers.

After the refactor, inspect the remaining canonical/draft code:

- `rv$state`
- `rv$draft`
- `rv$palette`
- `rv$saved`
- `remember_current()`
- `set_canonical()`

That remaining code should determine whether a project abstraction is truly
needed.

## Release C: internal project prototype

Prototype a low-level `dragmapr_project` internally before exporting it:

- `new_dragmapr_project(canonical, draft = canonical, palette = NULL, metadata = list())`
- `project_is_dirty(project)`
- `project_diff(project)`
- `project_apply(project)`
- `project_reset_draft(project)`

Avoid Shiny-specific concepts, source registries, navigation stages, export
behavior, and Pipeline Studio terminology.

## Release D: experimental project API

Export the project object only after it survives Pipeline Studio and at least
one non-Studio workflow. Mark it experimental at first.

## Keep app-level

These should remain Pipeline Studio or Shiny-helper code:

- upload archive inspection and safe extraction
- GeoPackage layer selection
- public deployment limits
- processing overlays
- source registry and bundled-data fallback
- notifications, modals, navigation, and download buttons
- the Explore -> Refine -> Apply -> Export user journey

## Cross-package ownership

- `explodemap` owns exploded layouts, input preparation, diagnostics,
  fingerprints, group palettes, `focus_map()`, and applying editable state back
  to exploded layouts.
- `dragmapr` owns editable composition state, state validation, state
  comparison, state serialization, interactive editing, proxy updates, and any
  future project state.
- Adapters should be directional and avoid hard circular dependencies.
