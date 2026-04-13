# Format a distance in metres as a human-readable km string

Adapts precision to magnitude: "23.6 km" for large values, "0.067 km"
for small ones, so tiny test geometries don't show "0 km".

## Usage

``` r
fmt_dist(x_m)
```

## Arguments

- x_m:

  Distance in metres

## Value

Character string
