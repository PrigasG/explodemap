required_packages <- c("explodemap", "sf", "dplyr", "ggplot2", "utils")

missing_packages <- required_packages[!vapply(
  required_packages,
  requireNamespace,
  logical(1),
  quietly = TRUE
)]

if (length(missing_packages) > 0) {
  stop(
    "Install required package(s): ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

library(explodemap)
library(sf)
library(dplyr)
library(ggplot2)

paper_dir <- file.path(getwd(), "paper")
paper_output_dir <- file.path(paper_dir, "outputs")
paper_figure_dir <- file.path(paper_output_dir, "figures")
paper_table_dir <- file.path(paper_output_dir, "tables")
paper_log_dir <- file.path(paper_output_dir, "logs")

dir.create(paper_figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(paper_table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(paper_log_dir, recursive = TRUE, showWarnings = FALSE)

source(file.path(paper_dir, "scripts", "paper_helpers.R"))
source(file.path(paper_dir, "scripts", "state_registry_paper.R"))

write_run_info <- function(script_name) {
  info <- capture.output({
    cat("Script:", script_name, "\n")
    cat("Time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
    cat("R:", paste(R.version$major, R.version$minor, sep = "."), "\n")
    cat("Platform:", R.version$platform, "\n")
    cat("explodemap:", as.character(utils::packageVersion("explodemap")), "\n")
    print(sessionInfo())
  })
  writeLines(info, file.path(paper_log_dir, paste0(script_name, "_session.txt")))
}
