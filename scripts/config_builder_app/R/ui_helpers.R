status_badge <- function(done) {
  if (isTRUE(done)) {
    shiny::span(class = "status-done", "✓")
  } else {
    shiny::span(class = "status-pending", "○")
  }
}

progress_group <- function(title, items) {
  shiny::tagList(
    shiny::tags$h4(title),
    shiny::tags$ul(
      class = "progress-list",
      lapply(items, function(item) {
        shiny::tags$li(status_badge(item$done), shiny::span(item$label))
      })
    )
  )
}

validation_panel <- function(result) {
  if (is.null(result)) {
    return(NULL)
  }

  blocks <- list()
  if (length(result$errors)) {
    error_count <- length(result$errors)
    blocks <- c(blocks, list(shiny::div(
      class = "validation-errors",
      shiny::tags$strong(sprintf(
        "%d blocking correction%s — this file cannot be saved yet",
        error_count,
        if (identical(error_count, 1L)) "" else "s"
      )),
      shiny::tags$p(
        "Fix the item(s) below, then click 'Validate, save, and continue' again."
      ),
      shiny::tags$ul(lapply(result$errors, shiny::tags$li))
    )))
  }
  if (length(result$warnings)) {
    blocks <- c(blocks, list(shiny::div(
      class = "validation-warnings",
      shiny::tags$strong(if (isTRUE(result$ok)) {
        "Non-blocking warning — this file can still be saved"
      } else {
        "Additional non-blocking warning"
      }),
      shiny::tags$ul(lapply(result$warnings, shiny::tags$li))
    )))
  }
  if (result$ok && !length(result$warnings)) {
    blocks <- c(blocks, list(shiny::div(class = "validation-success", "All checks passed.")))
  }

  shiny::tagList(blocks)
}

blocking_validation_notification <- function(file_label, result, context = c("save", "import")) {
  context <- match.arg(context)
  error_count <- length(result$errors)
  heading <- if (identical(context, "import")) {
    sprintf("%s was imported, but it is not ready to save.", file_label)
  } else {
    sprintf("%s was not saved.", file_label)
  }

  shiny::div(
    class = "validation-notification",
    shiny::tags$strong(heading),
    shiny::tags$p(sprintf(
      "%d blocking correction%s:",
      error_count,
      if (identical(error_count, 1L)) "" else "s"
    )),
    shiny::tags$ul(lapply(result$errors, shiny::tags$li)),
    shiny::tags$p("Correct the value in the table, then validate again.")
  )
}

apply_table_cell_edit <- function(data, edit, fixed_columns = character()) {
  if (is.null(edit) || !all(c("row", "col", "value") %in% names(edit))) {
    return(data)
  }

  row_index <- suppressWarnings(as.integer(edit$row[[1]]))
  # DT reports JavaScript column indices, which start at zero. With
  # rownames = FALSE, add one before looking up an R data-frame column.
  column_index <- suppressWarnings(as.integer(edit$col[[1]])) + 1L

  if (is.na(row_index) || is.na(column_index) ||
      row_index < 1L || row_index > nrow(data) ||
      column_index < 1L || column_index > ncol(data)) {
    return(data)
  }

  if (names(data)[[column_index]] %in% fixed_columns) {
    return(data)
  }

  data[row_index, column_index] <- as.character(edit$value[[1]])
  data
}

import_controls <- function(prefix) {
  shiny::tagList(
    shiny::radioButtons(
      paste0(prefix, "_source_mode"),
      "How would you like to start?",
      choices = c(
        "Fill in the table in the app" = "manual",
        "Import an existing file" = "import"
      ),
      selected = "manual"
    ),
    shiny::conditionalPanel(
      condition = sprintf("input['%s_source_mode'] === 'import'", prefix),
      shiny::radioButtons(
        paste0(prefix, "_import_format"),
        "Import format",
        choices = c("CSV" = "csv", "Excel (.xlsx)" = "xlsx"),
        inline = TRUE
      ),
      shiny::fileInput(
        paste0(prefix, "_upload"),
        "Choose an existing file",
        accept = c(".csv", ".xlsx")
      )
    )
  )
}

