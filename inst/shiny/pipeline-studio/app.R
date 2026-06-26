# Pipeline Studio: explodemap + dragmapr as one connected workflow.
#
# The loop:
#   1. Explore  - explodemap renders the canonical layout (the "face").
#   2. Refine   - if it looks off, dragmapr edits a *draft* of it.
#   3. Apply    - push the draft back; it becomes the new canonical layout.
#   4. Export   - render and persist the canonical composition.
#
# One dragmapr_state is the single source of truth. Dragging only changes the
# draft, so the canonical renders refresh exactly when you Apply -- nothing is
# recomputed per drag.
#
# Run after installing either package:
#   shiny::runApp(system.file("shiny/pipeline-studio", package = "explodemap"))
#   shiny::runApp(system.file("shiny/pipeline-studio", package = "dragmapr"))

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(sf)
  library(dplyr)
  library(ggplot2)
  library(explodemap)
  library(dragmapr)
})

options(shiny.maxRequestSize = 100 * 1024^2)

# Real TIGER boundaries carry tiny self-intersections that s2's strict loop
# validation rejects ("Loop ... is not valid: Edge ... crosses edge ..."). Use
# the GEOS planar path for lon/lat ops, and make every loaded layer valid.
suppressMessages(try(sf::sf_use_s2(FALSE), silent = TRUE))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

# Make an sf object's geometry valid (no-op for already-valid synthetic data).
make_valid <- function(x) {
  if (!inherits(x, "sf")) return(x)
  tryCatch(sf::st_make_valid(x), error = function(e) x)
}

# Lightly simplify projected geometry so large layers (the national map) render
# quickly. Tolerance scales with the layer's extent; topology is preserved.
simplify_units <- function(x) {
  if (!inherits(x, "sf") || !nrow(x)) return(x)
  bb <- sf::st_bbox(x)
  tol <- as.numeric(max(bb["xmax"] - bb["xmin"], bb["ymax"] - bb["ymin"])) * 0.0012
  if (!is.finite(tol) || tol <= 0) return(x)
  tryCatch(
    make_valid(sf::st_simplify(x, dTolerance = tol, preserveTopology = TRUE)),
    error = function(e) x
  )
}

choose_id_column <- function(cols) {
  hits <- intersect(
    c("GEOID", "geoid", "GEOID20", "GEOID10", "id", "ID", "unit_id", "feature_id"),
    cols
  )
  if (length(hits)) hits[[1L]] else ""
}

make_region_palette <- function(regions) {
  group_palette(regions)
}

geometry_vertex_count <- function(x) {
  if (!inherits(x, "sf")) return(0L)
  count_geometry_vertices(x)
}

validate_upload <- function(x, region_col = NULL, label_col = NULL, id_col = NULL,
                            max_features = 3000L, max_vertices = 500000L,
                            check_vertices = TRUE) {
  issues <- character()
  if (!inherits(x, "sf")) {
    return("The uploaded object is not an sf layer.")
  }
  if (nrow(x) < 2L) {
    issues <- c(issues, "The layer needs at least two features.")
  }
  if (nrow(x) > max_features) {
    issues <- c(issues, paste0("The layer has ", nrow(x),
                               " features; use ", max_features,
                               " or fewer for this public demo."))
  }
  vertices <- geometry_vertex_count(x)
  if (isTRUE(check_vertices) && vertices > max_vertices) {
    issues <- c(issues, paste0("The layer has ", format(vertices, big.mark = ","),
                               " vertices; simplify it before using this public demo."))
  }
  if (is.na(sf::st_crs(x))) {
    issues <- c(issues, "The layer does not declare a coordinate reference system.")
  }
  geometry_types <- unique(as.character(sf::st_geometry_type(x, by_geometry = TRUE)))
  bad_types <- setdiff(geometry_types, c("POLYGON", "MULTIPOLYGON"))
  if (length(bad_types)) {
    issues <- c(issues, paste("Expected polygon geometry; found",
                              paste(bad_types, collapse = ", "), "."))
  }
  if (any(sf::st_is_empty(x))) {
    issues <- c(issues, "The layer contains empty geometries.")
  }

  check_values <- function(col, label) {
    if (is.null(col) || !nzchar(col) || !(col %in% names(x))) return(NULL)
    values <- trimws(as.character(x[[col]]))
    if (anyNA(values) || any(!nzchar(values))) {
      paste0("The selected ", label, " column has missing values.")
    } else {
      NULL
    }
  }
  issues <- c(issues, check_values(region_col, "region/group"))
  issues <- c(issues, check_values(label_col, "label"))

  if (!is.null(region_col) && nzchar(region_col) && region_col %in% names(x)) {
    values <- trimws(as.character(x[[region_col]]))
    values <- values[nzchar(values) & !is.na(values)]
    if (length(unique(values)) < 2L) {
      issues <- c(issues, "At least two unique groups are required.")
    }
  }

  if (!is.null(id_col) && nzchar(id_col) && id_col %in% names(x)) {
    ids <- trimws(as.character(x[[id_col]]))
    if (anyNA(ids) || any(!nzchar(ids))) {
      issues <- c(issues, "Feature IDs cannot be missing.")
    }
    if (anyDuplicated(ids)) {
      issues <- c(issues, "Feature IDs must be unique.")
    }
  }

  issues[!is.na(issues) & nzchar(issues)]
}

validate_prepared_units <- function(x, max_parent_groups = 150L) {
  issues <- character()
  if (is.null(x)) return("No upload is ready yet.")
  if (!all(c("region", "unit_name", "unit_id") %in% names(x))) {
    return("The upload has not been configured.")
  }
  if (anyNA(x$region) || any(!nzchar(trimws(as.character(x$region))))) {
    issues <- c(issues, "Parent groups contain missing values.")
  }
  group_count <- length(unique(as.character(x$region)))
  if (group_count < 2L) {
    issues <- c(issues, "At least two parent groups are required.")
  }
  if (group_count > max_parent_groups) {
    issues <- c(issues, paste0("The configuration creates ", group_count,
                               " parent groups. Use ", max_parent_groups,
                               " or fewer."))
  }
  if (anyNA(x$unit_id) || any(!nzchar(trimws(as.character(x$unit_id))))) {
    issues <- c(issues, "Feature IDs contain missing values.")
  }
  if (anyDuplicated(as.character(x$unit_id))) {
    issues <- c(issues, "Feature IDs must be unique.")
  }
  if (anyNA(x$unit_name) || any(!nzchar(trimws(as.character(x$unit_name))))) {
    issues <- c(issues, "Feature labels contain missing values.")
  }
  issues[!is.na(issues) & nzchar(issues)]
}

assign_cluster_regions <- function(x, groups = 6L, seed = 1L) {
  assign_spatial_groups(x, method = "clusters", groups = groups, seed = seed)
}

geometry_fingerprint <- function(x) {
  explodemap_fingerprint(x, id_col = "unit_id", group_col = "region")
}

project_upload <- function(x) {
  # EPSG:5070 is a better metric layout default than Web Mercator for the US
  # public demo data this app is designed around.
  make_valid(sf::st_transform(make_valid(x), 5070))
}

simplify_upload_vertices <- function(x, target_vertices = 350000L) {
  result <- simplify_to_vertex_budget(x, target_vertices = target_vertices)
  list(x = result$data, before = result$before, after = result$after,
       tolerance = result$tolerance, simplified = result$simplified)
}

