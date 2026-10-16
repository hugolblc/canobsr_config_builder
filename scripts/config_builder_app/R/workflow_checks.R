write_site_check_report <- function(config_directory, result) {
  lines <- c(
    "canObsR configuration report — schema 3.1.0",
    sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")), ""
  )
  details <- result$details %||% list()
  shown <- character()
  for (relative in names(details)) {
    item <- details[[relative]]
    if (!length(c(item$errors, item$warnings))) next
    shown <- c(shown, relative)
    lines <- c(lines, sprintf("config/%s", relative))
    if (length(item$errors)) lines <- c(lines, "  ERRORS", paste0("  - ", item$errors))
    if (length(item$warnings)) lines <- c(lines, "  WARNINGS", paste0("  - ", item$warnings))
    lines <- c(lines, "")
  }
  assigned_errors <- unique(unlist(lapply(details, `[[`, "errors"), use.names = FALSE))
  assigned_warnings <- unique(unlist(lapply(details, `[[`, "warnings"), use.names = FALSE))
  global_errors <- setdiff(result$errors %||% character(), assigned_errors)
  global_warnings <- setdiff(result$warnings %||% character(), assigned_warnings)
  if (length(c(global_errors, global_warnings))) {
    lines <- c(lines, "GLOBAL")
    if (length(global_errors)) lines <- c(lines, "  ERRORS", paste0("  - ", global_errors))
    if (length(global_warnings)) lines <- c(lines, "  WARNINGS", paste0("  - ", global_warnings))
    lines <- c(lines, "")
  }
  if (!length(c(result$errors, result$warnings))) lines <- c(lines, "No warning or error was detected.")
  write_utf8_text_file(lines, file.path(config_directory, "site_check.txt"))
}

normalize_single_column_yaml_records <- function(actual, expected) {
  expected_records <- is.list(expected) && length(expected) && all(vapply(
    expected,
    function(record) is.list(record) && length(record) == 1L &&
      !is.null(names(record)) && nzchar(names(record)[[1]]),
    logical(1)
  ))
  if (!expected_records) return(actual)
  actual_records <- if (is.list(actual)) actual else as.list(actual)
  if (length(actual_records) != length(expected)) return(actual)
  lapply(seq_along(expected), function(index) {
    field <- names(expected[[index]])[[1]]
    record <- actual_records[[index]]
    if (is.list(record) && !is.null(names(record)) && field %in% names(record)) {
      value <- record[[field]]
    } else if (is.list(record) && length(record) == 1L) {
      value <- record[[1]]
    } else {
      value <- record
    }
    stats::setNames(list(as.character(value)), field)
  })
}

compare_nested_config_values <- function(actual, expected, prefix = "") {
  actual <- normalize_single_column_yaml_records(actual, expected)
  if (identical(actual, expected)) return(character())
  if (!is.list(actual) && !is.list(expected) &&
      length(actual) == 1L && length(expected) == 1L &&
      identical(as.character(actual), as.character(expected))) return(character())
  if (!is.list(actual) || !is.list(expected)) return(sprintf("%s differs.", prefix %||% "value"))
  messages <- character()
  if (is.null(names(actual)) && is.null(names(expected))) {
    length_max <- max(length(actual), length(expected))
    for (index in seq_len(length_max)) {
      label <- sprintf("%s[%d]", prefix, index)
      if (index > length(actual)) messages <- c(messages, sprintf("Missing YAML item: %s.", label))
      else if (index > length(expected)) messages <- c(messages, sprintf("Unexpected YAML item: %s.", label))
      else messages <- c(messages, compare_nested_config_values(actual[[index]], expected[[index]], label))
    }
    return(messages)
  }
  for (name in union(names(actual), names(expected))) {
    label <- if (nzchar(prefix)) paste(prefix, name, sep = ".") else name
    if (!name %in% names(actual)) messages <- c(messages, sprintf("Missing YAML key: %s.", label))
    else if (!name %in% names(expected)) messages <- c(messages, sprintf("Unexpected YAML key: %s.", label))
    else messages <- c(messages, compare_nested_config_values(actual[[name]], expected[[name]], label))
  }
  messages
}

