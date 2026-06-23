# =============================================================================
# explodemap gallery — interactive demo of hierarchical exploded-view maps
# =============================================================================
#
# A bslib Shiny app that showcases the explodemap package on pre-baked Census
# boundary data (no runtime network calls). Tabs:
#
#   1. Counties        focus_map on state counties (raw / exploded)
#   2. Municipalities  focus_map on county subdivisions
#   3. Drill-down      explode one region, fade the rest as context
#   4. National (HHS)  explode_grouped across all US states
#   5. Parameter lab   manual alpha_r / alpha_l tuning, side-by-side
#
# Data is produced by prep_data.R and read from APP_DATA_DIR (default ./data).
# =============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(sf)
  library(dplyr)
  library(ggplot2)
  library(purrr)
  library(explodemap)
})

if (!requireNamespace("ggiraph", quietly = TRUE)) {
  stop("This app needs ggiraph for the HHS reference tab. Install it with install.packages('ggiraph').", call. = FALSE)
}

# -----------------------------------------------------------------------------
# Data location + lazy bake for local first-run
# -----------------------------------------------------------------------------
app_dir  <- tryCatch(dirname(normalizePath(sys.frame(1)$ofile, mustWork = FALSE)),
                     error = function(e) getwd())
DATA_DIR <- Sys.getenv("APP_DATA_DIR", file.path(app_dir, "data"))

ensure_data <- function() {
  needed <- file.path(DATA_DIR, "us_states.rds")
  if (file.exists(needed)) return(invisible(TRUE))
  prep <- file.path(app_dir, "prep_data.R")
  if (file.exists(prep) && requireNamespace("tigris", quietly = TRUE)) {
    message("Gallery data not found — baking it now (first run only)...")
    sys.source(prep, envir = new.env(parent = globalenv()))
  }
  invisible(file.exists(needed))
}
ensure_data()

read_layer <- function(name) {
  path <- file.path(DATA_DIR, name)
  if (!file.exists(path)) {
    stop("Missing data file '", name, "'. Run prep_data.R first.", call. = FALSE)
  }
  readRDS(path)
}

# All 50 states for the Counties tab.
COUNTY_STATES <- tryCatch(
  read_layer("county_states.rds"),
  error = function(e) data.frame(
    name = c("New Jersey", "Texas", "Georgia", "California", "Pennsylvania"),
    abbr = c("NJ", "TX", "GA", "CA", "PA"),
    stringsAsFactors = FALSE
  )
)
COUNTY_CHOICES <- stats::setNames(COUNTY_STATES$abbr, COUNTY_STATES$name)

# Municipality-friendly subset for Municipalities and Drill-down tabs.
DEMO_STATES <- tryCatch(
  read_layer("demo_states.rds"),
  error = function(e) data.frame(
    name = c("New Jersey", "Pennsylvania", "New York", "Ohio", "Michigan",
             "Minnesota", "Wisconsin", "Illinois", "Texas", "Georgia"),
    abbr = c("NJ", "PA", "NY", "OH", "MI",
             "MN", "WI", "IL", "TX", "GA"),
    stringsAsFactors = FALSE
  )
)
STATE_CHOICES <- stats::setNames(DEMO_STATES$abbr, DEMO_STATES$name)

# -----------------------------------------------------------------------------
# Small shared helpers
# -----------------------------------------------------------------------------
app_error <- function(action, error) {
  paste0(
    "We could not ", action, ". ", conditionMessage(error),
    " Try a different state, mode, or a lighter setting."
  )
}

# Assign N/S/E/W quadrant regions from feature centroids (for demo grouping).
assign_quadrant_regions <- function(sf_obj) {
  centroids <- suppressWarnings(sf::st_centroid(sf_obj))
  coords <- sf::st_coordinates(centroids)
  cx <- stats::median(coords[, 1]); cy <- stats::median(coords[, 2])
  dx <- coords[, 1] - cx;           dy <- coords[, 2] - cy
  sf_obj$region <- dplyr::case_when(
    dy >= 0 & abs(dy) >= abs(dx) ~ "North",
    dy <  0 & abs(dy) >= abs(dx) ~ "South",
    dx >= 0 & abs(dx) >  abs(dy) ~ "East",
    TRUE ~ "West"
  )
  sf_obj
}

