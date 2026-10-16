config_snapshot_paths <- function(config_directory) {
  directory <- resolve_existing_config_directory(config_directory)
  nested <- unlist(lapply(c("param", "reference", "path", "archive"), function(folder) {
    root <- file.path(directory, folder)
    if (!dir.exists(root)) return(character())
    list.files(root, recursive = TRUE, full.names = TRUE, all.files = FALSE)
  }), use.names = FALSE)
  root_files <- list.files(directory, recursive = FALSE, full.names = TRUE, all.files = FALSE)
  root_files <- root_files[grepl(
    "^(observatory[.]yaml|site_check[.]txt)$",
    basename(root_files), perl = TRUE
  )]
  paths <- unique(c(nested, root_files))
  paths[file.exists(paths) & !dir.exists(paths)]
}

#' Capture the editable and generated text files of a config folder
#'
#' Keep this object before modifying a published configuration, then pass it to
#' `generate_config_outputs()` so the publication report can describe the full
#' before/after change set.
#' @export
capture_config_snapshot <- function(config_directory = "config") {
  directory <- resolve_existing_config_directory(config_directory)
  paths <- config_snapshot_paths(directory)
  root <- paste0(directory, "/")
  files <- lapply(paths, function(path) {
    relative <- substring(normalizePath(path, winslash = "/", mustWork = TRUE), nchar(root) + 1L)
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    table <- if (tolower(tools::file_ext(path)) == "csv") {
      tryCatch(read_delimited_table(path), error = function(error) NULL)
    } else {
      NULL
    }
    list(relative_path = relative, lines = lines, table = table)
  })
  names(files) <- vapply(files, `[[`, character(1), "relative_path")
  structure(
    list(
      config_directory = directory,
      captured_at = Sys.time(),
      files = files
    ),
    class = "canobs_config_snapshot"
  )
}

snapshot_table <- function(snapshot, relative_path, fallback = data.frame()) {
  relative <- gsub("\\\\", "/", relative_path)
  if (is.null(snapshot) || is.null(snapshot$files[[relative]]) || is.null(snapshot$files[[relative]]$table)) {
    return(as_character_table(fallback))
  }
  as_character_table(snapshot$files[[relative]]$table)
}

snapshot_file_lines <- function(snapshot, relative_path) {
  relative <- gsub("\\\\", "/", relative_path)
  if (is.null(snapshot) || is.null(snapshot$files[[relative]])) return(NULL)
  snapshot$files[[relative]]$lines
}

table_identity_columns <- function(relative_path, data) {
  filename <- basename(relative_path)
  proposed <- switch(
    filename,
    "site.csv" = "param",
    "survey.csv" = "survey",
    "sensor.csv" = c("survey", "sensor", "start_date"),
    "product.csv" = c("survey", "product"),
    "crownfile_param.csv" = "param",
    "tree_picture_zooms.csv" = c("sensor", "zoom", "zoom_type"),
    "contributors.csv" = "contributor",
    "plots_list.csv" = "plot_name",
    "dawkins_param.csv" = "param",
    "taxa_ref.csv" = if (ncol(data)) names(data)[[1]] else character(),
    "UAV_folder.csv" = c("survey", "product", "server", "path"),
    "UAV_file_patterns.csv" = c("survey", "product"),
    "vectors.csv" = if ("file" %in% names(data)) "file" else character(),
    character()
  )
  intersect(proposed, names(data))
}

table_row_keys <- function(data, key_columns = character()) {
  data <- as_character_table(data)
  if (!nrow(data)) return(character())
  if (!length(key_columns) || !all(key_columns %in% names(data))) {
    return(sprintf(".row:%09d", seq_len(nrow(data))))
  }
  values <- do.call(paste, c(data[key_columns], sep = "\u001f"))
  if (any(!nzchar(values)) || anyDuplicated(values)) return(sprintf(".row:%09d", seq_len(nrow(data))))
  values
}

