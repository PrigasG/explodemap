# Paper Reproducibility Scripts

These scripts regenerate the main validation tables and figures used by the
explodemap paper from public boundary data and the package API.

Run from the package root:

```r
source("paper/scripts/01_pa_validation.R")
source("paper/scripts/02_cross_state_validation.R")
source("paper/scripts/03_canada_validation.R")
source("paper/scripts/04_hhs_grouped_layout.R")
```

To regenerate the interactive paper drag helpers for registered cases, run:

```r
source("paper/scripts/07_generate_drag_helpers.R")
```

The committed helper output inventory includes all 50 U.S. states under
`paper/outputs/drag_helpers/<state>/index.html`, plus Canada and Germany.
The helper pages load saved manual offsets from
`paper/outputs/tables/<state>_drag_offsets.csv` when those CSVs exist.
States without an offset file use the formula-derived helper layout.

To render the documented offset layouts for every state listed in
`paper/outputs/tables/drag_helper_index.csv`, run:

```r
source("paper/scripts/08_render_dragged_layouts.R")
```

The current review pass writes summary outputs to:

- `paper/outputs/drag_helper_review`: screenshots, contact sheets, and
  browser-load audits for visual review.
- `paper/outputs/tables/dragged_layout_overlap_audit.csv`: formula and
  manual-offset overlap metrics.
- `paper/outputs/tables/dragged_layout_formula_vs_manual_audit.csv`:
  before/after comparison, offset magnitudes, and review status.

Outputs are written to:

- `paper/outputs/figures`
- `paper/outputs/tables`
- `paper/outputs/logs`
- `paper/outputs/drag_helpers`

The scripts download public U.S. Census TIGER/Line 2024 and Statistics Canada
2021 boundaries as needed. Repeated runs use the package cache where possible.

The old exploratory files in `C:/Users/priga/Downloads/d3` were used as source
material for region maps, validation logic, and HHS settings. These scripts are
the cleaned, reproducible versions for review.
