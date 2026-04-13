# Build mapshaper CLI arguments

Build mapshaper CLI arguments

## Usage

``` r
.build_mapshaper_args(input, output, simplify = NULL)
```

## Arguments

- input:

  Path to input GeoJSON file

- output:

  Path to output TopoJSON file

- simplify:

  Optional simplification proportion in `(0, 1)`.

## Value

Character vector of arguments for system2()
