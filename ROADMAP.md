# explodemap + dragmapr roadmap

This roadmap captures the package boundary revealed by Pipeline Studio and the
prototype work. The packages should own reusable layout, state, validation, and
export contracts. The apps should own upload policy, navigation, public demo
limits, and the user journey.

The central contract is:

```text
computed layout movement
        +
manual editorial movement
        =
final spatial composition
```

`explodemap` owns computed/base layout movement. `dragmapr` owns manual edits,
state, labels, validation, undo-friendly operations, and reproducible export.
Pipeline Studio, Spatial Studio, and future apps should consume those package
APIs instead of recreating layout, state, label, connector, and export logic.

The first complete use case should stay US-focused. The United States gives us a
full hierarchy ladder: national layouts at the state level, state layouts at the
county level, and county layouts at municipality, tract, or place level. HHS
regions also give a useful parent-to-state workflow. That is enough to exercise
coarse, middle, and fine geography without changing country assumptions.

## Naming Rules

Use current exported names where they already exist, even when they include the
package name. For new APIs, prefer package-native verbs and nouns instead of
repeating the package name inside every function.

Examples for future APIs:

```r
layout_offsets(layout)
transition_data(layout)
original_geometry(layout)
final_geometry(layout)
connector_geometry(layout)
region_connectors(layout, state)
label_connectors(labels, state)
update_region_offset(state, region, dx_m, dy_m)
update_label_offset(state, label_id, dx_m, dy_m)
hierarchy_state(root, children = list())
```

Keep established names such as `dragmapr_state()`, `dragmapr_widget()`,
`drag_map_prototype()`, `prepare_explodemap_input()`,
`validate_explodemap_input()`, `explodemap_fingerprint()`, and
`as_dragmapr_state()` unless there is a deliberate breaking API cleanup.

## Shared Foundation

### Canonical Spatial Input

Stabilize `prepare_explodemap_input()` as the canonical preparation pipeline and
standardize its return contract. It should own the common steps now repeated in
apps: geometry repair, CRS choice, stable IDs, feature labels, parent columns,
optional simplification, vertex budgeting, and transparent reporting.

The return object should include:

```r
list(
  data = prepared_sf,
  validation = validation_result,
  crs = crs_decision,
  simplification = simplification_report,
  fingerprint = fingerprint,
  roles = list(
    id = "feature_id",
    label = "label",
    parent = "parent_id"
  )
)
```

This lets apps preserve the user's original field names while still giving both
packages a stable layout input.

### Structured Validation

Expand `validate_explodemap_input()` to return structured errors, warnings,
recommendations, and performance metrics.

The result should be easy for an app to display:

```r
list(
  valid = TRUE,
  errors = character(),
  warnings = "Geometry has 684,000 vertices.",
  recommendations = "Simplify to approximately 250,000 vertices.",
  metrics = list(
    features = 564,
    vertices = 684000,
    invalid = 3,
    empty = 0
  )
)
```

Use the same pattern for state compatibility checks in `dragmapr`.

### Stable Identity

Standardize `explodemap_fingerprint()` across package interoperability, saved
projects, and state compatibility checks. Fingerprints should cover the parts
that make a saved state safe or unsafe to reuse:

- stable feature IDs;
- parent/group IDs;
- CRS;
- geometry content when requested;
- layout method and key parameters;
- schema/package versions.

Avoid persisted IDs that depend only on row order. When apps must generate IDs,
they should be deterministic from source identifiers and hierarchy level.

## explodemap Priorities

### 1. Layout Offsets

Add a stable `layout_offsets()` accessor for computed movement. It should
describe base movement produced by the layout algorithm, not manual edits.

```r
offsets <- layout_offsets(layout, level = "group")
```

Recommended columns:

```text
feature_id
parent_id
base_dx_m
base_dy_m
anchor_x
anchor_y
```

`dragmapr` can then store manual movement separately:

```text
final_dx_m = base_dx_m + manual_dx_m
final_dy_m = base_dy_m + manual_dy_m
```

