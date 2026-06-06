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

To regenerate the interactive paper drag helpers, run:

```r
source("paper/scripts/07_generate_drag_helpers.R")
```

The default helper batch includes 26 U.S. state cases:

- NJ, PA, OH, MI, KY, IL, ND, NC, VA, TN, GA, MN, CA, CO, TX, FL
- AZ, IN, MA, MO, NV, NY, OR, SC, UT, WA

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
