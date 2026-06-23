---
title: explodemap gallery
emoji: 🗺️
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
license: mit
---

# explodemap gallery

An interactive gallery for the [**explodemap**](https://github.com/PrigasG/explodemap)
R package — hierarchical *exploded-view* cartography. Click any area to lift and
zoom it; right-click or press <kbd>Esc</kbd> to reset.

## Tabs

| Tab | What it shows |
| --- | --- |
| **Counties** | `focus_map()` on a state's counties, raw or exploded by quadrant. |
| **Municipalities** | County subdivisions, with the small-area `"municipal"` preset. |
| **Drill-down** | `explode_section()` — explode one region, fade the rest as context. |
| **National (HHS)** | `explode_grouped()` across all states grouped into 10 HHS regions. |
| **Parameter lab** | Manual `alpha_r` / `alpha_l` tuning on a synthetic dataset. |

## How it runs

Census boundary data (5 demo states + the national layer) is **baked into the
Docker image at build time** by [`prep_data.R`](./prep_data.R). The running
container makes **no network calls** — cold start is instant and reproducible.

## Run locally

```r
# from the repo root, with explodemap + bslib + tigris installed
shiny::runApp("inst/huggingface")
```

On first run the app will bake the data into `inst/huggingface/data/` (requires
`tigris` + internet, once). After that it loads straight from `.rds`.

## Build the Docker image

```bash
# build context is this directory
docker build -t explodemap-gallery inst/huggingface
docker run --rm -p 7860:7860 explodemap-gallery
# open http://localhost:7860
```

To deploy local (uncommitted) package changes instead of the GitHub release,
switch the Dockerfile to the "COPY local source" block (and build from the repo
root so the package source is in the build context).

## Deploy to Hugging Face

1. Create a new **Docker** Space.
2. Copy `app.R`, `prep_data.R`, `Dockerfile`, and this `README.md` into it
   (the YAML front-matter above is what HF reads — keep `app_port: 7860`).
3. Push. HF builds the image, bakes the data, and serves the app.
