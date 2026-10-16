product_inventory_result <- function(data, errors = character(), warnings = character(), inconsistencies = character()) {
  result <- validation_result(data, errors, warnings)
  result$inconsistencies <- unique(as.character(inconsistencies))
  result$exportable <- result$ok
  class(result) <- unique(c("canobs_product_inventory", class(result)))
  result
}

escape_regex_literal <- function(value) gsub("([][{}()+.^$|\\\\])", "\\\\\\1", as.character(value), perl = TRUE)

portable_path_join <- function(...) {
  parts <- gsub("\\\\", "/", unlist(list(...)))
  parts <- gsub("^/+|/+$", "", parts)
  value <- paste(Filter(nzchar, parts), collapse = "/")
  gsub("/+", "/", value)
}

site_placeholder_value <- function(token, site_values) {
  if (!startsWith(token, "site.")) return(NULL)
  key <- sub("^site[.]", "", token)
  if (!key %in% CANOBS_SITE_PARAMETERS) return(NULL)
  named_value_or(site_values, key)
}

pattern_capture <- function(token) {
  if (token %in% names(CANOBS_DATE_PATTERN_FORMATS)) {
    expression <- switch(token, date = "([0-9]{8})", `date:%Y-%m-%d` = "([0-9]{4}-[0-9]{2}-[0-9]{2})", `date:%Y_%m_%d` = "([0-9]{4}_[0-9]{2}_[0-9]{2})")
    return(list(regex = expression, field = "date", format = CANOBS_DATE_PATTERN_FORMATS[[token]], transform = ""))
  }
  simple <- c(site = "site", sensor = "sensor", zoom = "zoom", `capture.picture_code` = "capture.picture_code", original_name = "original_name", extension = "extension")
  if (token %in% names(simple)) return(list(regex = "(.+?)", field = unname(simple[[token]]), format = "", transform = ""))
  crown_token <- grepl(
    "^crownfile(?:[.](?:geometry|infos))?[.][A-Za-z][A-Za-z0-9_]*(?:[|]space_to_hyphen)?$",
    token, perl = TRUE
  )
  if (crown_token) {
    transform <- if (grepl("[|]space_to_hyphen$", token, perl = TRUE)) "space_to_hyphen" else ""
    field <- sub("[|]space_to_hyphen$", "", token)
    return(list(regex = "(.+?)", field = field, format = "", transform = transform))
  }
  NULL
}

template_to_regex <- function(template, product, site_values) {
  template <- gsub("\\\\", "/", as.character(template %||% ""))
  expression <- "^"
  fields <- formats <- transforms <- character()
  position <- 1L
  while (position <= nchar(template)) {
    ch <- substr(template, position, position)
    if (ch == "{") {
      remainder <- substr(template, position, nchar(template))
      closing <- regexpr("}", remainder, fixed = TRUE)[[1]]
      if (closing < 2L) stop(sprintf("Unbalanced placeholder in pattern: %s.", template), call. = FALSE)
      token <- substr(remainder, 2L, closing - 1L)
      if (token == "product") expression <- paste0(expression, escape_regex_literal(product))
      else {
        site_value <- site_placeholder_value(token, site_values)
        if (!is.null(site_value)) expression <- paste0(expression, escape_regex_literal(site_value))
        else {
          capture <- pattern_capture(token)
          if (is.null(capture)) stop(sprintf("Unsupported pattern placeholder: {%s}.", token), call. = FALSE)
          expression <- paste0(expression, capture$regex)
          fields <- c(fields, capture$field)
          formats <- c(formats, capture$format)
          transforms <- c(transforms, capture$transform)
        }
      }
      position <- position + closing
    } else if (ch == "*") { expression <- paste0(expression, ".*"); position <- position + 1L
    } else if (ch == "?") { expression <- paste0(expression, "."); position <- position + 1L
    } else { expression <- paste0(expression, escape_regex_literal(ch)); position <- position + 1L }
  }
  if (anyDuplicated(fields)) stop("A captured field may occur only once in a pattern.", call. = FALSE)
  list(regex = paste0(expression, "$"), fields = fields, formats = formats, transforms = transforms)
}

