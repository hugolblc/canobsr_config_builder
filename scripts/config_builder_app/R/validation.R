validation_result <- function(data = NULL, errors = character(), warnings = character(), details = list()) {
  errors <- unique(as.character(errors[!is.na(errors) & nzchar(errors)]))
  warnings <- unique(as.character(warnings[!is.na(warnings) & nzchar(warnings)]))
  structure(
    list(ok = !length(errors), data = data, errors = errors, warnings = warnings, details = details),
    class = "canobs_validation"
  )
}

as_character_table <- function(data) {
  data <- as.data.frame(data %||% data.frame(), stringsAsFactors = FALSE, check.names = FALSE)
  if (ncol(data)) data[] <- lapply(data, function(x) { x <- as.character(x); x[is.na(x)] <- ""; trimws(x) })
  rownames(data) <- NULL
  data
}

drop_fully_empty_rows <- function(data) {
  data <- as_character_table(data)
  if (!nrow(data) || !ncol(data)) return(data)
  keep <- apply(data, 1L, function(row) any(nzchar(trimws(as.character(row)))))
  data[keep, , drop = FALSE]
}

check_columns <- function(data, expected, label = "File") {
  actual <- names(data)
  errors <- character()
  if (!identical(actual, expected)) {
    errors <- sprintf(
      "%s must contain exactly these columns in this order: %s. Found: %s.",
      label, paste(expected, collapse = ";"), paste(actual, collapse = ";")
    )
  }
  errors
}

table_to_named <- function(data, key, value) {
  data <- as_character_table(data)
  if (!all(c(key, value) %in% names(data))) return(setNames(character(), character()))
  stats::setNames(data[[value]], data[[key]])
}

parse_boolean <- function(x) {
  x <- as.character(x)
  valid <- x %in% c("TRUE", "FALSE")
  list(valid = valid, value = x == "TRUE")
}

parse_canobs_date <- function(x) {
  x <- trimws(as.character(x))
  parsed <- as.Date(x, format = "%Y%m%d")
  exact <- !is.na(parsed) & format(parsed, "%Y%m%d") == x & grepl("^[0-9]{8}$", x)
  parsed[!exact] <- as.Date(NA)
  parsed
}

contains_accent <- function(x) {
  x <- enc2utf8(as.character(x))
  iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT") != x
}

validate_site <- function(data) {
  data <- as_character_table(data)
  errors <- check_columns(data, c("param", "site_value"), "param/site.csv")
  if (length(errors)) return(validation_result(data, errors))
  if (!identical(data$param, CANOBS_SITE_PARAMETERS)) {
    errors <- c(errors, "param/site.csv must contain id_site, name, location, crs in that exact order, without extra rows.")
  }
  values <- table_to_named(data, "param", "site_value")
  missing <- CANOBS_SITE_PARAMETERS[!nzchar(values[CANOBS_SITE_PARAMETERS])]
  if (length(missing)) errors <- c(errors, sprintf("param/site.csv has empty required value(s): %s.", paste(missing, collapse = ", ")))
  id <- named_value_or(values, "id_site")
  if (nzchar(id) && !grepl("^[A-Za-z0-9_.-]+$", id)) {
    row <- match("id_site", data$param)
    errors <- c(errors, sprintf(
      "config/param/site.csv — row %d (id_site), column site_value: value '%s' is invalid. Spaces and other special characters are forbidden; use only letters, digits, underscores, hyphens, or dots.",
      row, id
    ))
  }
  for (field in c("name", "location")) {
    value <- named_value_or(values, field)
    if (nzchar(value) && contains_accent(value)) {
      errors <- c(errors, sprintf(
        "config/param/site.csv — row %d (%s), column site_value: value '%s' contains an accented character, which is forbidden.",
        match(field, data$param), field, value
      ))
    }
  }
  crs <- named_value_or(values, "crs")
  if (nzchar(crs)) {
    crs_ok <- if (requireNamespace("sf", quietly = TRUE)) {
      tryCatch(!is.na(sf::st_crs(crs)), error = function(e) FALSE)
    } else {
      grepl("^(EPSG:[0-9]+|[+]proj=|PROJCRS|GEOGCRS)", crs, ignore.case = TRUE)
    }
    if (!crs_ok) errors <- c(errors, sprintf(
      "config/param/site.csv — row %d (crs), column site_value: value '%s' is not a recognized coordinate reference system.",
      match("crs", data$param), crs
    ))
  }
  validation_result(data, errors)
}

