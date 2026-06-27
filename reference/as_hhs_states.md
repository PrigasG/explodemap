# Standardize state polygons for HHS reference maps

Adds `hhs_region`, `state_label`, and `state_geoid` columns to state or
territory polygons and transforms long-lat data to a projected CRS.

## Usage

``` r
as_hhs_states(states, crs = 5070)
```

## Arguments

- states:

  An `sf` object with either `hhs_region`, `region`, `STUSPS`, or `NAME`
  columns.

- crs:

  Target projected CRS used when `states` is long-lat. Default is
  EPSG:5070.

## Value

An `sf` object filtered to HHS-assigned states and territories.
