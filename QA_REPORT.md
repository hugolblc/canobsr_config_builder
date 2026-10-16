# Quality-assurance report — schema 3.1.0

## Completed in the build environment

- R-source delimiter and string-balance audit: PASS
- Cross-file contract audit (15 schema invariants): PASS
- Guide HTML DOM parse: PASS
- Guide structure (20 sections per language; 40 valid lateral links): PASS
- English/French page visibility and toggle-state audit: PASS
- Workflow numbering 1–15 aligned between the guide and Shiny: PASS
- Four-operation API, Shiny, and example-script alignment audit: PASS
- Crownfile `server`/relative-`path` contract source audit: PASS
- Light GeoPackage single-`crowns`-layer contract and generated-schema audit: PASS
- Empty-initialization and progressive-write source audit: PASS
- Always-editable draft/import and localized-validation source audit: PASS
- Side-by-side baseline/candidate table and colour-class source audit: PASS
- Shared comparison and cross-file impact API audit: PASS
- Publication archive naming, same-day suffix, and modification-report source audit: PASS
- Raw CSV report-block and derived-site-HTML exclusion source audit: PASS
- YAML-last raw report-block source audit: PASS
- One-column YAML round-trip and legacy-normalization source audit: PASS
- Conditional-step reactive-refresh source audit: PASS
- Active-survey product-editor filtering and canonical-save restoration audit: PASS
- Automatic server-alias field source audit: PASS
- Generated-table transition rendering and atomic-result handling audit: PASS
- Diagnostic placement, scrollable notification, bottom close control, and busy-state source audit: PASS
- UAV non-recursive pattern and placeholder-contract audit: PASS
- GeoPackage geometry-column normalization source audit: PASS
- Operation 3 PASS WITH WARNINGS, product-report, inventory-write, and comparison controls audit: PASS
- Optional-table omission from the site HTML report source audit: PASS
- Filterable inventory and raw/processed example-table audit: PASS
- UTF-8 text-file audit: PASS
- Deprecated user-facing terminology scan: PASS

## Runtime test suite

The bundle includes `scripts/tests/testthat/test-schema-v3.1.0.R`, covering empty initialization, progressive table saving, localized site diagnostics, strict schemas, sensor overlaps, active-survey product filtering with canonical-file restoration, product dependencies, conditional crown variables, the exact single-layer `crowns` light GeoPackage contract, zoom rules, non-recursive UAV patterns (including the complete documented 11-row file), generated references, ignored vectors content, YAML conditional sections, optional-table omission from the site HTML report, taxonomic-reference behavior, crownfile warning severities, GeoPackage geometry-column normalization, `PASS WITH WARNINGS`, product-report/inventory writes, grouped raw/processed comparisons, `site_check.txt` grouping, table-level modified/added/deleted detection, dependency-impact messages, publication archives, before/after reports, and repeated same-day publication suffixes.

The build container does not provide an R runtime, so the included `testthat` suite could not be executed there. Run it in the target R environment with:

```r
source("scripts/tests/testthat.R")
```
