make_dragmapr_state <- function(...) {
  exports <- getNamespaceExports("dragmapr")
  constructor <- if ("d_state" %in% exports) "d_state" else "dragmapr_state"
  getExportedValue("dragmapr", constructor)(...)
}