#' Check configuration and generated observatory files
#' @export
check_observatory_files <- function(config_directory = "config", print_report = TRUE) {
  directory <- resolve_existing_config_directory(config_directory)
  base <- validate_generated_configuration(directory, check_uav_paths = FALSE)
  errors <- base$errors; warnings <- base$warnings; details <- base$details
  yaml_path <- file.path(directory, "observatory.yaml")
  if (!file.exists(yaml_path)) warnings <- c(warnings, "observatory.yaml has not been generated.")
  else {
    actual <- tryCatch(yaml::read_yaml(yaml_path), error = function(e) e)
    expected <- build_observatory_definition(directory)
    if (inherits(actual, "error")) errors <- c(errors, sprintf("observatory.yaml cannot be read: %s.", conditionMessage(actual)))
    else {
      differences <- compare_nested_config_values(actual, expected)
      if (length(differences)) warnings <- c(
        warnings,
        "observatory.yaml is not synchronized with the current CSV configuration.",
        paste0("Configuration change: ", differences)
      )
    }
  }
  site <- read_delimited_table(file.path(directory, "param", "site.csv"))
  site_values <- table_to_named(site, "param", "site_value")
  report_path <- file.path(directory, config_report_filename(named_value_or(site_values, "name", "observatory")))
  if (!file.exists(report_path)) warnings <- c(warnings, sprintf("%s has not been generated.", basename(report_path)))
  else {
    source_paths <- list.files(directory, pattern = "[.]csv$", recursive = TRUE, full.names = TRUE)
    source_paths <- source_paths[!grepl("(^|/)(taxa_ref|vectors|all_products)[.]csv$", gsub("\\\\", "/", source_paths))]
    if (length(source_paths) && file.info(report_path)$mtime < max(file.info(source_paths)$mtime, na.rm = TRUE)) {
      warnings <- c(warnings, sprintf("%s is older than the current configuration CSV files.", basename(report_path)))
    }
  }
  result <- validation_result(NULL, errors, warnings, details)
  result$config_directory <- directory
  derived_patterns <- c(
    "observatory.yaml has not been generated", "observatory.yaml is not synchronized",
    "has not been generated", "is older than the current configuration"
  )
  derived_issue <- vapply(
    warnings,
    function(message) any(vapply(derived_patterns, grepl, logical(1), x = message, fixed = TRUE)),
    logical(1)
  )
  result$source_ok <- base$ok
  result$up_to_date <- base$ok && !any(derived_issue)
  result$yaml_current <- file.exists(yaml_path) && !any(grepl("observatory.yaml is not synchronized", warnings, fixed = TRUE))
  result$report_path <- report_path
  write_site_check_report(directory, result)
  if (isTRUE(print_report)) print_check_messages("Observatory files check", result)
  invisible(result)
}

require_current_observatory_files <- function(config_directory) {
  checked <- check_observatory_files(config_directory, print_report = FALSE)
  if (!isTRUE(checked$source_ok)) return(validation_result(errors = checked$errors, warnings = checked$warnings))
  if (!isTRUE(checked$up_to_date)) return(validation_result(
    errors = "Operation 3 lock: publish the current observatory.yaml and site HTML report before checking scientific data.",
    warnings = checked$warnings
  ))
  validation_result(warnings = checked$warnings)
}

#' List every server alias declared by the configuration
#'
#' Aliases are collected from the crownfile address and UAV folder mappings.
#' Local roots remain workstation-specific and are therefore never written to
#' config/.
#' @export
configured_server_aliases <- function(config_directory = "config") {
  directory <- resolve_existing_config_directory(config_directory)
  aliases <- character()

  crown_path <- file.path(directory, "param", "crownfile_param.csv")
  if (file.exists(crown_path)) {
    crown <- read_delimited_table(crown_path)
    if (all(c("param", "value") %in% names(crown))) {
      aliases <- c(aliases, crown$value[crown$param == "server"])
    }
  }

  uav_path <- file.path(directory, "path", "UAV_folder.csv")
  if (file.exists(uav_path)) {
    uav <- read_delimited_table(uav_path)
    if ("server" %in% names(uav)) aliases <- c(aliases, uav$server)
  }

  aliases <- trimws(as.character(aliases))
  unique(aliases[!is.na(aliases) & nzchar(aliases)])
}

