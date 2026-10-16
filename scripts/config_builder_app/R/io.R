detect_delimiter <- function(path) {
  header <- readLines(path, n = 1L, warn = FALSE, encoding = "UTF-8")
  if (!length(header)) return(";")
  candidates <- c(";", ",", "\t")
  counts <- vapply(candidates, function(x) lengths(regmatches(header, gregexpr(x, header, fixed = TRUE))), integer(1))
  if (!any(counts > 0L)) ";" else candidates[[which.max(counts)]]
}

read_delimited_table <- function(path) {
  data <- readr::read_delim(
    file = path, delim = detect_delimiter(path),
    col_types = readr::cols(.default = readr::col_character()),
    na = character(), trim_ws = TRUE, show_col_types = FALSE,
    progress = FALSE, name_repair = "minimal"
  )
  as_character_table(data)
}

read_excel_table <- function(path) {
  sheets <- readxl::excel_sheets(path)
  if (!length(sheets)) stop("The workbook contains no worksheet.", call. = FALSE)
  as_character_table(readxl::read_excel(
    path, sheet = sheets[[1]], col_types = "text", na = character(),
    trim_ws = TRUE, .name_repair = "minimal"
  ))
}

read_uploaded_table <- function(path, format = tolower(tools::file_ext(path))) {
  if (format %in% c("csv", "tsv")) return(read_delimited_table(path))
  if (format %in% c("xlsx", "xls")) return(read_excel_table(path))
  stop("Supported table formats are CSV, TSV, XLSX, and XLS.", call. = FALSE)
}

write_semicolon_csv <- function(data, path, diagnostic = NULL) {
  path <- trimws(as.character(path[[1]]))
  if (!nzchar(path)) stop("A destination path is required.", call. = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(dirname(path))) stop(sprintf("Could not create: %s", dirname(path)), call. = FALSE)
  data <- as_character_table(data)
  temporary <- tempfile("canobs-csv-", tmpdir = dirname(path), fileext = ".tmp")
  on.exit(unlink(temporary), add = TRUE)
  readr::write_delim(
    data, file = temporary, delim = ";", na = "", quote = "needed",
    append = FALSE, col_names = TRUE, escape = "double", eol = "\n"
  )
  if (!file.rename(temporary, path)) {
    if (!file.copy(temporary, path, overwrite = TRUE)) stop(sprintf("Could not write: %s", path), call. = FALSE)
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_utf8_text_file <- function(lines, path, diagnostic = NULL, diagnostic_label = "Text file") {
  path <- trimws(as.character(path[[1]]))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile("canobs-text-", tmpdir = dirname(path), fileext = ".tmp")
  on.exit(unlink(temporary), add = TRUE)
  writeLines(enc2utf8(as.character(lines)), temporary, useBytes = TRUE)
  if (!file.rename(temporary, path)) {
    if (!file.copy(temporary, path, overwrite = TRUE)) stop(sprintf("Could not write: %s", path), call. = FALSE)
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

create_config_skeleton <- function(parent_directory) {
  parent_directory <- trimws(as.character(parent_directory[[1]]))
  if (!dir.exists(parent_directory)) stop("Choose an existing parent directory.", call. = FALSE)
  config_directory <- file.path(parent_directory, "config")
  for (directory in file.path(config_directory, c("param", "reference", "path"))) {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(directory)) stop(sprintf("Could not create: %s", directory), call. = FALSE)
  }
  normalizePath(config_directory, winslash = "/", mustWork = TRUE)
}

config_file <- function(config_directory, ...) file.path(config_directory, ...)

load_existing_table <- function(path, fallback) {
  if (!file.exists(path)) return(fallback)
  tryCatch(read_delimited_table(path), error = function(e) fallback)
}

read_config_params <- function(config_directory) {
  path <- file.path(config_directory, "param", "crownfile_param.csv")
  if (!file.exists(path)) return(table_to_named(crownfile_param_template(), "param", "value"))
  table_to_named(read_delimited_table(path), "param", "value")
}

write_generated_tables <- function(config_directory, overwrite = TRUE) {
  parameter_path <- file.path(config_directory, "param", "crownfile_param.csv")
  if (!file.exists(parameter_path)) stop(
    "Step 11 cannot run before param/crownfile_param.csv has been validated and saved.",
    call. = FALSE
  )
  parameter_table <- read_delimited_table(parameter_path)
  parameter_check <- validate_crownfile_param(parameter_table)
  if (!parameter_check$ok) stop(paste(parameter_check$errors, collapse = "\n"), call. = FALSE)
  params <- table_to_named(parameter_check$data, "param", "value")
  crown <- crownfile_vars_template(
    named_value_or(params, "crownfile_type", "dynamic"),
    is_true_value(params, "plots_list"), is_true_value(params, "taxa_ref"), is_true_value(params, "dawkins")
  )
  written <- c(crownfile_vars = write_semicolon_csv(crown, file.path(config_directory, "param", "crownfile_vars.csv")))
  expected <- default_reference_tables(named_value_or(params, "crownfile_type", "dynamic"), is_true_value(params, "dawkins"))
  for (filename in names(expected)) {
    destination <- file.path(config_directory, "reference", filename)
    if (isTRUE(overwrite) || !file.exists(destination)) written[[filename]] <- write_semicolon_csv(expected[[filename]], destination)
  }
  inactive <- setdiff(c("dawkins.csv", "geom_modif.csv", "tree_status.csv"), names(expected))
  for (filename in inactive) {
    destination <- file.path(config_directory, "reference", filename)
    if (file.exists(destination)) {
      archived <- paste0(destination, ".non_activated")
      if (file.exists(archived)) archived <- paste0(archived, ".", format(Sys.time(), "%Y%m%d%H%M%S"))
      file.rename(destination, archived)
    }
  }
  written
}

initialize_config_templates <- function(config_directory, overwrite = FALSE) {
  templates <- list(
    "param/site.csv" = site_template(),
    "param/survey.csv" = survey_template(),
    "param/sensor.csv" = sensor_template(),
    "param/product.csv" = product_template(),
    "param/crownfile_param.csv" = crownfile_param_template(),
    "reference/contributors.csv" = contributors_template(),
    "path/UAV_folder.csv" = uav_folder_template(),
    "path/UAV_file_patterns.csv" = uav_file_patterns_template(),
    "path/vectors.csv" = vectors_template()
  )
  written <- character()
  for (relative in names(templates)) {
    destination <- file.path(config_directory, relative)
    if (isTRUE(overwrite) || !file.exists(destination)) written[[relative]] <- write_semicolon_csv(templates[[relative]], destination)
  }
  written
}

write_site_table <- function(data, config_directory) {
  result <- validate_site(data)
  if (!result$ok) return(result)
  result$path <- write_semicolon_csv(result$data, file.path(config_directory, "param", "site.csv"))
  result
}

config_report_filename <- function(site_name) {
  value <- gsub("['’]", "", as.character(site_name[[1]]))
  value <- gsub("[[:space:]]+", "_", trimws(value))
  paste0(value, "_observatory_infos.html")
}
