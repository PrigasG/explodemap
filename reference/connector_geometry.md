# Connector geometry for computed layout movement

Builds one line per moved group, from the original group anchor to the
final group anchor.

## Usage

``` r
connector_geometry(layout, threshold_m = 1, include_unmoved = FALSE)
```

## Arguments

- layout:

  A `grouped_exploded_map`.

- threshold_m:

  Minimum movement distance to mark a connector visible.

- include_unmoved:

  Include zero-distance rows.

## Value

An `sf` line layer with movement attributes.