#' Resolve the crownfile declared in param/crownfile_param.csv
#'
#' `path` is always interpreted relative to the root identified by `server`.
#' An explicit `crownfile_path` remains available for programmatic backwards
#' compatibility, but the application and the four example scripts use the
#' canonical configuration fields.
#' @export
resolve_configured_crownfile_path <- function(
    config_directory = "config", server_roots, crownfile_path = NULL) {
  directory <- resolve_existing_config_directory(config_directory)
  if (!is.null(crownfile_path) && length(crownfile_path) && nzchar(trimws(as.character(crownfile_path[[1]])))) {
    return(normalizePath(
      trimws(as.character(crownfile_path[[1]])), winslash = "/", mustWork = FALSE
    ))
  }
  parameter_file <- file.path(directory, "param", "crownfile_param.csv")
  if (!file.exists(parameter_file)) {
    stop("Cannot resolve the crownfile before param/crownfile_param.csv has been validated and saved.", call. = FALSE)
  }
  parameter_table <- read_delimited_table(parameter_file)
  checked <- validate_crownfile_param(parameter_table)
  if (!checked$ok) {
    stop(paste(c(
      "Cannot resolve the crownfile because param/crownfile_param.csv has blocking errors:",
      paste0("- ", checked$errors)
    ), collapse = "\n"), call. = FALSE)
  }
  parameters <- table_to_named(parameter_table, "param", "value")
  alias <- named_value_or(parameters, "server")
  relative_path <- gsub("\\\\", "/", named_value_or(parameters, "path"))
  roots <- resolve_directory_roots(server_roots)
  if (!alias %in% names(roots)) {
    stop(sprintf(
      "The crownfile server alias '%s' is not present in server_roots. Available aliases: %s.",
      alias, if (length(names(roots))) paste(names(roots), collapse = ", ") else "none"
    ), call. = FALSE)
  }
  root <- trimws(as.character(roots[[alias]][[1]]))
  if (!nzchar(root)) stop(sprintf("The server root for alias '%s' is empty.", alias), call. = FALSE)
  normalizePath(file.path(root, relative_path), winslash = "/", mustWork = FALSE)
}

#' Regenerate observatory.yaml and the bilingual site report
#' @export
update_observatory_files <- function(check_result, print_report = TRUE) {
  if (is.null(check_result$config_directory)) stop("check_result must come from check_observatory_files().", call. = FALSE)
  if (length(check_result$errors)) stop("Derived files cannot be updated while blocking configuration errors remain.", call. = FALSE)
  paths <- write_observatory_outputs(check_result$config_directory)
  post <- check_observatory_files(check_result$config_directory, print_report = FALSE)
  if (isTRUE(print_report)) cat(paste0("Written: ", paths, collapse = "\n"), "\n")
  invisible(list(paths = paths, check = post))
}

non_missing_vector <- function(values) {
  values <- as.character(values)
  values[!is.na(values) & nzchar(trimws(values))]
}

crown_value_format_errors <- function(values, expected_type, label) {
  values <- non_missing_vector(values)
  if (!length(values)) return(character())
  type <- tolower(expected_type)
  invalid <- logical(length(values))
  if (grepl("integer", type)) invalid <- !grepl("^-?[0-9]+$", values)
  else if (grepl("dbl|double|numeric", type)) invalid <- is.na(suppressWarnings(as.numeric(values)))
  else if (grepl("date", type)) invalid <- is.na(parse_canobs_date(values))
  if (any(invalid)) sprintf("%s contains value(s) incompatible with expected type '%s'.", label, expected_type) else character()
}

