candidate_app_directories <- c(
  file.path("scripts", "config_builder_app"),
  file.path("..", "..", "config_builder_app"),
  file.path("..", "config_builder_app")
)

app_directory <- candidate_app_directories[dir.exists(candidate_app_directories)][[1]]
source_order <- c(
  "constants.R", "validation.R", "io.R", "config_access.R",
  "observatory_yaml.R", "product_discovery.R", "change_management.R", "workflow_api.R",
  "workflow_checks.R", "ui_helpers.R"
)
source_files <- file.path(app_directory, "R", source_order)
invisible(lapply(source_files, source, local = FALSE))
