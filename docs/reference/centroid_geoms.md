# Compute centroids without attribute warnings

Wraps sf::st_centroid / sf::st_point_on_surface, operating on
st_geometry() rather than the full sf object. Returns an sfc column.

## Usage

``` r
centroid_geoms(x, centroid_fun = c("centroid", "point_on_surface"))
```

## Arguments

- x:

  An sf or sfc object

- centroid_fun:

  "centroid" (default) or "point_on_surface"

## Value

sfc geometry column of point centroids