normalize_sf_geometry_column <- function(data, target = "geometry") {
  if (!inherits(data, "sf")) return(data)
  current <- attr(data, "sf_column")
  if (is.null(current) || length(current) != 1L || !current %in% names(data)) {
    candidates <- names(data)[vapply(data, inherits, logical(1), what = "sfc")]
    if (length(candidates) != 1L) stop(
      "The spatial geometry column could not be identified unambiguously.", call. = FALSE
    )
    current <- candidates[[1]]
  }
  if (identical(current, target)) return(data)
  if (target %in% names(data)) stop(sprintf(
    "Cannot rename spatial column '%s' to '%s' because that field already exists.",
    current, target
  ), call. = FALSE)
  names(data)[names(data) == current] <- target
  attr(data, "sf_column") <- target
  data
}

read_crown_layer <- function(path, layer) {
  tryCatch(
    normalize_sf_geometry_column(
      sf::st_read(path, layer = layer, quiet = TRUE, stringsAsFactors = FALSE)
    ),
    error = function(e) e
  )
}

crownfile_layer_names <- function(path) {
  tryCatch(as.character(sf::st_layers(path)$name), error = function(e) e)
}

reference_key_column <- function(reference, variable_name) {
  preferred <- c(variable_name, switch(variable_name,
    Type_Obs = "Type_Obs", Tree_Status = "Tree_Status", Geom_Modif = "Geom_Modif",
    creator = "contributor", plot_name = "plot_name", dbh_type = "dbh_types",
    lianas = "lianas", dawkins_code = "Dawkins", variable_name
  ))
  preferred <- unique(preferred[preferred %in% names(reference)])
  if (length(preferred)) preferred[[1]] else if (ncol(reference)) names(reference)[[1]] else ""
}

check_external_reference_values <- function(values, variable, reference_path, label = variable) {
  if (variable == "taxa_id") return(validation_result())
  if (!file.exists(reference_path)) return(validation_result(errors = sprintf("Reference file required for %s is missing: %s.", variable, basename(reference_path))))
  reference <- read_delimited_table(reference_path)
  key <- reference_key_column(reference, variable)
  if (!nzchar(key)) return(validation_result(errors = sprintf("Reference table %s has no usable column.", basename(reference_path))))
  unknown <- setdiff(unique(non_missing_vector(values)), unique(non_missing_vector(reference[[key]])))
  if (!length(unknown)) return(validation_result())
  message <- sprintf("%s contains value(s) absent from %s column %s: %s.", label, basename(reference_path), key, paste(unknown, collapse = ", "))
  if (variable %in% c("creator", "plot_name")) validation_result(warnings = message) else validation_result(errors = message)
}