# Build a row of compact diagnostic value boxes from an exploded result.
diag_boxes <- function(result) {
  stats  <- result$stats
  params <- result$params
  fmt_km <- function(m) if (is.null(m) || is.na(m)) "—" else paste0(round(m / 1000, 1), " km")
  layout_columns(
    fill = FALSE, gap = "0.5rem",
    col_widths = c(3, 3, 3, 3),
    value_box("Regions", stats$n_regions, theme = "primary"),
    value_box("Units", format(stats$n_units %||% stats$n_units_input, big.mark = ","),
              theme = "secondary"),
    value_box("alpha_r", fmt_km(params$alpha_r), theme = "secondary"),
    value_box("alpha_l", fmt_km(params$alpha_l), theme = "secondary")
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

PRESET_CHOICES <- c(
  "Default"   = "none",
  "Municipal" = "municipal",
  "Drill-down" = "drilldown"
)
ORIGIN_CHOICES <- c(
  "Off"            = "none",
  "Outline (socket)" = "socket",
  "Mini overview"  = "inset",
  "Both"           = "both"
)

# -----------------------------------------------------------------------------
# HHS lookup and reference styling
# -----------------------------------------------------------------------------

hhs_assignments <- data.frame(
  state = tolower(c(
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
  )),
  STUSPS = c(
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
  ),
  hhs_region = as.character(c(
    rep(1, 6), rep(2, 4), rep(3, 6), rep(4, 8), rep(5, 6),
    rep(6, 5), rep(7, 4), rep(8, 6), rep(9, 7), rep(10, 4)
  )),
  stringsAsFactors = FALSE
)

hhs_colors <- stats::setNames(
  c(
    "#A89A83", "#C764A6", "#2B4970", "#DF514F", "#309396",
    "#70A255", "#F2BE42", "#8459A0", "#872722", "#3579B0"
  ),
  as.character(1:10)
)

hhs_region_names <- stats::setNames(
  paste0(
    as.character(1:10),
    " - ",
    c(
      "Boston", "New York", "Philadelphia", "Atlanta", "Chicago",
      "Dallas", "Kansas City", "Denver", "San Francisco", "Seattle"
    )
  ),
  as.character(1:10)
)

# These are display nudges for the reference dragged layout.
hhs_display_offsets <- data.frame(
  region = as.character(1:10),
  dx_m = c(-16354, -65414, 0, -228949, -130828, -498782, -245303, -237126, -449721, -327070),
  dy_m = c(-106298, 32707, -139005, -81768, 16354, 81768, 245303, -24530, -24530, 40884),
  stringsAsFactors = FALSE
)

# Legacy coarse offsets from the pre-explodemap framework.
legacy_region_offsets <- data.frame(
  hhs_region = as.character(1:10),
  x_offset = c(0, -2, -3, -3, -4, -6, -5, -8, -10, -11),
  y_offset = c(9, 7, 5, 1, 5, 0, 1, 5, 2, 6),
  stringsAsFactors = FALSE
)

territory_labels <- data.frame(
  NAME = c(
    "Puerto Rico", "United States Virgin Islands", "Hawaii", "Guam",
    "Commonwealth of the Northern Mariana Islands", "American Samoa"
  ),
  territory_label = c("PR", "VI", "HI", "GU", "MP", "AS"),
  stringsAsFactors = FALSE
)

# -----------------------------------------------------------------------------
# Geometry helpers from the original framework, cleaned up for reuse
# -----------------------------------------------------------------------------

scale_geom <- function(geom, scale = 5) {
  ctr <- sf::st_centroid(geom)
  m <- matrix(c(scale, 0, 0, scale), 2, 2)
  scaled <- (geom - ctr) * m + ctr
  sf::st_set_crs(scaled, sf::st_crs(geom))
}

territory_move_and_scale <- function(df, name, ref_name, scale = 6, x_offset = 0, y_offset = -5e5) {
  if (!("NAME" %in% names(df))) return(df)
  if (!any(df$NAME == name, na.rm = TRUE) || !any(df$NAME == ref_name, na.rm = TRUE)) return(df)

  df$geometry[df$NAME == name] <- scale_geom(df$geometry[df$NAME == name], scale = scale)

  terr_geom <- df$geometry[df$NAME == name]
  ref_geom <- df$geometry[df$NAME == ref_name]
  terr_centroid <- sf::st_centroid(terr_geom)
  ref_centroid <- sf::st_centroid(ref_geom)
  shift_vec <- sf::st_coordinates(ref_centroid) - sf::st_coordinates(terr_centroid) + c(x_offset, y_offset)

  df$geometry[df$NAME == name] <- terr_geom + shift_vec
  df
}

move_region <- function(sf_obj, region, dx, dy, region_col = "hhs_region") {
  idx <- as.character(sf_obj[[region_col]]) == as.character(region)
  if (any(idx)) {
    sf::st_geometry(sf_obj)[idx] <- sf::st_geometry(sf_obj)[idx] + c(dx, dy)
  }
  sf_obj
}

# -----------------------------------------------------------------------------
# Package layout discovery
# -----------------------------------------------------------------------------

standardize_states <- function(states) {
  stopifnot(inherits(states, "sf"))

  if (!("hhs_region" %in% names(states))) {
    if ("region" %in% names(states)) {
      states$hhs_region <- as.character(states$region)
    } else if ("STUSPS" %in% names(states)) {
      states <- states |>
        dplyr::mutate(STUSPS = as.character(.data$STUSPS)) |>
        dplyr::left_join(
          hhs_assignments |> dplyr::select(STUSPS, hhs_region),
          by = "STUSPS"
        )
    } else if ("NAME" %in% names(states)) {
      states <- states |>
        dplyr::mutate(state = tolower(.data$NAME)) |>
        dplyr::left_join(
          hhs_assignments |> dplyr::select(state, hhs_region),
          by = "state"
        )
    }
  }

  states <- states |> dplyr::filter(!is.na(.data$hhs_region))
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
    states <- sf::st_transform(states, 5070)
  }

  states
}

standardize_layout <- function(obj, source = "unknown") {
  if (inherits(obj, "sf")) {
    return(list(states = standardize_states(obj), labels = NULL, source = source))
  }

  if (is.list(obj) && !is.null(obj$states) && inherits(obj$states, "sf")) {
    states <- standardize_states(obj$states)
    labels <- obj$labels %||% NULL

    if (!is.null(labels) && is.data.frame(labels) && all(c("region", "x", "y") %in% names(labels))) {
      labels <- labels |>
        dplyr::mutate(region = as.character(.data$region)) |>
        dplyr::arrange(as.integer(.data$region))
    } else {
      labels <- NULL
    }

    return(list(states = states, labels = labels, source = source))
  }

  NULL
}

read_candidate_layout_file <- function(path) {
  if (!file.exists(path)) return(NULL)

  if (grepl("\\.rds$", path, ignore.case = TRUE)) {
    return(standardize_layout(readRDS(path), source = paste("file", basename(path))))
  }

  if (grepl("\\.(geojson|json|gpkg|shp)$", path, ignore.case = TRUE)) {
    return(standardize_layout(sf::st_read(path, quiet = TRUE), source = paste("file", basename(path))))
  }

  NULL
}

find_explodemap_hhs_layout <- function() {
  pkg_root <- system.file(package = "explodemap")
  if (!nzchar(pkg_root)) return(NULL)

  files <- list.files(
    pkg_root,
    pattern = "(hhs|drag).*(\\.rds$|\\.geojson$|\\.json$|\\.gpkg$|\\.shp$)",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(files)) {
    priority <- order(
      !grepl("hhs_manual_layout\\.rds$", files, ignore.case = TRUE),
      !grepl("hhs_drag_base\\.geojson$", files, ignore.case = TRUE),
      files
    )

    for (p in files[priority]) {
      out <- tryCatch(read_candidate_layout_file(p), error = function(e) NULL)
      if (!is.null(out)) {
        out$source <- paste("explodemap package", basename(p))
        out$source_path <- p
        return(out)
      }
    }
  }

  pkg_data <- tryCatch(utils::data(package = "explodemap")$results, error = function(e) NULL)
  if (!is.null(pkg_data) && nrow(pkg_data)) {
    items <- pkg_data[, "Item"]
    hhs_items <- items[grepl("hhs|drag", items, ignore.case = TRUE)]

    for (item in hhs_items) {
      env <- new.env(parent = emptyenv())
      loaded <- tryCatch({
        utils::data(list = item, package = "explodemap", envir = env)
        TRUE
      }, error = function(e) FALSE)

      if (isTRUE(loaded) && exists(item, envir = env, inherits = FALSE)) {
        obj <- get(item, envir = env, inherits = FALSE)
        out <- tryCatch(standardize_layout(obj, source = paste("explodemap data", item)), error = function(e) NULL)
        if (!is.null(out)) return(out)
      }
    }
  }

  NULL
}

# -----------------------------------------------------------------------------
# Fallback builder using explodemap and the legacy framework
# -----------------------------------------------------------------------------

read_fallback_states <- function() {
  candidates <- c(
    Sys.getenv("HHS_STATES_RDS", ""),
    file.path(DATA_DIR, "us_states.rds"),
    file.path(app_dir, "data", "us_states.rds"),
    file.path("data", "us_states.rds")
  )
  candidates <- candidates[nzchar(candidates)]

  for (p in candidates) {
    if (file.exists(p)) {
      return(readRDS(p))
    }
  }

  if (requireNamespace("tigris", quietly = TRUE)) {
    message("No local states file found. Downloading states with tigris.")
    options(tigris_use_cache = TRUE)
    return(tigris::states(year = 2024, cb = TRUE, class = "sf"))
  }

  stop(
    "No package HHS layout and no fallback states file were found. ",
    "Set HHS_STATES_RDS, add data/us_states.rds, or install tigris.",
    call. = FALSE
  )
}

build_legacy_layout <- function() {
  states <- read_fallback_states() |> standardize_states()

  shifted <- states |>
    dplyr::left_join(legacy_region_offsets, by = "hhs_region") |>
    dplyr::mutate(
      geometry_new = purrr::map2(.data$geometry, .data$hhs_region, function(geom, reg) {
        off <- legacy_region_offsets[legacy_region_offsets$hhs_region == reg, ]
        geom + c(off$x_offset * 1e5, off$y_offset * 1e5)
      })
    )

  shifted$geometry <- NULL
  shifted <- sf::st_as_sf(shifted, sf_column_name = "geometry_new")
  names(shifted)[names(shifted) == "geometry_new"] <- "geometry"
  sf::st_geometry(shifted) <- "geometry"

  shifted <- territory_move_and_scale(shifted, "Puerto Rico", "New Jersey", scale = 2, x_offset = 5e5, y_offset = -4e5)
  shifted <- territory_move_and_scale(shifted, "United States Virgin Islands", "New Jersey", scale = 4, x_offset = 5.5e5, y_offset = -1.1e6)
  shifted <- territory_move_and_scale(shifted, "Hawaii", "California", scale = 2, x_offset = 2e5, y_offset = -1.8e6)
  shifted <- territory_move_and_scale(shifted, "Guam", "California", scale = 2, x_offset = 5.5e5, y_offset = -1.1e6)
  shifted <- territory_move_and_scale(shifted, "Commonwealth of the Northern Mariana Islands", "California", scale = 3, x_offset = 8e5, y_offset = -2.1e6)
  shifted <- territory_move_and_scale(shifted, "American Samoa", "California", scale = 3, x_offset = 1e6, y_offset = -4.5e6)

  list(states = shifted, labels = NULL, source = "legacy framework fallback")
}

build_explodemap_auto_layout <- function() {
  states <- read_fallback_states() |> standardize_states()

  result <- explodemap::explode_grouped(
    states,
    region_col = "hhs_region",
    mode = "auto_collision",
    alpha_l = 120000,
    p = 1.25,
    kappa = 1.8,
    padding = 80000,
    delta = 20000,
    lambda = 0.18,
    eta = 0.18,
    padding_sep = 30000,
    max_iter = 60,
    label = "US by HHS region"
  )

  states_out <- result$sf_grouped %||% result$sf_exp %||% result$sf_grouped_wgs %||% result$sf_exp_wgs
  standardize_layout(states_out, source = "explode_grouped fallback")
}

load_reference_layout <- function(source_mode = c("package", "legacy", "explode_grouped")) {
  source_mode <- match.arg(source_mode)

  if (source_mode == "package") {
    out <- find_explodemap_hhs_layout()
    if (!is.null(out)) return(out)
    return(build_legacy_layout())
  }

  if (source_mode == "legacy") {
    return(build_legacy_layout())
  }

  build_explodemap_auto_layout()
}

compute_region_labels <- function(states) {
  labels_sf <- states |>
    dplyr::group_by(.data$hhs_region) |>
    dplyr::summarize(geometry = sf::st_union(.data$geometry), .groups = "drop") |>
    sf::st_centroid()

  coords <- sf::st_coordinates(labels_sf)
  data.frame(
    region = as.character(labels_sf$hhs_region),
    x = coords[, 1],
    y = coords[, 2],
    stringsAsFactors = FALSE
  ) |>
    dplyr::arrange(as.integer(.data$region))
}

apply_reference_offsets <- function(layout, offsets = hhs_display_offsets) {
  states <- layout$states
  labels <- layout$labels %||% compute_region_labels(states)

  for (i in seq_len(nrow(offsets))) {
    states <- move_region(
      states,
      region = offsets$region[i],
      dx = offsets$dx_m[i],
      dy = offsets$dy_m[i],
      region_col = "hhs_region"
    )
  }

  labels <- labels |>
    dplyr::mutate(region = as.character(.data$region)) |>
    dplyr::left_join(offsets, by = c("region" = "region")) |>
    dplyr::mutate(
      dx_m = dplyr::coalesce(.data$dx_m, 0),
      dy_m = dplyr::coalesce(.data$dy_m, 0),
      x = .data$x + .data$dx_m,
      y = .data$y + .data$dy_m
    ) |>
    dplyr::select(region, x, y) |>
    dplyr::arrange(as.integer(.data$region))

  list(
    states = states,
    labels = labels,
    source = layout$source,
    source_path = layout$source_path %||% NA_character_
  )
}

territory_label_points <- function(states) {
  if (!("NAME" %in% names(states))) return(data.frame())
  territories <- states |>
    dplyr::filter(.data$NAME %in% territory_labels$NAME) |>
    dplyr::left_join(territory_labels, by = "NAME")

  if (!nrow(territories)) return(data.frame())

  pts <- suppressWarnings(sf::st_point_on_surface(territories))
  xy <- sf::st_coordinates(pts)

  sf::st_drop_geometry(territories) |>
    dplyr::mutate(x = xy[, 1], y = xy[, 2]) |>
    dplyr::select(NAME, territory_label, x, y)
}

state_label_points <- function(states) {
  pts <- suppressWarnings(sf::st_point_on_surface(states))
  xy <- sf::st_coordinates(pts)

  sf::st_drop_geometry(states) |>
    dplyr::mutate(x = xy[, 1], y = xy[, 2]) |>
    dplyr::select(state_label, x, y)
}

make_tooltip <- function(states) {
  region_name <- hhs_region_names[as.character(states$hhs_region)]
  paste0(
    "<b>", htmltools::htmlEscape(states$state_label), "</b>",
    "<br>HHS region: ", htmltools::htmlEscape(region_name)
  )
}

make_hhs_plot <- function(layout, show_state_labels = FALSE, show_territory_labels = TRUE) {
  states <- layout$states
  labels <- layout$labels
  states$hhs_region <- as.character(states$hhs_region)
  states$tooltip <- make_tooltip(states)
  states$data_id <- states$state_geoid

  bbox <- sf::st_bbox(states)
  xpad <- (bbox[["xmax"]] - bbox[["xmin"]]) * 0.15
  ypad <- (bbox[["ymax"]] - bbox[["ymin"]]) * 0.15

  p <- ggplot2::ggplot() +
    ggiraph::geom_sf_interactive(
      data = states,
      ggplot2::aes(
        fill = factor(.data$hhs_region, levels = as.character(1:10)),
        tooltip = .data$tooltip,
        data_id = .data$data_id
      ),
      color = "white",
      linewidth = 1.1
    ) +
    ggplot2::scale_fill_manual(
      values = hhs_colors,
      breaks = as.character(1:10),
      labels = hhs_region_names,
      name = "HHS region",
      guide = "none"
    ) +
    ggiraph::geom_point_interactive(
      data = labels,
      ggplot2::aes(
        x = .data$x,
        y = .data$y,
        tooltip = paste0("HHS region ", .data$region),
        data_id = paste0("hhs_region_", .data$region)
      ),
      size = 6.5,
      shape = 21,
      fill = "white",
      color = "black",
      stroke = 1.4
    ) +
    ggiraph::geom_text_interactive(
      data = labels,
      ggplot2::aes(
        x = .data$x,
        y = .data$y,
        label = .data$region,
        tooltip = paste0("HHS region ", .data$region),
        data_id = paste0("hhs_region_", .data$region)
      ),
      size = 3.8,
      fontface = "bold"
    ) +
    ggplot2::coord_sf(
      xlim = c(bbox[["xmin"]] - xpad, bbox[["xmax"]] + xpad),
      ylim = c(bbox[["ymin"]] - ypad, bbox[["ymax"]] + ypad),
      expand = FALSE
    ) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", color = NA),
      panel.background = ggplot2::element_rect(fill = "white", color = NA),
      plot.margin = ggplot2::margin(10, 10, 10, 10)
    ) +
    ggplot2::labs(title = "US Map by HHS Regions")

  if (isTRUE(show_state_labels)) {
    state_labels <- state_label_points(states)
    p <- p +
      ggplot2::geom_text(
        data = state_labels,
        ggplot2::aes(x = .data$x, y = .data$y, label = .data$state_label),
        size = 2.2,
        check_overlap = TRUE,
        color = "grey10"
      )
  }

  if (isTRUE(show_territory_labels)) {
    terr <- territory_label_points(states)
    if (nrow(terr)) {
      p <- p +
        ggplot2::geom_text(
          data = terr,
          ggplot2::aes(x = .data$x, y = .data$y, label = .data$territory_label),
          fontface = "bold",
          color = "white",
          size = 4.5
        )
    }
  }

  p
}