validate_survey <- function(data) {
  data <- as_character_table(data)
  errors <- check_columns(data, c("survey", "status"), "param/survey.csv")
  if (length(errors)) return(validation_result(data, errors))
  if (nrow(data) != length(CANOBS_SURVEYS) || !setequal(data$survey, CANOBS_SURVEYS) || anyDuplicated(data$survey)) {
    errors <- c(errors, "param/survey.csv must contain each of RGB, MS, DLS, and tree_pictures exactly once.")
  }
  invalid <- unique(data$status[!data$status %in% c("TRUE", "FALSE")])
  if (length(invalid)) errors <- c(errors, "survey.status values must be TRUE or FALSE, in uppercase and without quotes.")
  if (!any(data$status == "TRUE")) errors <- c(errors, "At least one survey must have status TRUE.")
  validation_result(data, errors)
}

validate_sensor <- function(data, surveys) {
  data <- drop_fully_empty_rows(data)
  errors <- check_columns(data, c("sensor", "survey", "start_date", "end_date", "status"), "param/sensor.csv")
  warnings <- character()
  if (length(errors)) return(validation_result(data, errors))
  active_surveys <- surveys$survey[surveys$status == "TRUE"]
  if (any(!nzchar(data$sensor))) errors <- c(errors, "sensor.sensor must be filled on every row.")
  unknown <- unique(data$survey[!data$survey %in% CANOBS_SURVEYS])
  if (length(unknown)) errors <- c(errors, sprintf("sensor.survey contains unknown value(s): %s.", paste(unknown, collapse = ", ")))
  inactive <- unique(data$survey[data$survey %in% setdiff(CANOBS_SURVEYS, active_surveys)])
  if (length(inactive)) errors <- c(errors, sprintf("sensor.csv contains row(s) for inactive survey(s): %s.", paste(inactive, collapse = ", ")))
  invalid_status <- unique(data$status[!data$status %in% CANOBS_DRONE_STATUSES])
  if (length(invalid_status)) errors <- c(errors, "sensor.status must be exactly active or not active.")
  starts <- parse_canobs_date(data$start_date)
  invalid_start <- which(is.na(starts))
  if (length(invalid_start)) errors <- c(errors, sprintf("sensor.start_date must use yyyymmdd at row(s): %s.", paste(invalid_start, collapse = ", ")))
  active_with_end <- which(data$status == "active" & nzchar(data$end_date))
  if (length(active_with_end)) errors <- c(errors, sprintf("An active sensor must have an empty end_date at row(s): %s.", paste(active_with_end, collapse = ", ")))
  inactive_without_end <- which(data$status == "not active" & !nzchar(data$end_date))
  if (length(inactive_without_end)) errors <- c(errors, sprintf("A not active sensor must have end_date at row(s): %s.", paste(inactive_without_end, collapse = ", ")))
  ends <- rep(as.Date(NA), nrow(data))
  with_end <- nzchar(data$end_date)
  ends[with_end] <- parse_canobs_date(data$end_date[with_end])
  invalid_end <- which(with_end & is.na(ends))
  if (length(invalid_end)) errors <- c(errors, sprintf("sensor.end_date must use yyyymmdd at row(s): %s.", paste(invalid_end, collapse = ", ")))
  reversed <- which(!is.na(starts) & !is.na(ends) & ends < starts)
  if (length(reversed)) errors <- c(errors, sprintf("sensor.end_date must be on or after start_date at row(s): %s.", paste(reversed, collapse = ", ")))
  key <- paste(data$survey, data$sensor, data$start_date, sep = "|")
  if (anyDuplicated(key)) errors <- c(errors, "The sensor/survey/start_date key must be unique.")

  overlap_ends <- ends
  overlap_ends[data$status == "active" & is.na(overlap_ends)] <- Sys.Date()
  for (survey in intersect(unique(data$survey), CANOBS_SURVEYS)) {
    idx <- which(data$survey == survey & !is.na(starts) & !is.na(overlap_ends))
    if (length(idx) > 1L) {
      for (a in seq_len(length(idx) - 1L)) for (b in seq.int(a + 1L, length(idx))) {
        i <- idx[[a]]; j <- idx[[b]]
        if (starts[[i]] <= overlap_ends[[j]] && starts[[j]] <= overlap_ends[[i]]) {
          errors <- c(errors, sprintf("sensor.csv has inclusive overlapping periods for survey %s at rows %d and %d.", survey, i, j))
        }
      }
    }
  }
  missing_sensor <- setdiff(active_surveys, unique(data$survey))
  if (length(missing_sensor)) errors <- c(errors, sprintf("Active survey(s) without a sensor: %s.", paste(missing_sensor, collapse = ", ")))
  only_historical <- active_surveys[vapply(active_surveys, function(s) !any(data$survey == s & data$status == "active"), logical(1))]
  if (length(only_historical)) warnings <- c(warnings, sprintf("Active survey(s) have no sensor currently active: %s.", paste(only_historical, collapse = ", ")))
  validation_result(data, errors, warnings)
}

