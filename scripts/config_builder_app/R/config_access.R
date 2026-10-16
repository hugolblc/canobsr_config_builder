CANOBS_CONFIG_DATA_TYPES <- c(
  "schema_version", "date_format", "site", "survey", "sensor", "product",
  "crownfile_param", "crownfile_vars", "tree_picture_zooms", "dawkins_param",
  "contributors", "plots_list", "taxa_ref", "dawkins", "dbh_types",
  "geom_modif", "lianas", "tree_status", "type_obs", "UAV_folder",
  "UAV_file_patterns", "all_products", "products_check", "site_check"
)

config_data_type_paths <- function() {
  c(
    site = file.path("param", "site.csv"),
    survey = file.path("param", "survey.csv"),
    sensor = file.path("param", "sensor.csv"),
    product = file.path("param", "product.csv"),
    crownfile_param = file.path("param", "crownfile_param.csv"),
    crownfile_vars = file.path("param", "crownfile_vars.csv"),
    tree_picture_zooms = file.path("param", "tree_picture_zooms.csv"),
    dawkins_param = file.path("param", "dawkins_param.csv"),
    contributors = file.path("reference", "contributors.csv"),
    plots_list = file.path("reference", "plots_list.csv"),
    taxa_ref = file.path("reference", "taxa_ref.csv"),
    dawkins = file.path("reference", "dawkins.csv"),
    dbh_types = file.path("reference", "dbh_types.csv"),
    geom_modif = file.path("reference", "geom_modif.csv"),
    lianas = file.path("reference", "lianas.csv"),
    tree_status = file.path("reference", "tree_status.csv"),
    type_obs = file.path("reference", "type_obs.csv"),
    UAV_folder = file.path("path", "UAV_folder.csv"),
    UAV_file_patterns = file.path("path", "UAV_file_patterns.csv"),
    all_products = "all_products.csv",
    products_check = "products_check.txt",
    site_check = "site_check.txt"
  )
}

resolve_existing_config_directory <- function(config_directory) {
  config_directory <- trimws(as.character(config_directory %||% ""))
  if (length(config_directory) != 1L || !nzchar(config_directory) || !dir.exists(config_directory)) {
    stop("Choose an existing config folder.", call. = FALSE)
  }
  normalized <- normalizePath(config_directory, winslash = "/", mustWork = TRUE)
  nested <- file.path(normalized, "config")
  required_directories <- file.path(normalized, c("param", "reference", "path"))
  if (!all(dir.exists(required_directories))) {
    nested_directories <- file.path(nested, c("param", "reference", "path"))
    if (dir.exists(nested) && all(dir.exists(nested_directories))) {
      stop(sprintf("Select the config folder itself: %s", nested), call. = FALSE)
    }
    stop("The selected folder does not follow the canObsR 3.1.0 configuration schema.", call. = FALSE)
  }
  csv_files <- list.files(normalized, pattern = "[.]csv$", recursive = TRUE, full.names = FALSE, ignore.case = TRUE)
  if (length(csv_files) && !file.exists(file.path(normalized, "param", "site.csv"))) {
    stop("This partial configuration is invalid: param/site.csv must be the first saved file.", call. = FALSE)
  }
  normalized
}

config_relative_path_from_absolute <- function(path, config_directory) {
  root <- paste0(normalizePath(config_directory, winslash = "/", mustWork = TRUE), "/")
  normalized <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (!startsWith(normalized, root)) stop("The selected file is outside the config folder.", call. = FALSE)
  substring(normalized, nchar(root) + 1L)
}

config_absolute_path <- function(config_directory, relative_path, must_work = TRUE) {
  root <- normalizePath(config_directory, winslash = "/", mustWork = TRUE)
  candidate <- file.path(root, relative_path)
  parent <- normalizePath(dirname(candidate), winslash = "/", mustWork = TRUE)
  if (!identical(parent, root) && !startsWith(parent, paste0(root, "/"))) stop("The relative path escapes the config folder.", call. = FALSE)
  if (isTRUE(must_work) && !file.exists(candidate)) stop(sprintf("Configuration file not found: %s", relative_path), call. = FALSE)
  candidate
}