# =============================================================================
# Reusable focus-map sidebar (counties / municipalities)
# =============================================================================
focus_sidebar <- function(prefix, intro, default_preset = "none",
                         choices = STATE_CHOICES) {
  id <- function(x) paste0(prefix, "_", x)
  sidebar(
    width = 320,
    p(class = "text-muted small mb-2", intro),
    selectInput(id("state"), "State", choices, selected = choices[[1]]),
    radioButtons(id("mode"), "Mode",
                 c("Raw" = "raw", "Exploded" = "exploded"),
                 selected = "raw", inline = TRUE),
    selectInput(id("preset"), "Style preset", PRESET_CHOICES, selected = default_preset),
    selectInput(id("origin"), "Source while focused", ORIGIN_CHOICES, selected = "socket"),
    checkboxInput(id("drag"), "Drag-to-zoom", value = FALSE),
    checkboxInput(id("labels"), "Show labels", value = TRUE),
    accordion(
      open = FALSE,
      accordion_panel(
        "Advanced",
        icon = icon("sliders"),
        sliderInput(id("font"), "Label size", 4, 16, 9, 1),
        sliderInput(id("lift"), "Lift scale", 1.00, 1.40, 1.16, 0.01),
        sliderInput(id("focus_size"), "Zoom area size", 0.40, 1.30, 0.78, 0.02),
        sliderInput(id("focus_pad"), "Focus padding", 12, 120, 44, 4),
        sliderInput(id("card"), "Info card size", 0.75, 1.60, 1.10, 0.05),
        checkboxInput(id("perf"), "Performance mode", value = TRUE),
        checkboxInput(id("simplify"), "Extra simplify", value = FALSE),
        conditionalPanel(
          sprintf("input.%s_simplify", prefix),
          sliderInput(id("simplify_m"), "Tolerance (m)", 50, 2500, 250, 50)
        ),
        conditionalPanel(
          sprintf("input.%s_mode == 'exploded'", prefix),
          checkboxInput(id("refine"), "Collision refine", value = FALSE),
          radioButtons(id("refine_within"), "Refine scope",
                       c("Within region" = "region", "All" = "all"),
                       selected = "region", inline = TRUE)
        )
      )
    ),
    conditionalPanel(
      sprintf("input.%s_mode == 'exploded'", prefix),
      downloadButton(id("download"), "Download GeoJSON", class = "btn-sm btn-outline-primary w-100")
    )
  )
}

