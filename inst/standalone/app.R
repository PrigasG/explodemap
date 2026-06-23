suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(sf)
  library(dplyr)
  library(explodemap)
})

app_dir  <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile, mustWork = FALSE)),
  error = function(e) getwd()
)
DATA_DIR <- Sys.getenv("APP_DATA_DIR", file.path(app_dir, "data"))

ensure_data <- function() {
  if (file.exists(file.path(DATA_DIR, "states.rds"))) return(invisible(TRUE))
  prep <- file.path(app_dir, "prep_data.R")
  if (file.exists(prep)) {
    message("Data not found -- running prep_data.R (first run only)...")
    sys.source(prep, envir = new.env(parent = globalenv()))
  }
  invisible(file.exists(file.path(DATA_DIR, "states.rds")))
}
ensure_data()

STATES <- tryCatch(
  readRDS(file.path(DATA_DIR, "states.rds")),
  error = function(e) data.frame(
    name = c("New Jersey", "Pennsylvania", "Texas"),
    abbr = c("nj", "pa", "tx"),
    stringsAsFactors = FALSE
  )
)

available <- STATES$abbr[file.exists(file.path(DATA_DIR, paste0(STATES$abbr, "_display.rds")))]
STATES    <- STATES[STATES$abbr %in% available, ]
STATE_CHOICES <- stats::setNames(STATES$abbr, STATES$name)

read_display <- function(abbr) {
  path <- file.path(DATA_DIR, paste0(tolower(abbr), "_display.rds"))
  if (!file.exists(path))
    stop("No baked data for '", abbr, "'. Run prep_data.R first.", call. = FALSE)
  readRDS(path)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

ORIGIN_CHOICES <- c(
  "Off"    = "none",
  "Socket" = "socket",
  "Inset"  = "inset",
  "Both"   = "both"
)

ui <- page_navbar(
  title = "explodemap -- display layouts",
  theme = bs_theme(
    version = 5,
    primary = "#2d6ea3",
    "navbar-bg" = "#2d6ea3"
  ),
  header = tags$style(HTML(
    ".bslib-value-box .value-box-value { font-size:1.3rem; }
     .bslib-value-box .value-box-title { font-size:.7rem; text-transform:uppercase; letter-spacing:.04em; }
     .card { box-shadow: 0 1px 3px rgba(15,23,42,.08); }
     .shiny-bound-output.recalculating { opacity:.35; transition:opacity .2s ease; }"
  )),
  fillable = TRUE,

  nav_panel(
    "Map",
    layout_sidebar(
      sidebar = sidebar(
        width = 290,
        p(class = "text-muted small mb-2",
          "Manual display offsets from the paper applied to the formula-derived exploded layout.
          Click any area to zoom in. Right-click or Esc resets."),
        selectInput("state", "State", STATE_CHOICES,
                    selected = if ("nj" %in% STATE_CHOICES) "nj" else STATE_CHOICES[[1]]),
        hr(class = "my-2"),
        checkboxInput("labels", "Show labels", value = TRUE),
        sliderInput("font", "Label size", 4, 16, 9, 1),
        selectInput("origin", "Focus origin", ORIGIN_CHOICES, selected = "socket"),
        checkboxInput("drag", "Drag-to-zoom", value = FALSE),
        checkboxInput("perf", "Performance mode", value = TRUE),
        hr(class = "my-2"),
        uiOutput("diag_strip"),
        downloadButton("dl", "Download GeoJSON", class = "btn-sm btn-outline-primary w-100 mt-2")
      ),
      tagList(
        card(
          full_screen = TRUE,
          card_body(padding = 0, focusmapOutput("map", height = "100%"))
        )
      )
    )
  ),

  nav_spacer(),
  nav_item(tags$a(
    icon("github"), "Package",
    href = "https://github.com/PrigasG/explodemap",
    target = "_blank",
    class = "nav-link"
  ))
)

server <- function(input, output, session) {

  sf_data <- reactive({
    tryCatch(
      read_display(input$state),
      error = function(e) validate(need(FALSE, conditionMessage(e)))
    )
  }) |> bindCache(input$state)

  output$map <- renderFocusmap({
    x <- sf_data()
    focus_map(
      x,
      label_col        = "county_label",
      id_col           = "county_id",
      group_col        = "drag_region",
      info_cols        = c("county_label", "drag_region"),
      info_labels      = c(county_label = "Area", drag_region = "Region"),
      info_title       = "county_label",
      show_labels      = isTRUE(input$labels),
      font_size        = input$font %||% 9,
      origin_context   = input$origin %||% "socket",
      show_drag_zoom   = isTRUE(input$drag),
      performance_mode = isTRUE(input$perf),
      width = "100%", height = "100%"
    )
  })

  output$diag_strip <- renderUI({
    x <- sf_data()
    n_regions  <- dplyr::n_distinct(x$drag_region)
    n_features <- nrow(x)
    crs_label  <- tryCatch(sf::st_crs(x)$input %||% "unknown", error = function(e) "unknown")
    layout_columns(
      fill = FALSE, gap = "0.4rem", col_widths = c(4, 4, 4),
      value_box("Regions",  n_regions,                              theme = "primary",   showcase = NULL),
      value_box("Features", format(n_features, big.mark = ","),     theme = "secondary", showcase = NULL),
      value_box("CRS",      sub("^EPSG:", "", crs_label),           theme = "secondary", showcase = NULL)
    )
  })

  output$dl <- downloadHandler(
    filename = function() paste0(input$state, "_display_layout.geojson"),
    content  = function(file) {
      x <- sf_data()
      out <- tryCatch(sf::st_transform(x, 4326), error = function(e) x)
      sf::st_write(out, file, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
    }
  )
}

shinyApp(ui, server)
