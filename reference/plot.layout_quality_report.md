# Plot a grouped-layout diagnostic

Renders the region anchors as block circles inside the layout's canvas
frame, so unused space is visible as the gap between the blocks and the
frame, and draws a red segment between every overlapping region pair.
The subtitle summarises overlaps, label overlaps, and canvas
utilization.

## Usage

``` r
# S3 method for class 'layout_quality_report'
plot(x, ...)
```

## Arguments

- x:

  A `layout_quality_report` from
  [`diagnose_layout()`](https://prigasg.github.io/explodemap/reference/diagnose_layout.md).

- ...:

  Unused.

## Value

A `ggplot` object.
