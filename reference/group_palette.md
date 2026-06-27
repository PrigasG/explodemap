# Create a stable group palette

Create a stable group palette

## Usage

``` r
group_palette(groups, palette = "Dark 3", existing = NULL)
```

## Arguments

- groups:

  Character vector of group names.

- palette:

  Palette name passed to
  [`grDevices::hcl.colors()`](https://rdrr.io/r/grDevices/palettes.html).

- existing:

  Optional named colour vector. Existing assignments are retained and
  colours are generated only for new groups.

## Value

A named character vector of colours.
