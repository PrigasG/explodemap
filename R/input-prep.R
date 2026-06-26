#' Count geometry vertices
#'
#' Counts coordinate rows in an `sf` or `sfc` object. This is a lightweight
#' utility for upload limits, performance warnings, simplification decisions,
#' and diagnostics.
#'
#' @param x An `sf`, `sfc`, or geometry object accepted by [sf::st_geometry()].
#'
#' @return A single numeric vertex count.
#' @export
count_geometry_vertices <- function(x) {
  geom <- if (inherits(x, "sfc")) x else sf::st_geometry(x)
  sum(vapply(
    geom,
    function(g) nrow(sf::st_coordinates(g)),
    numeric(1)
  ), na.rm = TRUE)
}

#' Create a stable group palette
#'
#' @param groups Character vector of group names.
#' @param palette Palette name passed to [grDevices::hcl.colors()].
#' @param existing Optional named colour vector. Existing assignments are
#'   retained and colours are generated only for new groups.
#'
#' @return A named character vector of colours.
#' @export
group_palette <- function(groups, palette = "Dark 3", existing = NULL) {
  groups <- sort(unique(as.character(groups)))
  groups <- groups[!is.na(groups) & nzchar(groups)]

  existing <- existing %||% character()
  if (length(existing) && (is.null(names(existing)) || any(!nzchar(names(existing))))) {
    stop("`existing` must be a named colour vector.", call. = FALSE)
  }

  out <- existing[intersect(names(existing), groups)]
  missing <- setdiff(groups, names(out))
  if (length(missing)) {
    colours <- grDevices::hcl.colors(length(groups), palette = palette)
    generated <- stats::setNames(colours, groups)
    out <- c(out, generated[missing])
  }
  out[groups]
}

#' Assign generated spatial groups
#'
#' @param x An `sf` object.
#' @param method One of `"quadrants"`, `"clusters"`, or `"individual"`.
#' @param groups Number of clusters for `method = "clusters"`.
#' @param seed Random seed for deterministic clustering.
#' @param group_col Name of the output grouping column.
#'
#' @return `x` with `group_col` assigned.
#' @export
assign_spatial_groups <- function(x,
                                  method = c("quadrants", "clusters", "individual"),
                                  groups = 6L,
                                  seed = 1L,
                                  group_col = "region") {
  if (!inherits(x, "sf")) {
    stop("`x` must be an sf object.", call. = FALSE)
  }
  method <- match.arg(method)
  if (!is.character(group_col) || length(group_col) != 1L || !nzchar(group_col)) {
    stop("`group_col` must be a single non-empty string.", call. = FALSE)
  }

  if (identical(method, "individual")) {
    x[[group_col]] <- sprintf("Feature %d", seq_len(nrow(x)))
    return(x)
  }

  points <- suppressWarnings(sf::st_point_on_surface(sf::st_geometry(x)))
  coords <- sf::st_coordinates(points)

  if (identical(method, "quadrants")) {
    mx <- stats::median(coords[, 1], na.rm = TRUE)
    my <- stats::median(coords[, 2], na.rm = TRUE)
    dx <- coords[, 1] - mx
    dy <- coords[, 2] - my
    x[[group_col]] <- dplyr::case_when(
      dy >= 0 & abs(dy) >= abs(dx) ~ "North",
      dy < 0 & abs(dy) >= abs(dx) ~ "South",
      dx >= 0 & abs(dx) > abs(dy) ~ "East",
      TRUE ~ "West"
    )
    return(x)
  }

  groups <- max(2L, min(as.integer(groups %||% 6L), nrow(x)))
  old_seed <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", envir = .GlobalEnv)
  } else {
    NULL
  }
  on.exit({
    if (!is.null(old_seed)) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    }
  }, add = TRUE)
  set.seed(seed)
  scaled <- scale(coords)
  bad_cols <- !is.finite(colSums(scaled))
  if (any(bad_cols)) {
    scaled[, bad_cols] <- 0
  }
  fit <- stats::kmeans(scaled, centers = groups, nstart = 20)
  x[[group_col]] <- paste("Group", fit$cluster)
  x
}