validate_product <- function(data, surveys) {
  data <- drop_fully_empty_rows(data)
  errors <- check_columns(data, c("survey", "product", "status"), "param/product.csv")
  warnings <- character()
  if (length(errors)) return(validation_result(data, errors))
  catalog <- survey_product_catalog()
  expected <- paste(catalog$survey, catalog$product, sep = "|")
  actual <- paste(data$survey, data$product, sep = "|")
  if (nrow(data) != nrow(catalog) || !setequal(actual, expected) || anyDuplicated(actual)) {
    errors <- c(errors, "param/product.csv must contain every catalog survey/product pair exactly once and no additional product.")
  }
  if (any(!data$status %in% c("TRUE", "FALSE"))) errors <- c(errors, "product.status values must be TRUE or FALSE, in uppercase and without quotes.")
  active_surveys <- surveys$survey[surveys$status == "TRUE"]
  inactive_true <- data$survey %in% setdiff(CANOBS_SURVEYS, active_surveys) & data$status == "TRUE"
  if (any(inactive_true)) errors <- c(errors, "A product cannot be TRUE when its survey is FALSE.")
  for (survey in active_surveys) {
    rows <- data$survey == survey
    if (!any(data$status[rows] == "TRUE")) errors <- c(errors, sprintf("Active survey %s must have at least one product with status TRUE.", survey))
    false_products <- data$product[rows & data$status == "FALSE"]
    if (length(false_products)) warnings <- c(warnings, sprintf("Expected products disabled for %s: %s.", survey, paste(false_products, collapse = ", ")))
    raw <- CANOBS_SURVEY_PRODUCTS[[survey]][grepl("(^|_)raw($|_)", CANOBS_SURVEY_PRODUCTS[[survey]])]
    if (length(raw) && any(data$product == raw & data$status == "FALSE") && any(rows & data$product != raw & data$status == "TRUE")) {
      errors <- c(errors, sprintf("%s is FALSE while at least one derived %s product is TRUE.", raw, survey))
    }
  }
  validation_result(data, errors, warnings)
}

validate_crownfile_param <- function(data) {
  data <- as_character_table(data)
  errors <- check_columns(data, c("param", "value"), "param/crownfile_param.csv")
  if (length(errors)) return(validation_result(data, errors))
  if (!identical(data$param, CANOBS_CROWNFILE_PARAMETERS)) errors <- c(
    errors,
    "crownfile_param.csv must contain path, server, crownfile_type, plots_list, taxa_ref, dawkins in that exact order."
  )
  values <- table_to_named(data, "param", "value")
  crown_path <- named_value_or(values, "path")
  crown_server <- named_value_or(values, "server")
  if (!nzchar(crown_path)) errors <- c(errors, "config/param/crownfile_param.csv — row 1 (path), column value: a crownfile path relative to the server root is required.")
  if (nzchar(crown_path)) {
    normalized_path <- gsub("\\\\", "/", crown_path)
    absolute_path <- grepl("^(?:[A-Za-z]:|/|\\\\)", crown_path, perl = TRUE)
    parent_segment <- grepl("(?:^|/)[.][.](?:/|$)", normalized_path, perl = TRUE)
    if (absolute_path || parent_segment) errors <- c(
      errors,
      sprintf(
        "config/param/crownfile_param.csv — row 1 (path), column value: '%s' must be relative to the configured server root and contain no '..' segment.",
        crown_path
      )
    )
    if (!identical(tolower(tools::file_ext(normalized_path)), "gpkg")) errors <- c(
      errors,
      sprintf(
        "config/param/crownfile_param.csv — row 1 (path), column value: '%s' must identify a GeoPackage file with the .gpkg extension.",
        crown_path
      )
    )
  }
  if (!nzchar(crown_server)) errors <- c(errors, "config/param/crownfile_param.csv — row 2 (server), column value: a server alias is required.")
  if (nzchar(crown_server) && !grepl("^[A-Za-z0-9_.-]+$", crown_server)) errors <- c(
    errors,
    sprintf(
      "config/param/crownfile_param.csv — row 2 (server), column value: '%s' must contain only letters, digits, underscores, hyphens, or dots.",
      crown_server
    )
  )
  if (!named_value_or(values, "crownfile_type") %in% CANOBS_CROWNFILE_TYPES) errors <- c(errors, "crownfile_type must be dynamic or light.")
  booleans <- values[c("plots_list", "taxa_ref", "dawkins")]
  if (any(!booleans %in% c("TRUE", "FALSE"))) errors <- c(errors, "plots_list, taxa_ref, and dawkins must be TRUE or FALSE.")
  validation_result(data, errors)
}

