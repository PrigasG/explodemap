source(file.path("paper", "scripts", "00_setup.R"))
write_run_info("07_generate_drag_helpers")

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Install required package: jsonlite", call. = FALSE)
}

drag_cases_env <- Sys.getenv("EXPLODEMAP_DRAG_CASES", "NJ,PA,OH,MI,KY,IL,ND,NC,VA,TN,GA,MN,CA,CO")
drag_cases <- trimws(strsplit(drag_cases_env, ",", fixed = TRUE)[[1]])
drag_cases <- drag_cases[nzchar(drag_cases)]

drag_root <- file.path(paper_output_dir, "drag_helpers")
dir.create(drag_root, recursive = TRUE, showWarnings = FALSE)

province_regions <- data.frame(
  PRUID = c("10", "11", "12", "13", "24", "35", "46", "47", "48", "59", "60", "61", "62"),
  region = c(rep("Atlantic", 4), "Quebec", "Ontario", rep("Prairies", 3), "Pacific", rep("Territories", 3)),
  stringsAsFactors = FALSE
)

download_canada_csds <- function() {
  cache_file <- file.path(path.expand("~"), "explode_map_cache", "canada_csds_2021.rds")
  if (file.exists(cache_file)) {
    return(readRDS(cache_file))
  }

  url <- paste0(
    "https://www12.statcan.gc.ca/census-recensement/2021/geo/sip-pis/",
    "boundary-limites/files-fichiers/lcsd000b21a_e.zip"
  )
  tmp <- tempfile(fileext = ".zip")
  utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
  dir <- file.path(tempdir(), "canada_csds")
  dir.create(dir, showWarnings = FALSE)
  utils::unzip(tmp, exdir = dir)
  shp <- list.files(dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)
  sf_raw <- sf::st_read(shp[1], quiet = TRUE)
  dir.create(dirname(cache_file), showWarnings = FALSE, recursive = TRUE)
  saveRDS(sf_raw, cache_file)
  sf_raw
}

run_canada_case <- function() {
  sf_reg <- download_canada_csds() |>
    sf::st_transform(3347) |>
    dplyr::left_join(province_regions, by = "PRUID") |>
    dplyr::filter(.data$region != "Territories")

  explodemap::explode_sf(
    sf_reg,
    region_col = "region",
    gamma_r = 3.0,
    gamma_l = 1.136,
    allow_other = TRUE,
    plot = FALSE,
    export = FALSE,
    label = "Canada CSDs excluding territories",
    quiet = TRUE
  )
}

download_germany_gadm <- function() {
  cache_file <- file.path(path.expand("~"), "explode_map_cache", "gadm41_DEU.gpkg")
  if (file.exists(cache_file)) {
    return(cache_file)
  }

  url <- "https://geodata.ucdavis.edu/gadm/gadm4.1/gpkg/gadm41_DEU.gpkg"
  dir.create(dirname(cache_file), recursive = TRUE, showWarnings = FALSE)
  utils::download.file(url, cache_file, mode = "wb", quiet = TRUE)
  cache_file
}

run_germany_case <- function() {
  gpkg <- download_germany_gadm()
  germany_sf <- sf::st_read(gpkg, layer = "ADM_ADM_2", quiet = TRUE) |>
    dplyr::filter(.data$TYPE_2 != "Water body") |>
    sf::st_transform(3035)
  names(germany_sf)[names(germany_sf) == attr(germany_sf, "sf_column")] <- "geometry"
  sf::st_geometry(germany_sf) <- "geometry"

  explodemap::explode_sf(
    germany_sf,
    region_col = "NAME_1",
    gamma_r = 3.0,
    gamma_l = 1.136,
    allow_other = TRUE,
    plot = FALSE,
    export = FALSE,
    label = "Germany administrative districts",
    quiet = TRUE
  )
}

make_case_result <- function(case_key) {
  key <- toupper(case_key)
  if (key == "CANADA") {
    result <- run_canada_case()
    result$drag_case <- list(
      key = "canada",
      title = "Canada CSDs excluding territories",
      output_prefix = "canada_dragged"
    )
    return(result)
  }
  if (key == "GERMANY" || key == "DE") {
    result <- run_germany_case()
    result$drag_case <- list(
      key = "germany",
      title = "Germany administrative districts",
      output_prefix = "germany_dragged"
    )
    return(result)
  }

  result <- run_state_case(key, refine = FALSE)
  result$drag_case <- list(
    key = tolower(key),
    title = paper_state_registry[[key]]$name,
    output_prefix = paste0(tolower(key), "_dragged")
  )
  result
}