#' Compare the old and new versions of one configuration table
#'
#' The returned row and cell positions are used by both the Shiny comparison
#' view and the direct-R modification report.
#' @export
compare_config_tables <- function(before, after, relative_path = "") {
  before <- as_character_table(before)
  after <- as_character_table(after)
  key_columns <- unique(c(
    table_identity_columns(relative_path, before),
    table_identity_columns(relative_path, after)
  ))
  if (!all(key_columns %in% names(before)) || !all(key_columns %in% names(after))) key_columns <- character()
  before_keys <- table_row_keys(before, key_columns)
  after_keys <- table_row_keys(after, key_columns)
  matched <- intersect(before_keys, after_keys)

  before_status <- rep("unchanged", nrow(before))
  after_status <- rep("unchanged", nrow(after))
  before_cells <- replicate(nrow(before), integer(), simplify = FALSE)
  after_cells <- replicate(nrow(after), integer(), simplify = FALSE)

  deleted <- which(!before_keys %in% after_keys)
  added <- which(!after_keys %in% before_keys)
  before_status[deleted] <- "deleted"
  after_status[added] <- "added"

  common_columns <- intersect(names(before), names(after))
  for (key in matched) {
    old_row <- match(key, before_keys)
    new_row <- match(key, after_keys)
    changed_common <- common_columns[vapply(common_columns, function(column) {
      !identical(before[[column]][[old_row]], after[[column]][[new_row]])
    }, logical(1))]
    changed_before <- union(changed_common, setdiff(names(before), names(after)))
    changed_after <- union(changed_common, setdiff(names(after), names(before)))
    if (length(changed_before) || length(changed_after)) {
      before_status[[old_row]] <- "modified"
      after_status[[new_row]] <- "modified"
      before_cells[[old_row]] <- match(changed_before, names(before))
      after_cells[[new_row]] <- match(changed_after, names(after))
    } else if (!identical(old_row, new_row)) {
      before_status[[old_row]] <- "modified"
      after_status[[new_row]] <- "modified"
      before_cells[[old_row]] <- seq_len(ncol(before))
      after_cells[[new_row]] <- seq_len(ncol(after))
    }
  }

  structure(list(
    relative_path = gsub("\\\\", "/", relative_path),
    before = before,
    after = after,
    key_columns = key_columns,
    before_row_status = before_status,
    after_row_status = after_status,
    before_modified_cells = before_cells,
    after_modified_cells = after_cells,
    changed = !identical(before, after),
    summary = c(
      modified_rows = sum(after_status == "modified"),
      added_rows = sum(after_status == "added"),
      deleted_rows = sum(before_status == "deleted")
    )
  ), class = "canobs_table_comparison")
}

named_table_values <- function(data, key, value) {
  data <- as_character_table(data)
  if (!all(c(key, value) %in% names(data))) return(setNames(character(), character()))
  stats::setNames(data[[value]], data[[key]])
}

changed_named_entries <- function(before, after, key, value) {
  old <- named_table_values(before, key, value)
  new <- named_table_values(after, key, value)
  entries <- union(names(old), names(new))
  entries[vapply(entries, function(entry) {
    !identical(named_value_or(old, entry, NA_character_), named_value_or(new, entry, NA_character_))
  }, logical(1))]
}

