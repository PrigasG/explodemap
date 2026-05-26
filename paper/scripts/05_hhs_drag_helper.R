source(file.path("paper", "scripts", "00_setup.R"))
write_run_info("05_hhs_drag_helper")

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Install required package: jsonlite", call. = FALSE)
}

helper_dir <- file.path(paper_output_dir, "hhs_drag_helper")
dir.create(helper_dir, recursive = TRUE, showWarnings = FALSE)

hhs_lookup <- data.frame(
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
    rep(1, 6), rep(2, 4), rep(3, 6), rep(4, 8),
    rep(5, 6), rep(6, 5), rep(7, 4), rep(8, 6),
    rep(9, 7), rep(10, 4)
  )),
  stringsAsFactors = FALSE
)

manual_region_offsets <- data.frame(
  hhs_region = as.character(1:10),
  x_offset = c(0, -2, -3, -3, -4, -6, -5, -8, -10, -11) * 1e5,
  y_offset = c(9, 7, 5, 1, 5, 0, 1, 5, 2, 6) * 1e5,
  stringsAsFactors = FALSE
)

download_us_states <- function() {
  cache_file <- file.path(path.expand("~"), "explode_map_cache", "us_states_2024.rds")
  if (file.exists(cache_file)) {
    return(readRDS(cache_file))
  }

  url <- "https://www2.census.gov/geo/tiger/TIGER2024/STATE/tl_2024_us_state.zip"
  tmp <- tempfile(fileext = ".zip")
  utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
  dir <- file.path(tempdir(), "us_states")
  dir.create(dir, showWarnings = FALSE)
  utils::unzip(tmp, exdir = dir)
  shp <- list.files(dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)
  states_sf <- sf::st_read(shp[1], quiet = TRUE)
  dir.create(dirname(cache_file), showWarnings = FALSE, recursive = TRUE)
  saveRDS(states_sf, cache_file)
  states_sf
}

scale_geom <- function(geom, scale = 1) {
  ctr <- sf::st_centroid(geom)
  m <- matrix(c(scale, 0, 0, scale), 2, 2)
  scaled <- (geom - ctr) * m + ctr
  sf::st_set_crs(scaled, sf::st_crs(geom))
}

territory_move_and_scale <- function(df, code, ref_code, scale = 1, x_offset = 0, y_offset = 0) {
  if (!any(df$STUSPS == code) || !any(df$STUSPS == ref_code)) {
    return(df)
  }

  df$geometry[df$STUSPS == code] <- scale_geom(df$geometry[df$STUSPS == code], scale = scale)
  terr_geom <- df$geometry[df$STUSPS == code]
  ref_geom <- df$geometry[df$STUSPS == ref_code]
  shift_vec <- sf::st_coordinates(sf::st_centroid(ref_geom)) -
    sf::st_coordinates(sf::st_centroid(terr_geom)) +
    c(x_offset, y_offset)
  df$geometry[df$STUSPS == code] <- terr_geom + shift_vec
  df
}

build_manual_hhs_layout <- function(alpha_l = 120000, p = 1.25) {
  states_sf <- download_us_states() |>
    dplyr::left_join(hhs_lookup, by = "STUSPS") |>
    dplyr::filter(!is.na(.data$hhs_region)) |>
    sf::st_transform(5070)

  region_centroids <- states_sf |>
    dplyr::group_by(.data$hhs_region) |>
    dplyr::summarise(geometry = sf::st_union(.data$geometry), .groups = "drop") |>
    sf::st_centroid() |>
    dplyr::mutate(
      rx = sf::st_coordinates(.data$geometry)[, 1],
      ry = sf::st_coordinates(.data$geometry)[, 2]
    )

  state_centroids <- states_sf |>
    dplyr::mutate(
      cx = sf::st_coordinates(sf::st_centroid(.data$geometry))[, 1],
      cy = sf::st_coordinates(sf::st_centroid(.data$geometry))[, 2]
    ) |>
    dplyr::left_join(
      region_centroids |>
        sf::st_drop_geometry() |>
        dplyr::select("hhs_region", "rx", "ry"),
      by = "hhs_region"
    ) |>
    dplyr::mutate(
      dx_local = .data$cx - .data$rx,
      dy_local = .data$cy - .data$ry,
      mag_local = sqrt(.data$dx_local^2 + .data$dy_local^2),
      ux_local = .data$dx_local / pmax(.data$mag_local, 1),
      uy_local = .data$dy_local / pmax(.data$mag_local, 1)
    ) |>
    dplyr::group_by(.data$hhs_region) |>
    dplyr::mutate(
      d_max = max(.data$mag_local, na.rm = TRUE),
      local_scale = (.data$mag_local / pmax(.data$d_max, 1))^p
    ) |>
    dplyr::ungroup() |>
    dplyr::left_join(manual_region_offsets, by = "hhs_region") |>
    dplyr::mutate(
      x_total = .data$x_offset + alpha_l * .data$local_scale * .data$ux_local,
      y_total = .data$y_offset + alpha_l * .data$local_scale * .data$uy_local
    )

  shifted_geometries <- Map(
    function(geom, dx, dy) geom + c(dx, dy),
    sf::st_geometry(state_centroids),
    state_centroids$x_total,
    state_centroids$y_total
  )

  shifted_states <- state_centroids
  sf::st_geometry(shifted_states) <- sf::st_sfc(shifted_geometries, crs = sf::st_crs(states_sf))
  shifted_states <- sf::st_as_sf(shifted_states)

  shifted_states <- territory_move_and_scale(shifted_states, "PR", "NJ", scale = 2, x_offset = 5e5, y_offset = -4e5)
  shifted_states <- territory_move_and_scale(shifted_states, "VI", "NJ", scale = 4, x_offset = 5.5e5, y_offset = -1.1e6)
  shifted_states <- territory_move_and_scale(shifted_states, "HI", "CA", scale = 2, x_offset = 2e5, y_offset = -1.8e6)
  shifted_states <- territory_move_and_scale(shifted_states, "GU", "CA", scale = 2, x_offset = 5.5e5, y_offset = -1.1e6)
  shifted_states <- territory_move_and_scale(shifted_states, "MP", "CA", scale = 3, x_offset = 8e5, y_offset = -2.1e6)
  shifted_states <- territory_move_and_scale(shifted_states, "AS", "CA", scale = 3, x_offset = 1e6, y_offset = -4.5e6)

  region_labels <- shifted_states |>
    dplyr::group_by(.data$hhs_region) |>
    dplyr::summarise(geometry = sf::st_union(.data$geometry), .groups = "drop") |>
    sf::st_centroid()

  label_coords <- sf::st_coordinates(region_labels)
  labels <- data.frame(
    region = region_labels$hhs_region,
    x = label_coords[, 1],
    y = label_coords[, 2],
    stringsAsFactors = FALSE
  ) |>
    dplyr::arrange(as.integer(.data$region))

  shifted_states <- shifted_states |>
    dplyr::select("STUSPS", "NAME", "hhs_region", "geometry")

  list(states = shifted_states, labels = labels)
}

