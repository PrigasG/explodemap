# Clear explodemap download cache

Clear explodemap download cache

## Usage

``` r
cache_clear(key = NULL)
```

## Arguments

- key:

  Specific cache key to clear, or NULL to clear all

## Value

Invisibly returns `NULL`. The function is called for its side effect of
deleting cached `.rds` files and reporting what was removed.
