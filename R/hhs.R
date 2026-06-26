# HHS reference helpers -------------------------------------------------------

.hhs_state_names <- c(
  "Maine", "New Hampshire", "Vermont", "Massachusetts", "Rhode Island", "Connecticut",
  "New York", "New Jersey", "Puerto Rico", "United States Virgin Islands",
  "Pennsylvania", "Delaware", "Maryland", "District of Columbia", "Virginia", "West Virginia",
  "North Carolina", "South Carolina", "Georgia", "Florida", "Alabama", "Mississippi", "Tennessee", "Kentucky",
  "Minnesota", "Wisconsin", "Illinois", "Indiana", "Michigan", "Ohio",
  "Arkansas", "Louisiana", "New Mexico", "Oklahoma", "Texas",
  "Iowa", "Kansas", "Missouri", "Nebraska",
  "Colorado", "Montana", "North Dakota", "South Dakota", "Utah", "Wyoming",
  "Arizona", "California", "Hawaii", "Nevada", "Commonwealth of the Northern Mariana Islands", "American Samoa", "Guam",
  "Alaska", "Idaho", "Oregon", "Washington"
)

.hhs_stusps <- c(
  "ME", "NH", "VT", "MA", "RI", "CT",
  "NY", "NJ", "PR", "VI",
  "PA", "DE", "MD", "DC", "VA", "WV",
  "NC", "SC", "GA", "FL", "AL", "MS", "TN", "KY",
  "MN", "WI", "IL", "IN", "MI", "OH",
  "AR", "LA", "NM", "OK", "TX",
  "IA", "KS", "MO", "NE",
  "CO", "MT", "ND", "SD", "UT", "WY",
  "AZ", "CA", "HI", "NV", "MP", "AS", "GU",
  "AK", "ID", "OR", "WA"
)

.hhs_region_ids <- as.character(c(
  rep(1, 6), rep(2, 4), rep(3, 6), rep(4, 8), rep(5, 6),
  rep(6, 5), rep(7, 4), rep(8, 6), rep(9, 7), rep(10, 4)
))

.hhs_region_cities <- c(
  "Boston", "New York", "Philadelphia", "Atlanta", "Chicago",
  "Dallas", "Kansas City", "Denver", "San Francisco", "Seattle"
)

#' HHS regional assignments for states and territories
#'
#' Returns the lookup table used by the explodemap gallery's national HHS view.
#' It includes the 50 states, District of Columbia, Puerto Rico, U.S. Virgin
#' Islands, Guam, American Samoa, and the Northern Mariana Islands.
#'
#' @return A data frame with state name, postal/territory code, region id, and
#'   display labels.
#' @export
hhs_regions <- function() {
  region_name <- hhs_region_names()
  data.frame(
    state = tolower(.hhs_state_names),
    state_name = .hhs_state_names,
    STUSPS = .hhs_stusps,
    hhs_region = .hhs_region_ids,
    hhs_region_name = unname(region_name[.hhs_region_ids]),
    stringsAsFactors = FALSE
  )
}

#' HHS region display names
#'
#' @param short Logical. When `TRUE`, returns labels such as `"HHS 1"`;
#'   otherwise returns labels such as `"1 - Boston"`.
#' @return A named character vector keyed by region id.
#' @export
hhs_region_names <- function(short = FALSE) {
  if (isTRUE(short)) {
    return(stats::setNames(paste0("HHS ", as.character(1:10)), as.character(1:10)))
  }
  stats::setNames(
    paste0(as.character(1:10), " - ", .hhs_region_cities),
    as.character(1:10)
  )
}

#' HHS region colour palette
#'
#' @return A named character vector keyed by region id.
#' @export
hhs_palette <- function() {
  stats::setNames(
    c(
      "#A89A83", "#C764A6", "#2B4970", "#DF514F", "#309396",
      "#70A255", "#F2BE42", "#8459A0", "#872722", "#3579B0"
    ),
    as.character(1:10)
  )
}

#' HHS reference-layout display offsets
#'
#' These offsets are a small documented finishing step for the national HHS
#' reference view. They are interpreted in metres for projected layouts.
#'
#' @return A data frame with `region`, `dx_m`, and `dy_m`.
#' @export
hhs_display_offsets <- function() {
  data.frame(
    region = as.character(1:10),
    dx_m = c(-16354, -65414, 0, -228949, -130828, -498782, -245303, -237126, -449721, -327070),
    dy_m = c(-106298, 32707, -139005, -81768, 16354, 81768, 245303, -24530, -24530, 40884),
    stringsAsFactors = FALSE
  )
}

