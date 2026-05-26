# Validate inputs before explosion

Checks CRS, empty geometries, invalid geometries, region count, and
unmatched "Other" units. Optionally repairs invalid geometries.

## Usage

``` r
validate_input(sf_obj, region_col, allow_other = FALSE, fix_invalid = TRUE)
```

## Arguments

- sf_obj:

  sf object to validate

- region_col:

  Name of the grouping column

- allow_other:

  If TRUE, permits units labelled "Other"

- fix_invalid:

  If TRUE, attempts st_make_valid() on invalid geometries

## Value

The (possibly repaired) sf object, invisibly
