# Lay out child geography around a parent

Computes a renderer-neutral child expansion in metres. Child features
move radially away from the parent anchor, then a bounded axis-aligned
bounding-box or circle solver separates collisions while an attraction
term and bearing guard preserve the source geography's mental map. The
returned base offsets are algorithmic movement; manual/editorial
movement belongs in a `dragmapr_state` and can be composed downstream.

## Usage

``` r
layout_children(
  x,
  id_col,
  parent = NULL,
  parent_geometry = NULL,
  scale = 1.6,
  radial_kick = NULL,
  gap = NULL,
  collision = c("bbox", "circle"),
  attraction = 0.08,
  max_bearing_drift = 0.22,
  bounds = NULL,
  max_iter = 180L
)
```

## Arguments

- x:

  Projected polygon `sf` object containing child features.

- id_col:

  Stable unique feature identifier column.

- parent:

  Optional single parent identifier recorded in the output.

- parent_geometry:

  Optional parent `sf`, `sfc`, or `sfg` geometry whose representative
  point anchors the expansion. Defaults to the union of `x`.

- scale:

  Radial expansion multiplier applied to source vectors.

- radial_kick:

  Additional outward movement in metres. Defaults to two percent of the
  child layer's bounding-box diagonal.

- gap:

  Minimum separation in metres. Defaults to one percent of the child
  layer's bounding-box diagonal.

- collision:

  Collision approximation: feature bounding boxes or centroid circles
  derived from those boxes.

- attraction:

  Fraction of the remaining distance to the geographic target applied
  during each refinement iteration.

- max_bearing_drift:

  Maximum angular drift from the source bearing, in radians.

- bounds:

  Optional bounding box supplied as an `sf`/`sfc` object, `st_bbox`, or
  numeric `c(xmin, ymin, xmax, ymax)`.

- max_iter:

  Maximum collision-refinement iterations. Each iteration scans all
  feature pairs, so cost grows quadratically with the number of
  features: for large `x`, lower this (the iteration cap is also reduced
  automatically above 2,000 features) or lay out a subset of children.

## Value

An `explodemap_child_layout` with `offsets`, composed `geometry`, source
geometry, diagnostics, and parameters. `offsets` contains stable IDs,
source/final anchors, base offsets, distance, bearing, bearing drift,
and residual collision counts.
