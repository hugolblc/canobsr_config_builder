required <- c(
  "shiny",
  "bslib",
  "DT",
  "shinyFiles",
  "readr",
  "readxl",
  "sf",
  "yaml",
  "testthat"
)

missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (!length(missing)) {
  message("All required packages are already installed.")
} else {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing)
}
