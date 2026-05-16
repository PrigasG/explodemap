# Focus-map option presets

Returns a named list of
[`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
arguments for common interactive mapping workflows. Presets are
intentionally plain lists so they can be inspected, modified, or passed
through [`do.call()`](https://rdrr.io/r/base/do.call.html).

## Usage

``` r
focus_map_preset(
  name = c("municipal", "drilldown", "municipal_drilldown", "none")
)
```

## Arguments

- name:

  Preset name. `"municipal"` tunes small-area focus maps with adaptive
  sizing, source cues, drag zoom, and dense-layer performance.
  `"drilldown"` tunes selected-section maps with faded context and
  source cues. `"municipal_drilldown"` combines both.

## Value

A named list of
[`focus_map()`](https://prigasg.github.io/explodemap/reference/focus_map.md)
arguments.

## Examples

``` r
focus_map_preset("municipal")
#> $focus_size
#> [1] 0.78
#> 
#> $focus_padding
#> [1] 44
#> 
#> $min_focus_width
#> [1] 260
#> 
#> $min_focus_height
#> [1] 200
#> 
#> $tiny_feature_threshold
#> [1] 64
#> 
#> $tiny_feature_boost
#> [1] 1.35
#> 
#> $max_zoom
#> [1] 40
#> 
#> $origin_context
#> [1] "both"
#> 
#> $origin_context_position
#> [1] "top-left"
#> 
#> $focus_context_opacity
#> [1] 0.14
#> 
#> $show_drag_zoom
#> [1] TRUE
#> 
#> $performance_mode
#> [1] TRUE
#> 
if (FALSE) { # \dontrun{
args <- c(
  list(x = exploded_municipalities, label_col = "NAME"),
  focus_map_preset("municipal")
)
do.call(focus_map, args)
} # }
```
