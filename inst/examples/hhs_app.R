
# Recommended package example usage:
#   source(system.file("examples/hhs_reference_map.R", package = "explodemap"))
#
# Local usage:
#   shiny::runApp("hhs_reference_map.R")
#
# Optional local data fallbacks:
#   Sys.setenv(HHS_STATES_RDS = "path/to/us_states.rds")
#   Sys.setenv(APP_DATA_DIR = "path/to/data")
#


suppressPackageStartupMessages({
  library(shiny)
  library(sf)
  library(dplyr)
  library(ggplot2)
  library(purrr)
  library(explodemap)
})

if (!requireNamespace("ggiraph", quietly = TRUE)) {
  stop("This example needs ggiraph. Install it with install.packages('ggiraph').", call. = FALSE)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

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
    file.path(Sys.getenv("APP_DATA_DIR", "data"), "us_states.rds"),
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

# -----------------------------------------------------------------------------
# Shiny reference app
# -----------------------------------------------------------------------------

ui <- shiny::fluidPage(
  tags$head(
    tags$style(HTML("
      body { background: #f8fafc; }
      .container-fluid { max-width: 1280px; }
      .reference-header { margin: 18px 0 10px; }
      .source-note { color: #64748b; font-size: .9rem; margin-bottom: 10px; }
      .girafe.html-widget { width: 100% !important; height: calc(100vh - 220px) !important; min-height: 620px; }
    "))
  ),
  div(
    class = "reference-header",
    h2("explodemap HHS reference map"),
    div(class = "source-note", textOutput("source_note", inline = TRUE))
  ),
  fluidRow(
    column(
      3,
      selectInput(
        "source_mode",
        "Layout source",
        choices = c(
          "Prefer explodemap package layout" = "package",
          "Legacy pre-explodemap framework" = "legacy",
          "explode_grouped fallback" = "explode_grouped"
        ),
        selected = "package"
      ),
      checkboxInput("apply_offsets", "Apply documented display offsets", value = TRUE),
      checkboxInput("show_state_labels", "Show state names on map", value = FALSE),
      checkboxInput("show_territory_labels", "Show territory abbreviations", value = TRUE),
      helpText("Hover over states for state name and HHS region. Region numbers are drawn as a separate group-level layer.")
    ),
    column(
      9,
      ggiraph::girafeOutput("hhs_plot", width = "100%", height = "760px")
    )
  )
)

server <- function(input, output, session) {
  layout_base <- reactive({
    load_reference_layout(input$source_mode)
  })

  layout_final <- reactive({
    base <- layout_base()
    if (isTRUE(input$apply_offsets)) {
      apply_reference_offsets(base)
    } else {
      base$labels <- base$labels %||% compute_region_labels(base$states)
      base
    }
  })

  output$source_note <- renderText({
    lay <- layout_final()
    path <- lay$source_path %||% ""
    paste0(
      "Using: ", lay$source,
      if (nzchar(path)) paste0(" | ", path) else ""
    )
  })

  output$hhs_plot <- ggiraph::renderGirafe({
    lay <- layout_final()
    p <- make_hhs_plot(
      lay,
      show_state_labels = isTRUE(input$show_state_labels),
      show_territory_labels = isTRUE(input$show_territory_labels)
    )

    ggiraph::girafe(
      ggobj = p,
      width_svg = 9,
      height_svg = 6,
      options = list(
        ggiraph::opts_hover(css = "stroke:#111827;stroke-width:2.5px;"),
        ggiraph::opts_selection(type = "none"),
        ggiraph::opts_tooltip(css = "background:white;border:1px solid #cbd5e1;border-radius:6px;padding:6px 8px;color:#111827;"),
        ggiraph::opts_sizing(rescale = TRUE)
      )
    )
  })
}

shiny::shinyApp(ui, server)
