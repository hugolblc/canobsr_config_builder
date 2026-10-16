# Implementation checklist — schema 3.1.0

- [x] Canonical config architecture and filenames
- [x] Strict site, survey, sensor, product, crownfile, zoom, and Dawkins schemas
- [x] Conditional references and generated tables
- [x] Cross-file blocking errors and warnings
- [x] `vectors.csv` excluded from reads, checks, YAML, reports, and visualisation
- [x] YAML conditional-section statuses
- [x] File-scoped `site_check.txt`
- [x] `all_products.csv` and `products_check.txt`
- [x] Automatic `products_check.txt`, conditional all-products write button, and `PASS WITH WARNINGS` in operation 3
- [x] GeoPackage `sf` geometry-column normalization to `geometry`
- [x] Exact light-crownfile contract: one `.gpkg` spatial layer named `crowns`
- [x] Detailed and processed-product/status grouped raw/processed comparisons
- [x] Per-column filters in inventory and coverage DataTables
- [x] Four equivalent Shiny and direct-R operations: generate, modify, check, and visualise
- [x] Crownfile path resolved from the ordered `path` and `server` parameters
- [x] One local-root field per automatically detected server alias in Shiny operation 3
- [x] Reactive conditional-file menu after survey and crown-parameter saves
- [x] Operation 1 product editor restricted to products of surveys marked `TRUE`
- [x] Empty folder initialization and progressive file creation
- [x] Always-editable Shiny drafts, editable imports, localized diagnostics, and Next file navigation
- [x] Side-by-side published/candidate comparison with modified, added, and deleted highlighting
- [x] Cross-file consequence panel shared with direct R previews
- [x] Publication archive and dated before/after modification reports with raw CSV blocks, excluded derived HTML, and same-day suffixes
- [x] Raw YAML report blocks grouped after all other modified files
- [x] Stable YAML serialization and comparison for one-column reference tables
- [x] Non-recursive UAV patterns with exact date, fixed, captured, crown, and transformation placeholders
- [x] English-first offline guide with French toggle
- [x] Complete French guide and language-specific lateral contents
- [x] English/French offline site report
- [x] Optional tables omitted from the site HTML report when their files are absent
- [x] Example R scripts and automated schema tests

Scientific data are never modified by configuration generation or migration reporting.