extract_pattern_values <- function(paths, specification) {
  matched <- regexec(specification$regex, paths, perl = TRUE)
  captured <- regmatches(paths, matched)
  keep <- lengths(captured) > 0L
  if (!any(keep) || !length(specification$fields)) return(list(keep = keep, values = data.frame()))
  matrix <- do.call(rbind, lapply(captured[keep], function(x) x[-1L]))
  values <- as.data.frame(matrix, stringsAsFactors = FALSE, check.names = FALSE)
  names(values) <- specification$fields
  for (i in seq_along(specification$fields)) {
    if (nzchar(specification$formats[[i]])) {
      field <- specification$fields[[i]]
      parsed <- as.Date(values[[field]], format = specification$formats[[i]])
      values[[field]][!is.na(parsed)] <- format(parsed[!is.na(parsed)], "%Y%m%d")
    }
    if (identical(specification$transforms[[i]], "space_to_hyphen")) {
      field <- specification$fields[[i]]
      values[[field]] <- gsub("-", " ", values[[field]], fixed = TRUE)
    }
  }
  list(keep = keep, values = values)
}

bind_inventory_rows <- function(rows) {
  rows <- rows[vapply(rows, nrow, integer(1)) > 0L]
  if (!length(rows)) return(data.frame(
    survey = character(), product = character(), server = character(), configured_path = character(),
    relative_path = character(), object_name = character(), object_type = character(),
    stringsAsFactors = FALSE, check.names = FALSE
  ))
  columns <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(row) {
    for (name in setdiff(columns, names(row))) row[[name]] <- ""
    row[, columns, drop = FALSE]
  })
  result <- do.call(rbind, rows); rownames(result) <- NULL; result
}