#' Explain the cross-file effects of a candidate configuration change
#' @export
config_change_impacts <- function(config_directory, relative_path, before, after) {
  directory <- resolve_existing_config_directory(config_directory)
  relative <- gsub("\\\\", "/", relative_path)
  filename <- basename(relative)
  comparison <- compare_config_tables(before, after, relative)
  if (!isTRUE(comparison$changed)) return("No pending change was detected for this file.")

  impacts <- character()
  add <- function(...) impacts <<- c(impacts, sprintf(...))
  if (filename == "site.csv") {
    fields <- changed_named_entries(before, after, "param", "site_value")
    if ("name" %in% fields) add("The site HTML report filename will change and a new report will be generated at publication.")
    if ("id_site" %in% fields) add("Crownfile site values and any {site.id_site} patterns must be checked against the new id_site.")
    if (any(fields %in% c("id_site", "name", "location", "crs"))) add("observatory.yaml and the site HTML report must be regenerated.")
  } else if (filename == "survey.csv") {
    old <- named_table_values(before, "survey", "status")
    new <- named_table_values(after, "survey", "status")
    changed <- union(names(old), names(new))
    changed <- changed[vapply(changed, function(name) !identical(named_value_or(old, name, ""), named_value_or(new, name, "")), logical(1))]
    activated <- changed[vapply(changed, function(name) identical(named_value_or(new, name), "TRUE"), logical(1))]
    deactivated <- setdiff(changed, activated)
    if (length(activated)) add("Activated survey(s) %s require compatible rows in sensor.csv and product.csv.", paste(activated, collapse = ", "))
    if ("tree_pictures" %in% activated) add("param/tree_picture_zooms.csv must be created and filled for every tree_pictures sensor.")
    if (length(deactivated)) add("Rows linked to deactivated survey(s) %s must be reviewed in sensor.csv, product.csv, UAV_folder.csv, and UAV_file_patterns.csv.", paste(deactivated, collapse = ", "))
    add("all_products.csv and products_check.txt must be rebuilt after the configuration is published.")
  } else if (filename == "sensor.csv") {
    add("Sensor/date periods used by UAV_file_patterns.csv and product discovery must be rechecked.")
    add("If tree_pictures sensors changed, param/tree_picture_zooms.csv must contain matching zoom rows.")
  } else if (filename == "product.csv") {
    required <- c("survey", "product", "status")
    changed <- if (all(required %in% names(before)) && all(required %in% names(after))) {
      changed_named_entries(
        transform(before, key = paste(survey, product, sep = "/")),
        transform(after, key = paste(survey, product, sep = "/")),
        "key", "status"
      )
    } else {
      character()
    }
    if (length(changed)) add("Changed product(s) %s require matching review in UAV_folder.csv and UAV_file_patterns.csv.", paste(changed, collapse = ", "))
    add("all_products.csv and products_check.txt must be rebuilt after publication.")
  } else if (filename == "crownfile_param.csv") {
    old <- named_table_values(before, "param", "value")
    new <- named_table_values(after, "param", "value")
    changed <- changed_named_entries(before, after, "param", "value")
    if (any(changed %in% c("path", "server"))) add("The crownfile address changed: operation 3 will resolve the new path from the matching server root and rerun all crownfile checks.")
    if ("crownfile_type" %in% changed) {
      new_type <- named_value_or(new, "crownfile_type")
      add("param/crownfile_vars.csv will be regenerated; crownfile layers and crown placeholders in UAV_file_patterns.csv must match the new %s schema.", new_type)
      if (identical(new_type, "light")) add("The light crownfile must be a .gpkg containing exactly one spatial layer named crowns.")
    }
    conditional <- c(plots_list = "reference/plots_list.csv", taxa_ref = "reference/taxa_ref.csv", dawkins = "param/dawkins_param.csv")
    for (flag in intersect(names(conditional), changed)) {
      active <- identical(named_value_or(new, flag), "TRUE")
      if (active) add("%s is now activated: create and fill config/%s.", flag, conditional[[flag]])
      else add("%s is now deactivated: config/%s is no longer required and will be reported if retained.", flag, conditional[[flag]])
    }
    if ("dawkins" %in% changed) add("reference/dawkins.csv will be generated or deactivated with the Dawkins option.")
    if ("crownfile_type" %in% changed) add("reference/geom_modif.csv and reference/tree_status.csv are generated only for the dynamic schema.")
  } else if (filename == "tree_picture_zooms.csv") {
    add("tree_pictures product discovery and any {zoom} pattern must be checked against the revised zoom catalogue.")
  } else if (filename == "contributors.csv") {
    add("Crownfile creator values must be checked against reference/contributors.csv; missing correspondences remain warnings.")
  } else if (filename == "plots_list.csv") {
    add("Crownfile plot_name values must be checked against reference/plots_list.csv; missing correspondences remain warnings.")
  } else if (filename == "dawkins_param.csv") {
    add("reference/dawkins.csv and subsequent Dawkins classification outputs must be regenerated or rechecked.")
  } else if (filename == "taxa_ref.csv") {
    add("taxa_ref.csv contents are not validated in schema 3.1.0, but downstream taxonomic joins may need to be rerun.")
  } else if (filename == "UAV_folder.csv") {
    add("Product discovery paths changed: rebuild all_products.csv and products_check.txt.")
  } else if (filename == "UAV_file_patterns.csv") {
    add("Product discovery rules changed: rebuild all_products.csv and products_check.txt and review newly unmatched objects.")
  } else if (filename == "vectors.csv") {
    add("No other file is affected: vectors.csv is stored but never read by the schema 3.1.0 workflow.")
  }
  if (!length(impacts)) add("observatory.yaml, site_check.txt, and the site HTML report must be regenerated.")
  unique(impacts)
}

