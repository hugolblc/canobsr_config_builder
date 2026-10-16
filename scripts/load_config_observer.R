config_observer_source_file <- function() {
  file_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_argument)) {
    return(normalizePath(sub("^--file=", "", file_argument[[1]]), winslash = "/"))
  }

  frame_files <- unlist(lapply(sys.frames(), function(frame) {
    tryCatch(frame$ofile, error = function(error) NULL)
  }), use.names = FALSE)
  frame_files <- frame_files[nzchar(frame_files)]
  if (length(frame_files)) {
    return(normalizePath(frame_files[[length(frame_files)]], winslash = "/"))
  }

  if (interactive() && requireNamespace("rstudioapi", quietly = TRUE) &&
      isTRUE(rstudioapi::isAvailable())) {
    editor_path <- tryCatch(
      rstudioapi::getSourceEditorContext()$path,
      error = function(error) ""
    )
    if (nzchar(editor_path) && file.exists(editor_path)) {
      return(normalizePath(editor_path, winslash = "/", mustWork = TRUE))
    }
  }

  NULL
}

config_observer_scripts_directory <- function() {
  source_file <- config_observer_source_file()
  candidates <- if (is.null(source_file)) character() else dirname(source_file)

  current <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  repeat {
    candidates <- c(candidates, current, file.path(current, "scripts"))
    parent <- dirname(current)
    if (identical(parent, current)) break
    current <- parent
  }
  candidates <- unique(candidates)

  contains_observer <- vapply(candidates, function(directory) {
    file.exists(file.path(directory, "config_builder_app", "R", "config_access.R"))
  }, logical(1))
  if (any(contains_observer)) {
    return(normalizePath(
      candidates[which(contains_observer)[[1]]],
      winslash = "/",
      mustWork = TRUE
    ))
  }

  stop(
    paste(
      "Could not locate scripts/config_builder_app.",
      "Open the bundle root as the R working directory and run",
      "source('scripts/load_config_observer.R')."
    ),
    call. = FALSE
  )
}

required <- c("readr", "readxl", "sf", "yaml")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop(
    sprintf(
      "Missing package(s): %s. Run Rscript scripts/install_dependencies.R first.",
      paste(missing, collapse = ", ")
    ),
    call. = FALSE
  )
}

observer_scripts_directory <- config_observer_scripts_directory()
observer_app_directory <- file.path(observer_scripts_directory, "config_builder_app")
observer_r_directory <- file.path(observer_app_directory, "R")

source_order <- c(
  "constants.R",
  "validation.R",
  "io.R",
  "config_access.R",
  "observatory_yaml.R",
  "product_discovery.R",
  "change_management.R",
  "workflow_api.R",
  "workflow_checks.R",
  "ui_helpers.R"
)
invisible(lapply(
  source_order,
  function(filename) source(file.path(observer_r_directory, filename), local = FALSE)
))

if (interactive()) {
  message(
    paste(
      paste(
        "canObsR 3.1.0 functions are ready:",
        "operation1_generate_config(), operation2_modify_config(),",
        "operation3_check_parameters_and_data(),",
        "operation4_visualize_parameters_and_data(), and observe_config()."
      ),
      "See scripts/examples/ for one script per main operation."
    )
  )
}

invisible(TRUE)
