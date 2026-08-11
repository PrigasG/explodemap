# Validate an external data-to-spatial join

Reports exact stable-ID matches and separates unmatched, duplicated,
ambiguous-name, and wrong-parent rows. It does not mutate or join the
input; applications remain in control of policy for aliases and
fallbacks.

## Usage

``` r
validate_spatial_join(data, index, key_col, name_col = NULL, parent_col = NULL)
```

## Arguments

- data:

  External data frame to validate.

- index:

  A
  [`spatial_join_index()`](https://prigasg.github.io/explodemap/reference/spatial_join_index.md)
  object.

- key_col:

  Stable identifier column in `data`.

- name_col:

  Optional display-name column in `data`, used only to report ambiguous
  fallback names.

- parent_col:

  Optional parent identifier column in `data`, compared with
  `index$parent_id` for exact key matches.

## Value

A `spatial_join_validation` list containing `matched`, `unmatched`,
`ambiguous`, `duplicate`, `wrong_parent`, and summary counts.
