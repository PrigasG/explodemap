#' Build a stable spatial join index
#'
#' Creates a small renderer- and source-neutral lookup table for validating
#' external data joins against spatial features. Jurisdiction-specific parsing
#' and alias rules remain application responsibilities.
#'
#' @param x Spatial or ordinary data frame.
#' @param id_col Stable unique feature identifier column.
#' @param name_col Optional display-name column.
#' @param parent_col Optional parent identifier column.
#'
#' @return A `spatial_join_index` data frame with `feature_id`, optional
#'   `feature_name` and `parent_id`, and the original feature row.
#' @export
spatial_join_index <- function(x, id_col, name_col = NULL, parent_col = NULL) {
  if (!is.data.frame(x)) {
    stop("`x` must be an sf object or data frame.", call. = FALSE)
  }
  id_col <- join_column(x, id_col, "id_col", required = TRUE)
  name_col <- join_column(x, name_col, "name_col", required = FALSE)
  parent_col <- join_column(x, parent_col, "parent_col", required = FALSE)
  ids <- trimws(as.character(x[[id_col]]))
  if (anyNA(ids) || any(!nzchar(ids))) {
    stop("`id_col` contains missing or empty identifiers.", call. = FALSE)
  }
  if (anyDuplicated(ids)) {
    duplicates <- unique(ids[duplicated(ids)])
    stop(
      "`id_col` must be unique; duplicated identifier(s): ",
      paste(utils::head(duplicates, 8L), collapse = ", "),
      if (length(duplicates) > 8L) ", ..." else "",
      call. = FALSE
    )
  }
  out <- data.frame(
    feature_id = ids,
    feature_row = seq_len(nrow(x)),
    stringsAsFactors = FALSE
  )
  if (!is.null(name_col)) {
    out$feature_name <- trimws(as.character(x[[name_col]]))
  }
  if (!is.null(parent_col)) {
    out$parent_id <- trimws(as.character(x[[parent_col]]))
  }
  structure(
    out,
    class = c("spatial_join_index", "data.frame"),
    id_col = id_col,
    name_col = name_col,
    parent_col = parent_col
  )
}

#' Validate an external data-to-spatial join
#'
#' Reports exact stable-ID matches and separates unmatched, duplicated,
#' ambiguous-name, and wrong-parent rows. It does not mutate or join the input;
#' applications remain in control of policy for aliases and fallbacks.
#'
#' @param data External data frame to validate.
#' @param index A [spatial_join_index()] object.
#' @param key_col Stable identifier column in `data`.
#' @param name_col Optional display-name column in `data`, used only to report
#'   ambiguous fallback names.
#' @param parent_col Optional parent identifier column in `data`, compared with
#'   `index$parent_id` for exact key matches.
#'
#' @return A `spatial_join_validation` list containing `matched`, `unmatched`,
#'   `ambiguous`, `duplicate`, `wrong_parent`, and summary counts.
#' @export
validate_spatial_join <- function(data,
                                  index,
                                  key_col,
                                  name_col = NULL,
                                  parent_col = NULL) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  if (!inherits(index, "spatial_join_index")) {
    stop("`index` must be created by spatial_join_index().", call. = FALSE)
  }
  key_col <- join_column(data, key_col, "key_col", required = TRUE)
  name_col <- join_column(data, name_col, "name_col", required = FALSE)
  parent_col <- join_column(data, parent_col, "parent_col", required = FALSE)
  keys <- trimws(as.character(data[[key_col]]))
  index_row <- match(keys, index$feature_id)
  valid_key <- !is.na(keys) & nzchar(keys)
  matched_flag <- valid_key & !is.na(index_row)
  duplicate_flag <- valid_key & (duplicated(keys) | duplicated(keys, fromLast = TRUE))

  matched <- data[matched_flag & !duplicate_flag, , drop = FALSE]
  matched$.feature_id <- keys[matched_flag & !duplicate_flag]
  matched$.feature_row <- index$feature_row[index_row[matched_flag & !duplicate_flag]]
  unmatched <- data[!matched_flag, , drop = FALSE]
  unmatched$.join_key <- keys[!matched_flag]
  duplicate <- data[duplicate_flag, , drop = FALSE]
  duplicate$.join_key <- keys[duplicate_flag]

  ambiguous <- data[FALSE, , drop = FALSE]
  ambiguous$.join_name <- character()
  if (!is.null(name_col) && "feature_name" %in% names(index)) {
    index_names <- join_normalize_name(index$feature_name)
    ambiguous_names <- unique(index_names[
      nzchar(index_names) & (duplicated(index_names) | duplicated(index_names, fromLast = TRUE))
    ])
    data_names <- join_normalize_name(data[[name_col]])
    ambiguous_flag <- data_names %in% ambiguous_names
    ambiguous <- data[ambiguous_flag, , drop = FALSE]
    ambiguous$.join_name <- data_names[ambiguous_flag]
  }

  wrong_parent <- data[FALSE, , drop = FALSE]
  wrong_parent$.expected_parent <- character()
  wrong_parent$.actual_parent <- character()
  if (!is.null(parent_col) && "parent_id" %in% names(index)) {
    actual <- trimws(as.character(data[[parent_col]]))
    expected <- rep(NA_character_, nrow(data))
    expected[matched_flag] <- index$parent_id[index_row[matched_flag]]
    wrong_flag <- matched_flag & !is.na(actual) & nzchar(actual) &
      !is.na(expected) & nzchar(expected) & actual != expected
    wrong_parent <- data[wrong_flag, , drop = FALSE]
    wrong_parent$.expected_parent <- expected[wrong_flag]
    wrong_parent$.actual_parent <- actual[wrong_flag]
  }

  out <- list(
    matched = matched,
    unmatched = unmatched,
    ambiguous = ambiguous,
    duplicate = duplicate,
    wrong_parent = wrong_parent,
    summary = list(
      matched = nrow(matched),
      unmatched = nrow(unmatched),
      ambiguous = nrow(ambiguous),
      duplicate = nrow(duplicate),
      wrong_parent = nrow(wrong_parent)
    ),
    key_col = key_col,
    name_col = name_col,
    parent_col = parent_col
  )
  structure(out, class = c("spatial_join_validation", "list"))
}

#' @export
print.spatial_join_validation <- function(x, ...) {
  cat("Spatial join validation\n")
  for (name in c("matched", "unmatched", "ambiguous", "duplicate", "wrong_parent")) {
    cat("  ", gsub("_", " ", name), ": ", x$summary[[name]], "\n", sep = "")
  }
  invisible(x)
}

join_column <- function(data, column, arg, required) {
  if (is.null(column) && !required) return(NULL)
  if (!is.character(column) || length(column) != 1L || is.na(column) ||
      !nzchar(column) || !column %in% names(data)) {
    stop("`", arg, "` must name one column in the supplied data.", call. = FALSE)
  }
  column
}

join_normalize_name <- function(x) {
  out <- tolower(trimws(as.character(x)))
  out[is.na(out)] <- ""
  gsub("[[:space:]]+", " ", out)
}