diff_config_snapshots <- function(before_snapshot, after_snapshot) {
  before_files <- before_snapshot$files %||% list()
  after_files <- after_snapshot$files %||% list()
  paths <- sort(union(names(before_files), names(after_files)))
  changes <- lapply(paths, function(relative) {
    before <- before_files[[relative]]
    after <- after_files[[relative]]
    status <- if (is.null(before)) "created" else if (is.null(after)) "deleted" else if (!identical(before$lines, after$lines)) "modified" else "unchanged"
    list(
      relative_path = relative,
      status = status,
      before = if (is.null(before)) NULL else before$lines,
      after = if (is.null(after)) NULL else after$lines,
      before_table = if (is.null(before)) NULL else before$table,
      after_table = if (is.null(after)) NULL else after$table
    )
  })
  changes[vapply(changes, function(change) change$status != "unchanged", logical(1))]
}

publication_id <- function(config_directory, date = Sys.Date()) {
  directory <- resolve_existing_config_directory(config_directory)
  archive <- file.path(directory, "archive")
  day <- format(as.Date(date), "%Y%m%d")
  index <- 1L
  repeat {
    id <- if (index == 1L) day else paste0(day, "_", index)
    occupied <- c(
      file.path(archive, paste0("observatory_before_", id, ".yaml")),
      file.path(archive, paste0("site_check_before_", id, ".txt")),
      file.path(archive, paste0("modification_", id, ".txt")),
      file.path(directory, paste0("modification_", id, ".txt"))
    )
    if (!any(file.exists(occupied))) return(id)
    index <- index + 1L
  }
}

move_file_preserving_name <- function(source, destination) {
  if (!file.exists(source)) return(NULL)
  if (file.exists(destination)) stop(sprintf("Archive destination already exists: %s", destination), call. = FALSE)
  if (!file.rename(source, destination)) {
    if (!file.copy(source, destination, overwrite = FALSE)) stop(sprintf("Could not archive: %s", source), call. = FALSE)
    unlink(source)
  }
  normalizePath(destination, winslash = "/", mustWork = TRUE)
}

