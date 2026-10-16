config_functions_loader_file <- function() {
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

  NULL
}

loader_file <- config_functions_loader_file()
loader_candidates <- unique(c(
  if (is.null(loader_file)) character() else dirname(loader_file),
  file.path(getwd(), "scripts"),
  getwd()
))
observer_loader <- file.path(loader_candidates, "load_config_observer.R")
observer_loader <- observer_loader[file.exists(observer_loader)]
if (!length(observer_loader)) {
  stop(
    paste(
      "Could not locate scripts/load_config_observer.R.",
      "Open the bundle root as the R working directory and run",
      "source('scripts/load_config_functions.R')."
    ),
    call. = FALSE
  )
}

source(observer_loader[[1]], local = FALSE)
invisible(TRUE)
