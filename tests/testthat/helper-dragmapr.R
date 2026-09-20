make_dragmapr_state <- function(...) {
  exports <- getNamespaceExports("dragmapr")
  constructor <- if ("d_state" %in% exports) {
    "d_state"
  } else if ("dragmapr_state" %in% exports) {
    "dragmapr_state"
  } else {
    # Installed dragmapr predates any state constructor (e.g. CRAN 0.2.0):
    # skip instead of erroring so the suite stays green on old versions.
    testthat::skip("installed dragmapr has no state constructor")
  }
  getExportedValue("dragmapr", constructor)(...)
}
