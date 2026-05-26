source(file.path("paper", "scripts", "00_setup.R"))
write_run_info("03_canada_validation")
run_metrics <- identical(tolower(Sys.getenv("EXPLODEMAP_PAPER_RUN_METRICS", "false")), "true")

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

message("Running Canada validation...")
sf_raw <- download_canada_csds()
sf_reg <- sf_raw |>
  sf::st_transform(3347) |>
  dplyr::left_join(province_regions, by = "PRUID") |>
  dplyr::filter(.data$region != "Territories")

timing <- system.time({
  canada <- explodemap::explode_sf(
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
})

canada_metrics <- data.frame(
  dataset = "Canada CSDs excluding territories",
  stage = "formula",
  n_features = nrow(canada$sf_exp),
  vertex_count = count_vertices(canada$sf_exp),
  n_regions = canada$stats$n_regions,
  w_bar_m = canada$stats$w_bar,
  R_local_m = canada$stats$R_local,
  ratio = canada$stats$ratio,
  alpha_r_m = canada$params$alpha_r,
  alpha_l_m = canada$params$alpha_l,
  p = canada$params$p
)
if (run_metrics) {
  canada_metrics <- cbind(
    canada_metrics,
    compute_nearest_gap_metrics(canada$sf_exp, sample_n = 250),
    compute_displacement_metrics(canada$sf_orig, canada$sf_exp)
  )
}
canada_metrics$runtime_seconds <- unname(timing[["elapsed"]])
canada_calibration <- explodemap::calibration_row(canada)

save_table(canada_metrics, "canada_metrics.csv")
save_table(canada_calibration, "canada_calibration_row.csv")
save_plot(canada$plots$exp, "canada_formula_derived.png", width = 9, height = 6)

message("Canada validation complete.")