validate_tree_picture_zooms <- function(data, sensors) {
  data <- drop_fully_empty_rows(data)
  errors <- check_columns(data, c("sensor", "zoom", "zoom_type", "effective_focal"), "param/tree_picture_zooms.csv")
  if (length(errors)) return(validation_result(data, errors))
  allowed_sensors <- unique(sensors$sensor[sensors$survey == "tree_pictures"])
  unknown <- unique(data$sensor[!data$sensor %in% allowed_sensors])
  if (length(unknown)) errors <- c(errors, sprintf("tree_picture_zooms.sensor is not declared for tree_pictures: %s.", paste(unknown, collapse = ", ")))
  if (any(!grepl("^x[0-9]+$", data$zoom))) errors <- c(errors, "zoom must start with x followed by an integer, without spaces (for example x14).")
  if (any(!data$zoom_type %in% CANOBS_ZOOM_TYPES)) errors <- c(errors, "zoom_type must be exactly native or digital.")
  numeric <- suppressWarnings(as.numeric(data$effective_focal))
  if (any(is.na(numeric) | !nzchar(data$effective_focal))) errors <- c(errors, "effective_focal must be a decimal number; do not include the unit in the field.")
  key <- paste(data$sensor, data$zoom, data$zoom_type, sep = "|")
  if (anyDuplicated(key)) errors <- c(errors, "The sensor/zoom/zoom_type key must be unique.")
  missing <- setdiff(allowed_sensors, unique(data$sensor))
  if (length(missing)) errors <- c(errors, sprintf("Every tree_pictures sensor must have at least one zoom: %s.", paste(missing, collapse = ", ")))
  validation_result(data, errors)
}

validate_contributors <- function(data, repair = FALSE) {
  data <- as_character_table(data)
  errors <- check_columns(data, "contributor", "reference/contributors.csv")
  warnings <- character()
  if (length(errors)) return(validation_result(data, errors))
  empty <- !nzchar(data$contributor)
  duplicates <- duplicated(data$contributor) & nzchar(data$contributor)
  if (any(empty)) warnings <- c(warnings, "Empty contributor rows were detected.")
  if (any(duplicates)) warnings <- c(warnings, "Duplicate contributors were detected.")
  if (isTRUE(repair)) data <- data[!empty & !duplicates, , drop = FALSE]
  validation_result(data, errors, warnings)
}

validate_plots_list <- function(data, repair = FALSE) {
  data <- as_character_table(data)
  errors <- check_columns(data, "plot_name", "reference/plots_list.csv")
  warnings <- character()
  if (length(errors)) return(validation_result(data, errors))
  empty <- !nzchar(data$plot_name)
  duplicate <- duplicated(data$plot_name) & nzchar(data$plot_name)
  if (any(grepl("\\s", data$plot_name))) errors <- c(errors, "plots_list.plot_name must not contain spaces.")
  if (any(duplicate)) errors <- c(errors, "plots_list.plot_name values must be unique.")
  if (any(empty)) warnings <- c(warnings, "Empty plot_name rows were detected and can be removed.")
  if (isTRUE(repair)) data <- data[!empty, , drop = FALSE]
  validation_result(data, errors, warnings)
}

