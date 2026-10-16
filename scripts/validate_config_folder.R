script_file <- function() {
  file_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (!length(file_argument)) {
    stop("Run this validator with Rscript.", call. = FALSE)
  }
  normalizePath(sub("^--file=", "", file_argument[[1]]), winslash = "/")
}

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L) {
  stop(
    "Usage: Rscript scripts/validate_config_folder.R /absolute/path/to/config",
    call. = FALSE
  )
}

config_directory <- normalizePath(arguments[[1]], winslash = "/", mustWork = TRUE)
app_directory <- file.path(dirname(script_file()), "config_builder_app")
source(file.path(app_directory, "R", "constants.R"))
source(file.path(app_directory, "R", "validation.R"))
source(file.path(app_directory, "R", "io.R"))
source(file.path(app_directory, "R", "config_access.R"))
source(file.path(app_directory, "R", "observatory_yaml.R"))
source(file.path(app_directory, "R", "product_discovery.R"))
source(file.path(app_directory, "R", "change_management.R"))
source(file.path(app_directory, "R", "workflow_api.R"))
source(file.path(app_directory, "R", "workflow_checks.R"))

result <- check_config_folder(config_directory, print_report = FALSE)

if (length(result$warnings)) {
  message("Warnings:")
  invisible(lapply(result$warnings, function(item) message("- ", item)))
}

if (!result$ok) {
  message("Errors:")
  invisible(lapply(result$errors, function(item) message("- ", item)))
  quit(status = 1L)
}

derived <- check_observatory_files(config_directory, print_report = FALSE)
if (length(derived$warnings)) {
  message("Configuration is valid, with warning(s):")
  invisible(lapply(derived$warnings, function(item) message("- ", item)))
}
message("All schema 3.1.0 blocking checks passed.")
