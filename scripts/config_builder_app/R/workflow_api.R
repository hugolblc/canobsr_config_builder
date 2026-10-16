print_check_messages <- function(title, result) {
  cat(title, "\n", strrep("=", nchar(title)), "\n", sep = "")
  status <- if (!isTRUE(result$ok)) {
    "FAIL"
  } else if (length(result$warnings)) {
    "PASS WITH WARNINGS"
  } else {
    "PASS"
  }
  cat(sprintf("Status: %s\n", status))
  if (length(result$errors)) cat("\nBlocking errors:\n", paste0("- ", result$errors, collapse = "\n"), "\n", sep = "")
  if (length(result$warnings)) cat("\nWarnings:\n", paste0("- ", result$warnings, collapse = "\n"), "\n", sep = "")
  if (!length(c(result$errors, result$warnings))) cat("No warning or error was detected.\n")
  invisible(result)
}

#' Check configuration parameters without accessing scientific data
#' @export
check_config_folder <- function(config_directory = "config", print_report = TRUE) {
  directory <- resolve_existing_config_directory(config_directory)
  result <- validate_generated_configuration(directory, check_uav_paths = FALSE)
  result$config_directory <- directory
  class(result) <- unique(c("canobs_config_check", class(result)))
  write_site_check_report(directory, result)
  if (isTRUE(print_report)) {
    print_check_messages("canObsR 3.1.0 configuration check", result)
    cat("\nNo scientific file, configured data path, or server was accessed.\n")
  }
  invisible(result)
}

canonical_editable_config_paths <- function() gsub("\\\\", "/", CANOBS_EDITABLE_PATHS)

resolve_config_csv_target <- function(config_directory, config_file) {
  directory <- resolve_existing_config_directory(config_directory)
  requested <- gsub("\\\\", "/", trimws(as.character(config_file[[1]])))
  requested <- sub("^config/", "", requested)
  candidates <- canonical_editable_config_paths()
  exact <- candidates[tolower(candidates) == tolower(requested)]
  if (length(exact) == 1L) return(exact[[1]])
  by_name <- candidates[tolower(basename(candidates)) == tolower(basename(requested))]
  if (length(by_name) == 1L) return(by_name[[1]])
  stop(sprintf("Unsupported editable config file: %s.", config_file), call. = FALSE)
}

read_replacement_config_table <- function(path) read_uploaded_table(path, tolower(tools::file_ext(path)))

#' Preview one configuration-table modification without writing it
#'
#' @param before_snapshot Optional snapshot captured before a sequence of edits.
#' @export
preview_config_table_change <- function(
    config_directory, config_file, data, before_snapshot = NULL,
    repair = FALSE, print_report = TRUE) {
  directory <- resolve_existing_config_directory(config_directory)
  relative <- resolve_config_csv_target(directory, config_file)
  candidate <- as_character_table(data)
  if (is.null(before_snapshot)) before_snapshot <- capture_config_snapshot(directory)
  before <- snapshot_table(before_snapshot, relative, candidate[0, , drop = FALSE])
  validation <- if (basename(relative) == "vectors.csv") {
    validation_result(candidate)
  } else {
    validate_modified_config_table(candidate, relative, directory, repair = repair)
  }
  comparison <- compare_config_tables(before, validation$data, relative)
  impacts <- config_change_impacts(directory, relative, before, validation$data)
  result <- structure(list(
    relative_path = relative,
    before = before,
    candidate = validation$data,
    validation = validation,
    comparison = comparison,
    impacts = impacts
  ), class = "canobs_change_preview")
  if (isTRUE(print_report)) {
    print_check_messages(sprintf("Candidate: config/%s", relative), validation)
    cat(sprintf(
      "\nRows: %d modified, %d added, %d deleted.\n",
      comparison$summary[["modified_rows"]], comparison$summary[["added_rows"]],
      comparison$summary[["deleted_rows"]]
    ))
    cat("Consequences for other files:\n", paste0("- ", impacts, collapse = "\n"), "\n", sep = "")
  }
  invisible(result)
}