check_crown_schema_values <- function(config_directory, crownfile_path) {
  params <- read_config_params(config_directory)
  crownfile_type <- named_value_or(params, "crownfile_type", "dynamic")
  schema <- crownfile_vars_template(
    crownfile_type,
    is_true_value(params, "plots_list"), is_true_value(params, "taxa_ref"), is_true_value(params, "dawkins")
  )
  errors <- warnings <- character(); layers <- list()
  if (identical(crownfile_type, "light")) {
    available <- crownfile_layer_names(crownfile_path)
    if (inherits(available, "error")) return(validation_result(errors = sprintf("Cannot list crownfile layers: %s.", conditionMessage(available))))
    if (!identical(available, "crowns")) return(validation_result(errors = sprintf(
      "A light crownfile must be a GeoPackage containing exactly one spatial layer named 'crowns'. Found: %s.",
      if (length(available)) paste(available, collapse = ", ") else "no layer"
    )))
    layer_plan <- c(crowns = "crowns")
  } else {
    layer_plan <- stats::setNames(unique(schema$layer), unique(schema$layer))
  }
  for (layer in names(layer_plan)) {
    layer_data <- read_crown_layer(crownfile_path, layer_plan[[layer]])
    if (inherits(layer_data, "error")) {
      errors <- c(errors, sprintf("Cannot read crownfile layer '%s': %s.", layer, conditionMessage(layer_data)))
      next
    }
    layers[[layer]] <- layer_data
    rows_for_layer <- if ("layer" %in% names(schema)) schema$layer == layer else rep(TRUE, nrow(schema))
    required <- schema$var_name[rows_for_layer]
    missing <- setdiff(required, names(layer_data))
    if (length(missing)) errors <- c(errors, sprintf("Crownfile layer %s is missing required field(s): %s.", layer, paste(missing, collapse = ", ")))
    rows <- schema[rows_for_layer & schema$var_name %in% names(layer_data), , drop = FALSE]
    for (i in seq_len(nrow(rows))) {
      variable <- rows$var_name[[i]]
      if (variable == "taxa_id") next
      errors <- c(errors, crown_value_format_errors(layer_data[[variable]], rows$type[[i]], paste0(layer, ".", variable)))
      reference <- rows$reference_tables[[i]]
      if (!nzchar(reference) || reference == "crowns.gpkg") next
      result <- check_external_reference_values(
        layer_data[[variable]], variable, file.path(config_directory, "reference", reference),
        paste0(layer, ".", variable)
      )
      errors <- c(errors, result$errors); warnings <- c(warnings, result$warnings)
    }
    primary <- rows$var_name[grepl("PK", rows$type, fixed = TRUE)]
    for (variable in primary) {
      values <- non_missing_vector(layer_data[[variable]])
      if (length(values) != nrow(layer_data) || anyDuplicated(values)) {
        errors <- c(errors, sprintf("%s.%s must be complete and unique.", layer, variable))
      }
    }
  }
  infos <- layers$infos %||% layers$crowns %||% layers$light
  if (!is.null(infos)) {
    if (!is_true_value(params, "taxa_ref") && "taxa_id" %in% names(infos)) warnings <- c(warnings, "infos.taxa_id is present while taxa_ref is FALSE; enabling taxa_ref may be useful. No taxa_id value was checked.")
    # When dawkins is FALSE, dawkins_code is optional and deliberately unchecked.
    if (!is_true_value(params, "plots_list") && "plot_name" %in% names(infos)) warnings <- c(warnings, "infos.plot_name is present while plots_list is FALSE.")
  }
  geometry <- layers$geometry
  if (!is.null(geometry) && !is.null(infos) && "id" %in% names(geometry) && "id" %in% names(infos)) {
    orphan <- setdiff(non_missing_vector(geometry$id), non_missing_vector(infos$id))
    if (length(orphan)) errors <- c(errors, sprintf("geometry.id contains value(s) absent from infos.id: %s.", paste(orphan, collapse = ", ")))
  }
  site_values <- table_to_named(read_delimited_table(file.path(config_directory, "param", "site.csv")), "param", "site_value")
  expected_site <- named_value_or(site_values, "id_site")
  for (layer in names(layers)) {
    if ("site" %in% names(layers[[layer]])) {
      unexpected <- setdiff(unique(non_missing_vector(layers[[layer]]$site)), expected_site)
      if (length(unexpected)) errors <- c(errors, sprintf("%s.site contains value(s) different from site.id_site: %s.", layer, paste(unexpected, collapse = ", ")))
    }
  }
  validation_result(layers, errors, warnings)
}