# Main content (diagnostics strip + map card) for the two focus-map tabs.
focus_panel_body <- function(prefix) {
  tagList(
    conditionalPanel(
      sprintf("input.%s_mode == 'exploded'", prefix),
      uiOutput(paste0(prefix, "_diag"))
    ),
    card(full_screen = TRUE,
         card_body(padding = 0, focusmapOutput(paste0(prefix, "_map"), height = "100%")))
  )
}

# =============================================================================
# UI
# =============================================================================
ui <- page_navbar(
  title = tags$span(icon("map-location-dot"), "explodemap gallery"),
  id = "nav",
  theme = bs_theme(
    version = 5,
    primary = "#2d6ea3",
    "navbar-bg" = "#2d6ea3"
  ),
  header = tags$style(HTML("
      .bslib-value-box .value-box-value { font-size: 1.4rem; }
      .bslib-value-box .value-box-title { font-size: .7rem; text-transform: uppercase; letter-spacing: .04em; }
      .card { box-shadow: 0 1px 3px rgba(15,23,42,.08); }
      .shiny-bound-output.recalculating { opacity: .35; transition: opacity .2s ease; }
      .html-widget.recalculating { opacity: .35; }
      .hhs-reference-card .card-body { min-height: 0; height: 100%; }
      .hhs-reference-card .girafe.html-widget,
      .hhs-reference-card .girafe.html-widget > div,
      .hhs-reference-card .girafe.html-widget svg {
        width: 100% !important;
        height: 100% !important;
      }
  ")),
  # Only the map tabs fill the viewport; Parameter lab stays scrollable.
  fillable = c("Counties", "Municipalities", "Drill-down", "National (HHS)"),

  nav_panel(
    "Counties",
    layout_sidebar(
      sidebar = focus_sidebar("county", "Click a county to lift and zoom it. Right-click or Esc resets.",
                              choices = COUNTY_CHOICES),
      focus_panel_body("county")
    )
  ),
  nav_panel(
    "Municipalities",
    layout_sidebar(
      sidebar = focus_sidebar("muni", "County subdivisions. Try the Municipal preset for small-area focus.",
                              default_preset = "municipal"),
      focus_panel_body("muni")
    )
  ),
  nav_panel(
    "Drill-down",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        p(class = "text-muted small mb-2",
          "Explode one region's municipalities while the rest of the state stays as faded context."),
        selectInput("dd_state", "State", STATE_CHOICES, selected = "TX"),
        selectInput("dd_section", "Region to explode",
                    c("All regions" = "all", "North", "South", "East", "West"),
                    selected = "North"),
        radioButtons("dd_context", "Context",
                     c("Fade" = "fade", "Hide" = "hide"), selected = "fade", inline = TRUE),
        checkboxInput("dd_labels", "Show labels", value = TRUE),
        downloadButton("dd_download", "Download GeoJSON", class = "btn-sm btn-outline-primary w-100")
      ),
      uiOutput("dd_diag"),
      card(full_screen = TRUE,
           card_body(padding = 0, focusmapOutput("dd_map", height = "100%")))
    )
  ),
  nav_panel(
    "National (HHS)",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        p(
          class = "text-muted small mb-2",
          "Reference HHS grouped layout. The default source prefers the layout bundled with explodemap, then falls back to the legacy framework."
        ),
        selectInput(
          "hhs_source_mode",
          "Layout source",
          choices = c(
            "Prefer explodemap package layout" = "package",
            "Legacy pre-explodemap framework" = "legacy",
            "explode_grouped fallback" = "explode_grouped"
          ),
          selected = "package"
        ),
        checkboxInput("hhs_apply_offsets", "Apply documented display offsets", value = TRUE),
        checkboxInput("hhs_state_labels", "Show state names on map", value = FALSE),
        checkboxInput("hhs_territory_labels", "Show territory abbreviations", value = TRUE),
        helpText("Hover over states for state name and HHS region. Region numbers are a separate group-level layer."),
        downloadButton("hhs_download", "Download GeoJSON", class = "btn-sm btn-outline-primary w-100")
      ),
      uiOutput("hhs_diag"),
      card(
        full_screen = TRUE,
        class = "hhs-reference-card",
        card_body(
          padding = 0,
          ggiraph::girafeOutput("hhs_map", width = "100%", height = "100%")
        )
      )
    )
  ),

  nav_panel(
    "Parameter lab",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        p(class = "text-muted small mb-2",
          "See how the two displacement scales behave on a tiny synthetic dataset."),
        checkboxInput("lab_or_r", "Override alpha_r", value = TRUE),
        sliderInput("lab_r", "alpha_r multiplier", 0.25, 3.00, 1.50, 0.05),
        checkboxInput("lab_or_l", "Override alpha_l", value = FALSE),
        sliderInput("lab_l", "alpha_l multiplier", 0.25, 3.00, 1.00, 0.05)
      ),
      uiOutput("lab_diag"),
      card(full_screen = TRUE, card_header("Original vs exploded"),
           card_body(plotOutput("lab_plot", height = "560px"))),
      card(card_header("Derived vs tuned parameters"),
           card_body(verbatimTextOutput("lab_params")))
    )
  ),

  nav_spacer(),
  nav_item(actionLink("show_help", tagList(icon("circle-question"), "How to use"))),
  nav_item(tags$a(icon("github"), "Package", href = "https://github.com/PrigasG/explodemap",
                  target = "_blank", class = "nav-link"))
)