This separation is the core cross-package contract.

### 2. Transition Data

Add `transition_data()` as a renderer-neutral description of original-to-final
movement. The current browser prototypes should not have to invent animation
offsets in JavaScript.

```r
movement <- transition_data(layout)
```

Recommended columns:

```text
feature_id
parent_id
original_anchor_x
original_anchor_y
final_anchor_x
final_anchor_y
base_dx_m
base_dy_m
distance_m
angle_degrees
animation_order
```

This supports SVG, MapLibre, deck.gl, static diagnostics, reproducible exports,
and conversion to editable state.

### 3. Geometry Accessors

Applications should not inspect internal list structures. Add or stabilize
documented accessors:

```r
original_geometry(layout)
final_geometry(layout)
group_geometry(layout)
anchor_table(layout)
connector_geometry(layout)
```

Each accessor should return documented columns and classes.

### 4. Official dragmapr Handoff

Formalize and document `as_dragmapr_state()` as the official bridge from
`explodemap` layouts to `dragmapr` editing state.

The bridge should standardize:

- region IDs;
- geometry fingerprints;
- CRS;
- parent hierarchy;
- base offsets versus manual offsets;
- labels and label anchors.

The user-facing pattern should stay simple:

```r
layout <- explode_grouped(prepared, region_col = "region")
state <- as_dragmapr_state(layout)
editor <- dragmapr_edit(layout, state = state)
```

### 5. CRS Decisions

Stabilize CRS resolution as package behavior rather than app behavior. US data
can default to a national equal-area CRS where appropriate, while state and
local data can use a suitable projected CRS.

Future API:

```r
resolve_layout_crs(
  x,
  strategy = c("auto", "preserve", "utm", "laea", "aeqd", "user"),
  crs = NULL
)
```

Return a structured decision:

```r
list(
  crs = sf::st_crs(...),
  strategy = "auto",
  reason = "US-wide extent uses an equal-area working CRS.",
  centroid = c(x = ..., y = ...),
  warnings = character()
)
```

### 6. Actionable Diagnostics

Expand `diagnose_layout()` with displacement metrics, per-group findings,
actionable recommendations, and optional post-drag diagnostics.

Recommended shape:

```r
list(
  summary = list(
    overlap_count = 12,
    label_overlap_count = 8,
    minimum_gap_m = 1200,
    canvas_utilization = 0.63,
    median_displacement_m = 42000,
    maximum_displacement_m = 116000
  ),
  by_group = data.frame(...),
  overlapping_pairs = data.frame(...),
  displaced_features = data.frame(...),
  recommendations = c(
    "Increase group padding to approximately 35,000 meters.",
    "Reduce labels to the top 60 priority features."
  )
)
```

Apps should be able to zoom to the groups named in the report.

### 7. Deterministic Ordering

Expose deterministic `group_order`, `feature_order`, and `animation_order`.
Ordering should be stable across sessions and based on group position, angle
from layout center, feature position, or an optional user-supplied ordering
column.

### 8. Partial Recalculation

Support recalculating only part of a layout:

```r
recompute_groups(
  layout,
  groups,
  parameters = NULL,
  preserve_other_groups = TRUE
)
```

US use cases:

- recompute one HHS region;
- recompute one state's county layout;
- adjust only groups with remaining overlap;
- preserve manual anchors elsewhere.

### 9. Hierarchy-Aware Layouts

Make multi-level layouts explicit. A root layout can carry lazy child layouts:

```r
hierarchy <- layout_hierarchy(root = usa_states)
hierarchy <- attach_child_layout(hierarchy, parent_id = "30", child = montana_counties)
hierarchy <- attach_child_layout(hierarchy, parent_id = "34", child = new_jersey_counties)
```

The class should describe relationships without forcing every child level to be
computed up front.

## dragmapr Priorities

### 1. Safe State Mutation

Applications should not directly edit offset tables. Add helpers that validate
IDs, increment versions, and can later create history operations.