layout <- build_manual_hhs_layout()
saveRDS(layout, file.path(helper_dir, "hhs_manual_layout.rds"))

geojson_path <- file.path(helper_dir, "hhs_drag_base.geojson")
tmp_geojson <- tempfile(fileext = ".geojson")
sf::st_write(layout$states, tmp_geojson, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
file.copy(tmp_geojson, geojson_path, overwrite = TRUE)

geojson_text <- paste(readLines(tmp_geojson, warn = FALSE), collapse = "\n")
labels_json <- jsonlite::toJSON(layout$labels, dataframe = "rows", auto_unbox = TRUE, digits = 12)
bbox <- sf::st_bbox(layout$states)

html <- paste0(
'<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HHS drag helper</title>
<script src="https://cdn.jsdelivr.net/npm/d3@7"></script>
<style>
:root {
  color-scheme: light;
  --ink: #172033;
  --muted: #617089;
  --line: #d8dee8;
  --panel: #f7f8fb;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  color: var(--ink);
  background: white;
}
.app {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 330px;
  min-height: 100vh;
}
.stage {
  min-width: 0;
  border-right: 1px solid var(--line);
  background: #fbfcfe;
}
svg {
  display: block;
  width: 100%;
  height: 100vh;
  cursor: grab;
}
svg:active { cursor: grabbing; }
.region path {
  stroke: white;
  stroke-width: 1.1;
  vector-effect: non-scaling-stroke;
}
.region.dragging path {
  stroke: #111827;
  stroke-width: 1.8;
}
.label circle {
  fill: white;
  stroke: #111827;
  stroke-width: 1.5;
}
.label text {
  font-size: 15px;
  font-weight: 800;
  text-anchor: middle;
  dominant-baseline: central;
  pointer-events: none;
}
.side {
  padding: 18px;
  background: white;
}
h1 {
  margin: 0 0 8px;
  font-size: 20px;
  line-height: 1.2;
}
p {
  margin: 0 0 14px;
  color: var(--muted);
  line-height: 1.45;
}
.buttons {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-bottom: 12px;
}
button {
  border: 1px solid var(--line);
  background: var(--panel);
  color: var(--ink);
  border-radius: 6px;
  min-height: 36px;
  font: inherit;
  cursor: pointer;
}
button:hover { border-color: #9aa7bb; }
textarea {
  width: 100%;
  height: 340px;
  resize: vertical;
  border: 1px solid var(--line);
  border-radius: 6px;
  padding: 10px;
  font: 12px/1.35 ui-monospace, SFMono-Regular, Consolas, monospace;
}
.hint {
  margin-top: 12px;
  font-size: 13px;
}
</style>
</head>
<body>
<main class="app">
  <section class="stage"><svg id="map" aria-label="Draggable HHS region map"></svg></section>
  <aside class="side">
    <h1>HHS drag helper</h1>
    <p>Drag any numbered HHS region. The exported offsets are in projected meters relative to the original manual layout.</p>
    <div class="buttons">
      <button id="copy">Copy CSV</button>
      <button id="download">Download CSV</button>
      <button id="reset">Reset</button>
    </div>
    <textarea id="csv" spellcheck="false"></textarea>
    <p class="hint">After choosing a layout, save the CSV as <code>paper/outputs/tables/hhs_drag_offsets.csv</code> so the paper script can reuse it.</p>
  </aside>
</main>
<script>
const geojson = ', geojson_text, ';
const labels = ', labels_json, ';
const bounds = { xmin: ', bbox[["xmin"]], ', xmax: ', bbox[["xmax"]], ', ymin: ', bbox[["ymin"]], ', ymax: ', bbox[["ymax"]], ' };
const colors = {
  "1":"#A89A83", "2":"#C764A6", "3":"#2B4970", "4":"#DF514F", "5":"#309396",
  "6":"#70A255", "7":"#F2BE42", "8":"#8459A0", "9":"#872722", "10":"#3579B0"
};

const svg = d3.select("#map");
const regionIds = d3.range(1, 11).map(String);
const offsets = new Map(regionIds.map(region => [region, { px: 0, py: 0 }]));
const featureByRegion = d3.group(geojson.features, d => String(d.properties.hhs_region));
const labelByRegion = new Map(labels.map(d => [String(d.region), d]));

function measure() {
  const node = svg.node();
  const width = node.clientWidth || 900;
  const height = node.clientHeight || 700;
  const pad = 38;
  const sx = (width - pad * 2) / (bounds.xmax - bounds.xmin);
  const sy = (height - pad * 2) / (bounds.ymax - bounds.ymin);
  const scale = Math.min(sx, sy);
  const tx = pad + (width - pad * 2 - (bounds.xmax - bounds.xmin) * scale) / 2 - bounds.xmin * scale;
  const ty = pad + (height - pad * 2 + (bounds.ymax - bounds.ymin) * scale) / 2 + bounds.ymin * scale;
  return { width, height, scale, tx, ty };
}

let m = measure();
let projection = d3.geoIdentity().reflectY(true).scale(m.scale).translate([m.tx, m.ty]);
let path = d3.geoPath(projection);

const root = svg.append("g");
const regions = root.selectAll("g.region")
  .data(regionIds)
  .join("g")
  .attr("class", "region")
  .attr("data-region", d => d);

regions.selectAll("path")
  .data(d => featureByRegion.get(d) || [])
  .join("path")
  .attr("fill", d => colors[String(d.properties.hhs_region)])
  .attr("d", path)
  .append("title")
  .text(d => `${d.properties.NAME} - HHS ${d.properties.hhs_region}`);

const labelLayer = root.append("g").attr("class", "labels");
const labelsG = labelLayer.selectAll("g.label")
  .data(regionIds)
  .join("g")
  .attr("class", "label")
  .attr("data-region", d => d);

labelsG.append("circle").attr("r", 15);
labelsG.append("text").text(d => d);

function projectedLabel(region) {
  const label = labelByRegion.get(region);
  return projection([label.x, label.y]);
}

function transformFor(region) {
  const offset = offsets.get(region);
  return `translate(${offset.px},${offset.py})`;
}

function renderTransforms() {
  regions.attr("transform", d => transformFor(d));
  labelsG.attr("transform", d => {
    const p = projectedLabel(d);
    const offset = offsets.get(d);
    return `translate(${p[0] + offset.px},${p[1] + offset.py})`;
  });
  updateCsv();
}

function csvText() {
  const lines = ["region,dx_m,dy_m"];
  for (const region of regionIds) {
    const offset = offsets.get(region);
    const dx = offset.px / m.scale;
    const dy = -offset.py / m.scale;
    lines.push(`${region},${Math.round(dx)},${Math.round(dy)}`);
  }
  return lines.join("\\n");
}

function updateCsv() {
  document.querySelector("#csv").value = csvText();
}

const drag = d3.drag()
  .on("start", function(event, region) {
    d3.select(this).classed("dragging", true).raise();
    labelLayer.raise();
  })
  .on("drag", function(event, region) {
    const offset = offsets.get(region);
    offset.px += event.dx;
    offset.py += event.dy;
    renderTransforms();
  })
  .on("end", function(event, region) {
    d3.select(this).classed("dragging", false);
  });

regions.call(drag);
labelsG.call(drag);
renderTransforms();

window.addEventListener("resize", () => {
  m = measure();
  projection = d3.geoIdentity().reflectY(true).scale(m.scale).translate([m.tx, m.ty]);
  path = d3.geoPath(projection);
  regions.selectAll("path").attr("d", path);
  renderTransforms();
});

document.querySelector("#reset").addEventListener("click", () => {
  for (const region of regionIds) offsets.set(region, { px: 0, py: 0 });
  renderTransforms();
});

document.querySelector("#copy").addEventListener("click", async () => {
  await navigator.clipboard.writeText(csvText());
});

document.querySelector("#download").addEventListener("click", () => {
  const blob = new Blob([csvText()], { type: "text/csv" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "hhs_drag_offsets.csv";
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
});
</script>
</body>
</html>
')

html_path <- file.path(helper_dir, "index.html")
writeLines(html, html_path, useBytes = TRUE)

message("Wrote HHS drag helper: ", normalizePath(html_path, winslash = "/"))
