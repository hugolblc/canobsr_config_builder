# canObsR configuration builder

Version **3.1.0** provides a Shiny application and an equivalent R API for creating, modifying, checking, and visualising canObsR observatory configuration folders.

> Project status: operational 3.1.0 handover build. The automated test suite is included, but must be run in an R environment before publishing a release.

## Main workflows

The application and the example scripts expose the same four operations:

1. Generate the config folder.
2. Modify the config folder.
3. Check parameters and data.
4. Visualise parameters and data.

The authoritative user guide is [`docs/configuration_files_guide.html`](docs/configuration_files_guide.html). It works offline, displays English by default, and includes a French-language switch.

## Requirements

- R 4.2 or later;
- the R packages declared in [`scripts/install_dependencies.R`](scripts/install_dependencies.R);
- access to the configured server roots only for operation 3 data checks.

Install the R dependencies from the repository root:

```r
source("scripts/install_dependencies.R")
```

## Run the Shiny application

From the repository root:

```r
source("scripts/run_config_builder.R")
```

Operation 1 only creates and validates configuration files. It does not open scientific data or require access to the configured servers.

## Use the R API

Load the public functions:

```r
source("scripts/load_config_functions.R")
```

The four complete examples are:

- [`operation1_generate_config.R`](scripts/examples/operation1_generate_config.R)
- [`operation2_modify_config.R`](scripts/examples/operation2_modify_config.R)
- [`operation3_check_parameters_and_data.R`](scripts/examples/operation3_check_parameters_and_data.R)
- [`operation4_visualize_parameters_and_data.R`](scripts/examples/operation4_visualize_parameters_and_data.R)

## Important 3.1.0 contracts

- `param/crownfile_param.csv` starts with `path` and `server`. The path is relative to the local root supplied for that server alias.
- A `light` crownfile is a GeoPackage containing exactly one spatial layer named `crowns`.
- Spatial layers are normalised after reading so their active `sf` geometry column is named `geometry`.
- `vectors.csv` may be created, but its contents are not read, validated, exported, or visualised.
- `all_products.csv` and `products_check.txt` are generated during connected product checks, not during the initial configuration-only workflow.
- Optional configuration tables that do not exist are omitted from `{site.name}_observatory_infos.html`.
- Publishing archives previous reports and produces a dated `modification_yyyymmdd[_n].txt` report.

For the complete functional contract, see the user guide and [`RELEASE_3.1.0.md`](RELEASE_3.1.0.md).

## Tests

Run from the repository root:

```r
source("scripts/tests/testthat.R")
```

The current test coverage and the build-environment limitations are documented in [`QA_REPORT.md`](QA_REPORT.md).

## Development and handover

- [`HANDOVER.md`](HANDOVER.md) explains the architecture, invariants, validation flow, known limitations, and recommended next steps.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) defines the contribution and review workflow.
- [`IMPLEMENTATION_CHECKLIST.md`](IMPLEMENTATION_CHECKLIST.md) records the implemented 3.1.0 requirements.

## Licence

This project is distributed under the [GNU General Public License v3.0](LICENSE).
