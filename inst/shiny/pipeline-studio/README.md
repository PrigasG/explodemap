# Pipeline Studio: explodemap + dragmapr

A Shiny app that makes the two packages feel like one connected tool. There is a
single source of truth - one `dragmapr_state` - and you move it through a loop:

```text
Explore (explodemap)  ->  Refine (dragmapr)  ->  Apply  ->  Export
        ^---------------------------------------------|
```

## The loop

1. **Explore** - explodemap renders the canonical layout (the "face"). Pick a
   map (national HHS regions, a state's counties/municipalities, or an uploaded
   polygon layer), optionally run a label-aware parameter search, and inspect
   the layout with `diagnose_layout()`. The Explore controls include shared
   label visibility switches and municipality focus presets so parent counties
   can be inspected as child municipality layouts without leaving the bridge.
2. **Refine** - if the layout is off from what you expected, open it in the
   dragmapr editor. Dragging changes a *draft* only, so nothing downstream
   moves until you commit. The Refine controls are the subtle Spatial Studio
   ones: label visibility, origin outlines, movement connectors, drag trail,
   background, and region selection - wired live with `updateDragmapr()` where
   the widget supports live updates.
3. **Apply** - push the draft back. It becomes the new canonical layout, and the
   Explore view now reflects your fix. This is the round trip: a dragmapr edit
   becomes the new face of explodemap.
4. **Export** - render the canonical composition statically with
   `render_dragged_map()` and save it (PNG or `dragmapr_state` JSON), or load a
   saved state back in.

Because dragging only touches the draft, the canonical `focus_map()` and static
renders refresh exactly when you **Apply** - never per drag, and nothing is
recomputed.

Each stage's sidebar shows only the controls that stage needs: compute and
diagnostics on Explore, drag display + selection on Refine, title/label/save/load
on Export.

## Run

The app ships with both packages and needs both installed:

```r
shiny::runApp(system.file("shiny/pipeline-studio", package = "explodemap"))
shiny::runApp(system.file("shiny/pipeline-studio", package = "dragmapr"))
```

## Data

The app is self-contained. If pre-baked boundary data is available it uses real
US geography (`us_states.rds` for the HHS map, `<ST>_counties.rds` for the
drill-down); otherwise every source falls back to synthetic projected geometry,
so a clean package install still renders. No runtime network calls.

Uploaded U.S. polygon layers are handled as an explicit four-step path: upload a
polygon file, configure feature IDs/labels/parent groups, explode the prepared
layer, then optionally refine it in dragmapr. Uploaded data is projected to
NAD83 / Conus Albers (EPSG:5070) for layout calculations. GeoPackage, GeoJSON,
zipped shapefile, JSON, and RDS uploads are supported for local/package demos.
Public deployments should keep the feature and vertex limits conservative.

Point at a local data folder with:

```r
Sys.setenv(APP_DATA_DIR = "/path/to/data")
```

## Standalone deployment

Copy this folder and, if desired, place `.rds` data files in a sibling `data/`
directory or set `APP_DATA_DIR`. The single `app.R` depends on `shiny`, `bslib`,
`sf`, `dplyr`, `ggplot2`, `explodemap`, and `dragmapr`.

## Notes

- The state drill-down groups a state's counties into North/South/East/West
  regions from centroids; the national source groups real states by HHS region.
  Swap in your own `region` column for production use.
- Larger sources (more counties) make the optional diagnostics and label-aware
  search slower; the synthetic fallback is intentionally small.