#' Validate explodemap input
#'
#' @param x An `sf` object.
#' @param group_col Grouping column.
#' @param id_col Optional unique feature ID column.
#' @param label_col Optional feature label column.
#' @param max_features,max_groups,max_vertices Optional limits.
#' @param min_groups Minimum number of groups required.
#'
#' @return An `explodemap_validation` object.
#' @export
validate_explodemap_input <- function(x,
                                      group_col,
                                      id_col = NULL,
                                      label_col = NULL,
                                      max_features = Inf,
                                      max_groups = Inf,
                                      max_vertices = Inf,
                                      min_groups = 2L) {
  errors <- character()
  warnings <- character()
  metrics <- list(
    features = NA_integer_,
    groups = NA_integer_,
    vertices = NA_real_,
    geometry_types = character(),
    crs = NA
  )

  if (!inherits(x, "sf")) {
    errors <- c(errors, "`x` must be an sf object.")
    return(new_explodemap_validation(errors, warnings, metrics))
  }

  metrics$features <- nrow(x)
  metrics$vertices <- count_geometry_vertices(x)
  metrics$geometry_types <- sort(unique(as.character(sf::st_geometry_type(x, by_geometry = TRUE))))
  crs <- sf::st_crs(x)
  metrics$crs <- if (is.na(crs)) NA else crs$epsg %||% crs$wkt

  if (is.na(crs)) {
    errors <- c(errors, "`x` must have a coordinate reference system.")
  }
  if (nrow(x) > max_features) {
    errors <- c(errors, paste0("`x` has ", nrow(x), " features; maximum is ", max_features, "."))
  }
  if (is.finite(max_vertices) && metrics$vertices > max_vertices) {
    errors <- c(errors, paste0("`x` has ", format(metrics$vertices, big.mark = ","),
                               " vertices; maximum is ", format(max_vertices, big.mark = ","), "."))
  }
  if (any(sf::st_is_empty(x))) {
    errors <- c(errors, "`x` contains empty geometries.")
  }
  if (!all(grepl("POLYGON", metrics$geometry_types))) {
    errors <- c(errors, "`x` must contain polygon or multipolygon geometries.")
  }

  check_col <- function(col, arg, required = FALSE) {
    if (is.null(col) || !nzchar(col)) {
      if (required) paste0("`", arg, "` must name a column.") else NULL
    } else if (!col %in% names(x)) {
      paste0("`", arg, "` column '", col, "' was not found.")
    } else {
      NULL
    }
  }
  errors <- c(errors, check_col(group_col, "group_col", required = TRUE))
  errors <- c(errors, check_col(id_col, "id_col"))
  errors <- c(errors, check_col(label_col, "label_col"))

  if (!is.null(group_col) && nzchar(group_col) && group_col %in% names(x)) {
    groups <- trimws(as.character(x[[group_col]]))
    if (anyNA(groups) || any(!nzchar(groups))) {
      errors <- c(errors, "Group values cannot be missing.")
    }
    metrics$groups <- length(unique(groups[!is.na(groups) & nzchar(groups)]))
    if (metrics$groups < min_groups) {
      errors <- c(errors, paste0("At least ", min_groups, " groups are required."))
    }
    if (metrics$groups > max_groups) {
      errors <- c(errors, paste0("`x` has ", metrics$groups, " groups; maximum is ", max_groups, "."))
    }
  }

  if (!is.null(id_col) && nzchar(id_col) && id_col %in% names(x)) {
    ids <- trimws(as.character(x[[id_col]]))
    if (anyNA(ids) || any(!nzchar(ids))) errors <- c(errors, "Feature IDs cannot be missing.")
    if (anyDuplicated(ids)) errors <- c(errors, "Feature IDs must be unique.")
  }
  if (!is.null(label_col) && nzchar(label_col) && label_col %in% names(x)) {
    labels <- trimws(as.character(x[[label_col]]))
    if (anyNA(labels) || any(!nzchar(labels))) warnings <- c(warnings, "Feature labels contain missing values.")
  }

  new_explodemap_validation(errors, warnings, metrics)
}

new_explodemap_validation <- function(errors, warnings, metrics) {
  structure(
    list(
      valid = length(errors) == 0L,
      errors = errors[!is.na(errors) & nzchar(errors)],
      warnings = warnings[!is.na(warnings) & nzchar(warnings)],
      metrics = metrics,
      suggestions = character(),
      format_version = 1L
    ),
    class = "explodemap_validation"
  )
}

#' @export
print.explodemap_validation <- function(x, ...) {
  cat("explodemap input validation\n")
  cat("Status: ", if (isTRUE(x$valid)) "valid" else "invalid", "\n", sep = "")
  if (length(x$errors)) {
    cat("Errors:\n")
    cat(paste0("- ", x$errors, collapse = "\n"), "\n")
  }
  if (length(x$warnings)) {
    cat("Warnings:\n")
    cat(paste0("- ", x$warnings, collapse = "\n"), "\n")
  }
  invisible(x)
}