#' Standardize state polygons for HHS reference maps
#'
#' Adds `hhs_region`, `state_label`, and `state_geoid` columns to state or
#' territory polygons and transforms long-lat data to a projected CRS.
#'
#' @param states An `sf` object with either `hhs_region`, `region`, `STUSPS`, or
#'   `NAME` columns.
#' @param crs Target projected CRS used when `states` is long-lat. Default is
#'   EPSG:5070.
#' @return An `sf` object filtered to HHS-assigned states and territories.
#' @export
as_hhs_states <- function(states, crs = 5070) {
  stopifnot(inherits(states, "sf"))
  lookup <- hhs_regions()

  if (!("hhs_region" %in% names(states))) {
    if ("region" %in% names(states)) {
      states$hhs_region <- as.character(states$region)
    } else if ("STUSPS" %in% names(states)) {
      states <- dplyr::left_join(
        dplyr::mutate(states, STUSPS = as.character(.data$STUSPS)),
        dplyr::select(lookup, dplyr::all_of(c("STUSPS", "hhs_region"))),
        by = "STUSPS"
      )
    } else if ("NAME" %in% names(states)) {
      states <- dplyr::left_join(
        dplyr::mutate(states, state = tolower(.data$NAME)),
        dplyr::select(lookup, dplyr::all_of(c("state", "hhs_region"))),
        by = "state"
      )
    } else {
      stop("`states` must contain hhs_region, region, STUSPS, or NAME.", call. = FALSE)
    }
  }

  states <- dplyr::filter(states, !is.na(.data$hhs_region))
  states$hhs_region <- as.character(states$hhs_region)

  if (!("state_label" %in% names(states))) {
    if ("NAME" %in% names(states)) {
      states$state_label <- as.character(states$NAME)
    } else if ("STUSPS" %in% names(states)) {
      states$state_label <- as.character(states$STUSPS)
    } else {
      states$state_label <- as.character(seq_len(nrow(states)))
    }
  }

  if (!("state_geoid" %in% names(states))) {
    if ("GEOID" %in% names(states)) {
      states$state_geoid <- as.character(states$GEOID)
    } else if ("STUSPS" %in% names(states)) {
      states$state_geoid <- as.character(states$STUSPS)
    } else {
      states$state_geoid <- paste0("state_", seq_len(nrow(states)))
    }
  }

  if (is.na(sf::st_crs(states))) {
    sf::st_crs(states) <- 4326
  }
  if (isTRUE(sf::st_is_longlat(states))) {
    states <- sf::st_transform(states, crs)
  }

  states
}

#' Build an HHS reference layout
#'
#' @param states An `sf` object of state or territory polygons.
#' @param apply_offsets Logical. Apply the documented gallery display offsets?
#' @param offsets Offset data frame, usually from `hhs_display_offsets()`.
#' @param source Optional source label stored in the returned list.
#' @return A list with `states`, `labels`, and `source`.
#' @export
hhs_layout <- function(states,
                       apply_offsets = TRUE,
                       offsets = hhs_display_offsets(),
                       source = "user data") {
  states <- as_hhs_states(states)
  labels <- .hhs_region_label_points(states)
  if (isTRUE(apply_offsets)) {
    offsets <- dplyr::filter(
      offsets,
      as.character(.data$region) %in% unique(as.character(states$hhs_region))
    )
    states <- apply_region_offsets(
      states,
      offsets,
      region_col = "hhs_region",
      offset_region_col = "region"
    )
    labels <- dplyr::left_join(
      dplyr::mutate(labels, region = as.character(.data$region)),
      offsets,
      by = c(region = "region")
    )
    labels <- dplyr::mutate(
      labels,
      dx_m = dplyr::coalesce(.data$dx_m, 0),
      dy_m = dplyr::coalesce(.data$dy_m, 0),
      x = .data$x + .data$dx_m,
      y = .data$y + .data$dy_m
    )
    labels <- dplyr::select(labels, dplyr::all_of(c("region", "x", "y")))
  }

  list(
    states = states,
    labels = dplyr::arrange(labels, as.integer(.data$region)),
    source = source
  )
}

#' Create a focus-map widget for HHS regions
#'
#' @param states An `sf` object of state or territory polygons.
#' @param apply_offsets Logical. Apply `hhs_display_offsets()` before drawing?
#' @param show_region_labels Logical. Show one passive HHS label per region.
#' @param show_drag_zoom Logical. Show the drag-to-zoom button.
#' @param show_labels Logical. Show labels on lifted states/territories.
#' @param ... Additional arguments passed to [focus_map()].
#' @return An `htmlwidgets` focus-map widget.
#' @export
hhs_focus_map <- function(states,
                          apply_offsets = TRUE,
                          show_region_labels = TRUE,
                          show_drag_zoom = TRUE,
                          show_labels = TRUE,
                          ...) {
  layout <- hhs_layout(states, apply_offsets = apply_offsets)
  states <- dplyr::mutate(
    layout$states,
    hhs_region_name = hhs_region_names()[as.character(.data$hhs_region)]
  )

  focus_map(
    states,
    label_col = "state_label",
    id_col = "state_geoid",
    group_col = "hhs_region",
    coordinate_system = "planar",
    group_palette = hhs_palette(),
    info_cols = c("state_label", "STUSPS", "hhs_region_name"),
    info_labels = c(
      state_label = "State / territory",
      STUSPS = "Code",
      hhs_region_name = "HHS region"
    ),
    info_title = "state_label",
    origin_context = "socket",
    show_drag_zoom = isTRUE(show_drag_zoom),
    show_labels = isTRUE(show_labels),
    show_group_labels = isTRUE(show_region_labels),
    group_labels = hhs_region_names(short = TRUE),
    area_min = 0,
    width_min = 0,
    height_min = 0,
    focus_size = 0.82,
    focus_padding = 46,
    info_card_scale = 1.05,
    performance_mode = TRUE,
    simplify = FALSE,
    ...
  )
}

.hhs_region_label_points <- function(states) {
  labels_sf <- suppressWarnings(sf::st_centroid(dplyr::summarize(
    dplyr::group_by(states, .data$hhs_region),
    geometry = sf::st_union(.data$geometry),
    .groups = "drop"
  )))
  coords <- sf::st_coordinates(labels_sf)
  dplyr::arrange(
    data.frame(
      region = as.character(labels_sf$hhs_region),
      x = coords[, 1],
      y = coords[, 2],
      stringsAsFactors = FALSE
    ),
    as.integer(.data$region)
  )
}
