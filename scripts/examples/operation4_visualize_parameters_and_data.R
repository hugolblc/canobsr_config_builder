# Operation 4 — Visualise parameters and data
# ===========================================

source("scripts/load_config_functions.R")

config_directory <- file.path("example_observatory", "config")

# Return every available section, as in the operation 4 selector in Shiny.
views <- operation4_visualize_parameters_and_data(config_directory)
views$site
views$survey
views$product

# Read one section, or render one table interactively in RStudio. Tables made
# with as_datatable = TRUE include a filter field above every column.
sensors <- observe_config(config_directory, "sensor")
inventory <- observe_config(config_directory, "all_products", as_datatable = TRUE)
inventory

# Detailed coverage: one row per survey, date, and processed product.
coverage_details <- compare_raw_processed(
  config_directory,
  group_by_processed_status = FALSE,
  as_datatable = TRUE
)
coverage_details

# Grouped coverage: sums raw_count and processed_count for each
# processed_product/status combination. Status values are completed,
# missing_processed, and processed_without_raw.
coverage_by_product_status <- compare_raw_processed(
  config_directory,
  group_by_processed_status = TRUE,
  as_datatable = TRUE
)
coverage_by_product_status
