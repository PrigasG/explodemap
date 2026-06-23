# Read drag-helper offset CSVs into a region offset data frame

Reads one or more drag-helper offset files and returns a tidy data frame
ready for
[`apply_region_offsets`](https://prigasg.github.io/explodemap/reference/apply_region_offsets.md).
The drag helper tool exports a CSV named `{state}_drag_offsets.csv`
(e.g. `nj_drag_offsets.csv`) with three columns: `region`, `dx_m`, and
`dy_m`. This function provides a convenient way to load that file – by
explicit path, by state abbreviation, or a mix of both – and prints a
compact summary so you can verify the offsets before applying them.

## Usage

``` r
read_drag_offsets(x, dir = ".", quiet = FALSE)
```

## Arguments

- x:

  A character vector of one or more items, each of which is either:

  - a path to a CSV file (e.g. `"outputs/nj_drag_offsets.csv"`), or

  - a US state abbreviation (e.g. `"NJ"` or `"nj"`), which is resolved
    to `{tolower(x)}_drag_offsets.csv` inside `dir`.

- dir:

  Directory to search when an element of `x` is a state abbreviation
  rather than a full path. Defaults to the current working directory.

- quiet:

  Logical; when `FALSE` (default), prints a compact summary of the
  offsets that were read.

## Value

A data frame with columns `region` (character), `dx_m` (numeric), and
`dy_m` (numeric). When multiple files are supplied an additional `state`
column (the lower-case abbreviation or file stem) is prepended and rows
from all files are combined.

## Details

Typical workflow after running the drag helper tool:


    # 1. Compute the exploded layout
    nj <- explode_state("34", crs = 32111, region_map = list(...))

    # 2. Read the offsets exported from the drag helper
    offsets <- read_drag_offsets("NJ", dir = "outputs/drag_helpers")

    # 3. Apply them as a reproducible finishing step
    nj_display <- apply_region_offsets(nj, offsets)

You can also pass the CSV path directly to
[`apply_region_offsets`](https://prigasg.github.io/explodemap/reference/apply_region_offsets.md)
without calling `read_drag_offsets()` first – both accept a file path.
`read_drag_offsets()` is most useful when you want to inspect the
offsets interactively, load multiple state files at once, or resolve
files by abbreviation rather than full path.

## See also

[`apply_region_offsets`](https://prigasg.github.io/explodemap/reference/apply_region_offsets.md)
