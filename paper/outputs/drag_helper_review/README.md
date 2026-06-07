# Drag Helper Review

This folder contains visual review artifacts for the all-state drag helper
pass. The helper pages themselves live in:

- `paper/outputs/drag_helpers/<state>/index.html`
- `paper/outputs/drag_helpers/<state>/map.geojson`

Serve `paper/outputs` locally and open the helper index URLs from
`paper/outputs/tables/drag_helper_index.csv`. For example:

```sh
python -m http.server 8765 --bind 127.0.0.1 --directory paper/outputs
```

Then open:

```text
http://127.0.0.1:8765/drag_helpers/pa/index.html
```

Saved manual offsets are stored in
`paper/outputs/tables/<state>_drag_offsets.csv`. The helper pages initialize
from those CSVs, so the visible layout matches the documented offset state.
States without an offset CSV use the formula-derived helper layout.

## Review Outputs

- `screenshots/`: browser screenshots of each helper page.
- `contact_sheet_*.png`: formula/helper screenshots for quick visual scan.
- `offset_contact_sheet_*.png`: rendered layouts after applying saved offsets.
- `render_audit.json`: browser render metadata for the helper pages.
- `helper_page_offset_load_audit.json`: browser verification metadata for
  offset loading.

The tabular audits are stored in `paper/outputs/tables`:

- `drag_helper_geometry_audit.csv`
- `dragged_layout_overlap_audit.csv`
- `dragged_layout_formula_vs_manual_audit.csv`

## Current Review Status

After applying saved manual offsets:

- OK: 49 states
- Needs more offset work: MN

Minnesota remains the only state above the current overlap threshold. The
remaining overlap signal is between the Metro and North regions.
