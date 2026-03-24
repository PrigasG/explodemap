# explodemap 0.2.0

## New features

* Three-level grouped layout engine via `explode_grouped()`, supporting
  `"auto"`, `"auto_collision"`, and `"manual"` anchor modes (Section 12
  of the paper).
* `layout_regions()` computes anchor positions as a standalone step for
  custom workflows.
* `estimate_block_radii()` estimates per-region block radii using the
  85th percentile of unit-to-centroid distances.
* `export_topojson()` exports exploded maps as TopoJSON via external
  `mapshaper` CLI tool (optional, requires `npm install -g mapshaper`).
* `summary.grouped_exploded_map()` provides full diagnostic output
  including Level 1 parameters, anchor parameters, and block radii.
* `fmt_dist()` internal helper for adaptive km/m formatting in print
  output (fixes "0 km" display on small test geometries).

## Improvements

* All centroid operations now use `st_geometry()` to avoid sf attribute
  warnings. Shared `centroid_geoms()` helper used throughout.
* `compute_stats()` accepts `centroid_fun` parameter for consistent
  centroid semantics across stats and displacement.
* `validate_input()` returns visibly (not `invisible()`).
* `explode_sf_core()` demoted to internal (`@keywords internal`).
* Grouped class inheritance: `c("grouped_exploded_map", "exploded_map", "list")`.
* Duplicate S3 methods removed from `grouped.R`; all methods live in
  `methods.R`.
* Direction comments in `core.R` corrected: "Cs → Cr" and "Cr → Ci".
* Variable naming in `methods.R` standardised: `params` not `p`.

## Documentation

* Three vignettes: getting-started, grouped-layouts,
  reproducing-paper-examples.
* `pkgdown` site configuration with hex logo.
* `R/explodemap-package.R` added for `.data` pronoun import.

---

# explodemap 0.1.0

## Initial release

* Core two-level displacement engine (`explode_sf_core()`).
* Three public entry points: `explode_sf()`, `explode_sf_with_lookup()`,
  `explode_state()`.
* Analytical parameter derivation via `derive_params()` implementing
  Analytical Results 1 and 2.
* Geometry statistics via `compute_stats()`.
* S3 class `exploded_map` with `print()`, `plot()`, `summary()` methods.
* `calibration_row()` for cross-dataset calibration tables.
* TIGER/Line download and caching via `explode_state()`.
* State registry with NJ, PA, OH, NY configurations.
* Example scripts for cross-state calibration, Canada validation, and
  HHS grouped layout.
