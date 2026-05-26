# Journal Submission Checklist

Fill in the items below **before uploading to the journal system**.
Each item has a corresponding tagged comment in `explodemap_paper.tex`
(search for the tag to jump straight to it).

---

## 1. Zenodo DOI  `ZENODO-DOI`

**Status: ✅ DONE — DOI minted: `10.5281/zenodo.20402131`**

Zenodo form fields to fill in (see screenshots for the current form state):

| Field | Value |
|---|---|
| Resource type | Software |
| Title | `explodemap: Hierarchical Exploded-View Cartography` |
| Publication date | `2026-05-26` |
| Author | George Arthur |
| Version | `0.2.0` |
| Description | (see below) |
| License | MIT |
| Repository URL | `https://github.com/PrigasG/explodemap` |
| Programming language | R |
| Keywords | cartography, exploded-view, R package, spatial displacement, administrative maps |
| Development status | Active |

Suggested description for the Zenodo record:
> explodemap is an R package implementing a hierarchical vector-based framework
> for multi-scale exploded-view cartography. It generates spatially separated
> administrative map layouts using centroid-driven displacement fields while
> preserving exact polygon geometry through rigid-body translation. Includes
> formula-derived parameter estimation, documented display-offset support, and
> a three-level multi-scale extension for grouped national layouts.
> Reproducible case studies cover 16 U.S. states, Canada, and Germany.

After pressing **Get a DOI now!** and completing the deposit:

1. Copy the minted DOI, e.g. `10.5281/zenodo.12345678`.
2. In `explodemap_paper.tex`, search for `ZENODO-DOI` — two places to update:
   - The `% ZENODO-DOI:` comment line near the Code Availability section header.
   - Un-comment and update the `\url` line in `\bibitem[Arthur(2026b)]{zenodo_explodemap}`.
3. Restore the full Code Availability sentence (replace the pending-deposit note
   with the full citation sentence referencing the real DOI).
4. Rebuild the PDF (`pdflatex` × 2).

---

## 2. Final commit SHA  `FINAL-SHA`

After the last pre-submission commit:

```bash
git log --oneline -1   # copy the 7-char SHA
```

Replace `FINAL-SHA` comment value in `explodemap_paper.tex` with
the new SHA. Also update the `FINAL-SHA` line in the Code Availability
section if it appears in prose.

Current HEAD before gallery synchronization: `1952569`
Tagged release v0.2.0: `5948bb7`

After the final synchronization commit, update this line and the
`% FINAL-SHA:` comment in `paper/explodemap_paper.tex` to the commit
that contains the final paper and gallery assets.

---

## 3. Journal manuscript number  `SUBMISSION-REF`

Assigned by the journal after initial submission, e.g. `CAGIS-2026-0042`.

1. Add it to the `% SUBMISSION-REF:` comment in `explodemap_paper.tex`.
2. Update the `\bibitem[Arthur(2026a)]{arthur2026paper}` entry to
   reference the journal + manuscript number.

**Target journals (in priority order):**

| Journal | Publisher | Scope fit |
|---------|-----------|-----------|
| Cartography and Geographic Information Science (CaGIS) | Taylor & Francis | Primary — cartographic methods |
| International Journal of Geographical Information Science (IJGIS) | Taylor & Francis | Strong — GIS methods |
| Transactions in GIS | Wiley | Good — applied GIS |
| Journal of Spatial Information Science (JOSIS) | Open access | Open-access option |

---

## 4. Author / affiliation block

The title page currently shows only "George Arthur" with no affiliation
or ORCID. Add before submission:

```latex
\author{George Arthur\thanks{Affiliation. Email: ...}}
```

Or use the journal's author macro. Add ORCID if required.

---

## 5. Acknowledgements

Add a brief acknowledgement section after the Conclusion if the journal
requires one (funding, data sources, reviewers).

---

## 6. Figures — check file names match `\includegraphics`

Run from the `paper/` directory:

```bash
grep -o 'includegraphics.*\.png' explodemap_paper.tex | \
  sed 's/.*{\(.*\)}/\1/' | \
  while read f; do [ -f "outputs/figures/$f" ] || echo "MISSING: $f"; done
```

---

## 7. Final PDF build

```bash
cd paper
pdflatex explodemap_paper.tex
pdflatex explodemap_paper.tex   # second pass for cross-refs
```

Check that:
- Table of contents page numbers are correct
- All `\ref{}` and `\cite{}` resolve (no `??`)
- `XXXXXXX` does not appear in the built PDF
- `[to be assigned]` does not appear in the built PDF

---

## 8. Post-acceptance

- Replace `\textit{Working paper}` in `\bibitem[Arthur(2026a)]` with
  the full journal citation: volume, issue, pages, DOI.
- Update the `\url` in Code Availability to point to the published
  article DOI if the journal provides one.
