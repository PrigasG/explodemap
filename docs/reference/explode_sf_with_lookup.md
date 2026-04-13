# Explode any sf object using an external lookup table

Joins the lookup to `sf_obj` before exploding. Unmatched units are
labelled "Other".

## Usage

``` r
explode_sf_with_lookup(
  sf_obj,
  join_col,
  lookup,
  lookup_key = join_col,
  region_col = "region",
  ...
)
```

## Arguments

- sf_obj:

  Projected sf object

- join_col:

  Column in sf_obj to join on

- lookup:

  data.frame with join key and region column

- lookup_key:

  Column name in lookup matching join_col

- region_col:

  Column name in lookup containing region labels

- ...:

  Passed to
  [`explode_sf()`](https://prigasg.github.io/explodemap/reference/explode_sf.md)

## Value

An `exploded_map` S3 object
