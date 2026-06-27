# Build an HHS reference layout

Build an HHS reference layout

## Usage

``` r
hhs_layout(
  states,
  apply_offsets = TRUE,
  offsets = hhs_display_offsets(),
  source = "user data"
)
```

## Arguments

- states:

  An `sf` object of state or territory polygons.

- apply_offsets:

  Logical. Apply the documented gallery display offsets?

- offsets:

  Offset data frame, usually from
  [`hhs_display_offsets()`](https://prigasg.github.io/explodemap/reference/hhs_display_offsets.md).

- source:

  Optional source label stored in the returned list.

## Value

A list with `states`, `labels`, and `source`.
