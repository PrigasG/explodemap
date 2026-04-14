# Derive displacement parameters from geometry statistics

Implements Analytical Results 1 and 2 from the paper: alpha_r = gamma_r
\* w_bar / (2 \* sin(pi / n_regions)) alpha_l = gamma_l \* 2 \* R_local
/ sqrt(n_bar)

## Usage

``` r
derive_params(stats, gamma_r = 3, gamma_l = 1.136, p = 1.25)
```

## Arguments

- stats:

  Output of
  [`compute_stats()`](https://prigasg.github.io/explodemap/reference/compute_stats.md)

- gamma_r:

  Regional clearance coefficient (default 3.0)

- gamma_l:

  Local clearance coefficient (default 1.136)

- p:

  Distance scaling exponent (default 1.25)

## Value

Named list with alpha_r, alpha_l, p, gamma_r, gamma_l
