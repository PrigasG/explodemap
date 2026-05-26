# Plot an exploded_map object

Plot an exploded_map object

## Usage

``` r
# S3 method for class 'exploded_map'
plot(x, which = c("exploded", "original", "both"), ...)
```

## Arguments

- x:

  An `exploded_map` object

- which:

  "exploded" (default), "original", or "both"

- ...:

  Ignored

## Value

Invisibly returns `x`, the original `exploded_map` object. The method is
called for its side effect of drawing the stored `ggplot2` original
and/or exploded map objects.
