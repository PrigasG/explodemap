# =============================================================================
# R/presets.R - Interactive workflow presets
# =============================================================================

#' Focus-map option presets
#'
#' Returns a named list of [focus_map()] arguments for common interactive
#' mapping workflows. Presets are intentionally plain lists so they can be
#' inspected, modified, or passed through `do.call()`.
#'
#' @param name Preset name. `"municipal"` tunes small-area focus maps with
#'   adaptive sizing, source cues, drag zoom, and dense-layer performance.
#'   `"drilldown"` tunes selected-section maps with faded context and source
#'   cues. `"municipal_drilldown"` combines both.
#' @return A named list of [focus_map()] arguments.
#' @export
#' @examples
#' focus_map_preset("municipal")
#' \dontrun{
#' args <- c(
#'   list(x = exploded_municipalities, label_col = "NAME"),
#'   focus_map_preset("municipal")
#' )
#' do.call(focus_map, args)
#' }
focus_map_preset <- function(name = c("municipal", "drilldown", "municipal_drilldown", "none")) {
  name <- match.arg(name)

  municipal <- list(
    focus_size = 0.78,
    focus_padding = 44,
    min_focus_width = 260,
    min_focus_height = 200,
    tiny_feature_threshold = 64,
    tiny_feature_boost = 1.35,
    max_zoom = 40,
    origin_context = "both",
    origin_context_position = "top-left",
    focus_context_opacity = 0.14,
    show_drag_zoom = TRUE,
    performance_mode = TRUE
  )

  drilldown <- list(
    context_mode = "fade",
    context_opacity = 0.16,
    context_clickable = FALSE,
    origin_context = "socket",
    focus_context_opacity = 0.22
  )

  switch(
    name,
    none = list(),
    municipal = municipal,
    drilldown = drilldown,
    municipal_drilldown = utils::modifyList(drilldown, municipal)
  )
}
