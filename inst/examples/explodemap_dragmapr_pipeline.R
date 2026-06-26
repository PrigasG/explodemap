# End-to-end explodemap + dragmapr pipeline.
#
# Run with:
#   source(system.file("examples/explodemap_dragmapr_pipeline.R", package = "explodemap"))

if (!requireNamespace("dragmapr", quietly = TRUE)) {
  stop("Install dragmapr to run this cross-package example.", call. = FALSE)
}

library(explodemap)
library(dragmapr)

make_square <- function(x0, y0, size = 30000) {
  sf::st_polygon(list(rbind(
    c(x0, y0), c(x0 + size, y0), c(x0 + size, y0 + size),
    c(x0, y0 + size), c(x0, y0)
  )))
}

# A compact synthetic "service territory" with four related regions. The
# geometry is intentionally crowded so diagnostics and composition matter.
grid <- expand.grid(col = 0:3, row = 0:2)
region <- c(
  "North", "North", "Core", "Core",
  "West",  "West",  "Core", "East",
  "West",  "South", "South", "East"
)

service_areas <- sf::st_sf(
  unit_id = sprintf("u%02d", seq_len(12)),
  unit_name = paste(region, seq_len(12)),
  region = region,
  cases = c(42, 38, 95, 88, 34, 31, 102, 55, 29, 48, 44, 61),
  geometry = sf::st_sfc(
    lapply(seq_len(12), function(i) {
      make_square(grid$col[i] * 34000, grid$row[i] * 34000)
    }),
    crs = 3857
  )
)

# Compute several mathematically valid layouts and choose the one that best
# balances overlap, compactness, displacement, and approximate label conflicts.
search_grid <- expand.grid(
  kappa = c(1.4, 1.8),
  padding = c(20000, 45000),
  delta = c(5000, 15000),
  padding_sep = c(10000, 25000),
  KEEP.OUT.ATTRS = FALSE
)

layout <- optimize_grouped_layout(
  service_areas,
  region_col = "region",
  label_col = "unit_name",
  grid = search_grid
)

report <- diagnose_layout(layout, label_col = "unit_name")
print(report)
if (interactive()) print(plot(report))

# Hand the computed geometry to dragmapr as an editable composition state.
state <- as_dragmapr_state(layout, geometry_id = "service-territory-demo-v1")

# Simulate a small editorial pass. In a real session this state comes back from:
#   state <- dragmapr_widget_state(input$map_state)
state$region_offsets$dx_m[state$region_offsets$region == "East"] <- 25000
state$region_offsets$dy_m[state$region_offsets$region == "East"] <- -8000
state$region_offsets$dx_m[state$region_offsets$region == "South"] <- -12000
state$region_offsets$dy_m[state$region_offsets$region == "South"] <- -18000
state$selected_feature <- "East"

composed_layout <- update_exploded_layout(layout, state)

state_path <- file.path(tempdir(), "service-territory-composition.json")
write_dragmapr_state(state, state_path)
message("Saved composition state to: ", state_path)

if (interactive()) {
  editor <- dragmapr_edit(layout, state = state, label_col = "unit_name")
  print(editor)

  focus <- focus_map(
    composed_layout,
    state = state,
    label_col = "unit_name",
    group_col = "region",
    info_cols = c("cases"),
    restore_selection = TRUE
  )
  print(focus)
}

png_path <- file.path(tempdir(), "service-territory-composed.png")
static_map <- render_dragged_map(
  layout$sf_grouped,
  region_col = "region",
  label_col = "unit_name",
  state = state,
  title = "Service territory composition",
  file = png_path
)
message("Wrote static map to: ", png_path)

static_map