generate_products_inventory <- function(config_directory, server_roots, diagnostic = NULL) {
  directory <- resolve_existing_config_directory(config_directory)
  server_roots <- resolve_directory_roots(server_roots)
  folders <- read_delimited_table(file.path(directory, "path", "UAV_folder.csv"))
  patterns <- read_delimited_table(file.path(directory, "path", "UAV_file_patterns.csv"))
  products <- read_delimited_table(file.path(directory, "param", "product.csv"))
  sensors <- read_delimited_table(file.path(directory, "param", "sensor.csv"))
  crown_vars <- read_delimited_table(file.path(directory, "param", "crownfile_vars.csv"))
  site <- table_to_named(read_delimited_table(file.path(directory, "param", "site.csv")), "param", "site_value")
  config_check <- validate_uav_folder(folders, products, check_paths = TRUE, server_roots = server_roots)
  pattern_check <- validate_uav_file_patterns(patterns, products, folders, crown_vars)
  errors <- c(config_check$errors, pattern_check$errors)
  warnings <- c(config_check$warnings, pattern_check$warnings)
  if (length(errors)) return(product_inventory_result(data.frame(), errors, warnings))

  rows <- list(); inconsistencies <- character()
  for (i in seq_len(nrow(folders))) {
    folder <- folders[i, , drop = FALSE]
    if (!nzchar(folder$server) || !nzchar(folder$path)) next
    pair <- patterns$survey == folder$survey & patterns$product == folder$product
    if (!any(pair)) next
    pattern <- patterns[which(pair)[[1]], , drop = FALSE]
    root <- file.path(server_roots[[folder$server]], folder$path)
    if (!dir.exists(root)) next
    directory_only <- nzchar(pattern$directory_pattern) && !nzchar(pattern$filename_pattern)
    filename_only <- !nzchar(pattern$directory_pattern) && nzchar(pattern$filename_pattern)
    if (directory_only) {
      objects <- list.dirs(root, recursive = FALSE, full.names = FALSE)
      objects <- objects[nzchar(objects) & objects != "."]
      object_type <- "directory"
    } else if (filename_only) {
      objects <- list.files(root, recursive = FALSE, full.names = FALSE, include.dirs = FALSE, all.files = FALSE)
      object_type <- "file"
    } else {
      next
    }
    objects <- gsub("\\\\", "/", objects)
    template <- portable_path_join(pattern$directory_pattern, pattern$filename_pattern)
    if (!nzchar(template)) next
    specification <- tryCatch(template_to_regex(template, folder$product, site), error = function(e) e)
    if (inherits(specification, "error")) {
      errors <- c(errors, sprintf("Pattern for %s/%s is invalid: %s", folder$survey, folder$product, conditionMessage(specification)))
      next
    }
    extracted <- extract_pattern_values(objects, specification)
    if (!any(extracted$keep)) {
      warnings <- c(warnings, sprintf("No object matches the configured pattern for %s/%s in %s.", folder$survey, folder$product, root))
      next
    }
    matched <- objects[extracted$keep]
    base <- data.frame(
      survey = folder$survey, product = folder$product, server = folder$server,
      configured_path = folder$path, relative_path = matched,
      object_name = basename(matched), object_type = object_type,
      stringsAsFactors = FALSE, check.names = FALSE
    )
    if (ncol(extracted$values)) base <- cbind(base, extracted$values)
    rows[[length(rows) + 1L]] <- base
  }
  inventory <- bind_inventory_rows(rows)
  if (nrow(inventory) && "sensor" %in% names(inventory)) {
    for (i in which(nzchar(inventory$sensor))) {
      declared <- sensors$survey == inventory$survey[[i]] & sensors$sensor == inventory$sensor[[i]]
      if (!any(declared)) {
        inconsistencies <- c(inconsistencies, sprintf(
          "Observed sensor '%s' is not declared for survey %s (%s).",
          inventory$sensor[[i]], inventory$survey[[i]], inventory$relative_path[[i]]
        ))
        next
      }
      if ("date" %in% names(inventory) && nzchar(inventory$date[[i]])) {
        observed_date <- parse_canobs_date(inventory$date[[i]])
        starts <- parse_canobs_date(sensors$start_date[declared])
        ends <- parse_canobs_date(sensors$end_date[declared])
        ends[sensors$status[declared] == "active" & is.na(ends)] <- Sys.Date()
        covered <- !is.na(observed_date) & any(!is.na(starts) & !is.na(ends) & observed_date >= starts & observed_date <= ends)
        if (!covered) inconsistencies <- c(inconsistencies, sprintf(
          "Observed date %s is outside the inclusive configured period for sensor '%s' and survey %s (%s).",
          inventory$date[[i]], inventory$sensor[[i]], inventory$survey[[i]], inventory$relative_path[[i]]
        ))
      }
    }
  }
  enabled <- paste(products$survey[products$status == "TRUE"], products$product[products$status == "TRUE"], sep = "|")
  if (nrow(inventory)) {
    inactive <- !paste(inventory$survey, inventory$product, sep = "|") %in% enabled
    if (any(inactive)) warnings <- c(warnings, "Objects were found for one or more products with status FALSE.")
  }
  if (length(inconsistencies)) warnings <- c(warnings, inconsistencies)
  product_inventory_result(inventory, errors, warnings, inconsistencies)
}

write_products_check_report <- function(
    config_directory, products, inconsistencies = character(), warnings = character(),
    errors = character(), inventory_written = FALSE) {
  inconsistencies <- unique(as.character(inconsistencies))
  warnings <- setdiff(unique(as.character(warnings)), inconsistencies)
  lines <- c(
    "canObsR product inventory check — schema 3.1.0",
    sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    sprintf("Inventory: %d object(s)", nrow(as.data.frame(products))),
    sprintf("all_products.csv: %s", if (isTRUE(inventory_written)) "present" else "not written"), ""
  )
  if (length(errors)) lines <- c(lines, "ERRORS", paste0("- ", unique(errors)), "")
  if (length(warnings)) lines <- c(lines, "WARNINGS", paste0("- ", unique(warnings)), "")
  if (length(inconsistencies)) lines <- c(lines, "INCONSISTENCIES", paste0("- ", unique(inconsistencies)), "")
  if (!length(c(errors, warnings, inconsistencies))) lines <- c(lines, "No warning or error was detected.")
  write_utf8_text_file(lines, file.path(config_directory, "products_check.txt"))
}

write_products_inventory <- function(config_directory, products, diagnostic = NULL) {
  write_semicolon_csv(products, file.path(config_directory, "all_products.csv"))
}