validate_dawkins_param <- function(data) {
  data <- as_character_table(data)
  errors <- check_columns(data, c("param", "value"), "param/dawkins_param.csv")
  if (length(errors)) return(validation_result(data, errors))
  if (!identical(data$param, CANOBS_DAWKINS_PARAMETERS)) errors <- c(errors, "dawkins_param.csv must contain all 14 parameters in the required order.")
  numeric <- suppressWarnings(as.numeric(data$value))
  if (any(is.na(numeric) | !nzchar(data$value))) errors <- c(errors, "Every dawkins_param.value must be numeric.")
  validation_result(data, errors)
}

validate_taxa_ref <- function(data) validation_result(as_character_table(data))

validate_uav_folder <- function(data, products, check_paths = FALSE, server_roots = NULL) {
  data <- drop_fully_empty_rows(data)
  errors <- check_columns(data, c("survey", "product", "server", "path"), "path/UAV_folder.csv")
  warnings <- character()
  if (length(errors)) return(validation_result(data, errors))
  catalog <- paste(survey_product_catalog()$survey, survey_product_catalog()$product, sep = "|")
  keys <- paste(data$survey, data$product, sep = "|")
  invalid <- unique(keys[!keys %in% catalog])
  if (length(invalid)) errors <- c(errors, sprintf("UAV_folder.csv contains unsupported survey/product pair(s): %s.", paste(invalid, collapse = ", ")))
  configured <- stats::setNames(products$status, paste(products$survey, products$product, sep = "|"))
  active <- names(configured)[configured == "TRUE"]
  missing <- setdiff(active, unique(keys[nzchar(data$server) & nzchar(data$path)]))
  if (length(missing)) warnings <- c(warnings, sprintf("Active survey/product pair(s) without a UAV folder: %s.", paste(missing, collapse = ", ")))
  inactive <- unique(keys[keys %in% names(configured)[configured == "FALSE"] & (nzchar(data$server) | nzchar(data$path))])
  if (length(inactive)) warnings <- c(warnings, sprintf("UAV folders are retained for disabled product(s): %s.", paste(inactive, collapse = ", ")))
  incomplete <- xor(nzchar(data$server), nzchar(data$path))
  if (any(incomplete)) errors <- c(errors, sprintf("UAV_folder.server and path must be filled together at row(s): %s.", paste(which(incomplete), collapse = ", ")))
  full_key <- paste(data$survey, data$product, data$server, data$path, sep = "|")
  populated <- nzchar(data$server) & nzchar(data$path)
  if (anyDuplicated(full_key[populated])) errors <- c(errors, "The survey/product/server/path combination must be unique in UAV_folder.csv.")
  invalid_path <- populated & (
    grepl("^(?:[A-Za-z]:|/|\\\\)", data$path, perl = TRUE) |
      grepl("(?:^|/)[.][.](?:/|$)", gsub("\\\\", "/", data$path), perl = TRUE)
  )
  if (any(invalid_path)) errors <- c(errors, sprintf("UAV_folder.path must be relative and contain no '..' segment at row(s): %s.", paste(which(invalid_path), collapse = ", ")))
  if (isTRUE(check_paths) && nrow(data)) {
    roots <- server_roots %||% character()
    for (i in which(nzchar(data$server) & nzchar(data$path))) {
      if (!data$server[[i]] %in% names(roots)) errors <- c(errors, sprintf("No local root was supplied for server '%s'.", data$server[[i]]))
      else if (!dir.exists(file.path(roots[[data$server[[i]]]], data$path[[i]]))) warnings <- c(warnings, sprintf("Configured UAV folder was not found for row %d.", i))
    }
  }
  validation_result(data, errors, warnings)
}

extract_pattern_tokens <- function(value) {
  matches <- regmatches(value, gregexpr("\\{[^{}]+\\}", value, perl = TRUE))[[1]]
  if (!length(matches) || identical(matches, character(0))) {
    character()
  } else {
    sub("^\\{(.*)\\}$", "\\1", matches, perl = TRUE)
  }
}