instruction_details <- function(
    summary,
    purpose,
    fields = NULL,
    rules = character(),
    example = NULL) {
  field_table <- NULL
  if (!is.null(fields) && nrow(fields)) {
    field_table <- shiny::div(
      class = "instruction-table-wrapper",
      shiny::tags$table(
        class = "table table-sm instruction-table",
        shiny::tags$thead(
          shiny::tags$tr(lapply(names(fields), shiny::tags$th))
        ),
        shiny::tags$tbody(lapply(seq_len(nrow(fields)), function(row) {
          shiny::tags$tr(lapply(fields[row, , drop = TRUE], shiny::tags$td))
        }))
      )
    )
  }

  shiny::tags$details(
    class = "instruction-details",
    shiny::tags$summary(summary),
    shiny::p(purpose),
    field_table,
    if (length(rules)) {
      shiny::tagList(
        shiny::tags$h5("Validation rules"),
        shiny::tags$ul(lapply(rules, shiny::tags$li))
      )
    },
    if (!is.null(example)) {
      shiny::tagList(
        shiny::tags$h5("Example"),
        shiny::tags$pre(class = "file-example", example)
      )
    }
  )
}

table_edit_controls <- function(prefix, allow_rows = TRUE) {
  if (!allow_rows) {
    return(NULL)
  }

  shiny::div(
    class = "table-actions",
    shiny::actionButton(paste0(prefix, "_add_row"), "Add row", icon = shiny::icon("plus")),
    shiny::actionButton(paste0(prefix, "_delete_row"), "Delete selected row", icon = shiny::icon("trash"))
  )
}

diff_row_callback <- function(comparison, side = c("before", "after")) {
  side <- match.arg(side)
  statuses <- comparison[[paste0(side, "_row_status")]] %||% character()
  cells <- comparison[[paste0(side, "_modified_cells")]] %||% list()
  status_js <- if (length(statuses)) {
    paste0("['", paste(statuses, collapse = "','"), "']")
  } else {
    "[]"
  }
  cell_js <- if (length(cells)) {
    paste0(
      "[",
      paste(vapply(cells, function(indices) {
        indices <- indices[!is.na(indices)] - 1L
        paste0("[", paste(indices, collapse = ","), "]")
      }, character(1)), collapse = ","),
      "]"
    )
  } else {
    "[]"
  }
  DT::JS(sprintf(
    paste0(
      "function(row, data, displayNumber, displayIndex, dataIndex) {",
      "var statuses=%s; var changedCells=%s; var status=statuses[dataIndex]||'unchanged';",
      "if(status==='added'){$('td',row).addClass('diff-added');}",
      "if(status==='deleted'){$('td',row).addClass('diff-deleted');}",
      "if(status==='modified'){var cells=changedCells[dataIndex]||[];",
      "for(var i=0;i<cells.length;i++){$('td:eq('+cells[i]+')',row).addClass('diff-modified');}}",
      "}"
    ), status_js, cell_js
  ))
}

change_legend <- function() {
  shiny::div(
    class = "change-legend",
    shiny::span(class = "legend-item", shiny::span(class = "legend-swatch diff-modified"), "Modified cell"),
    shiny::span(class = "legend-item", shiny::span(class = "legend-swatch diff-deleted"), "Deleted row"),
    shiny::span(class = "legend-item", shiny::span(class = "legend-swatch diff-added"), "Added row")
  )
}

change_impact_panel <- function(impacts, comparison) {
  if (is.null(comparison) || !isTRUE(comparison$changed)) {
    return(shiny::div(class = "change-impact no-change", "No pending modification was detected for this file."))
  }
  summary <- comparison$summary
  shiny::div(
    class = "change-impact",
    shiny::tags$h4("Consequences for other files"),
    shiny::tags$p(sprintf(
      "%d modified row(s), %d added row(s), and %d deleted row(s).",
      summary[["modified_rows"]], summary[["added_rows"]], summary[["deleted_rows"]]
    )),
    shiny::tags$ul(lapply(impacts, shiny::tags$li))
  )
}

step_card <- function(title, intro, ..., footer = NULL) {
  bslib::card(
    bslib::card_header(shiny::tags$h2(title)),
    bslib::card_body(
      shiny::p(class = "step-intro", intro),
      ...
    ),
    if (!is.null(footer)) bslib::card_footer(footer)
  )
}

save_button <- function(id, label = "Validate, save, and continue") {
  shiny::actionButton(id, label, class = "btn-primary", icon = shiny::icon("check"))
}

navigation_buttons <- function(show_previous = TRUE) {
  shiny::div(
    class = "wizard-navigation",
    if (show_previous) shiny::actionButton("previous_step", "Previous", icon = shiny::icon("arrow-left"))
  )
}
