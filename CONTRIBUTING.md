# Contributing

Thank you for helping maintain the canObsR configuration builder.

## Before changing code

1. Read `HANDOVER.md` and the user guide.
2. Check `IMPLEMENTATION_CHECKLIST.md` and `QA_REPORT.md`.
3. Open or reference a GitHub issue describing the expected behaviour, affected files, and acceptance criteria.
4. Create a short-lived branch from `main`.

Suggested branch names are `fix/short-description`, `feature/short-description`, `docs/short-description`, and `test/short-description`.

## Implementation rules

- Keep business rules in the shared R modules; Shiny and the direct-R examples must use the same functions.
- Preserve semicolon-delimited UTF-8 CSV output.
- Never modify scientific data during configuration generation, validation, reporting, or visualisation.
- Keep `vectors.csv` independent from validation and downstream outputs.
- Normalise `sf` geometry columns through `normalize_sf_geometry_column()` after reading spatial layers.
- Update the guide generator rather than editing only the generated HTML.
- Do not commit real observatory data, server paths, credentials, generated `config/` folders, GeoPackages, or local reports.

## Tests and documentation

Every functional change should include a regression test, an update to the relevant example script, and an update to the guide generator when the user-facing contract changes.

Run:

```r
source("scripts/install_dependencies.R")
source("scripts/tests/testthat.R")
```

For interface changes, also run `source("scripts/run_config_builder.R")` and exercise the affected workflow manually.

## Pull requests

A pull request should state the problem and expected outcome, affected configuration files and operations, test environment and results, documentation changes, and compatibility or migration impact.

Keep pull requests focused. At least one reviewer should verify that Shiny and direct-R behaviour remain equivalent before merging.
