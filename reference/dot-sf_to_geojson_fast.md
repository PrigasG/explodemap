# Fast bulk GeoJSON via a single sf::st_write call

Writes the whole sf to a temp GeoJSON file and passes the raw JSON
string to the widget. The JS side does `JSON.parse()`, which avoids the
`fromJSON → R list → toJSON` round-trip that can mangle deeply nested
coordinate arrays.

## Usage

``` r
.sf_to_geojson_fast(
  sf_obj,
  label_col,
  id_col = NULL,
  group_col = NULL,
  info_cols = NULL,
  info_title = label_col
)
```
