# canObsR configuration builder 3.1.0

The 3.1.0 schema provides:

- the canonical `site.csv`, `survey.csv`, `sensor.csv`, `product.csv`, and `crownfile_param.csv` parameter model;
- portable crownfile addressing through the first two `crownfile_param.csv` rows, `path` and `server`;
- a fixed 17-product catalogue and strict cross-file validation;
- generated `crownfile_vars.csv` and controlled reference tables driven by crownfile options;
- empty `config/` initialization followed by progressive validated file creation;
- always-editable Shiny drafts, editable imports, explicit diagnostics displayed before the table, and `Next file` navigation;
- simultaneous published/candidate tables with colour-coded modified cells, deleted rows, and added rows;
- cross-file impact messages shared by Shiny and direct R previews;
- publication archives for prior YAML/check reports and dated before/after modification reports with collision-safe same-day suffixes, raw copyable CSV blocks, and no derived site-HTML entry;
- non-recursive UAV object patterns with validated fixed and captured placeholders;
- a persistent bottom close control for long notifications and a visible work-in-progress indicator while Shiny is busy;
- complete English/French offline guide with language-specific lateral contents;
- explicit, non-blocking handling of optional plot and taxonomic references;
- crownfile validation without any dependency on `vectors.csv`;
- `all_products.csv`, `products_check.txt`, and file-scoped `site_check.txt` reports;
- four identical Shiny and direct-R operations: generate, modify, check, and visualise;
- immediate Shiny navigation updates when survey or crownfile flags activate conditional files;
- automatic server-alias fields in operation 3 and stable YAML round trips for one-column reference tables;
- raw YAML before/after blocks grouped at the end of modification reports;
- automatic normalization of every opened GeoPackage geometry column to `geometry`;
- `PASS WITH WARNINGS`, connected generation/update of `all_products.csv`, and automatic `products_check.txt` output in Shiny operation 3;
- detailed or processed-product/status grouped raw/processed comparisons with filterable tables;
- an exact light-crownfile contract: one `.gpkg` layer named `crowns`, reflected in `crownfile_vars.csv` and all checks;
- omission of absent optional tables from the generated site HTML report;
- an operation 1 product editor limited to products of active surveys while preserving the complete saved catalogue;
- an offline bilingual configuration guide and bilingual site report.

Scientific data are never modified by the builder or its migration diagnostics.
