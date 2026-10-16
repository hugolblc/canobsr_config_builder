script_file <- function() {
  file_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_argument)) {
    return(normalizePath(sub("^--file=", "", file_argument[[1]]), winslash = "/"))
  }

  frame_file <- tryCatch(sys.frame(1)$ofile, error = function(error) NULL)
  if (!is.null(frame_file)) {
    return(normalizePath(frame_file, winslash = "/"))
  }

  stop("Could not determine the script location. Run this file with Rscript.", call. = FALSE)
}

required <- c("shiny", "bslib", "DT", "shinyFiles", "readr", "readxl", "sf", "yaml")
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

app_directory <- file.path(dirname(script_file()), "config_builder_app")
shiny::runApp(app_directory, launch.browser = TRUE)
