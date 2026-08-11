# The canonical state-first pipeline across explodemap + dragmapr:
#
#   explode_grouped()      compute a mathematically valid exploded layout
#        |
#   as_dragmapr_state()    hand it over as a d_state (the shared
#        |                 editorial composition contract: deltas + crs + id)
#        |
#   d_edit()        compose: edit the layout interactively (optional)
#        |
#   focus_map(state = )    render the composed state interactively, and
#   render_dragged_map()   reproduce it as a static image -- no recomputation
#
# Run with:
#   source(system.file("examples/state_first_workflow.R", package = "explodemap"))

library(explodemap)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

have_dragmapr <- requireNamespace("dragmapr", quietly = TRUE)
if (!have_dragmapr) {
  message("Install dragmapr to run the bridge/render steps of this example.")
}

# Geometry: a few regions, each with several units in a projected CRS.
unit_square <- function(x0, y0, size = 40000) {
  sf::st_polygon(list(rbind(
    c(x0, y0), c(x0 + size, y0), c(x0 + size, y0 + size),
    c(x0, y0 + size), c(x0, y0)
  )))
}

grid <- expand.grid(col = 0:2, row = 0:2)
regions <- sf::st_sf(
  region = rep(c("A", "B", "C"), each = 3),
  unit   = sprintf("u%02d", seq_len(9)),
  geometry = sf::st_sfc(
    lapply(seq_len(9), function(i) {
      unit_square(grid$col[i] * 50000, grid$row[i] * 50000)
    }),
    crs = 3857
  )
)

layout <- explode_grouped(regions, region_col = "region")

if (have_dragmapr) {
  state <- as_dragmapr_state(layout)

  message("Initial composition:")
  message("  geometry_id: ", state$geometry_id %||% "(none)")
  message("  crs:         ", format(state$crs))
  message("  regions:     ", paste(state$region_offsets$region, collapse = ", "))

  # In RStudio / Shiny this opens the draggable editor seeded with the layout.
  # Capture edits back into a state with dragmapr::d_widget_state().
  if (interactive()) {
    editor <- dragmapr::d_edit(layout, state = state)
    print(editor)
  }

  # Pretend the user selected region "B" while composing.
  state$selected_feature <- "B"

  # Interactive focus map; opens focused on the saved selection.
  focus_widget <- focus_map(
    layout,
    state = state,
    group_col = "region",
    restore_selection = TRUE
  )
  if (interactive()) print(focus_widget)

  # Static, reproducible image straight from geometry + state -- no recompute.
  out_png <- file.path(tempdir(), "state_first_workflow.png")
  dragmapr::render_dragged_map(
    layout$sf_grouped,
    region_col = "region",
    state = state,
    title = "Composed layout (state-first)",
    file = out_png
  )
  message("Wrote static render to: ", out_png)
}
