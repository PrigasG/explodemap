## Test environments

* Local Windows 11 x64, R 4.5.1

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes

The package includes optional examples that download public boundary data
from U.S. Census TIGER/Line services or via `tigris`. CRAN-running examples
and vignettes avoid live downloads; longer examples are installed under
`inst/examples/` or marked `eval = FALSE`.

TopoJSON export uses the optional external `mapshaper` command-line tool.
The package checks for this tool at runtime and reports a clear error if it
is unavailable.
