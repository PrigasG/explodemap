## Test environments

* Local Windows 11 x64, R 4.5.1

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes

The sole exported function beginning with the redundant `explodemap_` prefix,
`explodemap_fingerprint()`, was renamed to `e_fingerprint()`. The old name is
no longer exported; object classes and persisted values are unchanged. Package
code, Pipeline Studio, examples, tests, reference indexes, and documentation
use the new name.

This release adds projected child-layout and renderer-neutral offset contracts,
real post-drag layout diagnostics, generic stable-ID join diagnostics, and RNG-
neutral deterministic spatial grouping. Bloom-specific CSV parsing,
jurisdiction registries, lazy boundary loading, thematic classification, and UI
orchestration remain outside the package.

The bundled Pipeline Studio was also reviewed after dependency updates. Its
deferred Shiny work is reactive-safe and single-flight, and label-aware search
falls back to the standard layout above 1,000 features or 50 parent groups.
All dragmapr integration points now use dragmapr's renamed `d_*` public API;
the persisted `dragmapr_state` class contract is unchanged.

The package includes optional examples that download public boundary data
from U.S. Census TIGER/Line services or via `tigris`. CRAN-running examples
and vignettes avoid live downloads; longer examples are installed under
`inst/examples/` or marked `eval = FALSE`.

TopoJSON export uses the optional external `mapshaper` command-line tool.
The package checks for this tool at runtime and reports a clear error if it
is unavailable.