validate_uav_file_patterns <- function(data, products, folders = NULL, crownfile_vars = NULL) {
  data <- drop_fully_empty_rows(data)
  errors <- check_columns(data, c("survey", "product", "directory_pattern", "filename_pattern"), "path/UAV_file_patterns.csv")
  warnings <- character()
  if (length(errors)) return(validation_result(data, errors))
  keys <- paste(data$survey, data$product, sep = "|")
  catalog_data <- survey_product_catalog()
  catalog <- paste(catalog_data$survey, catalog_data$product, sep = "|")
  invalid <- unique(keys[!keys %in% catalog])
  if (length(invalid)) errors <- c(errors, sprintf("UAV_file_patterns.csv contains unsupported pair(s): %s.", paste(invalid, collapse = ", ")))
  if (anyDuplicated(keys)) errors <- c(errors, "UAV_file_patterns.csv must contain at most one pattern per survey/product pair.")
  configured <- stats::setNames(products$status, paste(products$survey, products$product, sep = "|"))
  active <- names(configured)[configured == "TRUE"]
  has_directory <- nzchar(data$directory_pattern)
  has_filename <- nzchar(data$filename_pattern)
  complete <- has_directory | has_filename
  both <- has_directory & has_filename
  if (any(both)) errors <- c(errors, sprintf(
    "UAV_file_patterns.csv must fill directory_pattern or filename_pattern, never both, at row(s): %s.",
    paste(which(both), collapse = ", ")
  ))
  missing <- setdiff(active, unique(keys[complete]))
  if (length(missing)) warnings <- c(warnings, sprintf("Active survey/product pair(s) without a file pattern: %s.", paste(missing, collapse = ", ")))
  if (!is.null(folders) && all(c("survey", "product", "server", "path") %in% names(folders))) {
    folder_keys <- unique(paste(
      folders$survey[nzchar(folders$server) & nzchar(folders$path)],
      folders$product[nzchar(folders$server) & nzchar(folders$path)], sep = "|"
    ))
    missing_for_folder <- setdiff(folder_keys, unique(keys[complete]))
    if (length(missing_for_folder)) warnings <- c(warnings, sprintf(
      "Configured UAV folder pair(s) without a file pattern: %s.",
      paste(missing_for_folder, collapse = ", ")
    ))
  }
  inactive <- unique(keys[keys %in% names(configured)[configured == "FALSE"] & complete])
  if (length(inactive)) warnings <- c(warnings, sprintf("File patterns are retained for disabled product(s): %s.", paste(inactive, collapse = ", ")))
  patterns <- ifelse(has_directory, data$directory_pattern, data$filename_pattern)
  for (i in which(complete)) {
    if (grepl("[/\\\\]", patterns[[i]], perl = TRUE)) {
      errors <- c(errors, sprintf(
        "UAV pattern at row %d is applied to an immediate child name and must not contain '/' or '\\\\'.",
        i
      ))
    }
    opens <- lengths(regmatches(patterns[[i]], gregexpr("{", patterns[[i]], fixed = TRUE)))
    closes <- lengths(regmatches(patterns[[i]], gregexpr("}", patterns[[i]], fixed = TRUE)))
    if (opens != closes) errors <- c(errors, sprintf("UAV pattern braces are unbalanced at row %d.", i))
    tokens <- extract_pattern_tokens(patterns[[i]])
    dynamic_crown <- grepl(
      "^crownfile[.](geometry|infos)[.][A-Za-z][A-Za-z0-9_]*(?:[|]space_to_hyphen)?$",
      tokens, perl = TRUE
    )
    light_crown <- grepl(
      "^crownfile[.][A-Za-z][A-Za-z0-9_]*(?:[|]space_to_hyphen)?$",
      tokens, perl = TRUE
    )
    supported <- tokens %in% CANOBS_PATTERN_BASE_TOKENS |
      grepl("^site[.](id_site|name|location|crs)$", tokens) |
      dynamic_crown | light_crown
    unsupported <- tokens[!supported]
    if (length(unsupported)) errors <- c(errors, sprintf("Unsupported pattern token(s) at row %d: %s.", i, paste(unsupported, collapse = ", ")))
    captured <- tokens[!tokens %in% c("product") & !grepl("^site[.](id_site|name|location|crs)$", tokens)]
    captured <- sub("[|]space_to_hyphen$", "", captured)
    captured[captured %in% names(CANOBS_DATE_PATTERN_FORMATS)] <- "date"
    if (anyDuplicated(captured)) errors <- c(errors, sprintf(
      "A captured field may occur only once in the UAV pattern at row %d.", i
    ))
    if (data$survey[[i]] != "tree_pictures" && any(tokens == "zoom")) {
      errors <- c(errors, sprintf("{zoom} is allowed only for tree_pictures patterns (row %d).", i))
    }
    date_count <- sum(tokens %in% names(CANOBS_DATE_PATTERN_FORMATS))
    if (data$survey[[i]] %in% c("RGB", "MS", "DLS") && date_count != 1L) {
      errors <- c(errors, sprintf(
        "UAV pattern at row %d must contain exactly one supported date placeholder for survey %s; found %d.",
        i, data$survey[[i]], date_count
      ))
    }
    crown_tokens <- tokens[dynamic_crown | light_crown]
    if (length(crown_tokens) && !is.null(crownfile_vars) && nrow(crownfile_vars)) {
      base_tokens <- sub("[|]space_to_hyphen$", "", crown_tokens)
      light_schema <- "layer" %in% names(crownfile_vars) &&
        identical(unique(crownfile_vars$layer), "crowns")
      if ("layer" %in% names(crownfile_vars) && !light_schema) {
        expected <- paste("crownfile", crownfile_vars$layer, crownfile_vars$var_name, sep = ".")
        wrong_shape <- light_crown[dynamic_crown | light_crown]
      } else {
        expected <- paste("crownfile", crownfile_vars$var_name, sep = ".")
        wrong_shape <- dynamic_crown[dynamic_crown | light_crown]
      }
      invalid_crown <- crown_tokens[wrong_shape | !base_tokens %in% expected]
      if (length(invalid_crown)) errors <- c(errors, sprintf(
        "Crown placeholder(s) at row %d do not match param/crownfile_vars.csv: %s.",
        i, paste(invalid_crown, collapse = ", ")
      ))
    }
  }
  validation_result(data, errors, warnings)
}