```r
state <- update_region_offset(
  state,
  region = "30",
  dx_m = 14000,
  dy_m = 1500,
  mode = "replace"
)

state <- update_label_offset(
  state,
  label_id = "30-label",
  dx_m = 4000,
  dy_m = 2500,
  mode = "increment"
)
```

Also add reset helpers:

```r
reset_region(state, "30")
reset_regions(state, c("30", "34"))
reset_label(state, "30-label")
reset_labels(state)
reset_all(state)
```

### 2. Improved State Diff

Expand `dragmapr_state_diff()` so apps can explain what changed without writing
their own offset comparison code.

```r
diff <- dragmapr_state_diff(before, after, tolerance = 1)
```

Return:

```r
list(
  moved_regions = data.frame(...),
  moved_labels = data.frame(...),
  added_regions = character(),
  removed_regions = character(),
  expanded_groups_changed = FALSE,
  view_changed = FALSE,
  selected_feature_changed = FALSE,
  summary = list(
    region_changes = 4,
    label_changes = 7
  )
)
```

### 3. Compatibility Validation

Add compatibility checks between a layout and a state:

```r
validate_state_compatibility(layout, state, strict = TRUE)
```

Check geometry fingerprint, CRS, feature IDs, region IDs, labels, hierarchy
level, schema version, and package version. Return structured errors and
migration advice.

### 4. First-Class Connector Data

Move movement connectors and label connectors out of renderer-only logic.

```r
region_lines <- region_connectors(
  layout,
  state,
  threshold_m = 1,
  include_unmoved = FALSE
)

label_lines <- label_connectors(
  labels,
  state,
  threshold_m = 1,
  connector_type = NULL
)
```

The result can be an `sf` line layer or a table with explicit anchors:

```text
id
origin_x
origin_y
final_x
final_y
distance_m
connector_type
visible
```

This supports SVG rendering, MapLibre rendering, static maps, GeoPackage export,
and diagnostics.

### 5. Formal Label Objects

Create a documented label object for text edits, visibility, priority, width,
height, connector settings, locked state, and style.

```r
labels <- drag_labels(
  data,
  id_col,
  region_col,
  label_col,
  anchor = "point_on_surface",
  priority_col = NULL
)
```

The internal table should carry:

```text
label_id
region
text
anchor_x
anchor_y
manual_dx_m
manual_dy_m
visible
priority
locked
connector
connector_type
```

### 6. Performance-Aware Label Selection

Move label thinning into package code:

```r
selected <- select_labels(
  labels,
  max_labels = 80,
  priority_col = NULL,
  always_include = NULL,
  method = "hybrid"
)

limit <- recommend_label_limit(
  feature_count = nrow(x),
  viewport = view,
  label_lengths = nchar(labels$text)
)
```

### 7. Hierarchical State

Add a root-plus-children state for US state, county, and municipality workflows:

```r
project_state <- hierarchy_state(
  root = usa_states_state,
  children = list(
    `30` = montana_counties_state,
    `34` = new_jersey_counties_state
  ),
  active_path = c("USA", "30")
)
```

Accessors:

```r
root_state(project_state)
child_state(project_state, "30")
set_child_state(project_state, "30", montana_counties_state)
remove_child_state(project_state, "30")
active_path(project_state)
set_active_path(project_state, c("USA", "34"))
```

### 8. Schema Versioning And Migration

Every persisted state should include:

```r
schema_version = "1.0.0"
package_version = as.character(utils::packageVersion("dragmapr"))
```

Add:

```r
migrate_state(state)
migrate_hierarchy_state(project_state)
```

Saved projects should remain readable as the state format evolves.

### 9. Reversible Operations

Create package-level operation objects that apps can use for Undo/Redo:

```r
operation <- new_operation(
  type = "move_region",
  target = "30",
  before = before_state,
  after = after_state,
  metadata = list(source = "widget")
)

state <- apply_operation(state, operation)
state <- reverse_operation(state, operation)
```

Operation types should include move region, move label, reset region, delete
region, restore region, change label text, lock, and unlock.

### 10. Project Bundles And Spatial Export

Continue formalizing project bundle support around:

