# Operation 2 — Modify the config folder
# =======================================
#
# This deliberately detailed script mirrors the Shiny comparison workflow.
# `operation2_modify_config()` loads an existing configuration and captures its
# published state before the first edit. Keep `before_snapshot` unchanged until
# final publication: it is the source of every BEFORE block in the dated report.

source("scripts/load_config_functions.R")

config_directory <- file.path("example_observatory", "config")
modification <- operation2_modify_config(config_directory)
config_directory <- modification$config_directory
before_snapshot <- modification$before_snapshot

# Reusable review-and-save pattern
# --------------------------------
# The preview returns old/new tables, modified cells, added/deleted rows, and
# downstream consequences. The save call refuses to write blocking errors.
review_and_save <- function(relative_path, candidate) {
  preview <- preview_config_table_change(
    config_directory, relative_path, candidate,
    before_snapshot = before_snapshot
  )
  print(preview$impacts)
  saved <- save_config_table(
    config_directory, relative_path, candidate,
    update_outputs = FALSE, cross_validate = FALSE,
    print_report = TRUE
  )
  stopifnot(saved$validation$ok)
  invisible(saved)
}

# Change the crownfile address
# ----------------------------
# `server` is a portable alias supplied again as a local root in operation 3.
# `path` is the crownfile location below that root. It must remain relative.
# crown <- read_delimited_table(file.path(config_directory, "param", "crownfile_param.csv"))
# crown$value[crown$param == "server"] <- "work"
# crown$value[crown$param == "path"] <- "observatories/mbalmayo/crowns.gpkg"
# review_and_save("param/crownfile_param.csv", crown)

# Activate a survey
# -----------------
# The survey catalogue is fixed. Activating MS, DLS, RGB, or tree_pictures can
# require matching sensors, products, folders, patterns, and—for tree pictures—
# zoom rows. The impact preview lists these dependencies before anything is
# published.
# surveys <- read_delimited_table(file.path(config_directory, "param", "survey.csv"))
# surveys$status[surveys$survey == "MS"] <- "TRUE"
# review_and_save("param/survey.csv", surveys)

# Add a drone or sensor period
# ----------------------------
# Dates use yyyymmdd. Periods are inclusive and must not overlap for a survey.
# A current sensor uses status `active` and an empty end_date; a historical
# period uses `not active` and a filled end_date.
# sensors <- read_delimited_table(file.path(config_directory, "param", "sensor.csv"))
# sensors <- rbind(sensors, data.frame(
#   sensor = "Mavic3E", survey = "RGB", start_date = "20260829",
#   end_date = "", status = "active", stringsAsFactors = FALSE
# ))
# review_and_save("param/sensor.csv", sensors)

# Change the crownfile format
# ---------------------------
# `dynamic` generates geom_modif.csv and tree_status.csv and expects geometry
# and infos layers. `light` removes those conditional tables and requires one
# and only one GeoPackage layer named `crowns`.
# UAV crown placeholders must match the resulting crownfile_vars.csv schema.
# crown$value[crown$param == "crownfile_type"] <- "light"
# review_and_save("param/crownfile_param.csv", crown)

# Activate plots_list
# -------------------
# TRUE requires reference/plots_list.csv and adds plot_name to the generated
# crownfile_vars.csv. Missing crown correspondences remain warnings.
# crown$value[crown$param == "plots_list"] <- "TRUE"
# review_and_save("param/crownfile_param.csv", crown)
# plots <- data.frame(plot_name = c("P01", "P02"), stringsAsFactors = FALSE)
# review_and_save("reference/plots_list.csv", plots)

# Activate a Dawkins table
# ------------------------
# TRUE requires param/dawkins_param.csv, generates reference/dawkins.csv, and
# adds dawkins_code to crownfile_vars.csv. Fill the parameter table before final
# publication so its validation and crown reference are synchronized.
# crown$value[crown$param == "dawkins"] <- "TRUE"
# review_and_save("param/crownfile_param.csv", crown)
# dawkins_parameters <- dawkins_param_template()
# review_and_save("param/dawkins_param.csv", dawkins_parameters)

# Import any replacement file
# ---------------------------
# This uses the same reader and validator as an upload in Shiny. The candidate
# remains reviewable before save.
# replacement <- read_replacement_config_table(file.path("prepared_tables", "product.csv"))
# review_and_save("param/product.csv", replacement)

# Validate, archive, and publish all changes
# ------------------------------------------
# Controlled tables, observatory.yaml, site_check.txt, and the derived site HTML
# are regenerated. The site HTML is intentionally absent from the modification
# report. CSV BEFORE/AFTER blocks are written raw so they can be copied directly.
publication <- generate_config_outputs(
  config_directory,
  before_snapshot = before_snapshot
)
stopifnot(publication$validation$ok)
cat(sprintf("Modification report: %s\n", publication$modification_report))
cat(sprintf("Archive directory: %s\n", publication$archive$archive_directory))
