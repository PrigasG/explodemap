# Plot a grouped_exploded_map object

Plot a grouped_exploded_map object

## Usage

``` r
# S3 method for class 'grouped_exploded_map'
plot(x, which = c("grouped", "original", "local", "all"), ...)
```

## Arguments

- x:

  A `grouped_exploded_map` object

- which:

  "grouped" (default), "original", "local", or "all"

- ...:

  Ignored

## Value

Invisibly returns `x`, the original `grouped_exploded_map` object. The
method is called for its side effect of drawing the stored `ggplot2`
grouped, original, and/or local map objects.
