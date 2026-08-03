# Access geometry from a grouped exploded layout

These accessors expose the stable geometry components of a
`grouped_exploded_map` without requiring applications to inspect the
layout's internal list structure.

## Usage

``` r
original_geometry(layout)

local_geometry(layout)

final_geometry(layout)

group_geometry(layout)
```

## Arguments

- layout:

  A `grouped_exploded_map`.

## Value

An `sf` object.