check_dynamic_crown_date_coverage <- function(config_directory, crown_layers) {
  params <- read_config_params(config_directory)
  if (named_value_or(params, "crownfile_type") != "dynamic") return(validation_result())
  surveys <- read_delimited_table(file.path(config_directory, "param", "survey.csv"))
  products <- read_delimited_table(file.path(config_directory, "param", "product.csv"))
  rgb_active <- any(surveys$survey == "RGB" & surveys$status == "TRUE")
  ortho_active <- any(products$product == "RGB_orthomosaic" & products$status == "TRUE")
  if (!rgb_active || !ortho_active) return(validation_result())
  inventory_path <- file.path(config_directory, "all_products.csv")
  if (!file.exists(inventory_path)) return(validation_result(warnings = "Dynamic date coverage was not compared because all_products.csv is absent."))
  inventory <- read_delimited_table(inventory_path)
  if (!"date" %in% names(inventory)) return(validation_result(warnings = "Dynamic date coverage was not compared because all_products.csv has no date column."))
  rgb_dates <- unique(inventory$date[inventory$product == "RGB_orthomosaic"])
  rgb_dates <- non_missing_vector(rgb_dates)
  if (!length(rgb_dates)) return(validation_result(warnings = "No RGB_orthomosaic object was found for dynamic date coverage."))
  crown_dates <- if (!is.null(crown_layers$geometry) && "date" %in% names(crown_layers$geometry)) non_missing_vector(crown_layers$geometry$date) else character()
  missing <- setdiff(crown_dates, rgb_dates)
  if (length(missing)) validation_result(warnings = sprintf("Crownfile date(s) without an observed RGB_orthomosaic: %s.", paste(missing, collapse = ", "))) else validation_result()
}

#' Check one explicitly supplied crownfile
#'
#' vectors.csv is never read by this function.
#' @export
check_crownfile <- function(config_directory = "config", crownfile_path, check_rgb_dates = TRUE, print_report = TRUE) {
  directory <- resolve_existing_config_directory(config_directory)
  gate <- require_current_observatory_files(directory)
  crownfile_path <- trimws(as.character(crownfile_path[[1]]))
  if (!gate$ok) result <- gate
  else if (!identical(tolower(tools::file_ext(crownfile_path)), "gpkg")) result <- validation_result(errors = sprintf("The crownfile must be a GeoPackage file with the .gpkg extension: %s.", crownfile_path), warnings = gate$warnings)
  else if (!file.exists(crownfile_path)) result <- validation_result(errors = sprintf("Crownfile not found: %s.", crownfile_path), warnings = gate$warnings)
  else if (!requireNamespace("sf", quietly = TRUE)) result <- validation_result(errors = "The sf package is required to inspect a crownfile.")
  else {
    result <- check_crown_schema_values(directory, crownfile_path)
    if (isTRUE(check_rgb_dates) && result$ok) {
      coverage <- check_dynamic_crown_date_coverage(directory, result$data)
      result <- validation_result(result$data, c(result$errors, coverage$errors), c(result$warnings, coverage$warnings))
    }
  }
  result$config_directory <- directory; result$crownfile_path <- crownfile_path
  if (isTRUE(print_report)) print_check_messages("Crownfile check", result)
  invisible(result)
}

#' Check whether all_products.csv matches current UAV sources
#' @export
check_products_file <- function(config_directory = "config", server_roots, print_report = TRUE) {
  directory <- resolve_existing_config_directory(config_directory)
  gate <- require_current_observatory_files(directory)
  if (!gate$ok) {
    result <- gate
    result$config_directory <- directory
    result$current_inventory <- data.frame()
    result$inconsistencies <- character()
    result$products_check_path <- write_products_check_report(
      directory, result$current_inventory, warnings = result$warnings,
      errors = result$errors, inventory_written = file.exists(file.path(directory, "all_products.csv"))
    )
    if (isTRUE(print_report)) print_check_messages("all_products.csv check", result)
    return(invisible(result))
  }
  current <- tryCatch(generate_products_inventory(directory, server_roots), error = function(error) error)
  if (inherits(current, "error")) {
    result <- validation_result(
      data.frame(),
      errors = sprintf("Product inventory scan failed: %s", conditionMessage(current))
    )
    result$config_directory <- directory
    result$current_inventory <- data.frame()
    result$inconsistencies <- character()
    result$products_check_path <- write_products_check_report(
      directory, result$current_inventory, errors = result$errors,
      inventory_written = file.exists(file.path(directory, "all_products.csv"))
    )
    if (isTRUE(print_report)) print_check_messages("all_products.csv check", result)
    return(invisible(result))
  }
  path <- file.path(directory, "all_products.csv")
  errors <- current$errors; warnings <- current$warnings
  changes <- list(added = data.frame(), removed = data.frame())
  if (!file.exists(path)) warnings <- c(warnings, "all_products.csv has not been generated.")
  else if (current$ok) {
    stored <- read_delimited_table(path)
    key_columns <- intersect(c("survey", "product", "server", "configured_path", "relative_path"), intersect(names(stored), names(current$data)))
    key <- function(x) if (!length(key_columns)) character() else apply(x[, key_columns, drop = FALSE], 1L, paste, collapse = "|")
    old_key <- key(stored); new_key <- key(current$data)
    changes$added <- current$data[!new_key %in% old_key, , drop = FALSE]
    changes$removed <- stored[!old_key %in% new_key, , drop = FALSE]
    if (nrow(changes$added) || nrow(changes$removed)) warnings <- c(warnings, sprintf("all_products.csv is not current: %d added and %d removed object(s).", nrow(changes$added), nrow(changes$removed)))
  }
  result <- validation_result(current$data, errors, warnings, details = changes)
  result$config_directory <- directory
  result$current_inventory <- current$data
  result$inconsistencies <- current$inconsistencies
  result$products_check_path <- write_products_check_report(
    directory, current$data, current$inconsistencies, warnings, errors,
    inventory_written = file.exists(path)
  )
  if (isTRUE(print_report)) print_check_messages("all_products.csv check", result)
  invisible(result)
}

