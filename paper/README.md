# explodemap papers

This directory is for the working papers and mathematical companions for
the `explodemap` package.

Current manuscripts:

- `explodemap_paper.tex`: the main paper for the static exploded-view
  cartographic displacement method.
- `math_companion.tex`: detailed proofs and derivations for the
  exploded-view method.
- `focus_map_paper.tex`: a separate draft for the `focus_map()`
  interaction model, covering screen-space selected-feature focusing,
  label visibility, non-blocking information cards, and Shiny/htmlwidgets
  implementation.

The directory is intentionally excluded from `R CMD build` via
`.Rbuildignore`, so the manuscript can live in the source repository
without increasing the CRAN package bundle size. Package users should
learn the methods from the vignettes and help pages; the full papers are
for review, citation, and deeper methodological context.