#' Validate and save one editable configuration table
#'
#' This is the shared implementation used by Shiny and the direct R API. The
#' table is written only after its blocking checks pass. Automatic tables stay
#' deferred until workflow step 11.
#' @export
save_config_table <- function(
    config_directory, config_file, data, update_outputs = FALSE,
    cross_validate = FALSE, print_report = TRUE, repair = FALSE) {
  directory <- resolve_existing_config_directory(config_directory)
  relative <- resolve_config_csv_target(directory, config_file)
  candidate <- as_character_table(data)
  destination <- file.path(directory, relative)
  before_snapshot <- if (isTRUE(update_outputs)) capture_config_snapshot(directory) else NULL
  before_data <- if (file.exists(destination)) {
    tryCatch(read_delimited_table(destination), error = function(error) candidate[0, , drop = FALSE])
  } else {
    candidate[0, , drop = FALSE]
  }
  local <- if (basename(relative) == "vectors.csv") {
    validation_result(candidate)
  } else {
    validate_modified_config_table(candidate, relative, directory, repair = repair)
  }
  comparison <- compare_config_tables(before_data, local$data, relative)
  impacts <- config_change_impacts(directory, relative, before_data, local$data)
  if (isTRUE(print_report)) print_check_messages(sprintf("Candidate: config/%s", relative), local)
  if (!local$ok) {
    return(invisible(list(
      path = NULL, relative_path = relative, data = local$data,
      validation = local, complete_config_validation = NULL,
      outputs_updated = FALSE, comparison = comparison, impacts = impacts
    )))
  }

  path <- write_semicolon_csv(local$data, destination)
  publication <- if (isTRUE(update_outputs)) {
    generate_config_outputs(
      directory, overwrite_reference_tables = TRUE, print_report = FALSE,
      before_snapshot = before_snapshot
    )
  } else {
    NULL
  }
  global <- if (!is.null(publication)) {
    publication$validation
  } else if (isTRUE(cross_validate)) {
    validate_generated_configuration(directory, check_uav_paths = FALSE)
  } else {
    NULL
  }
  if (!is.null(global) && is.null(publication)) write_site_check_report(directory, global)
  outputs_updated <- !is.null(publication) && isTRUE(publication$validation$ok)
  if (isTRUE(print_report) && !is.null(global)) print_check_messages("Complete configuration", global)
  invisible(list(
    path = path, relative_path = relative, data = local$data,
    validation = local, complete_config_validation = global,
    outputs_updated = outputs_updated, publication = publication,
    comparison = comparison, impacts = impacts
  ))
}

#' Replace one editable configuration CSV
#'
#' Scientific data are never changed. By default, normalization is diagnostic
#' only; set `repair = TRUE` from Shiny to remove empty plot rows and duplicate
#' contributors while retaining a warning.
#' @export
update_csv_file <- function(
    config_directory, config_file, replacement_file, update_outputs = TRUE,
    cross_validate = TRUE, print_report = TRUE, repair = FALSE) {
  directory <- resolve_existing_config_directory(config_directory)
  relative <- resolve_config_csv_target(directory, config_file)
  if (basename(relative) == "vectors.csv") {
    destination <- file.path(directory, relative)
    copied <- file.copy(replacement_file, destination, overwrite = TRUE)
    if (!isTRUE(copied)) stop("vectors.csv could not be copied.", call. = FALSE)
    return(invisible(list(
      path = normalizePath(destination, winslash = "/", mustWork = TRUE),
      relative_path = relative, data = NULL, validation = validation_result(),
      complete_config_validation = NULL, outputs_updated = FALSE
    )))
  }
  candidate <- read_replacement_config_table(replacement_file)
  result <- save_config_table(
    directory, relative, candidate, update_outputs = update_outputs,
    cross_validate = cross_validate, print_report = print_report, repair = repair
  )
  if (!result$validation$ok) {
    stop(paste(
      c(
        sprintf("config/%s was not modified because it has blocking errors:", relative),
        paste0("- ", result$validation$errors)
      ),
      collapse = "\n"
    ), call. = FALSE)
  }
  invisible(result)
}

#' Check configured UAV sources and build an in-memory product inventory
#' @export
check_products_sources <- function(config_directory = "config", server_roots, print_report = TRUE) {
  result <- check_products_file(config_directory, server_roots, print_report = FALSE)
  if (isTRUE(print_report)) print_check_messages("UAV product source check", result)
  invisible(result)
}