validate_crownfile_vars_definition <- function(data, params) {
  data <- as_character_table(data)
  expected <- crownfile_vars_template(
    named_value_or(params, "crownfile_type", "dynamic"),
    is_true_value(params, "plots_list"), is_true_value(params, "taxa_ref"), is_true_value(params, "dawkins")
  )
  errors <- character()
  if (!identical(data, as_character_table(expected))) errors <- "param/crownfile_vars.csv differs from the generated schema required by crownfile_param.csv."
  validation_result(data, errors)
}

read_config_table_for_validation <- function(config_directory, relative_path) {
  path <- file.path(config_directory, relative_path)
  if (!file.exists(path)) return(NULL)
  tryCatch(read_delimited_table(path), error = function(e) structure(list(error = conditionMessage(e)), class = "canobs_read_error"))
}

missing_file_result <- function(relative_path, severity = "error") {
  message <- sprintf("Required file is missing: config/%s.", gsub("\\\\", "/", relative_path))
  if (identical(severity, "warning")) validation_result(NULL, warnings = message) else validation_result(NULL, errors = message)
}

validate_generated_reference <- function(actual, expected, relative_path) {
  if (is.null(actual)) return(missing_file_result(relative_path))
  if (inherits(actual, "canobs_read_error")) return(validation_result(NULL, sprintf("Cannot read config/%s: %s.", relative_path, actual$error)))
  if (!identical(as_character_table(actual), as_character_table(expected))) {
    return(validation_result(actual, sprintf("config/%s differs from the required generated model.", relative_path)))
  }
  validation_result(actual)
}