#' Simplify geometry to a vertex budget
#'
#' @param x An `sf` object.
#' @param target_vertices Desired maximum vertex count.
#' @param max_tolerance Optional maximum simplification tolerance.
#' @param preserve_features Require row count, non-empty geometries, and polygon
#'   geometry types to be preserved.
#' @param preserve_topology Passed to [sf::st_simplify()].
#'
#' @return An `explodemap_simplification` object.
#' @export
simplify_to_vertex_budget <- function(x,
                                      target_vertices = 350000,
                                      max_tolerance = NULL,
                                      preserve_features = TRUE,
                                      preserve_topology = TRUE) {
  if (!inherits(x, "sf")) stop("`x` must be an sf object.", call. = FALSE)
  before <- count_geometry_vertices(x)
  if (!is.finite(before) || before <= target_vertices) {
    return(new_simplification_result(x, before, before, 0, FALSE, 0L))
  }
  bb <- sf::st_bbox(x)
  extent <- as.numeric(max(bb["xmax"] - bb["xmin"], bb["ymax"] - bb["ymin"]))
  if (!is.finite(extent) || extent <= 0) {
    return(new_simplification_result(x, before, before, 0, FALSE, 0L))
  }

  fractions <- c(0.00005, 0.0001, 0.0002, 0.0004, 0.0008, 0.0016, 0.0032)
  tolerances <- extent * fractions
  if (!is.null(max_tolerance)) {
    tolerances <- tolerances[tolerances <= max_tolerance]
  }

  best <- x
  best_tol <- 0
  best_vertices <- before
  attempts <- 0L
  original_types <- unique(as.character(sf::st_geometry_type(x, by_geometry = TRUE)))
  for (tol in tolerances) {
    attempts <- attempts + 1L
    candidate <- tryCatch(
      sf::st_make_valid(sf::st_simplify(x, dTolerance = tol, preserveTopology = preserve_topology)),
      error = function(e) NULL
    )
    if (is.null(candidate)) next
    if (isTRUE(preserve_features)) {
      candidate_types <- unique(as.character(sf::st_geometry_type(candidate, by_geometry = TRUE)))
      if (nrow(candidate) != nrow(x) || any(sf::st_is_empty(candidate))) next
      if (!all(grepl("POLYGON", candidate_types)) || !all(grepl("POLYGON", original_types))) next
    }
    candidate_vertices <- count_geometry_vertices(candidate)
    if (candidate_vertices < best_vertices) {
      best <- candidate
      best_tol <- tol
      best_vertices <- candidate_vertices
    }
    if (candidate_vertices <= target_vertices) break
  }

  new_simplification_result(best, before, best_vertices, best_tol, best_tol > 0, attempts)
}

new_simplification_result <- function(data, before, after, tolerance, simplified, attempts) {
  structure(
    list(
      data = data,
      before = before,
      after = after,
      tolerance = tolerance,
      simplified = simplified,
      attempts = attempts,
      format_version = 1L
    ),
    class = "explodemap_simplification"
  )
}

#' @export
print.explodemap_simplification <- function(x, ...) {
  cat("explodemap simplification\n")
  cat("Vertices: ", format(x$before, big.mark = ","), " -> ",
      format(x$after, big.mark = ","), "\n", sep = "")
  cat("Tolerance: ", signif(x$tolerance, 4), "\n", sep = "")
  invisible(x)
}