list_config_csv_files <- function(config_directory, editable_only = FALSE) {
  directory <- resolve_existing_config_directory(config_directory)
  paths <- list.files(directory, pattern = "[.]csv$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  relative <- vapply(paths, config_relative_path_from_absolute, character(1), config_directory = directory)
  relative <- sort(gsub("\\\\", "/", relative))
  if (isTRUE(editable_only)) relative <- relative[relative %in% gsub("\\\\", "/", CANOBS_EDITABLE_PATHS)]
  relative
}

config_csv_choices <- function(relative_paths) {
  relative_paths <- gsub("\\\\", "/", relative_paths)
  stats::setNames(relative_paths, paste0("config/", relative_paths))
}

config_table_edit_policy <- function(relative_path) {
  filename <- basename(relative_path)
  if (filename %in% c("site.csv", "crownfile_param.csv", "dawkins_param.csv")) return(list(fixed_columns = "param", allow_rows = FALSE))
  if (filename %in% c("survey.csv", "product.csv")) return(list(fixed_columns = setdiff(names(if (filename == "survey.csv") survey_template() else product_template()), "status"), allow_rows = FALSE))
  list(fixed_columns = character(), allow_rows = TRUE)
}

read_related_config_table <- function(config_directory, relative_path, fallback = data.frame()) {
  path <- file.path(config_directory, relative_path)
  if (!file.exists(path)) fallback else read_delimited_table(path)
}

validate_modified_config_table <- function(data, relative_path, config_directory, repair = FALSE) {
  filename <- basename(relative_path)
  surveys <- read_related_config_table(config_directory, file.path("param", "survey.csv"), survey_template())
  sensors <- read_related_config_table(config_directory, file.path("param", "sensor.csv"), sensor_template())
  products <- read_related_config_table(config_directory, file.path("param", "product.csv"), product_template())
  folders <- read_related_config_table(config_directory, file.path("path", "UAV_folder.csv"), uav_folder_template(products))
  crown_vars <- read_related_config_table(config_directory, file.path("param", "crownfile_vars.csv"), data.frame())
  switch(
    filename,
    "site.csv" = validate_site(data),
    "survey.csv" = validate_survey(data),
    "sensor.csv" = validate_sensor(data, surveys),
    "product.csv" = validate_product(data, surveys),
    "crownfile_param.csv" = validate_crownfile_param(data),
    "tree_picture_zooms.csv" = validate_tree_picture_zooms(data, sensors),
    "contributors.csv" = validate_contributors(data, repair = repair),
    "plots_list.csv" = validate_plots_list(data, repair = repair),
    "dawkins_param.csv" = validate_dawkins_param(data),
    "taxa_ref.csv" = validate_taxa_ref(data),
    "UAV_folder.csv" = validate_uav_folder(data, products, check_paths = FALSE),
    "UAV_file_patterns.csv" = validate_uav_file_patterns(data, products, folders, crown_vars),
    "vectors.csv" = validation_result(as_character_table(data)),
    validation_result(as_character_table(data), sprintf("Unsupported editable file: %s.", relative_path))
  )
}

#' Read a canObsR 3.1.0 configuration section
#'
#' @param config_directory Path to the config folder.
#' @param data_type Optional section name. When omitted, observatory.yaml is read.
#' @param as_datatable Return tables as a DT widget.
#' @export
observe_config <- function(config_directory = "config", data_type = NULL, as_datatable = FALSE) {
  directory <- resolve_existing_config_directory(config_directory)
  if (is.null(data_type) || !length(data_type) || !nzchar(data_type)) {
    path <- file.path(directory, "observatory.yaml")
    if (!file.exists(path)) stop("observatory.yaml has not been generated.", call. = FALSE)
    return(yaml::read_yaml(path))
  }
  data_type <- as.character(data_type[[1]])
  if (!data_type %in% CANOBS_CONFIG_DATA_TYPES) stop(sprintf("Unsupported data_type: %s.", data_type), call. = FALSE)
  if (identical(data_type, "schema_version")) return(CANOBS_SCHEMA_VERSION)
  if (identical(data_type, "date_format")) return(CANOBS_DATE_FORMAT)
  relative <- config_data_type_paths()[[data_type]]
  path <- file.path(directory, relative)
  if (!file.exists(path)) return(NULL)
  if (tools::file_ext(path) == "csv") {
    data <- read_delimited_table(path)
    if (isTRUE(as_datatable)) return(DT::datatable(
      data, rownames = FALSE, filter = "top",
      options = list(pageLength = 25, scrollX = TRUE)
    ))
    return(data)
  }
  readLines(path, warn = FALSE, encoding = "UTF-8")
}