archive_previous_publication <- function(config_directory, date = Sys.Date()) {
  directory <- resolve_existing_config_directory(config_directory)
  archive <- file.path(directory, "archive")
  dir.create(archive, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(archive)) stop("Could not create config/archive.", call. = FALSE)
  old_reports <- list.files(
    directory,
    pattern = "^modification_[0-9]{8}(?:_[0-9]+)?[.]txt$",
    full.names = TRUE, recursive = FALSE
  )
  moved_reports <- vapply(old_reports, function(path) {
    move_file_preserving_name(path, file.path(archive, basename(path))) %||% ""
  }, character(1))
  id <- publication_id(directory, date)
  archived <- c(
    moved_reports[nzchar(moved_reports)],
    observatory = move_file_preserving_name(
      file.path(directory, "observatory.yaml"),
      file.path(archive, paste0("observatory_before_", id, ".yaml"))
    ) %||% "",
    site_check = move_file_preserving_name(
      file.path(directory, "site_check.txt"),
      file.path(archive, paste0("site_check_before_", id, ".txt"))
    ) %||% ""
  )
  list(id = id, archive_directory = normalizePath(archive, winslash = "/", mustWork = TRUE), files = archived[nzchar(archived)])
}

indent_report_lines <- function(lines) {
  if (is.null(lines) || !length(lines)) return("  | <empty file>")
  paste0("  | ", lines)
}

report_file_lines <- function(lines, relative_path) {
  raw_extension <- tolower(tools::file_ext(relative_path)) %in% c("csv", "yaml", "yml")
  if (raw_extension) {
    # CSV and YAML lines must remain byte-for-byte copyable: no indentation,
    # bullets, quotation fences, or other report decoration is added.
    if (is.null(lines) || !length(lines)) return(character())
    return(lines)
  }
  indent_report_lines(lines)
}

write_modification_report <- function(config_directory, before_snapshot, after_snapshot, id) {
  directory <- resolve_existing_config_directory(config_directory)
  changes <- diff_config_snapshots(before_snapshot, after_snapshot)
  # YAML before/after blocks are usually much longer than the CSV changes.
  # Keep every YAML entry at the end of the report for easier navigation.
  yaml_change <- vapply(
    changes,
    function(change) tolower(tools::file_ext(change$relative_path)) %in% c("yaml", "yml"),
    logical(1)
  )
  changes <- c(changes[!yaml_change], changes[yaml_change])
  lines <- c(
    "canObsR configuration modification report — schema 3.1.0",
    sprintf("Publication: %s", id),
    sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    "SUMMARY"
  )
  statuses <- vapply(changes, `[[`, character(1), "status")
  for (status in c("modified", "created", "deleted")) {
    lines <- c(lines, sprintf("  %s: %d", toupper(status), sum(statuses == status)))
  }
  if (!length(changes)) lines <- c(lines, "", "No file change was detected.")

  for (change in changes) {
    lines <- c(lines, "", strrep("=", 78), sprintf("[%s] config/%s", toupper(change$status), change$relative_path))
    archived_history <- grepl("^archive/", change$relative_path)
    if (archived_history) {
      lines <- c(lines, "", "ARCHIVED CONTENT", "  | Content retained in config/archive and not duplicated in this report.")
    } else {
      extension <- tolower(tools::file_ext(change$relative_path))
      raw_label <- if (extension == "csv") "RAW CSV" else if (extension %in% c("yaml", "yml")) "RAW YAML" else ""
      if (change$status %in% c("modified", "deleted")) lines <- c(
        lines, "", if (nzchar(raw_label)) paste("BEFORE —", raw_label) else "BEFORE",
        report_file_lines(change$before, change$relative_path)
      )
      if (change$status %in% c("modified", "created")) lines <- c(
        lines, "", if (nzchar(raw_label)) paste("AFTER —", raw_label) else "AFTER",
        report_file_lines(change$after, change$relative_path)
      )
    }
    if (!archived_history && (!is.null(change$before_table) || !is.null(change$after_table))) {
      impacts <- config_change_impacts(
        directory, change$relative_path,
        change$before_table %||% data.frame(), change$after_table %||% data.frame()
      )
      impacts <- impacts[!grepl("site HTML report", impacts, fixed = TRUE)]
      if (length(impacts)) lines <- c(lines, "", "IMPACT ON OTHER FILES", paste0("  - ", impacts))
    }
  }
  write_utf8_text_file(lines, file.path(directory, paste0("modification_", id, ".txt")))
}
