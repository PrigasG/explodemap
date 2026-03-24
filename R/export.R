# =============================================================================
# R/export.R — Optional TopoJSON export via external mapshaper
# =============================================================================
#
# Provides a convenience helper for exporting exploded maps as TopoJSON,
# a common format for downstream tools such as Power BI, D3.js,
# and Observable.
#
# Requires the external `mapshaper` CLI tool (not an R dependency):
#   npm install -g mapshaper
#
# Design:
#   - Accepts sf, exploded_map, or grouped_exploded_map objects
#   - Writes a temporary GeoJSON via sf::st_write
#   - Shells out to mapshaper for GeoJSON → TopoJSON conversion
#   - Optionally simplifies geometry during conversion
#   - Keeps explodemap free of heavy JS/topology dependencies
# =============================================================================


# ─────────────────────────────────────────────────────────────────────────────
# INTERNAL HELPERS
# ─────────────────────────────────────────────────────────────────────────────

#' Normalize input to an export-ready sf object in WGS84
#' @param x An sf, exploded_map, or grouped_exploded_map object
#' @return sf object
#' @keywords internal
.as_export_sf <- function(x) {
  if (inherits(x, "grouped_exploded_map")) {
    return(x$sf_grouped_wgs)
  }

  if (inherits(x, "exploded_map")) {
    return(x$sf_exp_wgs)
  }

  if (inherits(x, "sf")) {
    crs <- sf::st_crs(x)

    if (is.na(crs)) {
      warning("Input sf object has no CRS; exporting as-is.", call. = FALSE)
      return(x)
    }

    if (!isTRUE(crs$epsg == 4326L)) {
      return(sf::st_transform(x, 4326))
    }

    return(x)
  }

  stop(
    "`x` must be an sf object, exploded_map, or grouped_exploded_map.",
    call. = FALSE
  )
}


#' Locate the mapshaper executable on the system path
#' @return Path to mapshaper executable
#' @keywords internal
.find_mapshaper <- function() {
  exe <- Sys.which("mapshaper")

  if (!nzchar(exe)) {
    stop(
      "The `mapshaper` command-line tool was not found on your system path.\n",
      "Install it with: npm install -g mapshaper\n",
      "Then restart your R session and try again.",
      call. = FALSE
    )
  }

  exe
}


#' Build mapshaper CLI arguments
#' @param input Path to input GeoJSON file
#' @param output Path to output TopoJSON file
#' @param simplify Optional simplification proportion in `(0, 1)`.
#' @return Character vector of arguments for system2()
#' @keywords internal
.build_mapshaper_args <- function(input, output, simplify = NULL) {
  args <- c(input)

  if (!is.null(simplify)) {
    if (!is.numeric(simplify) || length(simplify) != 1 ||
        simplify <= 0 || simplify >= 1) {
      stop(
        "`simplify` must be a single number between 0 and 1 (exclusive).",
        call. = FALSE
      )
    }

    args <- c(args, "-simplify", as.character(simplify))
  }

  c(args, "-o", "format=topojson", output)
}


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

#' Export an exploded map as TopoJSON
#'
#' Converts an `sf`, `exploded_map`, or `grouped_exploded_map` object to
#' TopoJSON using the external `mapshaper` command-line tool. The input is
#' first written as a temporary GeoJSON file, then converted by mapshaper.
#'
#' This is intended as a convenience helper for downstream tools such as
#' Power BI, D3.js, and Observable that prefer or require TopoJSON input.
#'
#' @param x An `sf`, `exploded_map`, or `grouped_exploded_map` object.
#'   For `exploded_map` objects, the WGS84 exploded geometry (`sf_exp_wgs`)
#'   is exported. For `grouped_exploded_map` objects, the WGS84 grouped
#'   geometry (`sf_grouped_wgs`) is exported.
#' @param file Output file path. Should end in `.topojson` or `.json`.
#' @param simplify Optional simplification proportion passed to
#'   `mapshaper -simplify`. Must be a single number between 0 and 1
#'   (exclusive). For example, `simplify = 0.5` retains 50% of vertices.
#'   Default is `NULL` (no simplification). Note that simplification
#'   modifies polygon geometry and therefore breaks the exact geometry
#'   preservation guarantee of Proposition 1.
#' @param overwrite Logical; if `TRUE`, overwrite `file` if it already
#'   exists. Default is `FALSE`.
#'
#' @details
#' This function requires the external `mapshaper` command-line tool to be
#' installed and available on the system path. It can be installed with:
#'
#' \preformatted{npm install -g mapshaper}
#'
#' The `mapshaper` tool is not an R package dependency; it is invoked via
#' `system2()`. If mapshaper is not found, the function errors with an
#' informative message.
#'
#' @return Invisibly returns the output file path.
#'
#' @examples
#' \dontrun{
#' # Two-level export
#' result <- explode_sf(my_sf, region_col = "region", plot = FALSE)
#' export_topojson(result, "exploded.topojson")
#'
#' # Three-level grouped export
#' grp <- explode_grouped(my_sf, region_col = "region", plot = FALSE)
#' export_topojson(grp, "grouped.topojson")
#'
#' # With simplification (breaks Proposition 1 guarantee)
#' export_topojson(result, "simplified.topojson", simplify = 0.5)
#'
#' # Raw sf object
#' export_topojson(my_sf, "raw.topojson", overwrite = TRUE)
#' }
#'
#' @export
export_topojson <- function(x, file, simplify = NULL, overwrite = FALSE) {
  if (!is.character(file) || length(file) != 1 || !nzchar(file)) {
    stop("`file` must be a non-empty file path.", call. = FALSE)
  }

  ext <- tolower(tools::file_ext(file))
  if (!ext %in% c("topojson", "json")) {
    warning(
      "Output file does not end in .topojson or .json.",
      call. = FALSE
    )
  }

  if (file.exists(file) && !isTRUE(overwrite)) {
    stop(
      "Output file '", file, "' already exists. ",
      "Use `overwrite = TRUE` to replace it.",
      call. = FALSE
    )
  }

  sf_obj <- .as_export_sf(x)
  exe <- .find_mapshaper()

  out_path <- normalizePath(file, winslash = "/", mustWork = FALSE)
  out_dir <- dirname(out_path)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  tmp_geojson <- tempfile(fileext = ".geojson")
  on.exit(unlink(tmp_geojson), add = TRUE)

  sf::st_write(
    sf_obj,
    tmp_geojson,
    driver = "GeoJSON",
    quiet = TRUE,
    delete_dsn = TRUE
  )

  args <- .build_mapshaper_args(
    input = tmp_geojson,
    output = out_path,
    simplify = simplify
  )

  cmd_out <- suppressWarnings(
    system2(exe, args = args, stdout = TRUE, stderr = TRUE)
  )

  if (!file.exists(out_path)) {
    detail <- if (length(cmd_out)) paste(cmd_out, collapse = "\n") else ""
    stop("TopoJSON export failed.\n", detail, call. = FALSE)
  }

  size_kb <- round(file.info(out_path)$size / 1024, 1)
  message("Exported: ", out_path, " (", size_kb, " KB)")

  invisible(out_path)
}
