library(shiny)
library(sf)
library(dplyr)
library(tigris)
library(explodemap)

options(tigris_use_cache = TRUE)

states <- data.frame(
  name = c("New Jersey", "Texas", "Georgia", "California", "Pennsylvania"),
  abbr = c("NJ", "TX", "GA", "CA", "PA"),
  stringsAsFactors = FALSE
)

app_error <- function(action, error) {
  paste0(
    "We could not ", action, ". ",
    conditionMessage(error),
    " Check your internet connection, try a smaller boundary file, or choose a different state."
  )
}

load_counties <- function(state_abbr, cb = TRUE, year = 2024) {
  out <- tigris::counties(state = state_abbr, year = year, cb = cb, class = "sf") |>
    dplyr::filter(!sf::st_is_empty(.data$geometry)) |>
    dplyr::mutate(
      county_label = dplyr::coalesce(.data$NAMELSAD, .data$NAME),
      county_geoid = .data$GEOID,
      county_id = paste0(.data$STATEFP, .data$COUNTYFP)
    )

  if (!nrow(out)) {
    stop(
      "No counties were returned for ", state_abbr, ". ",
      "Try another state or turn off cartographic boundary files.",
      call. = FALSE
    )
  }

  out
}

assign_quadrant_regions <- function(sf_obj) {
  centroids <- suppressWarnings(sf::st_centroid(sf_obj))
  coords <- sf::st_coordinates(centroids)
  cx <- stats::median(coords[, 1])
  cy <- stats::median(coords[, 2])
  dx <- coords[, 1] - cx
  dy <- coords[, 2] - cy

  sf_obj$region <- dplyr::case_when(
    dy >= 0 & abs(dy) >= abs(dx) ~ "North",
    dy <  0 & abs(dy) >= abs(dx) ~ "South",
    dx >= 0 & abs(dx) >  abs(dy) ~ "East",
    TRUE ~ "West"
  )
  sf_obj
}

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      .container-fluid { padding: 0; }
      .focus-shell { display: grid; grid-template-columns: 300px minmax(0, 1fr); height: 100vh; }
      .focus-controls { padding: 18px; border-right: 1px solid #dbe6f1; overflow-y: auto; background: #fff; }
      .focus-controls h2 { margin-top: 0; font-size: 20px; }
      .focus-map { min-width: 0; min-height: 0; padding: 12px; background: #f5f8fc; }
      .focus-map .html-widget, .focus-map .shiny-html-output { width: 100% !important; height: 100% !important; }
      @media (max-width: 900px) {
        .focus-shell { grid-template-columns: 1fr; grid-template-rows: auto minmax(560px, 1fr); height: auto; min-height: 100vh; }
        .focus-controls { border-right: 0; border-bottom: 1px solid #dbe6f1; }
        .focus-map { height: 75vh; }
      }
      .shiny-output-error-validation {
        color: #713f12;
        background: #fff7ed;
        border: 1px solid #fed7aa;
        border-radius: 6px;
        padding: 14px 16px;
        margin: 12px;
        font-size: 15px;
        line-height: 1.4;
      }
    "))
  ),
  div(
    class = "focus-shell",
    div(
      class = "focus-controls",
      h2("focus_map: counties"),
      selectInput("state", "State", choices = stats::setNames(states$abbr, states$name), selected = "TX"),
      checkboxInput("cb", "Use cartographic boundary file", value = TRUE),
      radioButtons("mode", "Mode", choices = c("Raw" = "raw", "Exploded" = "exploded"), inline = TRUE),
      sliderInput("font_size", "Focused label size", min = 4, max = 16, value = 8, step = 1),
      sliderInput("lift_scale", "Lift scale", min = 1.00, max = 1.35, value = 1.12, step = 0.01),
      sliderInput("focus_size", "Zoomed area size", min = 0.35, max = 1.30, value = 1.17, step = 0.01),
      sliderInput("focus_padding", "Focus padding", min = 12, max = 120, value = 48, step = 4),
      sliderInput("info_card_scale", "Info card size", min = 0.75, max = 1.60, value = 1.60, step = 0.05),
      checkboxInput("show_labels", "Show focused labels", value = TRUE),
      helpText("Zoomed area size controls how much of the viewport the selected area may occupy. Focus padding keeps the boundary away from the edge; lower it if a high zoomed-area size stops getting bigger.")
    ),
    div(
      class = "focus-map",
      focusmapOutput("map", height = "100%")
    )
  )
)

server <- function(input, output, session) {
  counties <- reactive({
    tryCatch(
      load_counties(input$state, cb = isTRUE(input$cb)),
      error = function(e) {
        validate(need(FALSE, app_error("load county boundaries", e)))
      }
    )
  }) |>
    bindCache(input$state, input$cb)

  map_data <- reactive({
    x <- counties()

    if (identical(input$mode, "exploded")) {
      validate(need(
        nrow(x) >= 3,
        "Exploded mode needs at least three mapped areas. Choose a state with more counties or switch to Raw mode."
      ))

      result <- tryCatch(
        {
          projected <- x |>
            sf::st_transform(5070) |>
            assign_quadrant_regions()

          explode_sf(
            projected,
            region_col = "region",
            plot = FALSE,
            quiet = TRUE,
            label = paste(input$state, "counties")
          )
        },
        error = function(e) {
          validate(need(FALSE, app_error("create the exploded map", e)))
        }
      )

      list(x = result, label_col = NULL, group_col = "region")
    } else {
      list(x = x, label_col = "county_label", group_col = NULL)
    }
  })

  output$map <- renderFocusmap({
    md <- map_data()
    tryCatch(
      focus_map(
        md$x,
        label_col = md$label_col,
        id_col = "county_geoid",
        group_col = md$group_col,
        info_cols = c("county_label", "county_geoid"),
        info_labels = c(county_label = "County", county_geoid = "GEOID"),
        info_title = "county_label",
        font_size = input$font_size,
        lift_scale = input$lift_scale,
        focus_size = input$focus_size,
        focus_padding = input$focus_padding,
        info_card_scale = input$info_card_scale,
        show_labels = isTRUE(input$show_labels),
        performance_mode = NULL,
        width = "100%",
        height = "100%"
      ),
      error = function(e) {
        validate(need(FALSE, app_error("render the interactive map", e)))
      }
    )
  })
}

shinyApp(ui, server)