layout_fingerprint <- function(layout) {
  x <- layout$sf_grouped
  if (!inherits(x, "sf")) return(NULL)
  id_candidates <- intersect(
    c("unit_id", "GEOID", "geoid", "GEOID20", "GEOID10", "feature_id"),
    names(x)
  )
  x$unit_id <- if (length(id_candidates)) {
    as.character(x[[id_candidates[[1L]]]])
  } else {
    sprintf("feature-%06d", seq_len(nrow(x)))
  }
  if (!"unit_name" %in% names(x)) {
    x$unit_name <- x$unit_id
  }
  geometry_fingerprint(x)
}

app_dir <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile, mustWork = FALSE)),
  error = function(e) getwd()
)

find_data_dir <- function() {
  candidates <- c(
    Sys.getenv("APP_DATA_DIR", ""),
    file.path(app_dir, "data"),
    system.file("huggingface/data", package = "explodemap"),
    system.file("extdata", package = "explodemap")
  )
  for (d in candidates) {
    if (nzchar(d) && file.exists(file.path(d, "us_states.rds"))) return(d)
  }
  ""
}

DATA_DIR <- find_data_dir()
HAVE_DATA <- nzchar(DATA_DIR)

read_layer <- function(name) {
  if (!HAVE_DATA) return(NULL)
  path <- file.path(DATA_DIR, name)
  if (!file.exists(path)) return(NULL)
  tryCatch(readRDS(path), error = function(e) NULL)
}

# TRUE only when a real pre-baked data file exists. Used to tell the user when a
# layout is real vs synthetic demonstration geometry.
data_file_exists <- function(name) HAVE_DATA && file.exists(file.path(DATA_DIR, name))

drill_choices <- function() {
  abbrs <- c(NewJersey = "NJ", Pennsylvania = "PA", California = "CA",
             Georgia = "GA", Texas = "TX")
  if (HAVE_DATA) {
    have <- vapply(
      abbrs,
      function(a) file.exists(file.path(DATA_DIR, paste0(a, "_counties.rds"))),
      logical(1)
    )
    abbrs <- abbrs[have]
  }
  if (!length(abbrs)) c(Synthetic = "DEMO") else abbrs
}

DRILL_CHOICES <- drill_choices()

# The Explore picker: the national HHS map (always available, synthetic if no
# data) plus any state county drill-downs that have data.
MAP_SOURCES <- c(`National (HHS regions)` = "HHS", DRILL_CHOICES,
                 `Upload U.S. polygon data` = "UPLOAD")

display_field <- function(value, fallback) {
  if (is.null(value) || !nzchar(value)) fallback else value
}

assign_quadrant_regions <- function(sf_obj) {
  assign_spatial_groups(sf_obj, method = "quadrants")
}

synthetic_units <- function(seed = 1) {
  set.seed(seed)
  cell <- function(x0, y0, s = 24000) {
    sf::st_polygon(list(rbind(
      c(x0, y0), c(x0 + s, y0), c(x0 + s, y0 + s),
      c(x0, y0 + s), c(x0, y0)
    )))
  }
  grid <- expand.grid(col = 0:5, row = 0:5)
  sf::st_sf(
    unit_id = sprintf("u%02d", seq_len(nrow(grid))),
    unit_name = sprintf("Unit %02d", seq_len(nrow(grid))),
    value = round(runif(nrow(grid), 20, 120)),
    geometry = sf::st_sfc(
      lapply(seq_len(nrow(grid)), function(i) {
        cell(grid$col[i] * 30000, grid$row[i] * 30000)
      }),
      crs = 5070
    )
  )
}

synthetic_states <- function() {
  cell <- function(x0, y0, w = 90000, h = 65000) {
    sf::st_polygon(list(rbind(
      c(x0, y0), c(x0 + w, y0), c(x0 + w, y0 + h),
      c(x0, y0 + h), c(x0, y0)
    )))
  }
  grid <- expand.grid(col = 0:4, row = 0:1)
  sf::st_sf(
    STUSPS = sprintf("S%02d", seq_len(nrow(grid))),
    NAME = paste("Demo state", seq_len(nrow(grid))),
    hhs_region = as.character(seq_len(nrow(grid))),
    geometry = sf::st_sfc(
      lapply(seq_len(nrow(grid)), function(i) {
        cell(grid$col[i] * 110000, grid$row[i] * 85000)
      }),
      crs = 5070
    )
  )
}

us_states_raw <- read_layer("us_states.rds")
US_STATES_REAL <- !is.null(us_states_raw)
us_states <- make_valid(us_states_raw %||% synthetic_states())

# Turn a state's counties (or municipalities) into projected units.
#   level = "county" -> counties grouped into N/S/E/W quadrant regions.
#   level = "muni"   -> municipalities grouped by their parent county
#                       (this is the "decompose counties into municipalities").
load_state_units <- function(abbr, level = "county") {
  # Only the explicit DEMO source may synthesize geometry. Real sources either
  # return real data or fail, so compute_source() is the single place that
  # decides whether to substitute a demonstration.
  if (identical(abbr, "DEMO")) {
    return(assign_quadrant_regions(synthetic_units()))
  }
  file <- if (identical(level, "muni")) "_munis.rds" else "_counties.rds"
  raw <- read_layer(paste0(abbr, file))
  if (is.null(raw)) {
    stop("Could not read ", abbr, file, ".", call. = FALSE)
  }
  # Web Mercator keeps a single state north-up (Albers shears eastern states).
  units <- simplify_units(make_valid(sf::st_transform(make_valid(raw), 3857)))
  name_col <- intersect(
    c("NAME", "name", "NAMELSAD", "muni_label", "unit_name"), names(units)
  )[1]
  units$unit_name <- if (!is.na(name_col)) {
    as.character(units[[name_col]])
  } else {
    sprintf("Unit %d", seq_len(nrow(units)))
  }
  units$unit_id <- sprintf("u%05d", seq_len(nrow(units)))
  if (identical(level, "muni")) {
    county_col <- intersect(
      c("county_name", "COUNTYNAME", "NAMELSADCO", "COUNTY", "COUNTYFP", "county"),
      names(units)
    )[1]
    if (!is.na(county_col)) {
      units$region <- as.character(units[[county_col]])
      return(units)
    }
  }
  assign_quadrant_regions(units)
}

# National HHS units: real states grouped by HHS region, with a uniform
# `region` + `unit_name` so the rest of the pipeline is identical to a state.
load_hhs_units <- function() {
  # Let an as_hhs_states() failure propagate to compute_source(), which is the
  # only place allowed to fall back to demonstration geometry.
  units <- as_hhs_states(us_states)
  units <- simplify_units(make_valid(sf::st_transform(units, 5070)))
  units$region <- as.character(units$hhs_region)
  name_col <- intersect(c("state_label", "NAME", "STUSPS", "unit_name"), names(units))[1]
  units$unit_name <- if (!is.na(name_col)) as.character(units[[name_col]]) else units$region
  units
}

