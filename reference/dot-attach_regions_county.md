# Assign regions to county-level sf data

Two modes:

- Named `region_map` (list of region -\> county names): explicit
  assignment

- `region_map = NULL`: automatic k-means clustering on projected
  centroids

## Usage

``` r
.attach_regions_county(
  sf_obj,
  n_regions = NULL,
  region_map = NULL,
  quiet = FALSE
)
```

## Arguments

- sf_obj:

  Projected sf object with county polygons

- n_regions:

  Number of k-means regions (used only when region_map is NULL)

- region_map:

  Named list mapping region labels to county NAME vectors, or NULL

- quiet:

  Suppress messages

## Value

sf_obj with a `region` column added