#' Update all_products.csv from a product file check
#' @export
update_products_file <- function(check_result, print_report = TRUE) {
  write_all_products_csv(check_result, print_report = print_report)
}

#' Create the config folder skeleton without reading scientific data
#' @export
generate_config_folder <- function(parent_directory) create_config_skeleton(parent_directory)

#' Initialize an empty 3.1.0 config folder skeleton
#' @export
initialize_config_folder <- function(parent_directory, print_report = TRUE) {
  candidate <- file.path(trimws(as.character(parent_directory[[1]])), "config")
  if (dir.exists(candidate) && length(list.files(candidate, all.files = FALSE, recursive = TRUE))) {
    stop("config/ already exists and is not empty. Load it instead of initializing it again.", call. = FALSE)
  }
  directory <- create_config_skeleton(parent_directory)
  if (isTRUE(print_report)) cat(sprintf(
    "Initialized empty canObsR schema %s folders in %s\n",
    CANOBS_SCHEMA_VERSION, directory
  ))
  invisible(directory)
}

#' Generate automatic tables, validate the config, and publish derived files
#'
#' @param before_snapshot Optional result from `capture_config_snapshot()`
#'   captured before the first edit. It enables a complete modification report.
#' @param publication_date Date used in archive and modification filenames.
#' @param archive_previous Archive the previous YAML, site check, and same-day
#'   modification report before publishing replacements.
#' @export
generate_config_outputs <- function(
    config_directory = "config", overwrite_reference_tables = TRUE,
    print_report = TRUE, before_snapshot = NULL,
    publication_date = Sys.Date(), archive_previous = TRUE) {
  directory <- resolve_existing_config_directory(config_directory)
  if (is.null(before_snapshot)) before_snapshot <- capture_config_snapshot(directory)
  if (!inherits(before_snapshot, "canobs_config_snapshot")) {
    stop("before_snapshot must come from capture_config_snapshot().", call. = FALSE)
  }
  if (!identical(
    normalizePath(before_snapshot$config_directory, winslash = "/", mustWork = TRUE),
    directory
  )) {
    stop("before_snapshot belongs to a different config folder.", call. = FALSE)
  }
  generated <- write_generated_tables(directory, overwrite = overwrite_reference_tables)
  check <- validate_generated_configuration(directory, check_uav_paths = FALSE)
  site_check <- NULL
  outputs <- character()
  archive <- NULL
  modification_report <- NULL
  if (check$ok) {
    archive <- if (isTRUE(archive_previous)) {
      archive_previous_publication(directory, publication_date)
    } else {
      list(id = publication_id(directory, publication_date), archive_directory = NULL, files = character())
    }
    site_check <- write_site_check_report(directory, check)
    outputs <- write_observatory_outputs(directory)
    after_snapshot <- capture_config_snapshot(directory)
    modification_report <- write_modification_report(
      directory, before_snapshot, after_snapshot, archive$id
    )
    outputs <- c(outputs, site_check = site_check, modification_report = modification_report)
  } else {
    site_check <- write_site_check_report(directory, check)
  }
  if (isTRUE(print_report)) {
    print_check_messages("Configuration output generation", check)
    if (length(outputs)) cat(paste0("Written: ", outputs, collapse = "\n"), "\n")
  }
  invisible(list(
    validation = check, generated = generated, outputs = outputs,
    site_check = site_check, archive = archive,
    modification_report = modification_report
  ))
}