# National HHS layout seeded with the published display offsets, so the region
# placement matches explodemap's reference map. Still a refinable
# grouped_exploded_map; falls back to the algorithmic explode on any failure.
hhs_canonical_layout <- function() {
  units <- load_hhs_units()
  offs <- tryCatch(hhs_display_offsets(), error = function(e) NULL)
  anchors <- NULL
  if (!is.null(offs) && "region" %in% names(units)) {
    g <- sf::st_geometry(units)
    reg <- as.character(units$region)
    rs <- unique(reg)
    cc <- t(vapply(rs, function(r) {
      suppressWarnings(
        sf::st_coordinates(sf::st_centroid(sf::st_union(g[reg == r])))
      )[1, 1:2]
    }, numeric(2)))
    base <- data.frame(region = rs, cx = cc[, 1], cy = cc[, 2], stringsAsFactors = FALSE)
    offs$region <- as.character(offs$region)
    base <- merge(base, offs[, c("region", "dx_m", "dy_m")], by = "region", all.x = TRUE)
    base$dx_m[is.na(base$dx_m)] <- 0
    base$dy_m[is.na(base$dy_m)] <- 0
    anchors <- data.frame(
      region = base$region,
      anchor_x = base$cx + base$dx_m,
      anchor_y = base$cy + base$dy_m,
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(anchors)) {
    tryCatch(
      explode_grouped(units, region_col = "region", mode = "manual",
                      anchors = anchors, plot = FALSE, quiet = TRUE),
      error = function(e) explode_grouped(units, region_col = "region",
                                          plot = FALSE, quiet = TRUE)
    )
  } else {
    explode_grouped(units, region_col = "region", plot = FALSE, quiet = TRUE)
  }
}

# Compute a grouped layout, with an optional label-aware parameter search.
compute_layout <- function(units, optimize = FALSE) {
  if (isTRUE(optimize)) {
    grid <- expand.grid(
      kappa = c(1.4, 2.0),
      padding = c(30000, 60000),
      delta = 12000,
      padding_sep = 18000,
      KEEP.OUT.ATTRS = FALSE
    )
    optimize_grouped_layout(
      units, region_col = "region", label_col = "unit_name", grid = grid
    )
  } else {
    explode_grouped(units, region_col = "region", plot = FALSE, quiet = TRUE)
  }
}

# Compute a source's layout. Returns list(layout, fallback): `fallback` is a
# message when synthetic demonstration geometry was substituted (NULL = real
# data). The app never errors, but it also never silently passes synthetic data
# off as real.
compute_source <- function(source, optimize = FALSE, level = "county", upload = NULL) {
  demo <- function(msg) {
    list(layout = compute_layout(load_state_units("DEMO")), fallback = msg, error = NULL)
  }
  if (identical(source, "UPLOAD")) {
    if (is.null(upload)) {
      return(list(layout = NULL, fallback = NULL,
                  error = paste("Upload a polygon file (GeoPackage, GeoJSON, zipped",
                                "shapefile, or .rds) and choose its columns to begin.")))
    }
    return(tryCatch(
      list(layout = compute_layout(upload, optimize = optimize), fallback = NULL),
      error = function(e) list(layout = NULL, fallback = NULL,
                               error = paste0("Could not build a layout from the upload: ",
                                              conditionMessage(e)))
    ))
  }
  if (identical(source, "HHS")) {
    if (!US_STATES_REAL) {
      return(demo("No us_states.rds found - showing synthetic demonstration geometry."))
    }
    return(tryCatch(
      list(layout = hhs_canonical_layout(), fallback = NULL, error = NULL),
      error = function(e) demo(paste0("HHS layout could not be built (",
                                      conditionMessage(e), ")."))
    ))
  }
  file <- if (identical(level, "muni")) {
    paste0(source, "_munis.rds")
  } else {
    paste0(source, "_counties.rds")
  }
  if (!data_file_exists(file)) {
    return(demo(paste0("No data file '", file,
                       "' - showing synthetic demonstration geometry.")))
  }
  tryCatch(
    list(layout = compute_layout(load_state_units(source, level), optimize = optimize),
         fallback = NULL, error = NULL),
    error = function(e) demo(paste0("Layout could not be built (",
                                    conditionMessage(e), ")."))
  )
}

BG_CHOICES <- c("White" = "white", "Light grid" = "light_grid",
                "Dark" = "dark", "Transparent" = "transparent")

# Count how many region and label offsets differ between a draft and a canonical
# state (movements beyond `tol` metres). Returns list(regions, labels).
offset_changes <- function(draft, canonical, tol = 1) {
  cmp <- function(x, y, key) {
    if (is.null(x) || is.null(y)) return(0L)
    if (nrow(x) == 0L && nrow(y) == 0L) return(0L)
    j <- merge(x, y, by = key, suffixes = c(".d", ".c"), all = TRUE)
    dxd <- j$dx_m.d; dyd <- j$dy_m.d; dxc <- j$dx_m.c; dyc <- j$dy_m.c
    dxd[is.na(dxd)] <- 0; dyd[is.na(dyd)] <- 0
    dxc[is.na(dxc)] <- 0; dyc[is.na(dyc)] <- 0
    sum(abs(dxd - dxc) > tol | abs(dyd - dyc) > tol)
  }
  list(
    regions = cmp(draft$region_offsets, canonical$region_offsets, "region"),
    labels = cmp(draft$label_offsets, canonical$label_offsets, "label_id")
  )
}

# Raw composition state, tucked into a collapsed developer accordion so it does
# not dominate the interface.
state_bar <- function(id) {
  accordion(
    open = FALSE,
    accordion_panel(
      "Developer details (raw state)",
      verbatimTextOutput(id, placeholder = TRUE)
    )
  )
}

theme <- bs_theme(version = 5, bootswatch = "flatly", primary = "#2166ac")

note <- function(...) p(class = "pipeline-note", ...)

# A small spinner overlay on any output that is recalculating (e.g. while a
# big layout builds). Falls back gracefully on older bslib.
busy_indicators <- tryCatch(bslib::useBusyIndicators(), error = function(e) NULL)

pipeline_overlay <- div(
  id = "pipeline-process-overlay",
  class = "pipeline-process-overlay",
  div(
    class = "pipeline-process-pill",
    div(
      class = "spinner-border spinner-border-sm",
      role = "status",
      tags$span(class = "visually-hidden", "Processing")
    ),
    span(id = "pipeline-process-message", "Processing...")
  )
)

ui <- page_navbar(
  id = "stage",
  title = "Pipeline Studio",
  theme = theme,
  fillable = TRUE,
  header = tagList(
    busy_indicators,
    pipeline_overlay,
    tags$head(tags$style(HTML(paste(
      ".shiny-text-output{font-size:0.8rem;}",
      ".card-header{font-weight:600;}",
      ".pipeline-note{font-size:0.9rem;color:#5f6b76;}",
      "body.pipeline-is-processing{overflow:hidden;}",
      ".pipeline-process-overlay{position:fixed;inset:56px 0 0 0;z-index:1060;display:none;align-items:center;justify-content:center;background:rgba(248,250,251,0.62);backdrop-filter:blur(2px);-webkit-backdrop-filter:blur(2px);cursor:wait;}",
      ".pipeline-process-overlay.is-visible{display:flex;}",
      ".pipeline-process-pill{display:inline-flex;align-items:center;gap:0.65rem;max-width:min(90vw,460px);padding:0.7rem 1rem;border:1px solid rgba(56,78,88,0.16);border-radius:999px;background:rgba(255,255,255,0.94);box-shadow:0 8px 28px rgba(34,52,61,0.12);color:#3c515a;font-size:0.9rem;font-weight:500;}",
      ".pipeline-process-pill .spinner-border{width:1rem;height:1rem;border-width:0.14rem;}",
      sep = "\n"
    ))),
    tags$script(HTML("
      (() => {
        let showTimer = null;

        Shiny.addCustomMessageHandler('pipeline-process-show', (message) => {
          const overlay = document.getElementById('pipeline-process-overlay');
          const label = document.getElementById('pipeline-process-message');
          if (!overlay || !label) return;
          label.textContent = message.text || 'Processing...';
          window.clearTimeout(showTimer);
          showTimer = window.setTimeout(() => {
            overlay.classList.add('is-visible');
            overlay.setAttribute('aria-busy', 'true');
            document.body.classList.add('pipeline-is-processing');
          }, message.delay ?? 200);
        });

        Shiny.addCustomMessageHandler('pipeline-process-update', (message) => {
          const label = document.getElementById('pipeline-process-message');
          if (label) label.textContent = message.text || 'Processing...';
        });

        Shiny.addCustomMessageHandler('pipeline-process-hide', () => {
          const overlay = document.getElementById('pipeline-process-overlay');
          window.clearTimeout(showTimer);
          if (overlay) {
            overlay.classList.remove('is-visible');
            overlay.removeAttribute('aria-busy');
          }
          document.body.classList.remove('pipeline-is-processing');
        });
      })();
    ")))
  ),

  # ---- 1. Explore: explodemap renders the canonical layout ------------------
  nav_panel(
    title = "1 - Explore",
    value = "explore",
    layout_sidebar(
      sidebar = sidebar(
        width = 310,
        if (!HAVE_DATA) div(
          class = "alert alert-warning p-2",
          "No boundary data found - using synthetic geometry. ",
          "Set APP_DATA_DIR to use local pre-baked data."
        ),
        h6("Map"),
        selectInput("map_source", "Layout to explore", choices = MAP_SOURCES),
        conditionalPanel(
          "input.map_source == 'HHS'",
          note("Geography: published HHS region placement.")
        ),
        conditionalPanel(
          "input.map_source == 'UPLOAD'",
          accordion(
            open = c("1. Upload", "2. Configure"),
            accordion_panel(
              "1. Upload",
              fileInput("upload_file", "Spatial file",
                        accept = c(".gpkg", ".geojson", ".json", ".rds", ".zip")),
              uiOutput("upload_layer_ui")
            ),
            accordion_panel(
              "2. Configure",
              selectInput("upload_id", "Feature ID", choices = c("(row number)" = "")),
              div(class = "pipeline-note mb-2", "A unique value for every polygon."),
              selectInput("upload_label", "Feature label", choices = c("(row number)" = "")),
              div(class = "pipeline-note mb-2", "The text displayed for each polygon."),
              selectInput(
                "upload_group_method",
                "Parent groups",
                choices = c(
                  "Use a column" = "column",
                  "Create spatial quadrants" = "quadrants",
                  "Create spatial clusters" = "clusters",
                  "Treat every polygon separately" = "individual"
                ),
                selected = "quadrants"
              ),
              conditionalPanel(
                "input.upload_group_method == 'column'",
                selectInput("upload_region", "Parent-group column", choices = NULL)
              ),
              conditionalPanel(
                "input.upload_group_method == 'clusters'",
                sliderInput("upload_cluster_count", "Number of groups",
                            min = 2, max = 20, value = 6, step = 1)
              ),
              checkboxInput("upload_auto_simplify", "Auto-simplify large uploads", TRUE),
              conditionalPanel(
                "input.upload_auto_simplify",
                sliderInput("upload_vertex_target", "Target vertices",
                            min = 100000, max = 750000, value = 350000,
                            step = 50000)
              ),
              uiOutput("upload_summary")
            )
          )
        ),
        conditionalPanel(
          "input.map_source != 'HHS' && input.map_source != 'UPLOAD'",
          selectInput(
            "granularity", "Geography",
            c("Counties" = "county", "Municipalities" = "muni")
          ),
          selectInput(
            "focus_preset", "Focus behavior",
            c(
              "None" = "none",
              "Municipal focus" = "municipal",
              "Parent-to-child drill-down" = "drilldown"
            ),
            selected = "none"
          )
        ),
        checkboxInput("show_labels", "Show labels", TRUE),
        checkboxInput("show_region_labels", "Show region labels", TRUE),
        conditionalPanel(
          "input.map_source != 'HHS'",
          checkboxInput("optimize", "Label-aware parameter search", FALSE)
        ),
        uiOutput("compute_action"),
        checkboxInput("show_diag", "Show layout diagnostics", FALSE),
        hr(),
        note("Is the exploded layout off from what you expected?"),
        actionButton(
          "go_refine", "Refine in dragmapr ->",
          class = "btn-primary w-100"
        )
      ),
      card(
        card_header(
          textOutput("explore_title", inline = TRUE),
          uiOutput("source_status", inline = TRUE)
        ),
        card_body(focusmapOutput("explore_map", height = "560px"))
      ),
      conditionalPanel(
        "input.show_diag",
        card(
          card_header("Layout diagnostics"),
          card_body(
            uiOutput("explore_diag_boxes"),
            plotOutput("explore_diag_plot", height = "360px")
          )
        )
      )
    )
  ),

  # ---- 2. Refine: dragmapr edits a draft of the canonical layout ------------
  nav_panel(
    title = "2 - Refine",
    value = "refine",
    layout_sidebar(
      sidebar = sidebar(
        width = 310,
        note(paste(
          "Drag regions to fix the layout. Edits change a draft only -",
          "Apply makes them the new face of explodemap."
        )),
        h6("Selection"),
        selectInput("sel_region", "Focus a region", choices = NULL),
        h6("Display"),
        checkboxInput("editor_labels", "Show labels", TRUE),
        checkboxInput("show_origin", "Origin outlines", FALSE),
        checkboxInput("show_connectors", "Movement connectors", FALSE),
        checkboxInput("show_trail", "Drag trail", FALSE),
        selectInput("map_bg", "Background", choices = BG_CHOICES),
        hr(),
        actionButton("apply", "Apply to explodemap", class = "btn-success w-100 mb-2"),
        actionButton("reset_draft", "Reset draft", class = "btn-outline-secondary w-100")
      ),
      card(
        card_header("Draggable editor (draft)", uiOutput("dirty_badge", inline = TRUE)),
        dragmaprOutput("editor", height = "560px")
      ),
      state_bar("draft_state")
    )
  ),

  # ---- 3. Export: render + persist the canonical composition ----------------
  nav_panel(
    title = "3 - Export",
    value = "export",
    layout_sidebar(
      sidebar = sidebar(
        width = 310,
        note("The canonical composition - the result of everything you applied."),
        textInput("export_title", "Title", value = "Composed layout"),
        checkboxInput("export_labels", "Show labels", TRUE),
        downloadButton("save_state", "Save state JSON", class = "w-100 mb-2"),
        downloadButton("save_png", "Save static PNG", class = "w-100 mb-2"),
        fileInput("load_state", "Load state JSON", accept = ".json")
      ),
      uiOutput("export_warning"),
      card(
        card_header("Static re-render (no recomputation)"),
        plotOutput("export_static", height = "560px")
      ),
      state_bar("export_state")
    )
  ),

  nav_spacer(),
  nav_item(tags$a("explodemap docs", href = "https://prigasg.github.io/explodemap/", target = "_blank")),
  nav_item(tags$a("dragmapr docs", href = "https://prigasg.github.io/dragmapr/", target = "_blank"))
)

server <- function(input, output, session) {

  process_depth <- reactiveVal(0L)

  show_process <- function(message, delay = 200L) {
    process_depth(process_depth() + 1L)
    session$sendCustomMessage(
      "pipeline-process-show",
      list(text = message, delay = delay)
    )
  }

  update_process <- function(message) {
    session$sendCustomMessage("pipeline-process-update", list(text = message))
  }

  hide_process <- function() {
    remaining <- max(0L, process_depth() - 1L)
    process_depth(remaining)
    if (remaining == 0L) {
      session$sendCustomMessage("pipeline-process-hide", list())
    }
  }

  run_process <- function(message, task, delay = 200L) {
    show_process(message, delay = delay)
    runner <- function() {
      on.exit(hide_process(), add = TRUE)
      tryCatch(
        task(),
        error = function(e) {
          showNotification(conditionMessage(e), type = "error", duration = 10)
        }
      )
    }
    if (requireNamespace("later", quietly = TRUE)) {
      later::later(runner, delay = 0.05)
    } else {
      runner()
    }
    invisible(NULL)
  }

  state_summary <- function(s) {
    if (is.null(s)) return("No composition yet.")
    moved <- s$region_offsets[
      s$region_offsets$dx_m != 0 | s$region_offsets$dy_m != 0, , drop = FALSE
    ]
    paste0(
      "revision:    ", s$version, "\n",
      "crs:         ", format(s$crs), "\n",
      "geometry_id: ", s$geometry_id %||% "(none)", "\n",
      "selected:    ", s$selected_feature %||% "(none)", "\n",
      "moved:       ", if (nrow(moved)) paste(moved$region, collapse = ", ") else "(none)"
    )
  }

  diag_boxes <- function(report) {
    fmt <- function(v) if (is.null(v) || is.na(v)) "-" else v
    layout_columns(
      fill = FALSE, col_widths = c(3, 3, 3, 3),
      value_box("Overlaps", nrow(report$overlapping_pairs), theme = "primary"),
      value_box("Label overlaps", fmt(report$label_overlap_count), theme = "secondary"),
      value_box("Utilization", sprintf("%.2f", report$canvas_utilization), theme = "secondary"),
      value_box("Min gap", fmt(round(report$minimum_group_gap)), theme = "secondary")
    )
  }

  # Single source of truth. `state` is the canonical "face"; `draft` is what the
  # editor is currently changing; `egen` forces the editor to re-seed. `saved`
  # caches each source's applied composition so switching layouts (and back)
  # never loses progress.
  rv <- reactiveValues(layout = NULL, state = NULL, draft = NULL,
                       source = MAP_SOURCES[[1]], level = "county",
                       key = NULL, saved = list(), fallback = NULL,
                       palette = NULL, egen = 0L)

  upload_source <- reactiveValues(path = NULL, name = NULL, size = NULL,
                                  type = NULL, layers = character(),
                                  layer_paths = character(),
                                  extracted_dir = NULL)

  upload_geometry_id <- function() {
    x <- upload_units()
    if (is.null(x)) return(NULL)
    issues <- validate_prepared_units(x)
    if (length(issues)) return(NULL)
    geometry_fingerprint(x)
  }

  source_key <- function(source, level, optimize = FALSE) {
    if (identical(source, "HHS")) {
      return("HHS")
    }
    if (identical(source, "UPLOAD")) {
      return(paste(
        "UPLOAD",
        upload_geometry_id() %||% "none",
        isTRUE(optimize),
        sep = ":"
      ))
    }
    paste(source, level, isTRUE(optimize), sep = ":")
  }

  set_canonical <- function(res, source, level, optimize = FALSE, restore_saved = TRUE) {
    if (!is.null(res$error)) {
      showNotification(res$error, type = "error", duration = 10)
      return(invisible(FALSE))
    }
    key <- source_key(source, level, optimize = optimize)
    rv$layout <- res$layout
    rv$fallback <- res$fallback
    layout_id <- layout_fingerprint(res$layout) %||% key
    fresh <- as_dragmapr_state(res$layout, geometry_id = paste0("studio-", layout_id))
    saved <- rv$saved[[key]]
    # Restore this source's saved canonical AND draft if its regions still match;
    # otherwise start fresh. Preserving the draft means switching maps never
    # loses unfinished (unapplied) work.
    can_restore <- isTRUE(restore_saved) &&
      !is.null(saved) &&
      identical(saved$canonical$geometry_id, fresh$geometry_id) &&
      setequal(saved$canonical$region_offsets$region, fresh$region_offsets$region)
    if (can_restore) {
      rv$state <- saved$canonical
      rv$draft <- saved$draft %||% saved$canonical
      rv$palette <- saved$palette %||% make_region_palette(res$layout$sf_grouped$region)
    } else {
      rv$state <- fresh
      rv$draft <- fresh
      rv$palette <- make_region_palette(res$layout$sf_grouped$region)
    }
    rv$source <- source
    rv$level <- level
    rv$key <- key
    rv$egen <- rv$egen + 1L
    regions <- sort(unique(as.character(rv$state$region_offsets$region)))
    updateSelectInput(session, "sel_region", choices = regions)
    invisible(TRUE)
  }

  # Stash the current source's composition (call before switching away, and
  # after Apply / load) so it survives layout changes.
  remember_current <- function() {
    if (!is.null(rv$key)) {
      rv$saved[[rv$key]] <- list(canonical = rv$state, draft = rv$draft,
                                 palette = rv$palette)
    }
  }

  active_palette <- reactive({
    req(rv$palette)
    rv$palette
  })

  # Region + label movements the draft has applied over the canonical state.
  draft_diff <- reactive({
    if (is.null(rv$draft) || is.null(rv$state)) return(list(regions = 0L, labels = 0L))
    offset_changes(rv$draft, rv$state)
  })
  draft_changes <- reactive({
    d <- draft_diff()
    d$regions + d$labels
  })

  # Reflect unapplied edits in the Apply button label.
  observe({
    n <- draft_changes()
    label <- if (n > 0) sprintf("Apply %d change%s", n, if (n == 1) "" else "s") else
      "Apply to explodemap"
    updateActionButton(session, "apply", label = label)
  })

  # Real vs demonstration-data badge shown next to the Explore title.
  output$source_status <- renderUI({
    if (identical(rv$source, "UPLOAD") && is.null(rv$fallback)) {
      return(span(class = "badge bg-primary ms-2", "Uploaded data"))
    }
    if (is.null(rv$fallback)) {
      span(class = "badge bg-success ms-2", "Bundled data")
    } else {
      tagList(
        span(class = "badge bg-warning text-dark ms-2", "Demonstration data"),
        span(class = "pipeline-note ms-2", rv$fallback)
      )
    }
  })

  # Unapplied-edits badge (regions + labels) shown on the editor card.
  output$dirty_badge <- renderUI({
    d <- draft_diff()
    if (d$regions + d$labels == 0) {
      return(span(class = "badge bg-success ms-2", "Applied"))
    }
    parts <- character()
    if (d$regions > 0) parts <- c(parts, sprintf("%d region%s", d$regions, if (d$regions == 1) "" else "s"))
    if (d$labels > 0) parts <- c(parts, sprintf("%d label%s", d$labels, if (d$labels == 1) "" else "s"))
    span(class = "badge bg-warning text-dark ms-2",
         paste0(paste(parts, collapse = " and "), " unapplied"))
  })

  output$compute_action <- renderUI({
    if (identical(input$map_source, "UPLOAD")) {
      issues <- prepared_upload_issues()
      actionButton(
        "compute",
        "Explode uploaded layer",
        class = "btn-primary w-100 mb-2",
        disabled = if (length(issues)) "disabled" else NULL
      )
    } else {
      actionButton("compute", "Render layout", class = "btn-primary w-100 mb-2")
    }
  })

  # ----- User-uploaded spatial data -----------------------------------------
  uploaded_projected_sf <- reactiveVal(NULL)
  uploaded_sf <- reactiveVal(NULL)
  upload_simplify_info <- reactiveVal(NULL)

  cleanup_upload_dir <- function() {
    path <- isolate(upload_source$extracted_dir)
    if (!is.null(path) && dir.exists(path)) {
      unlink(path, recursive = TRUE, force = TRUE)
    }
    isolate(upload_source$extracted_dir <- NULL)
  }
  session$onSessionEnded(function() cleanup_upload_dir())

  apply_upload_simplification <- function() {
    obj <- uploaded_projected_sf()
    if (is.null(obj)) return(invisible(NULL))
    if (isTRUE(input$upload_auto_simplify)) {
      update_process(
        paste0("Simplifying ", format(geometry_vertex_count(obj), big.mark = ","),
               " vertices...")
      )
      simplified <- simplify_upload_vertices(
        obj,
        target_vertices = input$upload_vertex_target %||% 350000L
      )
      if (simplified$after > 500000L) {
        uploaded_sf(NULL)
        upload_simplify_info(simplified)
        showNotification(
          paste0(
            "The layer still has ", format(simplified$after, big.mark = ","),
            " vertices after simplification. Lower the target vertices or simplify it before upload."
          ),
          type = "error", duration = 10
        )
        return(invisible(NULL))
      }
      uploaded_sf(simplified$x)
      upload_simplify_info(simplified)
    } else {
      vertices <- geometry_vertex_count(obj)
      if (vertices > 500000L) {
        uploaded_sf(NULL)
        upload_simplify_info(NULL)
        showNotification(
          paste0("The layer has ", format(vertices, big.mark = ","),
                 " vertices. Enable auto-simplify or simplify it before upload."),
          type = "error", duration = 10
        )
        return(invisible(NULL))
      }
      uploaded_sf(obj)
      upload_simplify_info(NULL)
    }
    invisible(uploaded_sf())
  }

  read_upload_layer <- function() {
    req(upload_source$path)
    ext <- upload_source$type
    layer <- input$upload_layer %||% ""
    if (identical(ext, "rds")) {
      return(readRDS(upload_source$path))
    }
    if (identical(ext, "zip")) {
      paths <- upload_source$layer_paths
      if (!length(paths)) stop("No .shp file found in the zip.", call. = FALSE)
      idx <- match(layer, names(paths))
      if (is.na(idx)) idx <- 1L
      return(sf::st_read(paths[[idx]], quiet = TRUE))
    }
    if (identical(ext, "gpkg") && nzchar(layer)) {
      return(sf::st_read(upload_source$path, layer = layer, quiet = TRUE))
    }
    sf::st_read(upload_source$path, quiet = TRUE)
  }

  prepare_uploaded_layer <- function() {
    if (is.null(upload_source$path)) return(invisible(NULL))
    update_process("Reading selected layer...")
    obj <- tryCatch(read_upload_layer(), error = function(e) e)

    if (inherits(obj, "error") || !inherits(obj, "sf")) {
      uploaded_projected_sf(NULL)
      uploaded_sf(NULL)
      showNotification(
        paste0("Could not read that as spatial data",
               if (inherits(obj, "error")) paste0(": ", conditionMessage(obj)) else "."),
        type = "error", duration = 8
      )
      return(invisible(NULL))
    }

    uploaded_projected_sf(NULL)
    upload_simplify_info(NULL)
    issues <- validate_upload(
      obj,
      check_vertices = !isTRUE(input$upload_auto_simplify)
    )
    if (length(issues)) {
      uploaded_sf(NULL)
      showNotification(paste(issues, collapse = " "), type = "error", duration = 10)
      return(invisible(NULL))
    }

    update_process("Projecting and repairing polygons...")
    projected <- tryCatch(project_upload(obj), error = function(e) NULL)
    if (is.null(projected)) {
      uploaded_sf(NULL)
      showNotification("Could not project that geometry.", type = "error")
      return(invisible(NULL))
    }
    uploaded_projected_sf(projected)

    obj <- apply_upload_simplification()
    if (is.null(obj)) return(invisible(NULL))
    cols <- setdiff(names(obj), attr(obj, "sf_column"))
    id_default <- choose_id_column(cols)
    updateSelectInput(session, "upload_region", choices = cols)
    updateSelectInput(session, "upload_label",
                      choices = c("(row number)" = "", cols))
    updateSelectInput(session, "upload_id",
                      choices = c("(row number)" = "", cols),
                      selected = id_default)
    showNotification(sprintf("Loaded %d polygons. Configure fields, then explode.",
                             nrow(obj)), type = "message")
    invisible(obj)
  }

  handle_uploaded_file <- function(f) {
    if (!is.null(f$size) && as.numeric(f$size) > 100 * 1024^2) {
      showNotification("The file exceeds the 100 MB upload limit.",
                       type = "error", duration = 8)
      return(invisible(NULL))
    }
    cleanup_upload_dir()
    uploaded_projected_sf(NULL)
    uploaded_sf(NULL)
    upload_source$path <- f$datapath
    upload_source$name <- f$name
    upload_source$size <- f$size
    upload_source$type <- tolower(tools::file_ext(f$name))
    upload_source$layers <- character()
    upload_source$layer_paths <- character()
    upload_source$extracted_dir <- NULL

    if (upload_source$type == "gpkg") {
      update_process("Inspecting GeoPackage layers...")
      upload_source$layers <- tryCatch(sf::st_layers(f$datapath)$name,
                                       error = function(e) character())
    } else if (upload_source$type == "zip") {
      update_process("Inspecting ZIP contents...")
      zip_info <- tryCatch(utils::unzip(f$datapath, list = TRUE),
                           error = function(e) NULL)
      if (is.null(zip_info)) {
        showNotification("Could not inspect that ZIP file.", type = "error")
        return(invisible(NULL))
      }
      if (nrow(zip_info) > 100L) {
        showNotification("The ZIP contains too many files.", type = "error")
        return(invisible(NULL))
      }
      if (sum(zip_info$Length, na.rm = TRUE) > 300 * 1024^2) {
        showNotification("The uncompressed ZIP is too large.", type = "error")
        return(invisible(NULL))
      }
      bad_paths <- grepl("(^|[\\\\/])\\.\\.([\\\\/]|$)|^[/\\\\]|^[A-Za-z]:", zip_info$Name)
      if (any(bad_paths)) {
        showNotification("The ZIP contains unsafe file paths.", type = "error")
        return(invisible(NULL))
      }
      update_process("Extracting shapefile archive...")
      td <- file.path(tempdir(), paste0("upload_", as.integer(stats::runif(1, 1, 1e6))))
      dir.create(td, showWarnings = FALSE)
      utils::unzip(f$datapath, exdir = td)
      shp <- list.files(td, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
      if (length(shp) > 20L) {
        cleanup_upload_dir()
        showNotification("The ZIP contains too many shapefiles.", type = "error")
        return(invisible(NULL))
      }
      upload_source$extracted_dir <- td
      upload_source$layers <- tools::file_path_sans_ext(basename(shp))
      upload_source$layer_paths <- stats::setNames(shp, upload_source$layers)
    }

    if (length(upload_source$layers) > 1L) {
      updateSelectInput(session, "upload_layer",
                        choices = upload_source$layers,
                        selected = upload_source$layers[[1L]])
    } else {
      prepare_uploaded_layer()
    }
    invisible(NULL)
  }

  observeEvent(input$upload_file, {
    f <- input$upload_file
    req(f)
    run_process("Reading uploaded geometry...", function() handle_uploaded_file(f))
  })

  observeEvent(input$upload_layer, {
    if (!is.null(upload_source$path) && nzchar(input$upload_layer %||% "")) {
      run_process(
        paste0("Preparing layer \"", input$upload_layer, "\"..."),
        prepare_uploaded_layer
      )
    }
  })

  observeEvent(input$upload_auto_simplify, {
    if (!is.null(uploaded_projected_sf())) {
      run_process("Simplifying uploaded geometry...", apply_upload_simplification,
                  delay = 250L)
    }
  }, ignoreInit = TRUE)

  vertex_target <- shiny::debounce(reactive(input$upload_vertex_target), millis = 500)
  observeEvent(vertex_target(), {
    if (!is.null(uploaded_projected_sf()) && isTRUE(input$upload_auto_simplify)) {
      run_process("Simplifying uploaded geometry...", apply_upload_simplification,
                  delay = 250L)
    }
  }, ignoreInit = TRUE)

  output$upload_layer_ui <- renderUI({
    if (length(upload_source$layers) <= 1L) return(NULL)
    selectInput("upload_layer", "Layer", choices = upload_source$layers)
  })

  upload_validation <- reactive({
    u <- uploaded_sf()
    if (is.null(u)) return(character())
    issues <- validate_upload(
      u,
      region_col = if (identical(input$upload_group_method, "column")) {
        input$upload_region %||% ""
      } else {
        ""
      },
      label_col = input$upload_label %||% "",
      id_col = input$upload_id %||% ""
    )
    if (identical(input$upload_group_method, "column") &&
        !nzchar(input$upload_region %||% "")) {
      issues <- c(issues, "Choose a parent-group column.")
    }
    issues
  })

  prepared_upload_issues <- reactive({
    validate_prepared_units(upload_units())
  })

  output$upload_summary <- renderUI({
    u <- uploaded_sf()
    if (is.null(u)) return(NULL)
    prepared <- upload_units()
    issues <- c(upload_validation(), validate_prepared_units(prepared))
    group_count <- if (!is.null(prepared)) {
      length(unique(as.character(prepared$region)))
    } else {
      NA_integer_
    }
    crs <- sf::st_crs(u)
    crs_label <- if (!is.na(crs$epsg)) paste0("EPSG:", crs$epsg) else crs$input %||% "defined"
    file_mb <- if (!is.null(upload_source$size)) {
      sprintf("%.1f MB", as.numeric(upload_source$size) / 1024^2)
    } else {
      "unknown"
    }
    simp <- upload_simplify_info()
    simplify_text <- if (!is.null(simp) && isTRUE(simp$simplified)) {
      sprintf(
        "%s -> %s vertices (tolerance %.1f m)",
        format(simp$before, big.mark = ","),
        format(simp$after, big.mark = ","),
        simp$tolerance
      )
    } else {
      paste0(format(geometry_vertex_count(u), big.mark = ","), " vertices")
    }
    div(
      class = "border rounded p-2 small bg-light mb-2",
      div(strong(format(nrow(u), big.mark = ",")), " polygons"),
      div(strong(length(setdiff(names(u), attr(u, "sf_column")))), " available columns"),
      div(strong(ifelse(is.na(group_count), "-", group_count)), " parent groups"),
      div("Feature ID: ", strong(display_field(input$upload_id, "Row number"))),
      div("Feature label: ", strong(display_field(input$upload_label, "Row number"))),
      div("CRS: ", strong(crs_label), " -> layout CRS EPSG:5070"),
      div("File size: ", strong(file_mb)),
      div("Simplification: ", strong(simplify_text)),
      if (length(issues)) {
        div(class = "alert alert-danger p-2 small mt-2 mb-0",
            paste(issues, collapse = " "))
      } else {
        span(class = "badge bg-success mt-2", "Ready to explode")
      }
    )
  })

  # Region-tagged units from the upload + the chosen columns.
  upload_units <- reactive({
    u <- uploaded_sf()
    if (is.null(u)) return(NULL)
    method <- input$upload_group_method %||% "quadrants"
    rc <- input$upload_region %||% ""
    if (identical(method, "column")) {
      u$region <- if (nzchar(rc) && rc %in% names(u)) as.character(u[[rc]]) else ""
    } else if (identical(method, "clusters")) {
      u <- assign_cluster_regions(u, input$upload_cluster_count %||% 6L)
    } else if (identical(method, "individual")) {
      u$region <- sprintf("Feature %d", seq_len(nrow(u)))
    } else {
      u <- assign_quadrant_regions(u)
    }
    lc <- input$upload_label %||% ""
    u$unit_name <- if (nzchar(lc) && lc %in% names(u)) {
      as.character(u[[lc]])
    } else {
      sprintf("Unit %d", seq_len(nrow(u)))
    }
    idc <- input$upload_id %||% ""
    u$unit_id <- if (nzchar(idc) && idc %in% names(u)) {
      as.character(u[[idc]])
    } else {
      sprintf("u%05d", seq_len(nrow(u)))
    }
    u
  })

  # Seed a default canonical layout at startup.
  isolate(set_canonical(compute_source(MAP_SOURCES[[1]]), MAP_SOURCES[[1]], "county"))

  # ----- Explore -------------------------------------------------------------
  build_selected_layout <- function() {
    source <- input$map_source %||% MAP_SOURCES[[1]]
    level <- if (identical(source, "UPLOAD")) {
      "upload"
    } else {
      input$granularity %||% "county"
    }
    upload <- if (identical(source, "UPLOAD")) upload_units() else NULL

    if (identical(source, "UPLOAD")) {
      if (is.null(upload)) {
        showNotification("Upload a polygon file and choose its columns first.",
                         type = "warning")
        return()
      }
      issues <- c(upload_validation(), validate_prepared_units(upload))
      if (length(issues)) {
        showNotification(paste(issues, collapse = " "), type = "error", duration = 10)
        return()
      }
    }

    remember_current()                        # preserve outgoing canonical + draft
    update_process(if (isTRUE(input$optimize)) {
      "Searching for the best label-aware layout..."
    } else {
      "Building the exploded layout..."
    })
    result <- compute_source(
      source,
      optimize = isTRUE(input$optimize),
      level = level,
      upload = upload
    )
    ok <- set_canonical(result, source, level, optimize = isTRUE(input$optimize))
    if (isTRUE(ok) && identical(source, "UPLOAD")) {
      group_count <- length(unique(as.character(upload$region)))
      showNotification(
        sprintf("Created %d parent groups from %d polygons.", group_count, nrow(upload)),
        type = "message"
      )
      showModal(modalDialog(
        title = "Layout ready",
        sprintf("%d polygons were arranged into %d parent groups.",
                nrow(upload), group_count),
        footer = tagList(
          modalButton("Review first"),
          actionButton("open_uploaded_editor", "Refine in dragmapr",
                       class = "btn-primary")
        )
      ))
    }
    invisible(NULL)
  }

  observeEvent(input$compute, {
    message <- if (identical(input$map_source, "UPLOAD")) {
      "Building the uploaded exploded layout..."
    } else if (isTRUE(input$optimize)) {
      "Searching for the best label-aware layout..."
    } else {
      "Building the exploded layout..."
    }
    run_process(message, build_selected_layout)
  })

  observeEvent(input$granularity, {
    if (identical(input$granularity, "muni")) {
      updateSelectInput(session, "focus_preset", selected = "municipal")
    } else {
      updateSelectInput(session, "focus_preset", selected = "none")
    }
  }, ignoreInit = TRUE)

  observeEvent(input$open_uploaded_editor, {
    removeModal()
    rv$egen <- rv$egen + 1L
    nav_select("stage", "refine")
  })

  source_label <- reactive({
    nm <- names(MAP_SOURCES)[match(rv$source, MAP_SOURCES)]
    if (is.na(nm)) rv$source else nm
  })

  output$explore_title <- renderText(paste0("explodemap layout: ", source_label()))

  output$explore_map <- renderFocusmap({
    req(rv$layout)
    regions <- sort(unique(as.character(rv$state$region_offsets$region)))
    # Pass the PROJECTED sf_grouped (not the grouped object, whose viewer sf is
    # WGS84). With coordinate_system = "planar" this renders in the same metric
    # projection as the editor, so Explore matches Refine (no lon/lat stretch,
    # no extreme-coordinate stray lines).
    focus_map(
      rv$layout$sf_grouped, state = rv$state,
      group_col = "region", group_palette = active_palette(),
      label_col = "unit_name",
      coordinate_system = "planar",
      fill_opacity = 0.92,
      focus_context_opacity = 0.42,
      performance_mode = TRUE,          # keep dense national maps responsive
      simplify = FALSE,                 # we pre-simplify in projected metres
      restore_selection = FALSE,        # show the whole composed face, not a zoom
      focus_preset = if (identical(rv$level, "muni")) {
        input$focus_preset %||% "municipal"
      } else {
        "none"
      },
      show_labels = isTRUE(input$show_labels),
      show_group_labels = isTRUE(input$show_region_labels),
      group_labels = stats::setNames(regions, regions)
    )
  })

  # Diagnostics must reflect the applied edits, so score the *composed* layout.
  explore_report <- reactive({
    req(isTRUE(input$show_diag), rv$layout)   # don't compute diagnostics when hidden
    applied <- update_exploded_layout(rv$layout, rv$state, update_plots = FALSE)
    diagnose_layout(applied, label_col = "unit_name")
  })
  output$explore_diag_boxes <- renderUI(diag_boxes(explore_report()))
  output$explore_diag_plot <- renderPlot(plot(explore_report()))

  # Move to Refine, seeding the draft from the current canonical state.
  observeEvent(input$go_refine, {
    # Keep any in-progress draft, but re-render the editor so it draws at the
    # correct size for the now-visible tab.
    rv$egen <- rv$egen + 1L
    nav_select("stage", "refine")
  })

  # ----- Refine --------------------------------------------------------------
  output$editor <- renderDragmapr({
    req(rv$layout)
    rv$egen
    dragmapr_widget(
      rv$layout$sf_grouped,
      region_col = "region",
      state = isolate(rv$draft),
      labels = isTRUE(input$editor_labels),
      display_options = isolate(dragmapr_display_options(
        region_palette = active_palette(),
        show_origin_outlines = isTRUE(input$show_origin),
        show_movement_connectors = isTRUE(input$show_connectors),
        show_drag_trail = isTRUE(input$show_trail),
        map_background = input$map_bg %||% "white"
      ))
    )
  })
  # Render the editor even while its tab is hidden, so it is ready on arrival
  # instead of flashing blank when you switch to Refine.
  outputOptions(output, "editor", suspendWhenHidden = FALSE)

  # Every browser edit rebuilds the draft (not the canonical state).
  observeEvent(input$editor_state, {
    edit <- dragmapr_widget_state(input$editor_state)
    if (!is.null(edit)) rv$draft <- edit
  })

  output$draft_state <- renderText(state_summary(rv$draft))

  # Live display toggles - update in place, never rebuild (edits are preserved).
  observeEvent(input$show_origin, {
    updateDragmapr(session, "editor", show_origin_outlines = isTRUE(input$show_origin))
  }, ignoreInit = TRUE)
  observeEvent(input$show_connectors, {
    updateDragmapr(session, "editor", show_movement_connectors = isTRUE(input$show_connectors))
  }, ignoreInit = TRUE)
  observeEvent(input$show_trail, {
    updateDragmapr(session, "editor", show_drag_trail = isTRUE(input$show_trail))
  }, ignoreInit = TRUE)
  observeEvent(input$map_bg, {
    updateDragmapr(session, "editor", map_background = input$map_bg)
  }, ignoreInit = TRUE)

  # Selecting a region immediately highlights it in the editor (no extra click).
  observeEvent(input$sel_region, {
    req(input$sel_region)
    updateDragmapr(session, "editor", selected_feature = input$sel_region)
  }, ignoreInit = TRUE)

  # Push the draft back: it becomes the new canonical face of explodemap.
  observeEvent(input$apply, {
    rv$state <- rv$draft
    remember_current()                        # persist applied edits for this source
    nav_select("stage", "explore")
  })

  observeEvent(input$reset_draft, {
    rv$draft <- rv$state
    rv$egen <- rv$egen + 1L
  })

  # ----- Export --------------------------------------------------------------
  output$export_warning <- renderUI({
    d <- draft_diff()
    total <- d$regions + d$labels
    if (total == 0L) return(NULL)
    div(
      class = "alert alert-warning d-flex align-items-center justify-content-between gap-2",
      span(sprintf(
        "%d draft change%s are not included in this export.",
        total,
        if (total == 1L) "" else "s"
      )),
      actionButton("apply_and_export", "Apply and update export",
                   class = "btn-sm btn-warning")
    )
  })

  observeEvent(input$apply_and_export, {
    rv$state <- rv$draft
    remember_current()
    nav_select("stage", "export")
  })

  export_title <- shiny::debounce(
    reactive(input$export_title %||% "Composed layout"),
    millis = 400
  )

  output$export_static <- renderPlot({
    req(rv$layout, rv$state)
    render_dragged_map(
      rv$layout$sf_grouped, region_col = "region",
      state = rv$state,
      region_palette = active_palette(),
      labels = isTRUE(input$export_labels),
      title = export_title()
    )
  })

  output$export_state <- renderText(state_summary(rv$state))

  output$save_state <- downloadHandler(
    filename = function() "pipeline-composition.json",
    content = function(file) {
      req(rv$state)
      write_dragmapr_state(rv$state, file)
    }
  )

  output$save_png <- downloadHandler(
    filename = function() "pipeline-composition.png",
    content = function(file) {
      req(rv$layout, rv$state)
      render_dragged_map(
        rv$layout$sf_grouped, region_col = "region",
        state = rv$state,
        region_palette = active_palette(),
        labels = isTRUE(input$export_labels),
        title = input$export_title %||% "Composed layout",
        file = file
      )
    }
  )

  restore_loaded_state <- function(f) {
    s <- tryCatch(read_dragmapr_state(f$datapath), error = function(e) NULL)
    if (is.null(s)) {
      showNotification("Could not read that file as a dragmapr_state.", type = "error")
      return(invisible(NULL))
    }
    # Only apply a loaded state if its regions match the current layout, so a
    # state from a different source or detail level can't be silently misapplied.
    if (!identical(s$geometry_id, rv$state$geometry_id) ||
        !setequal(s$region_offsets$region, rv$state$region_offsets$region)) {
      showNotification(
        sprintf(paste("That composition was made for a different layout (%s).",
                      "Switch to the matching source first, then load it."),
                s$geometry_id %||% "unknown"),
        type = "warning", duration = 8
      )
      return(invisible(NULL))
    }
    rv$state <- s
    rv$draft <- s
    rv$egen <- rv$egen + 1L     # refresh the editor with the loaded composition
    remember_current()
    showNotification("Loaded composition.", type = "message")
    invisible(NULL)
  }

  observeEvent(input$load_state, {
    req(input$load_state)
    f <- input$load_state
    run_process("Restoring saved composition...", function() restore_loaded_state(f))
  })
}

shinyApp(ui, server)
