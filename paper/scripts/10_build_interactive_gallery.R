# Build the static GitHub Pages gallery used by the paper.
#
# Run after pkgdown::build_site(); pkgdown leaves custom directories under docs/.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- "--file="
script_path <- sub(file_arg, "", args[startsWith(args, file_arg)])
if (!length(script_path)) {
  script_path <- file.path("paper", "scripts", "10_build_interactive_gallery.R")
}
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), mustWork = TRUE)

fig_dir <- file.path(repo_root, "paper", "outputs", "figures")
tab_dir <- file.path(repo_root, "paper", "outputs", "tables")
site_dir <- file.path(repo_root, "docs", "map-gallery")
asset_fig_dir <- file.path(site_dir, "assets", "figures")
asset_tab_dir <- file.path(site_dir, "assets", "tables")

dir.create(asset_fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(asset_tab_dir, recursive = TRUE, showWarnings = FALSE)

copy_if_exists <- function(from, to_dir) {
  path <- file.path(dirname(from), basename(from))
  if (!file.exists(path)) return(FALSE)
  file.copy(path, file.path(to_dir, basename(path)), overwrite = TRUE)
}

figures <- c(
  "nj_formula_derived.png", "nj_dragged_layout.png",
  "pa_original.png", "pa_formula_derived.png", "pa_dragged_layout.png",
  "pa_displacement_vectors.png",
  "oh_dragged_layout.png", "mi_dragged_layout.png", "ky_dragged_layout.png",
  "il_dragged_layout.png", "nd_dragged_layout.png", "nc_dragged_layout.png",
  "va_dragged_layout.png", "tx_dragged_layout.png", "fl_dragged_layout.png",
  "canada_dragged_layout.png", "germany_dragged_layout.png",
  "hhs_dragged_layout.png", "hhs_display_offsets.png"
)
invisible(vapply(file.path(fig_dir, figures), copy_if_exists, logical(1), to_dir = asset_fig_dir))

tables <- list.files(tab_dir, pattern = "(_drag_offsets(_used)?|cross_state_metrics|dragged_layout_render_index)\\.csv$", full.names = TRUE)
invisible(vapply(tables, copy_if_exists, logical(1), to_dir = asset_tab_dir))

metrics_path <- file.path(tab_dir, "cross_state_metrics.csv")
metrics <- if (file.exists(metrics_path)) read.csv(metrics_path, check.names = FALSE) else data.frame()

fmt_num <- function(x, digits = 1) {
  ifelse(is.na(x), "", format(round(x, digits), big.mark = ",", trim = TRUE))
}

state_param_rows <- ""
if (nrow(metrics)) {
  case_key <- c(
    "New Jersey" = "nj", "Pennsylvania" = "pa", "Ohio" = "oh",
    "Michigan" = "mi", "Kentucky" = "ky", "Illinois" = "il",
    "North Dakota" = "nd", "North Carolina" = "nc", "Virginia" = "va",
    "Texas" = "tx", "Florida" = "fl", "Canada" = "canada"
  )
  state_param_rows <- paste0(
    apply(metrics, 1, function(row) {
      key <- unname(case_key[[row[["dataset"]]]])
      if (is.null(key) || is.na(key)) key <- tolower(gsub("[^a-z0-9]+", "_", row[["dataset"]]))
      sprintf(
        "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>No</td><td><a href=\"assets/tables/%s_drag_offsets_used.csv\">CSV</a></td></tr>",
        row[["dataset"]],
        fmt_num(as.numeric(row[["alpha_r_m"]]) / 1000, 1),
        fmt_num(as.numeric(row[["alpha_l_m"]]) / 1000, 1),
        fmt_num(as.numeric(row[["n_features"]]), 0),
        key
      )
    }),
    collapse = "\n"
  )
}

card <- function(title, body, images, links = character()) {
  image_html <- paste0(
    vapply(images, function(img) {
      sprintf("<figure><img src=\"assets/figures/%s\" alt=\"%s\"><figcaption>%s</figcaption></figure>", img$file, img$alt, img$caption)
    }, character(1)),
    collapse = "\n"
  )
  link_html <- if (length(links)) {
    paste0("<p class=\"links\">", paste(links, collapse = " "), "</p>")
  } else {
    ""
  }
  sprintf("<section class=\"card\"><h2>%s</h2><p>%s</p><div class=\"figure-grid\">%s</div>%s</section>", title, body, image_html, link_html)
}

page <- paste0(
'<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>explodemap Interactive Map Gallery</title>
<style>
:root { --ink:#17202a; --muted:#5d6d7e; --line:#d8dee4; --brand:#2166ac; --bg:#f7f9fb; }
body { margin:0; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color:var(--ink); background:var(--bg); }
header { background:#fff; border-bottom:1px solid var(--line); padding:32px max(24px, calc((100vw - 1180px) / 2)); }
main { max-width:1180px; margin:0 auto; padding:28px 24px 56px; }
h1 { margin:0 0 10px; font-size:clamp(2rem, 4vw, 3.2rem); line-height:1.05; }
h2 { margin:0 0 10px; font-size:1.35rem; }
h3 { margin:24px 0 10px; }
p { line-height:1.55; }
a { color:var(--brand); }
.meta { display:grid; grid-template-columns:repeat(auto-fit, minmax(220px, 1fr)); gap:10px; margin-top:18px; color:var(--muted); }
.nav { display:flex; flex-wrap:wrap; gap:10px; margin-top:20px; }
.nav a { border:1px solid var(--line); border-radius:6px; padding:8px 10px; text-decoration:none; background:#fff; color:var(--ink); }
.card { background:#fff; border:1px solid var(--line); border-radius:8px; padding:20px; margin:20px 0; }
.figure-grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(260px, 1fr)); gap:16px; align-items:start; }
figure { margin:0; border:1px solid var(--line); border-radius:6px; overflow:hidden; background:#fff; }
img { display:block; width:100%; height:auto; }
figcaption { padding:9px 10px; color:var(--muted); font-size:.92rem; border-top:1px solid var(--line); }
table { border-collapse:collapse; width:100%; margin-top:12px; background:#fff; }
th, td { border:1px solid var(--line); padding:9px 10px; text-align:left; vertical-align:top; }
th { background:#edf4fb; }
.links a { display:inline-block; margin-right:10px; }
@media (max-width: 640px) { header { padding:24px 18px; } main { padding:20px 14px 44px; } }
</style>
</head>
<body>
<header>
<h1>Interactive Map Gallery</h1>
<p>Comparison outputs for the explodemap paper: original geography where available, formula-derived analytical layouts, and documented display-offset layouts used for publication figures and web review.</p>
<div class="meta">
<div><strong>GitHub Pages</strong><br><a href="https://prigasg.github.io/explodemap/map-gallery/index.html">https://prigasg.github.io/explodemap/map-gallery/index.html</a></div>
<div><strong>Repository</strong><br><a href="https://github.com/PrigasG/explodemap">https://github.com/PrigasG/explodemap</a></div>
<div><strong>Package version</strong><br>0.2.0</div>
<div><strong>Date accessed</strong><br>May 26, 2026</div>
</div>
<nav class="nav">
<a href="#nj">New Jersey</a><a href="#pa">Pennsylvania</a><a href="#states">Extended U.S. states</a><a href="#world">Canada/Germany</a><a href="#hhs">HHS grouped layout</a><a href="#downloads">Download data/code</a>
</nav>
</header>
<main>
<section class="card">
<h2>How to Read the Outputs</h2>
<table>
<thead><tr><th>Output type</th><th>Used for</th><th>Manual offsets?</th><th>Used in quantitative metrics?</th></tr></thead>
<tbody>
<tr><td>Original geographic layout</td><td>Baseline</td><td>No</td><td>Yes</td></tr>
<tr><td>Formula-derived exploded layout</td><td>Validation</td><td>No</td><td>Yes</td></tr>
<tr><td>Display-offset layout</td><td>Publication figures / web gallery</td><td>Yes, documented</td><td>Only if explicitly stated</td></tr>
</tbody>
</table>
</section>
<span id="nj"></span>',
card("New Jersey", "Formula-derived and display-offset layouts for the calibration case. The display offsets are documented separately from the analytical validation output.",
     list(list(file="nj_formula_derived.png", alt="New Jersey formula-derived exploded layout", caption="Formula-derived exploded layout"),
          list(file="nj_dragged_layout.png", alt="New Jersey display-offset exploded layout", caption="Display-offset layout")),
     c("<a href=\"assets/tables/nj_drag_offsets_used.csv\">Display offset CSV</a>")),
'<span id="pa"></span>',
card("Pennsylvania", "The Pennsylvania case includes the original geography, the formula-derived validation output, the display-offset figure, and a displacement-vector diagnostic showing how municipal units are pulled apart.",
     list(list(file="pa_original.png", alt="Pennsylvania original geography", caption="Original geography"),
          list(file="pa_formula_derived.png", alt="Pennsylvania formula-derived exploded layout", caption="Formula-derived exploded layout"),
          list(file="pa_dragged_layout.png", alt="Pennsylvania display-offset layout", caption="Display-offset layout"),
          list(file="pa_displacement_vectors.png", alt="Pennsylvania displacement vector diagnostic", caption="Displacement vectors")),
     c("<a href=\"assets/tables/pa_drag_offsets_used.csv\">Display offset CSV</a>", "<a href=\"assets/tables/cross_state_metrics.csv\">Validation metrics CSV</a>")),
'<section id="states" class="card">
<h2>Extended U.S. States</h2>
<p>Additional state examples show where the same analytical parameter derivation remains stable and where documented display offsets improve publication readability.</p>
<div class="figure-grid">
<figure><img src="assets/figures/oh_dragged_layout.png" alt="Ohio display-offset layout"><figcaption>Ohio display-offset layout</figcaption></figure>
<figure><img src="assets/figures/mi_dragged_layout.png" alt="Michigan display-offset layout"><figcaption>Michigan display-offset layout</figcaption></figure>
<figure><img src="assets/figures/ky_dragged_layout.png" alt="Kentucky display-offset layout"><figcaption>Kentucky display-offset layout</figcaption></figure>
<figure><img src="assets/figures/il_dragged_layout.png" alt="Illinois display-offset layout"><figcaption>Illinois display-offset layout</figcaption></figure>
<figure><img src="assets/figures/nd_dragged_layout.png" alt="North Dakota display-offset layout"><figcaption>North Dakota display-offset layout</figcaption></figure>
<figure><img src="assets/figures/nc_dragged_layout.png" alt="North Carolina display-offset layout"><figcaption>North Carolina display-offset layout</figcaption></figure>
<figure><img src="assets/figures/va_dragged_layout.png" alt="Virginia display-offset layout"><figcaption>Virginia display-offset layout</figcaption></figure>
<figure><img src="assets/figures/tx_dragged_layout.png" alt="Texas display-offset layout"><figcaption>Texas display-offset layout</figcaption></figure>
<figure><img src="assets/figures/fl_dragged_layout.png" alt="Florida display-offset layout"><figcaption>Florida display-offset layout</figcaption></figure>
</div>
<h3>Formula-Derived Validation Parameters</h3>
<table>
<thead><tr><th>Case</th><th>alpha_r (km)</th><th>alpha_l (km)</th><th>Units</th><th>Manual offsets in metrics?</th><th>Offset CSV</th></tr></thead>
<tbody>',
state_param_rows,
'</tbody></table>
</section>
<section id="world" class="card">
<h2>Canada/Germany</h2>
<p>Canada and Germany illustrate multi-region transfer outside the main U.S. municipal calibration set. Canada is included in the quantitative table; Germany is included as a display and stress-test example.</p>
<div class="figure-grid">
<figure><img src="assets/figures/canada_dragged_layout.png" alt="Canada display-offset layout"><figcaption>Canada display-offset layout</figcaption></figure>
<figure><img src="assets/figures/germany_dragged_layout.png" alt="Germany display-offset layout"><figcaption>Germany display-offset layout</figcaption></figure>
</div>
<p class="links"><a href="assets/tables/canada_drag_offsets_used.csv">Canada offset CSV</a> <a href="assets/tables/germany_drag_offsets_used.csv">Germany offset CSV</a></p>
</section>
<section id="hhs" class="card">
<h2>HHS National Grouped Layout</h2>
<p>The HHS example uses numbered region labels, with region membership defined in the manuscript table. The second figure documents the display-offset movement used to clean up the final publication layout.</p>
<div class="figure-grid">
<figure><img src="assets/figures/hhs_dragged_layout.png" alt="HHS national grouped display layout"><figcaption>Final HHS grouped layout</figcaption></figure>
<figure><img src="assets/figures/hhs_display_offsets.png" alt="HHS display-offset movement diagnostic"><figcaption>Documented display offsets</figcaption></figure>
</div>
<p class="links"><a href="assets/tables/hhs_drag_offsets_used.csv">HHS offset CSV</a></p>
</section>
<section id="downloads" class="card">
<h2>Download Data/Code</h2>
<p>The publication figures are generated from the package source, paper scripts, and documented offset tables. The repository contains the regeneration scripts under <code>paper/scripts</code>; this page mirrors the figures and small CSV outputs needed to audit the display-offset layouts.</p>
<p class="links"><a href="https://github.com/PrigasG/explodemap/tree/master/paper/scripts">Paper scripts</a> <a href="assets/tables/cross_state_metrics.csv">Cross-state metrics CSV</a> <a href="assets/tables/dragged_layout_render_index.csv">Rendered-layout index CSV</a> <a href="https://github.com/PrigasG/explodemap">Repository</a></p>
</section>
</main>
</body>
</html>')

writeLines(page, file.path(site_dir, "index.html"), useBytes = TRUE)
message("Wrote ", file.path(site_dir, "index.html"))