#' Operation 1 — generate the config folder
#' @export
operation1_generate_config <- function(parent_directory, print_report = TRUE) {
  initialize_config_folder(parent_directory, print_report)
}

#' Operation 2 — begin modification of an existing config folder
#'
#' The returned snapshot must be kept until `generate_config_outputs()` is
#' called, so the dated modification report can reproduce every before/after
#' version.
#' @export
operation2_modify_config <- function(config_directory = "config", print_report = TRUE) {
  directory <- resolve_existing_config_directory(config_directory)
  snapshot <- capture_config_snapshot(directory)
  if (isTRUE(print_report)) cat(sprintf("Loaded for modification: %s\n", directory))
  invisible(list(config_directory = directory, before_snapshot = snapshot))
}

#' Operation 3 — check parameters and scientific data
#' @export
operation3_check_parameters_and_data <- function(
    config_directory = "config", server_roots = NULL, crownfile_path = NULL,
    check_rgb_dates = TRUE, print_report = TRUE) {
  config <- check_observatory_files(config_directory, print_report = print_report)
  gate_open <- isTRUE(config$source_ok) && isTRUE(config$up_to_date)
  crown <- NULL
  if (gate_open && !is.null(server_roots)) {
    resolved_crownfile <- resolve_configured_crownfile_path(config_directory, server_roots, crownfile_path)
    crown <- check_crownfile(config_directory, resolved_crownfile, check_rgb_dates, print_report)
  }
  products <- if (!gate_open || is.null(server_roots)) NULL else check_products_file(config_directory, server_roots, print_report)
  errors <- c(config$errors, crown$errors %||% character(), products$errors %||% character())
  warnings <- c(config$warnings, crown$warnings %||% character(), products$warnings %||% character())
  if (!gate_open && !length(config$errors)) errors <- c(errors, "Operation 3 lock: publish the current observatory.yaml and site report before scientific-data checks.")
  if (gate_open && is.null(server_roots)) errors <- c(errors, "Operation 3 requires named server_roots to resolve the configured crownfile and product folders.")
  result <- validation_result(NULL, errors, warnings, details = list(config = config, crownfile = crown, products = products))
  class(result) <- unique(c("canobs_operation3", class(result)))
  invisible(result)
}

#' Operation 4 — visualize parameters and data summaries
#' @export
operation4_visualize_parameters_and_data <- function(config_directory = "config", as_datatable = FALSE) {
  directory <- resolve_existing_config_directory(config_directory)
  sections <- lapply(setdiff(CANOBS_CONFIG_DATA_TYPES, c("date_format", "schema_version", "products_check", "site_check")), function(type) {
    observe_config(directory, type, as_datatable = as_datatable)
  })
  names(sections) <- setdiff(CANOBS_CONFIG_DATA_TYPES, c("date_format", "schema_version", "products_check", "site_check"))
  sections
}

# Backwards-compatible aliases retained for existing direct-R integrations.
operation1_generate_or_modify_config <- function(parent_directory, print_report = TRUE) {
  operation1_generate_config(parent_directory, print_report)
}

operation2_check_parameters_and_data <- function(...) operation3_check_parameters_and_data(...)
operation3_visualize_parameters_and_data <- function(...) operation4_visualize_parameters_and_data(...)