# =============================================================================
# Server
# =============================================================================
server <- function(input, output, session) {

  # Help overlay -------------------------------------------------------------
  observeEvent(input$show_help, {
    showModal(modalDialog(
      title = tagList(icon("map-location-dot"), "How to use this gallery"),
      easyClose = TRUE, size = "l", footer = modalButton("Got it"),
      tags$ol(
        tags$li(tags$b("Pick a state and mode."), " Raw shows the true map; Exploded separates units with the package's vector field."),
        tags$li(tags$b("Click any area"), " to lift and zoom it. The info card shows its details."),
        tags$li(tags$b("Right-click or press Esc"), " to reset the view.")
      ),
      tags$hr(),
      tags$p(class = "mb-1", tags$b("Tips")),
      tags$ul(
        tags$li("Enable ", tags$b("Drag-to-zoom"), " (or Shift-drag) to marquee into dense clusters."),
        tags$li("The ", tags$b("Drill-down"), " tab explodes one region and fades the rest as context."),
        tags$li("Use ", tags$b("Download GeoJSON"), " to export any exploded layout.")
      )
    ))
  })

  # ----- Generic focus-map tab wiring (counties + municipalities) -----------
  make_focus_tab <- function(prefix, layer_suffix, label_col, id_col, info_cols, info_labels, info_title) {
    id <- function(x) paste0(prefix, "_", x)

    raw_layer <- reactive({
      tryCatch(
        read_layer(paste0(input[[id("state")]], "_", layer_suffix, ".rds")),
        error = function(e) validate(need(FALSE, app_error("load boundaries", e)))
      )
    }) |> bindCache(input[[id("state")]], layer_suffix)

    map_data <- reactive({
      x <- raw_layer()

      if (isTRUE(input[[id("mode")]] == "exploded")) {
        validate(need(nrow(x) >= 3,
                      "Exploded mode needs at least three areas. Choose a larger state or switch to Raw."))
        result <- tryCatch({
          proj <- x |> sf::st_transform(5070) |> assign_quadrant_regions()
          explode_sf(proj, region_col = "region", plot = FALSE, quiet = TRUE,
                     refine = isTRUE(input[[id("refine")]]),
                     refine_within = input[[id("refine_within")]] %||% "region",
                     label = paste(input[[id("state")]], layer_suffix))
        }, error = function(e) validate(need(FALSE, app_error("build the exploded map", e))))

        list(result = result, x = result,
             group_col = "region", info_cols = c(info_cols, "region"))
      } else {
        list(result = NULL, x = x,
             group_col = NULL, info_cols = info_cols)
      }
    })

    output[[id("map")]] <- renderFocusmap({
      md <- map_data()
      preset <- input[[id("preset")]] %||% "none"
      tryCatch(
        focus_map(
          md$x,
          label_col   = label_col,
          id_col      = id_col,
          group_col   = md$group_col,
          info_cols   = md$info_cols,
          info_labels = info_labels,
          info_title  = info_title,
          focus_preset = if (preset == "none") "none" else preset,
          origin_context = input[[id("origin")]] %||% "none",
          show_drag_zoom = isTRUE(input[[id("drag")]]),
          show_labels = isTRUE(input[[id("labels")]]),
          font_size   = input[[id("font")]],
          lift_scale  = input[[id("lift")]],
          focus_size  = input[[id("focus_size")]],
          focus_padding = input[[id("focus_pad")]],
          info_card_scale = input[[id("card")]],
          performance_mode = isTRUE(input[[id("perf")]]),
          simplify = if (isTRUE(input[[id("simplify")]])) {
            # convert metres to ~degrees for the WGS84 widget copy
            max(input[[id("simplify_m")]], 1) / 111000
          } else TRUE,
          width = "100%", height = "100%"
        ),
        error = function(e) validate(need(FALSE, app_error("render the map", e)))
      )
    })

    output[[id("diag")]] <- renderUI({
      md <- map_data()
      req(md$result)
      diag_boxes(md$result)
    })

    output[[id("download")]] <- downloadHandler(
      filename = function() paste0("exploded_", input[[id("state")]], "_", layer_suffix, ".geojson"),
      content = function(file) {
        md <- map_data(); req(md$result)
        sf::st_write(md$result$sf_exp_wgs, file, driver = "GeoJSON",
                     delete_dsn = TRUE, quiet = TRUE)
      }
    )
  }

  make_focus_tab(
    "county", "counties",
    label_col = "county_label", id_col = "county_geoid",
    info_cols = c("county_label", "county_geoid"),
    info_labels = c(county_label = "County", region = "Exploded region", county_geoid = "GEOID"),
    info_title = "county_label"
  )
  make_focus_tab(
    "muni", "munis",
    label_col = "muni_label", id_col = "muni_geoid",
    info_cols = c("muni_label", "county_name", "muni_geoid"),
    info_labels = c(muni_label = "Subdivision", county_name = "County",
                    region = "Exploded region", muni_geoid = "GEOID"),
    info_title = "muni_label"
  )

  # ----- Drill-down tab -----------------------------------------------------
  dd_munis <- reactive({
    tryCatch(
      read_layer(paste0(input$dd_state, "_munis.rds")) |>
        sf::st_transform(5070) |>
        assign_quadrant_regions(),
      error = function(e) validate(need(FALSE, app_error("load subdivisions", e)))
    )
  }) |> bindCache(input$dd_state)

  dd_result <- reactive({
    x <- dd_munis()
    section <- input$dd_section

    if (section != "all") {
      n_counties <- x |>
        sf::st_drop_geometry() |>
        dplyr::filter(.data$region == section) |>
        dplyr::distinct(.data$county_name) |>
        nrow()
      validate(need(n_counties >= 2,
                    paste0("The ", section, " region of ", input$dd_state,
                           " has too few counties to explode. Try another region or All.")))
    }

    tryCatch(
      explode_section(
        x,
        section_col = "region",
        section = section,
        region_col = "county_name",
        layout = "explode",
        context = input$dd_context,
        plot = FALSE, quiet = TRUE,
        label = paste(input$dd_state, "drill-down:", section)
      ),
      error = function(e) validate(need(FALSE, app_error("build the drill-down map", e)))
    )
  })

  output$dd_map <- renderFocusmap({
    res <- dd_result()
    tryCatch(
      focus_map(
        res,
        label_col = "muni_label",
        id_col = "muni_geoid",
        group_col = "county_name",
        context_col = ".explodemap_role",
        context_mode = input$dd_context,
        focus_preset = "drilldown",
        info_cols = c("muni_label", "county_name"),
        info_labels = c(muni_label = "Subdivision", county_name = "County"),
        info_title = "muni_label",
        show_labels = isTRUE(input$dd_labels),
        width = "100%", height = "100%"
      ),
      error = function(e) validate(need(FALSE, app_error("render the drill-down map", e)))
    )
  })

  output$dd_diag <- renderUI(diag_boxes(dd_result()))

  output$dd_download <- downloadHandler(
    filename = function() paste0("drilldown_", input$dd_state, "_", input$dd_section, ".geojson"),
    content = function(file) {
      sf::st_write(dd_result()$sf_exp_wgs, file, driver = "GeoJSON",
                   delete_dsn = TRUE, quiet = TRUE)
    }
  )

  # ----- National HHS reference tab -----------------------------------------
  hhs_layout_base <- reactive({
    tryCatch(
      load_reference_layout(input$hhs_source_mode),
      error = function(e) validate(need(FALSE, app_error("load the HHS reference layout", e)))
    )
  })

  hhs_layout_final <- reactive({
    base <- hhs_layout_base()
    if (isTRUE(input$hhs_apply_offsets)) {
      apply_reference_offsets(base)
    } else {
      base$labels <- base$labels %||% compute_region_labels(base$states)
      base
    }
  })

  output$hhs_map <- ggiraph::renderGirafe({
    lay <- hhs_layout_final()

    p <- make_hhs_plot(
      lay,
      show_state_labels = isTRUE(input$hhs_state_labels),
      show_territory_labels = isTRUE(input$hhs_territory_labels)
    )

    ggiraph::girafe(
      ggobj = p,
      width_svg = 9,
      height_svg = 6,
      options = list(
        ggiraph::opts_hover(css = "stroke:#111827;stroke-width:2.5px;"),
        ggiraph::opts_selection(type = "none"),
        ggiraph::opts_tooltip(
          css = "background:white;border:1px solid #cbd5e1;border-radius:6px;padding:6px 8px;color:#111827;"
        ),
        ggiraph::opts_sizing(rescale = TRUE)
      )
    )
  })

  output$hhs_diag <- renderUI({
    lay <- hhs_layout_final()
    layout_columns(
      fill = FALSE, gap = "0.5rem", col_widths = c(3, 3, 3, 3),
      value_box("Regions", dplyr::n_distinct(lay$states$hhs_region), theme = "primary"),
      value_box("States", format(nrow(lay$states), big.mark = ","), theme = "secondary"),
      value_box("Source", lay$source %||% "unknown", theme = "secondary"),
      value_box("Offsets", if (isTRUE(input$hhs_apply_offsets)) "applied" else "off", theme = "secondary")
    )
  })

  output$hhs_download <- downloadHandler(
    filename = function() "hhs_reference_layout.geojson",
    content = function(file) {
      lay <- hhs_layout_final()
      out <- if (isTRUE(sf::st_is_longlat(lay$states))) lay$states else sf::st_transform(lay$states, 4326)
      sf::st_write(out, file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
    }
  )

  # ----- Parameter lab ------------------------------------------------------
  lab_units <- function() {
    sq <- function(xmin, ymin, size = 1000) sf::st_polygon(list(matrix(c(
      xmin, ymin, xmin + size, ymin, xmin + size, ymin + size,
      xmin, ymin + size, xmin, ymin), ncol = 2, byrow = TRUE)))
    sf::st_sf(
      id = c("a1", "a2", "b1", "b2"),
      region = c("A", "A", "B", "B"),
      geometry = sf::st_sfc(sq(0, 0), sq(2000, 0), sq(10000, 0), sq(12000, 0), crs = 3857)
    )
  }

  lab_derived <- reactive(
    explode_sf(lab_units(), region_col = "region", plot = FALSE, quiet = TRUE, label = "Derived")
  )

  lab_result <- reactive({
    derived <- lab_derived()
    args <- list(sf_obj = lab_units(), region_col = "region", plot = FALSE, quiet = TRUE,
                 label = "Manual tuning")
    if (isTRUE(input$lab_or_r)) args$alpha_r <- derived$params$alpha_r * input$lab_r
    if (isTRUE(input$lab_or_l)) args$alpha_l <- derived$params$alpha_l * input$lab_l
    do.call(explode_sf, args)
  })

  output$lab_plot <- renderPlot(plot(lab_result(), which = "both"))

  output$lab_diag <- renderUI(diag_boxes(lab_result()))

  output$lab_params <- renderText({
    fmt <- function(r) paste(utils::capture.output(str(r$params)), collapse = "\n")
    paste("Derived:", fmt(lab_derived()), "", "Tuned:", fmt(lab_result()), sep = "\n")
  })
}

shinyApp(ui, server)
