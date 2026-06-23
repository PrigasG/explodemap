# Launch the explodemap demo gallery.
#
# The gallery is a self-contained bslib Shiny app that runs from pre-baked
# Census data (no runtime network calls). Its canonical source — together with
# the data-prep script and a Dockerfile for Hugging Face hosting — lives in
# inst/huggingface/.
#
# On first run the app bakes the boundary data into inst/huggingface/data/
# (requires `tigris` + internet, once); after that it loads straight from .rds.
#
# Requires: shiny, bslib, sf, dplyr, tigris (first run only), explodemap.

gallery_dir <- system.file("huggingface", package = "explodemap")
if (!nzchar(gallery_dir)) {
  # Not installed as a package — fall back to the source tree.
  gallery_dir <- file.path("inst", "huggingface")
}

shiny::runApp(gallery_dir)
