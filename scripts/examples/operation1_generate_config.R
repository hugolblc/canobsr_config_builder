# Operation 1 — Generate the config folder
# =========================================
#
# This script follows the same order as operation 1 in the Shiny application.
# It first creates only config/param, config/reference, and config/path. Each
# entered CSV is then validated and written progressively. Scientific files and
# server roots are not opened during this operation.

source("scripts/load_config_functions.R")

# 0 — Initialize the empty folder tree
# ------------------------------------
parent_directory <- file.path("example_observatory")
dir.create(parent_directory, recursive = TRUE, showWarnings = FALSE)
config_directory <- operation1_generate_config(parent_directory)
before_generation <- capture_config_snapshot(config_directory)

# 1 to 10 — Save user-entered parameter and reference files
# ----------------------------------------------------------
# Put prepared CSV/TSV/XLSX/XLS files in prepared_tables/. The names and order
# below exactly match the application. Conditional files may be absent when
# their controlling option is FALSE.
prepared_directory <- file.path("prepared_tables")
entered_files <- c(
  "param/site.csv" = "site.csv",
  "param/survey.csv" = "survey.csv",
  "param/sensor.csv" = "sensor.csv",
  "param/product.csv" = "product.csv",
  "param/crownfile_param.csv" = "crownfile_param.csv",
  "param/tree_picture_zooms.csv" = "tree_picture_zooms.csv",
  "reference/contributors.csv" = "contributors.csv",
  "reference/plots_list.csv" = "plots_list.csv",
  "param/dawkins_param.csv" = "dawkins_param.csv",
  "reference/taxa_ref.csv" = "taxa_ref.csv"
)

for (relative_path in names(entered_files)) {
  source_file <- file.path(prepared_directory, entered_files[[relative_path]])
  if (!file.exists(source_file)) next
  update_csv_file(
    config_directory, relative_path, source_file,
    update_outputs = FALSE, cross_validate = FALSE
  )
}

# crownfile_param.csv always starts with these two user-filled rows:
#
# param;value
# path;observatories/mbalmayo/crowns.gpkg
# server;work
# crownfile_type;dynamic
# plots_list;FALSE
# taxa_ref;FALSE
# dawkins;FALSE
#
# `path` is relative to the root of the alias in `server`. Absolute workstation
# paths must never be stored in this CSV.
# A light crownfile must still be a .gpkg and must contain exactly one spatial
# layer named `crowns`; generated crownfile_vars.csv then uses layer = crowns.
# In Shiny, product rows belonging to FALSE surveys are hidden during operation
# 1 and restored automatically with status FALSE when product.csv is saved.

# 11 — Generate controlled tables
# --------------------------------
write_generated_tables(config_directory, overwrite = TRUE)

# 12 to 14 — Save path tables
# ----------------------------
# vectors.csv may be empty or filled; its contents are never read.
for (relative_path in c("path/UAV_folder.csv", "path/UAV_file_patterns.csv", "path/vectors.csv")) {
  source_file <- file.path(prepared_directory, basename(relative_path))
  if (!file.exists(source_file)) next
  update_csv_file(
    config_directory, relative_path, source_file,
    update_outputs = FALSE, cross_validate = FALSE
  )
}

# 15 — Validate and publish
# -------------------------
publication <- generate_config_outputs(
  config_directory,
  before_snapshot = before_generation
)
stopifnot(publication$validation$ok)
cat(sprintf("Modification report: %s\n", publication$modification_report))