make_drag_layout <- function(result) {
  region_col <- result$diagnostics$region_col
  sf_exp <- result$sf_exp
  sf_exp$drag_region <- as.character(sf_exp[[region_col]])
  sf_exp$drag_region[is.na(sf_exp$drag_region)] <- "NA"

  labels_sf <- sf_exp |>
    dplyr::group_by(.data$drag_region) |>
    dplyr::summarise(geometry = sf::st_union(.data$geometry), .groups = "drop") |>
    sf::st_centroid()

  label_xy <- sf::st_coordinates(labels_sf)
  labels <- data.frame(
    region = labels_sf$drag_region,
    label = labels_sf$drag_region,
    x = label_xy[, 1],
    y = label_xy[, 2],
    stringsAsFactors = FALSE
  ) |>
    dplyr::arrange(.data$region)

  keep_cols <- unique(c("drag_region", region_col, "NAME", "NAMELSAD", "geometry"))
  keep_cols <- keep_cols[keep_cols %in% names(sf_exp)]
  sf_exp <- sf_exp[, keep_cols]

  list(
    states = sf_exp,
    labels = labels,
    region_col = region_col,
    title = result$drag_case$title,
    key = result$drag_case$key,
    output_prefix = result$drag_case$output_prefix
  )
}

write_drag_helper <- function(layout) {
  case_dir <- file.path(drag_root, layout$key)
  dir.create(case_dir, recursive = TRUE, showWarnings = FALSE)

  simplify_tol <- as.numeric(Sys.getenv("EXPLODEMAP_DRAG_SIMPLIFY_M", NA_character_))
  if (is.na(simplify_tol)) {
    simplify_tol <- if (nrow(layout$states) > 4000) {
      2500
    } else if (nrow(layout$states) > 1000) {
      250
    } else {
      50
    }
  }
  helper_states <- sf::st_simplify(
    layout$states,
    dTolerance = simplify_tol,
    preserveTopology = TRUE
  )

  geojson_path <- file.path(case_dir, "map.geojson")
  tmp_geojson <- tempfile(fileext = ".geojson")
  sf::st_write(helper_states, tmp_geojson, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE)
  file.copy(tmp_geojson, geojson_path, overwrite = TRUE)
  geojson_text <- paste(readLines(tmp_geojson, warn = FALSE), collapse = "\n")

  saveRDS(layout, file.path(case_dir, "layout.rds"))

  labels_json <- jsonlite::toJSON(layout$labels, dataframe = "rows", auto_unbox = TRUE, digits = 12)
  bbox <- sf::st_bbox(layout$states)
  offset_file <- paste0(layout$key, "_drag_offsets.csv")

  html <- paste0(
'<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>', htmltools_escape(layout$title), ' drag helper</title>
<style>
* { box-sizing: border-box; }
body { margin: 0; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #172033; background: white; }
.app { display: grid; grid-template-columns: minmax(0, 1fr) 340px; min-height: 100vh; }
.stage { min-width: 0; border-right: 1px solid #d8dee8; background: #fbfcfe; }
svg { display: block; width: 100%; height: 100vh; cursor: grab; }
svg:active { cursor: grabbing; }
.region path { stroke: white; stroke-width: 0.8; vector-effect: non-scaling-stroke; }
.region.dragging path { stroke: #111827; stroke-width: 1.8; }
.label circle { fill: white; stroke: #111827; stroke-width: 1.3; }
.label text { font-size: 11px; font-weight: 800; text-anchor: middle; dominant-baseline: central; pointer-events: none; }
.side { padding: 18px; background: white; }
h1 { margin: 0 0 8px; font-size: 20px; line-height: 1.2; }
p { margin: 0 0 14px; color: #617089; line-height: 1.45; }
.buttons { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 12px; }
button { border: 1px solid #d8dee8; background: #f7f8fb; color: #172033; border-radius: 6px; min-height: 36px; font: inherit; cursor: pointer; }
textarea { width: 100%; height: 360px; resize: vertical; border: 1px solid #d8dee8; border-radius: 6px; padding: 10px; font: 12px/1.35 ui-monospace, SFMono-Regular, Consolas, monospace; }
code { font-family: ui-monospace, SFMono-Regular, Consolas, monospace; }
</style>
</head>
<body>
<main class="app">
  <section class="stage"><svg id="map" aria-label="Draggable exploded map"></svg></section>
  <aside class="side">
    <h1>', htmltools_escape(layout$title), '</h1>
    <p>Drag parent regions to fine-tune the exploded layout. Exported offsets are projected meters from the formula-derived layout.</p>
    <div class="buttons">
      <button id="copy">Copy CSV</button>
      <button id="download">Download CSV</button>
      <button id="reset">Reset</button>
    </div>
    <textarea id="csv" spellcheck="false"></textarea>
    <p>Save as <code>paper/outputs/tables/', offset_file, '</code>, then run <code>08_render_dragged_layouts.R</code>.</p>
  </aside>
</main>
<script>
const labels = ', labels_json, ';
const geojson = ', geojson_text, ';
const bounds = { xmin: ', bbox[["xmin"]], ', xmax: ', bbox[["xmax"]], ', ymin: ', bbox[["ymin"]], ', ymax: ', bbox[["ymax"]], ' };
const offsetFile = "', offset_file, '";
const palette = ["#2166ac","#d73027","#1a9850","#984ea3","#ff7f00","#a65628","#f781bf","#999999","#33a02c","#b2df8a","#66c2a5","#fc8d62","#8da0cb","#e78ac3","#a6d854"];
const svg = document.querySelector("#map");
const offsets = new Map(labels.map(d => [String(d.region), { px: 0, py: 0 }]));
let regionIds, featureByRegion, m, root, regionGroups, labelGroups, labelLayer;
let activeRegion = null;
let activePointer = null;

function measure() {
  const width = svg.clientWidth || 900;
  const height = svg.clientHeight || 700;
  const pad = 38;
  const sx = (width - pad * 2) / (bounds.xmax - bounds.xmin);
  const sy = (height - pad * 2) / (bounds.ymax - bounds.ymin);
  const scale = Math.min(sx, sy);
  const tx = pad + (width - pad * 2 - (bounds.xmax - bounds.xmin) * scale) / 2 - bounds.xmin * scale;
  const ty = pad + (height - pad * 2 + (bounds.ymax - bounds.ymin) * scale) / 2 + bounds.ymin * scale;
  return { width, height, scale, tx, ty };
}

function setupProjectionOnly() {
  m = measure();
  svg.setAttribute("viewBox", `0 0 ${m.width} ${m.height}`);
}

function project(coord) {
  return [coord[0] * m.scale + m.tx, -coord[1] * m.scale + m.ty];
}

function ringPath(ring) {
  if (!ring.length) return "";
  const first = project(ring[0]);
  const rest = ring.slice(1).map(coord => {
    const p = project(coord);
    return `L${p[0].toFixed(2)},${p[1].toFixed(2)}`;
  }).join("");
  return `M${first[0].toFixed(2)},${first[1].toFixed(2)}${rest}Z`;
}

function geometryPath(geometry) {
  if (!geometry) return "";
  if (geometry.type === "Polygon") {
    return geometry.coordinates.map(ringPath).join("");
  }
  if (geometry.type === "MultiPolygon") {
    return geometry.coordinates.flatMap(poly => poly.map(ringPath)).join("");
  }
  return "";
}

function projectedLabel(region) {
  const label = labels.find(d => String(d.region) === String(region));
  return project([label.x, label.y]);
}

function transformFor(region) {
  const offset = offsets.get(String(region));
  return `translate(${offset.px},${offset.py})`;
}

function csvText() {
  const lines = ["region,dx_m,dy_m"];
  for (const region of regionIds) {
    const offset = offsets.get(String(region));
    const dx = offset.px / m.scale;
    const dy = -offset.py / m.scale;
    lines.push(`${csvEscape(region)},${Math.round(dx)},${Math.round(dy)}`);
  }
  return lines.join("\\n");
}

function csvEscape(value) {
  const text = String(value);
  return /[",\\n]/.test(text) ? `"${text.replaceAll(`"`, `""`)}"` : text;
}

function updateCsv() {
  document.querySelector("#csv").value = csvText();
}

function renderTransforms() {
  for (const [region, group] of regionGroups.entries()) {
    group.setAttribute("transform", transformFor(region));
  }
  for (const [region, group] of labelGroups.entries()) {
    const p = projectedLabel(region);
    const offset = offsets.get(String(region));
    group.setAttribute("transform", `translate(${p[0] + offset.px},${p[1] + offset.py})`);
  }
  updateCsv();
}

function colorFor(region) {
  const idx = Math.abs(Array.from(String(region)).reduce((acc, ch) => acc + ch.charCodeAt(0), 0)) % palette.length;
  return palette[idx];
}

function svgEl(name, attrs = {}) {
  const el = document.createElementNS("http://www.w3.org/2000/svg", name);
  for (const [key, value] of Object.entries(attrs)) {
    el.setAttribute(key, value);
  }
  return el;
}

function groupFeatures(features) {
  const grouped = new Map();
  for (const feature of features) {
    const region = String(feature.properties.drag_region);
    if (!grouped.has(region)) grouped.set(region, []);
    grouped.get(region).push(feature);
  }
  return grouped;
}

function startDrag(event, region) {
  activeRegion = String(region);
  activePointer = { x: event.clientX, y: event.clientY };
  event.currentTarget.classList.add("dragging");
  event.currentTarget.setPointerCapture?.(event.pointerId);
  labelLayer.parentNode.appendChild(labelLayer);
}

function dragMove(event) {
  if (!activeRegion || !activePointer) return;
  const offset = offsets.get(activeRegion);
  offset.px += event.clientX - activePointer.x;
  offset.py += event.clientY - activePointer.y;
  activePointer = { x: event.clientX, y: event.clientY };
  renderTransforms();
}

function endDrag() {
  document.querySelectorAll(".dragging").forEach(el => el.classList.remove("dragging"));
  activeRegion = null;
  activePointer = null;
}

function main() {
  regionIds = labels.map(d => String(d.region));
  featureByRegion = groupFeatures(geojson.features);
  setupProjectionOnly();

  root = svgEl("g");
  svg.appendChild(root);
  regionGroups = new Map();
  labelGroups = new Map();

  for (const region of regionIds) {
    const group = svgEl("g", { class: "region", "data-region": region });
    group.addEventListener("pointerdown", event => startDrag(event, region));
    for (const feature of featureByRegion.get(region) || []) {
      const path = svgEl("path", {
        fill: colorFor(feature.properties.drag_region),
        d: geometryPath(feature.geometry)
      });
      const title = svgEl("title");
      title.textContent = feature.properties.NAME || feature.properties.NAMELSAD || feature.properties.drag_region;
      path.appendChild(title);
      group.appendChild(path);
    }
    root.appendChild(group);
    regionGroups.set(region, group);
  }

  labelLayer = svgEl("g", { class: "labels" });
  root.appendChild(labelLayer);
  for (const region of regionIds) {
    const group = svgEl("g", { class: "label", "data-region": region });
    group.addEventListener("pointerdown", event => startDrag(event, region));
    group.appendChild(svgEl("circle", { r: 11 }));
    const text = svgEl("text");
    text.textContent = String(region).length > 4 ? String(region).slice(0, 4) : region;
    group.appendChild(text);
    labelLayer.appendChild(group);
    labelGroups.set(region, group);
  }

  svg.addEventListener("pointermove", dragMove);
  svg.addEventListener("pointerup", endDrag);
  svg.addEventListener("pointerleave", endDrag);
  renderTransforms();
}

window.addEventListener("resize", () => {
  if (!geojson) return;
  setupProjectionOnly();
  for (const group of regionGroups.values()) {
    for (const pathEl of group.querySelectorAll("path")) {
      const feature = (featureByRegion.get(group.dataset.region) || [])[Array.from(group.querySelectorAll("path")).indexOf(pathEl)];
      if (feature) pathEl.setAttribute("d", geometryPath(feature.geometry));
    }
  }
  renderTransforms();
});

document.querySelector("#reset").addEventListener("click", () => {
  for (const region of regionIds) offsets.set(String(region), { px: 0, py: 0 });
  renderTransforms();
});
document.querySelector("#copy").addEventListener("click", async () => navigator.clipboard.writeText(csvText()));
document.querySelector("#download").addEventListener("click", () => {
  const blob = new Blob([csvText()], { type: "text/csv" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = offsetFile;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
});
main();
</script>
</body>
</html>
')

  writeLines(html, file.path(case_dir, "index.html"), useBytes = TRUE)
  data.frame(
    case = layout$key,
    title = layout$title,
    helper_url = paste0("http://127.0.0.1:8765/drag_helpers/", layout$key, "/index.html"),
    offset_file = file.path("paper", "outputs", "tables", offset_file),
    stringsAsFactors = FALSE
  )
}

htmltools_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

rows <- lapply(drag_cases, function(case_key) {
  message("Building drag helper for ", case_key, "...")
  case_id <- if (toupper(case_key) == "CANADA") "canada" else tolower(case_key)
  layout_path <- file.path(drag_root, case_id, "layout.rds")
  if (file.exists(layout_path)) {
    layout <- readRDS(layout_path)
  } else {
    result <- make_case_result(case_key)
    layout <- make_drag_layout(result)
  }
  write_drag_helper(layout)
})

index <- dplyr::bind_rows(rows)
index_path <- file.path(paper_table_dir, "drag_helper_index.csv")
if (file.exists(index_path)) {
  existing_index <- utils::read.csv(index_path, stringsAsFactors = FALSE)
  index <- dplyr::bind_rows(existing_index, index) |>
    dplyr::distinct(.data$case, .keep_all = TRUE) |>
    dplyr::arrange(.data$case)
}
save_table(index, "drag_helper_index.csv")

message("Generated drag helpers in: ", normalizePath(drag_root, winslash = "/"))
