#' Apply documented display offsets by region
#'
#' Applies rigid display offsets to all features in each named region. This is
#' intended as a reproducible finishing step for publication or dashboard
#' layouts after an exploded map has already been computed.
#'
#' @param x An \code{sf}, \code{exploded_map}, or \code{grouped_exploded_map}
#'   object.
#' @param offsets A data frame, or a path to a CSV file, containing one row per
#'   region and numeric offset columns.
#' @param region_col Name of the region column in \code{x}. For
#'   \code{exploded_map} and \code{grouped_exploded_map} objects, the value
#'   recorded in \code{x$diagnostics} is used when this is \code{NULL}.
#' @param offset_region_col Name of the region column in \code{offsets}.
#' @param dx_col Name of the horizontal offset column in \code{offsets}.
#' @param dy_col Name of the vertical offset column in \code{offsets}.
#' @param update_plots Logical; when \code{TRUE}, rebuild stored ggplot objects
#'   for exploded map objects.
#'
#' @return For an \code{sf} input, an \code{sf} object with the same attributes
#'   and CRS as \code{x}; geometries belonging to each listed region are
#'   translated by the supplied offsets, and the normalized offset table is
#'   stored in the \code{display_offsets} attribute. For an
#'   \code{exploded_map}, returns the same S3 object structure with
#'   \code{sf_exp}, \code{sf_exp_wgs}, stored plots, and
#'   \code{display_offsets} updated. For a \code{grouped_exploded_map},
#'   returns the same S3 object structure with \code{sf_grouped},
#'   \code{sf_grouped_wgs}, stored plots, and \code{display_offsets} updated.
#'   The offsets are rigid translations, so polygon shape, area, and
#'   within-region relative geometry are preserved.
#'
#' @details Offsets are interpreted in the coordinate units of the projected
#' geometry being adjusted. The default column names \code{dx_m} and
#' \code{dy_m} assume a metric projected CRS, matching the package's
#' exploded-map workflow.
#'
#' @examples
#' library(sf)
#' x <- st_sf(
#'   region = c("A", "B"),
#'   geometry = st_sfc(
#'     st_point(c(0, 0)),
#'     st_point(c(10, 0)),
#'     crs = 3857
#'   )
#' )
#' offsets <- data.frame(region = "B", dx_m = 5, dy_m = 2)
#' apply_region_offsets(x, offsets, region_col = "region")
#'
#' @export
apply_region_offsets <- function(x,
                                 offsets,
                                 region_col = NULL,
                                 offset_region_col = "region",
                                 dx_col = "dx_m",
                                 dy_col = "dy_m",
                                 update_plots = TRUE) {
  offsets <- .normalize_region_offsets(
    offsets = offsets,
    offset_region_col = offset_region_col,
    dx_col = dx_col,
    dy_col = dy_col
  )

  if (inherits(x, "grouped_exploded_map")) {
    region_col <- .resolve_region_col(x$sf_grouped, region_col, x$diagnostics$region_col)
    out <- x
    out$sf_grouped <- .apply_region_offsets_sf(out$sf_grouped, offsets, region_col)
    out$sf_grouped_wgs <- sf::st_transform(out$sf_grouped, 4326)
    out$display_offsets <- offsets

    if (isTRUE(update_plots) && !is.null(out$plots)) {
      out$plots <- .make_grouped_plots(
        sf_orig    = out$sf_orig,
        sf_local   = out$sf_local,
        sf_grouped = out$sf_grouped,
        region_col = region_col,
        title      = out$diagnostics$label,
        params     = out$params
      )
    }
    return(out)
  }

  if (inherits(x, "exploded_map")) {
    region_col <- .resolve_region_col(x$sf_exp, region_col, x$diagnostics$region_col)
    out <- x
    out$sf_exp <- .apply_region_offsets_sf(out$sf_exp, offsets, region_col)
    out$sf_exp_wgs <- sf::st_transform(out$sf_exp, 4326)
    out$display_offsets <- offsets

    if (isTRUE(update_plots) && !is.null(out$plots)) {
      out$plots <- .make_plots(
        sf_orig    = out$sf_orig,
        sf_exp     = out$sf_exp,
        region_col = region_col,
        title      = out$diagnostics$label,
        params     = out$params
      )
    }
    return(out)
  }

  if (inherits(x, "sf")) {
    region_col <- .resolve_region_col(x, region_col, NULL)
    out <- .apply_region_offsets_sf(x, offsets, region_col)
    attr(out, "display_offsets") <- offsets
    return(out)
  }

  stop("`x` must be an sf, exploded_map, or grouped_exploded_map object.", call. = FALSE)
}


