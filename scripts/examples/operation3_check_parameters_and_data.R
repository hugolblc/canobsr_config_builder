# Operation 3 — Check parameters and data
# =======================================

source("scripts/load_config_functions.R")

config_directory <- file.path("example_observatory", "config")

# Local server roots are never written to config/. The `server` value in
# crownfile_param.csv selects one alias; its `path` value is appended below it.
server_roots <- c(
  work = file.path("mounted_servers", "work"),
  safe = file.path("mounted_servers", "safe")
)

result <- operation3_check_parameters_and_data(
  config_directory = config_directory,
  server_roots = server_roots,
  check_rgb_dates = TRUE
)
stopifnot(result$ok)

# Operation 3 writes products_check.txt even when non-blocking warnings are
# reported. Reuse its checked in-memory inventory instead of scanning twice.
products_check <- result$details$products
stopifnot(file.exists(products_check$products_check_path))

# Generate or update all_products.csv only after the full operation has passed.
all_products_path <- write_all_products_csv(products_check)

# The same inventory can be compared without reading all_products.csv again.
raw_processed_details <- compare_raw_processed(
  products = products_check$current_inventory,
  group_by_processed_status = FALSE
)
raw_processed_summary <- compare_raw_processed(
  products = products_check$current_inventory,
  group_by_processed_status = TRUE
)

raw_processed_details
raw_processed_summary