#' Write all_products.csv after a product-source check
#' @export
write_all_products_csv <- function(product_check, print_report = TRUE) {
  if (is.null(product_check$config_directory)) stop(
    "product_check was not created by check_products_sources() or check_products_file().",
    call. = FALSE
  )
  if (!isTRUE(product_check$ok)) stop("all_products.csv cannot be written while blocking errors remain.", call. = FALSE)
  inventory <- product_check$current_inventory %||% product_check$data
  if (is.null(inventory)) stop("The successful product check contains no inventory to write.", call. = FALSE)
  destination <- write_products_inventory(product_check$config_directory, inventory)
  report_warnings <- product_check$warnings %||% character()
  report_warnings <- report_warnings[!grepl(
    "^all_products[.]csv (has not been generated|is not current:)", report_warnings
  )]
  write_products_check_report(
    product_check$config_directory, inventory, product_check$inconsistencies %||% character(),
    report_warnings, product_check$errors, TRUE
  )
  if (isTRUE(print_report)) cat(sprintf("Written: %s\n", destination))
  invisible(destination)
}

empty_raw_processed_comparison <- function(group_by_processed_status = FALSE) {
  if (isTRUE(group_by_processed_status)) {
    return(data.frame(
      processed_product = character(), status = character(), raw_count = integer(),
      processed_count = integer(), stringsAsFactors = FALSE, check.names = FALSE
    ))
  }
  data.frame(
    survey = character(), date = character(), raw_product = character(),
    processed_product = character(), raw_count = integer(), processed_count = integer(),
    status = character(), stringsAsFactors = FALSE, check.names = FALSE
  )
}

#' Compare observed raw and processed products in all_products.csv
#'
#' Set `group_by_processed_status = TRUE` to sum raw and processed object counts
#' for each processed product and comparison status.
#' @export
compare_raw_processed <- function(
    config_directory = "config", products = NULL, as_datatable = FALSE,
    group_by_processed_status = FALSE) {
  if (is.null(products)) {
    directory <- resolve_existing_config_directory(config_directory)
    path <- file.path(directory, "all_products.csv")
    if (!file.exists(path)) stop("all_products.csv has not been generated.", call. = FALSE)
    products <- read_delimited_table(path)
  }
  products <- as_character_table(products)
  required <- c("survey", "product", "date")
  if (!all(required %in% names(products))) result <- empty_raw_processed_comparison() else {
    rows <- list()
    for (survey in intersect(c("RGB", "MS", "DLS"), unique(products$survey))) {
      catalog <- CANOBS_SURVEY_PRODUCTS[[survey]]
      raw <- catalog[grepl("_raw$", catalog)]
      derived <- setdiff(catalog, raw)
      dates <- unique(products$date[products$survey == survey & nzchar(products$date)])
      for (date in dates) for (processed in derived) {
        raw_count <- sum(products$survey == survey & products$date == date & products$product == raw)
        processed_count <- sum(products$survey == survey & products$date == date & products$product == processed)
        rows[[length(rows) + 1L]] <- data.frame(
          survey = survey, date = date, raw_product = raw, processed_product = processed,
          raw_count = raw_count, processed_count = processed_count,
          status = if (raw_count > 0L && processed_count > 0L) "completed" else if (processed_count > 0L) "processed_without_raw" else "missing_processed",
          stringsAsFactors = FALSE, check.names = FALSE
        )
      }
    }
    result <- if (length(rows)) do.call(rbind, rows) else empty_raw_processed_comparison()
  }
  if (isTRUE(group_by_processed_status)) {
    result <- if (!nrow(result)) {
      empty_raw_processed_comparison(TRUE)
    } else {
      grouped <- stats::aggregate(
        result[, c("raw_count", "processed_count"), drop = FALSE],
        by = result[, c("processed_product", "status"), drop = FALSE],
        FUN = sum
      )
      grouped[order(grouped$processed_product, grouped$status), , drop = FALSE]
    }
  }
  if (isTRUE(as_datatable)) {
    DT::datatable(
      result, rownames = FALSE, filter = "top",
      options = list(pageLength = 25, scrollX = TRUE)
    )
  } else result
}