validate_config_input_files <- function(config_directory, check_uav_paths = FALSE, server_roots = NULL) {
  details <- list()
  add <- function(path, result) details[[gsub("\\\\", "/", path)]] <<- result
  read <- function(path) read_config_table_for_validation(config_directory, path)
  required <- function(path, validator, ...) {
    data <- read(path)
    if (is.null(data)) add(path, missing_file_result(path))
    else if (inherits(data, "canobs_read_error")) add(path, validation_result(NULL, sprintf("Cannot read config/%s: %s.", path, data$error)))
    else add(path, validator(data, ...))
  }

  required(file.path("param", "site.csv"), validate_site)
  required(file.path("param", "survey.csv"), validate_survey)
  site <- details[["param/site.csv"]]$data %||% site_template()
  surveys <- details[["param/survey.csv"]]$data %||% survey_template()
  required(file.path("param", "sensor.csv"), validate_sensor, surveys = surveys)
  sensors <- details[["param/sensor.csv"]]$data %||% sensor_template()
  required(file.path("param", "product.csv"), validate_product, surveys = surveys)
  products <- details[["param/product.csv"]]$data %||% product_template()
  required(file.path("param", "crownfile_param.csv"), validate_crownfile_param)
  crown_data <- details[["param/crownfile_param.csv"]]$data %||% crownfile_param_template()
  params <- table_to_named(crown_data, "param", "value")

  tree_enabled <- any(surveys$survey == "tree_pictures" & surveys$status == "TRUE")
  zoom_path <- file.path("param", "tree_picture_zooms.csv")
  zoom_data <- read(zoom_path)
  if (tree_enabled) {
    if (is.null(zoom_data)) add(zoom_path, missing_file_result(zoom_path)) else add(zoom_path, validate_tree_picture_zooms(zoom_data, sensors))
  } else if (!is.null(zoom_data)) add(zoom_path, validation_result(zoom_data, warnings = "tree_picture_zooms.csv is present while tree_pictures is FALSE."))

  required(file.path("reference", "contributors.csv"), validate_contributors)
  for (item in list(c("plots_list", "reference/plots_list.csv"), c("taxa_ref", "reference/taxa_ref.csv"))) {
    enabled <- is_true_value(params, item[[1]])
    data <- read(item[[2]])
    if (enabled && is.null(data)) add(item[[2]], missing_file_result(item[[2]], "warning"))
    else if (!enabled && !is.null(data)) add(item[[2]], validation_result(data, warnings = sprintf("%s is present while %s is FALSE.", basename(item[[2]]), item[[1]])))
    else if (!is.null(data)) add(item[[2]], if (item[[1]] == "plots_list") validate_plots_list(data) else validate_taxa_ref(data))
  }

  dawkins_enabled <- is_true_value(params, "dawkins")
  dawkins_param_path <- file.path("param", "dawkins_param.csv")
  dawkins_param <- read(dawkins_param_path)
  if (dawkins_enabled && is.null(dawkins_param)) add(dawkins_param_path, missing_file_result(dawkins_param_path))
  else if (!dawkins_enabled && !is.null(dawkins_param)) add(dawkins_param_path, validation_result(dawkins_param, warnings = "dawkins_param.csv is present while dawkins is FALSE."))
  else if (!is.null(dawkins_param)) add(dawkins_param_path, validate_dawkins_param(dawkins_param))

  crown_vars <- read(file.path("param", "crownfile_vars.csv"))
  if (is.null(crown_vars)) add(file.path("param", "crownfile_vars.csv"), missing_file_result(file.path("param", "crownfile_vars.csv")))
  else add(file.path("param", "crownfile_vars.csv"), validate_crownfile_vars_definition(crown_vars, params))
  generated <- default_reference_tables(named_value_or(params, "crownfile_type", "dynamic"), dawkins_enabled)
  for (filename in names(generated)) {
    path <- file.path("reference", filename)
    add(path, validate_generated_reference(read(path), generated[[filename]], path))
  }
  inactive_generated <- setdiff(c("dawkins.csv", "geom_modif.csv", "tree_status.csv"), names(generated))
  for (filename in inactive_generated) {
    path <- file.path("reference", filename)
    data <- read(path)
    if (!is.null(data)) add(path, validation_result(data, warnings = sprintf("%s is present although its condition is disabled.", filename)))
  }

  required(file.path("path", "UAV_folder.csv"), validate_uav_folder, products = products, check_paths = check_uav_paths, server_roots = server_roots)
  folders <- details[["path/UAV_folder.csv"]]$data %||% uav_folder_template(products)
  required(
    file.path("path", "UAV_file_patterns.csv"), validate_uav_file_patterns,
    products = products, folders = folders, crownfile_vars = crown_vars %||% data.frame()
  )
  # vectors.csv is intentionally not read and has no effect on any diagnostic.

  errors <- unique(unlist(lapply(details, `[[`, "errors"), use.names = FALSE))
  warnings <- unique(unlist(lapply(details, `[[`, "warnings"), use.names = FALSE))
  validation_result(NULL, errors, warnings, details)
}

validate_generated_configuration <- function(config_directory, check_uav_paths = FALSE, server_roots = NULL) {
  validate_config_input_files(config_directory, check_uav_paths, server_roots)
}