#' Read drag-helper offset CSVs into a region offset data frame
#'
#' Reads one or more drag-helper offset files and returns a tidy data frame
#' ready for \code{\link{apply_region_offsets}}. The drag helper tool exports
#' a CSV named \code{{state}_drag_offsets.csv} (e.g. \code{nj_drag_offsets.csv})
#' with three columns: \code{region}, \code{dx_m}, and \code{dy_m}. This
#' function provides a convenient way to load that file -- by explicit path,
#' by state abbreviation, or a mix of both -- and prints a compact summary so
#' you can verify the offsets before applying them.
#'
#' @param x A character vector of one or more items, each of which is either:
#'   \itemize{
#'     \item a path to a CSV file (e.g. \code{"outputs/nj_drag_offsets.csv"}),
#'       or
#'     \item a US state abbreviation (e.g. \code{"NJ"} or \code{"nj"}), which
#'       is resolved to \code{{tolower(x)}_drag_offsets.csv} inside \code{dir}.
#'   }
#' @param dir Directory to search when an element of \code{x} is a state
#'   abbreviation rather than a full path. Defaults to the current working
#'   directory.
#' @param quiet Logical; when \code{FALSE} (default), prints a compact summary
#'   of the offsets that were read.
#'
#' @return A data frame with columns \code{region} (character), \code{dx_m}
#'   (numeric), and \code{dy_m} (numeric). When multiple files are supplied an
#'   additional \code{state} column (the lower-case abbreviation or file stem)
#'   is prepended and rows from all files are combined.
#'
#' @details
#' Typical workflow after running the drag helper tool:
#'
#' \preformatted{
#' # 1. Compute the exploded layout
#' nj <- explode_state("34", crs = 32111, region_map = list(...))
#'
#' # 2. Read the offsets exported from the drag helper
#' offsets <- read_drag_offsets("NJ", dir = "outputs/drag_helpers")
#'
#' # 3. Apply them as a reproducible finishing step
#' nj_display <- apply_region_offsets(nj, offsets)
#' }
#'
#' You can also pass the CSV path directly to
#' \code{\link{apply_region_offsets}} without calling
#' \code{read_drag_offsets()} first -- both accept a file path.
#' \code{read_drag_offsets()} is most useful when you want to inspect the
#' offsets interactively, load multiple state files at once, or resolve files
#' by abbreviation rather than full path.
#'
#' @seealso \code{\link{apply_region_offsets}}
#' @export
read_drag_offsets <- function(x, dir = ".", quiet = FALSE) {
  if (!is.character(x) || length(x) == 0L)
    stop("`x` must be a non-empty character vector of file paths or state abbreviations.",
         call. = FALSE)

  resolve_path <- function(item) {
    if (file.exists(item)) return(item)
    candidate <- file.path(dir, paste0(tolower(item), "_drag_offsets.csv"))
    if (file.exists(candidate)) return(candidate)
    stop(
      "Drag-offset file not found for '", item, "'.\n",
      "Checked: '", item, "' and '", candidate, "'.\n",
      "Export the CSV from the drag helper tool and place it in '",
      normalizePath(dir, mustWork = FALSE), "'.",
      call. = FALSE
    )
  }

  paths <- vapply(x, resolve_path, character(1L), USE.NAMES = FALSE)

  read_one <- function(path) {
    df <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    names(df) <- tolower(trimws(names(df)))
    required <- c("region", "dx_m", "dy_m")
    missing  <- setdiff(required, names(df))
    if (length(missing))
      stop("'", path, "' is missing column(s): ",
           paste(missing, collapse = ", "), ".", call. = FALSE)
    out <- data.frame(
      region = as.character(df$region),
      dx_m   = suppressWarnings(as.numeric(df$dx_m)),
      dy_m   = suppressWarnings(as.numeric(df$dy_m)),
      stringsAsFactors = FALSE
    )
    bad <- is.na(out$region) | out$region == ""
    if (any(bad))
      stop("Region names must be non-empty in '", path, "'.", call. = FALSE)
    if (anyNA(out$dx_m) || anyNA(out$dy_m))
      stop("Non-numeric offset values in '", path, "'.", call. = FALSE)
    if (anyDuplicated(out$region)) {
      dupes <- unique(out$region[duplicated(out$region)])
      stop("Duplicate region(s) in '", path, "': ",
           paste(dupes, collapse = ", "), ".", call. = FALSE)
    }
    out
  }

  if (length(paths) == 1L) {
    result <- read_one(paths)
    if (!quiet) {
      message("read_drag_offsets: ", nrow(result),
              " region(s) from '", basename(paths), "'")
      for (i in seq_len(nrow(result)))
        message("  ", format(result$region[i], width = 16L),
                "  dx = ", sprintf("%+.0f", result$dx_m[i]),
                " m   dy = ", sprintf("%+.0f", result$dy_m[i]), " m")
    }
    return(result)
  }

  state_keys <- tolower(sub("_drag_offsets\\.csv$", "",
                             basename(paths), ignore.case = TRUE))
  tables <- lapply(paths, read_one)
  for (i in seq_along(tables)) tables[[i]]$state <- state_keys[i]
  result <- do.call(rbind, tables)
  rownames(result) <- NULL
  result <- result[, c("state", "region", "dx_m", "dy_m")]

  if (!quiet)
    message("read_drag_offsets: ", nrow(result), " region(s) from ",
            length(paths), " file(s) (",
            paste(state_keys, collapse = ", "), ")")
  result
}