#' Prepare input for grouped explodemap layouts
#'
#' Standardizes common columns (`unit_id`, `unit_name`, and `region`) while
#' reporting each preparation choice.
#'
#' @param x An `sf` polygon object.
#' @param group_col,id_col,label_col Optional source columns.
#' @param group_method Grouping method when `group_col` is not supplied.
#' @param cluster_count Number of clusters for generated cluster groups.
#' @param target_crs CRS for layout work. Use `NULL` to keep the source CRS.
#' @param make_valid Repair geometries with [sf::st_make_valid()].
#' @param target_vertices Optional simplification budget.
#' @param seed Seed for generated clusters.
#'
#' @return An `explodemap_prepared_input` object with `data`, `report`,
#'   `mapping`, and `warnings`.
#' @export
prepare_explodemap_input <- function(x,
                                     group_col = NULL,
                                     id_col = NULL,
                                     label_col = NULL,
                                     group_method = c("column", "quadrants", "clusters", "individual"),
                                     cluster_count = 6L,
                                     target_crs = NULL,
                                     make_valid = TRUE,
                                     target_vertices = NULL,
                                     seed = 1L) {
  if (!inherits(x, "sf")) stop("`x` must be an sf object.", call. = FALSE)
  group_method <- match.arg(group_method)
  out <- x
  report <- list(
    input_crs = sf::st_crs(x)$epsg %||% sf::st_crs(x)$wkt,
    output_crs = NULL,
    geometry_fixed = isTRUE(make_valid),
    simplified = FALSE,
    simplification = NULL,
    seed = seed
  )
  warnings <- character()

  if (isTRUE(make_valid)) {
    out <- sf::st_make_valid(out)
  }
  if (!is.null(target_crs)) {
    out <- sf::st_transform(out, target_crs)
  }
  report$output_crs <- sf::st_crs(out)$epsg %||% sf::st_crs(out)$wkt

  if (!is.null(target_vertices)) {
    simp <- simplify_to_vertex_budget(out, target_vertices = target_vertices)
    out <- simp$data
    report$simplified <- isTRUE(simp$simplified)
    report$simplification <- unclass(simp)[setdiff(names(unclass(simp)), "data")]
  }

  out$unit_id <- if (!is.null(id_col) && nzchar(id_col) && id_col %in% names(out)) {
    as.character(out[[id_col]])
  } else {
    warnings <- c(warnings, "No ID column supplied; generated row-based unit IDs.")
    sprintf("feature-%06d", seq_len(nrow(out)))
  }
  out$unit_name <- if (!is.null(label_col) && nzchar(label_col) && label_col %in% names(out)) {
    as.character(out[[label_col]])
  } else {
    warnings <- c(warnings, "No label column supplied; generated row-based unit names.")
    sprintf("Unit %d", seq_len(nrow(out)))
  }

  if (identical(group_method, "column") && !is.null(group_col) && nzchar(group_col) && group_col %in% names(out)) {
    out$region <- as.character(out[[group_col]])
  } else {
    if (identical(group_method, "column")) {
      warnings <- c(warnings, "No usable group column supplied; generated quadrant groups.")
      group_method <- "quadrants"
    }
    out <- assign_spatial_groups(out, method = group_method, groups = cluster_count,
                                 seed = seed, group_col = "region")
  }

  validation <- validate_explodemap_input(out, "region", "unit_id", "unit_name")
  structure(
    list(
      data = out,
      report = c(report, list(validation = validation)),
      mapping = list(id_col = id_col, label_col = label_col, group_col = group_col,
                     group_method = group_method),
      warnings = unique(c(warnings, validation$warnings)),
      format_version = 1L
    ),
    class = "explodemap_prepared_input"
  )
}

#' @export
print.explodemap_prepared_input <- function(x, ...) {
  data <- x$data
  cat("Prepared explodemap input\n")
  cat("Features:      ", nrow(data), "\n", sep = "")
  cat("Parent groups: ", length(unique(as.character(data$region))), "\n", sep = "")
  cat("Vertices:      ", format(count_geometry_vertices(data), big.mark = ","), "\n", sep = "")
  if (length(x$warnings)) {
    cat("Warnings:\n")
    cat(paste0("- ", x$warnings, collapse = "\n"), "\n")
  }
  invisible(x)
}

#' Fingerprint explodemap geometry and grouping
#'
#' @param x An `sf` object or grouped explodemap layout.
#' @param id_col Optional feature ID column.
#' @param group_col Optional group column.
#' @param include_geometry Include EWKB geometry bytes.
#'
#' @return A stable MD5 fingerprint string.
#' @export
explodemap_fingerprint <- function(x,
                                   id_col = NULL,
                                   group_col = NULL,
                                   include_geometry = TRUE) {
  if (inherits(x, "grouped_exploded_map")) {
    x <- x$sf_grouped
  }
  if (!inherits(x, "sf")) stop("`x` must be an sf object or grouped explodemap layout.", call. = FALSE)

  ids <- if (!is.null(id_col) && id_col %in% names(x)) as.character(x[[id_col]]) else seq_len(nrow(x))
  groups <- if (!is.null(group_col) && group_col %in% names(x)) as.character(x[[group_col]]) else NULL
  payload <- list(
    format_version = 1L,
    crs = sf::st_crs(x)$wkt,
    ids = ids,
    groups = groups,
    bbox = unname(as.numeric(sf::st_bbox(x)))
  )
  if (isTRUE(include_geometry)) {
    payload$geometry <- sf::st_as_binary(sf::st_geometry(x), EWKB = TRUE)
  }
  path <- tempfile(fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(payload, path, version = 3)
  unname(tools::md5sum(path))
}