```text
source.gpkg
state.json
hierarchy-state.json
labels.csv
palette.csv
metadata.json
preview.png
```

Add spatial export helpers:

```r
apply_state_to_sf(x, state)
connector_sf(layout, state)
write_geopackage(project_state, "us-layout.gpkg")
```

A GeoPackage export should be able to include original geometry, final geometry,
region connectors, labels, label connectors, offset tables, and metadata.

## Interoperability Contract

### Offset Semantics

Document offsets explicitly:

```text
base_dx_m, base_dy_m     from computed layout movement
manual_dx_m, manual_dy_m from browser/editor movement
final_dx_m, final_dy_m   base + manual
```

`explodemap` supplies base movement. `dragmapr` owns manual movement. Static
renderers and app exports use final movement.

### Anchors

Use explicit anchor names rather than generic `x` and `y`:

- original centroid;
- original point on surface;
- original connector anchor;
- base/final group anchor;
- label anchor;
- label connector anchor.

### CRS Responsibility

`explodemap` chooses or accepts the working CRS. `dragmapr` preserves it and
rejects incompatible state. The browser receives transform metadata so screen
movement can be converted back into working-CRS movement.

## App Refactor

The apps are revealing package API gaps. Move reusable logic down into package
functions, then keep the apps thin.

Extract from Spatial Studio:

- hierarchy recommendations;
- project bundle handling;
- label editing;
- palette handling;
- input heuristics;
- label thinning.

Extract from Pipeline Studio:

- upload validation;
- source fingerprinting;
- geometry deletion;
- state snapshotting;
- undo and redo operations;
- layout caching.

The target app shape is:

```r
server <- function(input, output, session) {
  project <- project_state()

  mod_import_server("import", project)
  mod_layout_server("layout", project)
  mod_drag_server("drag", project)
  mod_export_server("export", project)
}
```

## Keep App-Level

Keep these outside the packages:

- country or jurisdiction registry;
- MapLibre camera behavior;
- background blur and visual decoration;
- search and navigation;
- data licensing catalog;
- application dashboards;
- rendered animation frames;
- deployment-specific cache management;
- public upload limits;
- processing overlays;
- source registry and bundled-data fallback;
- notifications, modals, navigation, and download buttons.

## Implementation Order

### explodemap

1. Stabilize `prepare_explodemap_input()` return contract.
2. Expand `validate_explodemap_input()` structured results.
3. Standardize `explodemap_fingerprint()` for interoperability.
4. Formalize `as_dragmapr_state()` as the bridge.
5. Expand `diagnose_layout()` with actionable findings.
6. Add `layout_offsets()`.
7. Add `transition_data()`.
8. Add geometry and connector accessors.
9. Stabilize CRS resolution.
10. Add deterministic ordering.
11. Add partial group recalculation.
12. Add hierarchy-aware layout support.

### dragmapr

1. Add safe state mutation helpers.
2. Improve `dragmapr_state_diff()`.
3. Add state compatibility validation.
4. Add region connector output.
5. Add label connector output.
6. Formalize label objects.
7. Add label selection and label limit helpers.
8. Add state schema versioning and migration.
9. Add hierarchy state.
10. Add reversible operation primitives.
11. Expand project bundle support.
12. Add spatial export helpers.

## Minimum US-First Workflow

```r
prepared <- prepare_explodemap_input(
  states,
  id_col = "GEOID",
  label_col = "NAME",
  parent_col = "HHS_REGION",
  working_crs = "auto"
)

layout <- explode_grouped(
  prepared$data,
  region_col = "HHS_REGION"
)

state <- as_dragmapr_state(layout)

state <- update_region_offset(
  state,
  region = "4",
  dx_m = 14000,
  dy_m = 1500
)

diagnostics <- diagnose_layout(layout, state = state)
connectors <- region_connectors(layout, state)

write_dragmapr_project(
  state,
  "us-hhs-layout.zip"
)
```

That workflow should scale from US states to counties and municipalities without
requiring app-specific state or geometry logic.