.normalize_region_offsets <- function(offsets,
                                      offset_region_col,
                                      dx_col,
                                      dy_col) {
  if (is.character(offsets) && length(offsets) == 1L) {
    offsets <- utils::read.csv(offsets, stringsAsFactors = FALSE, check.names = FALSE)
  }

  if (!is.data.frame(offsets)) {
    stop("`offsets` must be a data frame or a path to a CSV file.", call. = FALSE)
  }

  required <- c(offset_region_col, dx_col, dy_col)
  missing <- setdiff(required, names(offsets))
  if (length(missing) > 0L) {
    stop("`offsets` is missing required column(s): ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  out <- data.frame(
    region = as.character(offsets[[offset_region_col]]),
    dx_m   = as.numeric(offsets[[dx_col]]),
    dy_m   = as.numeric(offsets[[dy_col]]),
    stringsAsFactors = FALSE
  )

  if (anyNA(out$region) || any(out$region == "")) {
    stop("Offset region names must be non-missing and non-empty.", call. = FALSE)
  }
  if (anyNA(out$dx_m) || anyNA(out$dy_m)) {
    stop("Offset columns must be numeric and non-missing.", call. = FALSE)
  }
  if (anyDuplicated(out$region)) {
    dupes <- unique(out$region[duplicated(out$region)])
    stop("`offsets` contains duplicate region rows: ",
         paste(dupes, collapse = ", "), call. = FALSE)
  }

  out
}

.resolve_region_col <- function(sf_obj, region_col, fallback) {
  if (is.null(region_col)) {
    region_col <- fallback
  }
  if (is.null(region_col) || !nzchar(region_col)) {
    stop("`region_col` must be supplied for raw sf inputs.", call. = FALSE)
  }
  if (!region_col %in% names(sf_obj)) {
    stop("region_col '", region_col, "' not found in `x`.", call. = FALSE)
  }
  region_col
}

.apply_region_offsets_sf <- function(sf_obj, offsets, region_col) {
  if (is.na(sf::st_crs(sf_obj))) {
    stop("`x` has no CRS. Set a projected CRS before applying offsets.", call. = FALSE)
  }
  if (sf::st_is_longlat(sf_obj)) {
    stop("`x` is in geographic lon/lat coordinates. ",
         "Project it before applying metric offsets.", call. = FALSE)
  }

  out <- sf_obj
  known_regions <- as.character(unique(out[[region_col]]))
  unknown <- setdiff(offsets$region, known_regions)
  if (length(unknown) > 0L) {
    warning(
      "Ignoring offset rows for unknown region(s): ",
      paste(unknown, collapse = ", "),
      call. = FALSE
    )
  }

  for (i in seq_len(nrow(offsets))) {
    idx <- as.character(out[[region_col]]) == offsets$region[i]
    if (!any(idx)) next
    sf::st_geometry(out)[idx] <-
      sf::st_geometry(out)[idx] + c(offsets$dx_m[i], offsets$dy_m[i])
  }

  sf::st_as_sf(out)
}
