# =============================================================================
# R/section.R - Section-focus exploded maps
# =============================================================================

#' Explode one selected section and keep the rest as context
#'
#' `explode_section()` is a dashboard-oriented helper for exploratory maps.
#' It applies an exploded layout only to the requested section, then recombines
#' the untouched remainder of the layer as geographic context. The result can
#' be passed directly to [focus_map()] with `context_col` to fade or hide the
#' non-selected features.
#'
#' @param sf_obj Projected `sf` object.
#' @param section_col Column containing the high-level sections users choose
#'   from, such as `"North"`, `"Central"`, and `"South"`.
#' @param section Selected section value. Values in `all_values` explode the
#'   full layer.
#' @param region_col Column used for the explosion inside the selected section.
#'   Defaults to `section_col`. For municipality drill-downs, this is often a
#'   county column.
#' @param layout `"explode"` for [explode_sf()] or `"grouped"` for
#'   [explode_grouped()].
#' @param context `"fade"` or `"hide"` keeps non-selected features in the
#'   returned object as context; `"none"` drops them.
#' @param role_col Name of the role column added to the output. Focus features
#'   are marked `"focus"` and context features are marked `"context"`.
#' @param all_values Values that mean "all sections". Default `"all"`.
#' @param ... Passed to [explode_sf()] or [explode_grouped()].
#'
#' @return An `exploded_map` or `grouped_exploded_map` object with recombined
#'   focus/context geometry and extra diagnostics.
#' @export
#'
#' @examples
#' \dontrun{
#' focused <- explode_section(
#'   municipalities,
#'   section_col = "nj_region",
#'   section = "South",
#'   region_col = "county_name",
#'   alpha_r = 1800,
#'   alpha_l = 1200,
#'   plot = FALSE
#' )
#'
#' focus_map(
#'   focused,
#'   label_col = "NAME",
#'   context_col = ".explodemap_role",
#'   context_mode = "fade"
#' )
#' }
explode_section <- function(sf_obj,
                            section_col,
                            section,
                            region_col = section_col,
                            layout = c("explode", "grouped"),
                            context = c("fade", "hide", "none"),
                            role_col = ".explodemap_role",
                            all_values = "all",
                            ...) {
  layout <- match.arg(layout)
  context <- match.arg(context)

  if (!inherits(sf_obj, "sf")) {
    stop("`sf_obj` must be an sf object.", call. = FALSE)
  }
  if (!section_col %in% names(sf_obj)) {
    stop("section_col '", section_col, "' not found in sf_obj.", call. = FALSE)
  }
  if (!region_col %in% names(sf_obj)) {
    stop("region_col '", region_col, "' not found in sf_obj.", call. = FALSE)
  }

  section <- as.character(section %||% all_values[[1]])
  all_values <- as.character(all_values)
  is_all <- length(section) == 0 || section[[1]] %in% all_values

  if (is_all) {
    sf_obj[[role_col]] <- "focus"
    result <- .explode_section_dispatch(sf_obj, region_col, layout, ...)
    result$params$section_col <- section_col
    result$params$section <- all_values[[1]]
    result$params$context <- "none"
    result$params$role_col <- role_col
    result$diagnostics$section_col <- section_col
    result$diagnostics$section <- all_values[[1]]
    result$diagnostics$n_focus <- nrow(sf_obj)
    result$diagnostics$n_context <- 0L
    return(result)
  }

  section_values <- as.character(sf_obj[[section_col]])
  focus_idx <- !is.na(section_values) & section_values %in% section
  if (!any(focus_idx)) {
    stop(
      "No features matched section value(s): ",
      paste(section, collapse = ", "),
      call. = FALSE
    )
  }

  sf_focus <- sf_obj[focus_idx, , drop = FALSE]
  sf_context <- sf_obj[!focus_idx, , drop = FALSE]
  sf_focus[[role_col]] <- "focus"
  sf_context[[role_col]] <- "context"

  result <- .explode_section_dispatch(sf_focus, region_col, layout, ...)

  if (!identical(context, "none") && nrow(sf_context) > 0) {
    if (identical(layout, "grouped")) {
      result$sf_grouped <- .combine_focus_context_sf(
        result$sf_grouped,
        sf_context,
        role_col
      )
      result$sf_grouped_wgs <- sf::st_transform(result$sf_grouped, 4326)
    } else {
      result$sf_exp <- .combine_focus_context_sf(
        result$sf_exp,
        sf_context,
        role_col
      )
      result$sf_exp_wgs <- sf::st_transform(result$sf_exp, 4326)
    }
  }

  result$params$section_col <- section_col
  result$params$section <- section
  result$params$context <- context
  result$params$role_col <- role_col
  result$diagnostics$section_col <- section_col
  result$diagnostics$section <- section
  result$diagnostics$n_focus <- nrow(sf_focus)
  result$diagnostics$n_context <- if (identical(context, "none")) 0L else nrow(sf_context)
  result
}

#' @keywords internal
.explode_section_dispatch <- function(sf_obj, region_col, layout, ...) {
  if (identical(layout, "grouped")) {
    explode_grouped(sf_obj, region_col = region_col, ...)
  } else {
    explode_sf(sf_obj, region_col = region_col, ...)
  }
}

#' @keywords internal
.combine_focus_context_sf <- function(focus_sf, context_sf, role_col) {
  context_sf <- sf::st_transform(context_sf, sf::st_crs(focus_sf))

  focus_names <- names(focus_sf)
  context_missing <- setdiff(focus_names, names(context_sf))
  for (nm in context_missing) {
    context_sf[[nm]] <- NA
  }

  context_sf <- context_sf[, focus_names, drop = FALSE]
  focus_sf[[role_col]] <- as.character(focus_sf[[role_col]])
  context_sf[[role_col]] <- as.character(context_sf[[role_col]])

  dplyr::bind_rows(focus_sf, context_sf)
}
