required_packages <- c("shiny", "bslib", "DT", "shinyFiles", "readr", "readxl", "sf", "yaml")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) stop(sprintf("Missing package(s): %s. Run scripts/install_dependencies.R.", paste(missing_packages, collapse = ", ")), call. = FALSE)

source_order <- c(
  "constants.R", "validation.R", "io.R", "config_access.R", "observatory_yaml.R",
  "product_discovery.R", "change_management.R", "workflow_api.R", "workflow_checks.R", "ui_helpers.R"
)
invisible(lapply(file.path("R", source_order), source, local = FALSE))

docs_directory <- normalizePath(file.path("..", "..", "docs"), winslash = "/", mustWork = FALSE)
if (dir.exists(docs_directory)) shiny::addResourcePath("canobs-help", docs_directory)

ui <- bslib::page_sidebar(
  title = shiny::div(
    class = "app-title",
    shiny::span("canObsR configuration builder"),
    shiny::span(class = "app-subtitle", "Schema 3.1.0")
  ),
  theme = bslib::bs_theme(version = 5, bootswatch = "flatly", primary = "#217346"),
  fillable = FALSE,
  shiny::tags$head(shiny::tags$link(rel = "stylesheet", href = "styles.css")),
  sidebar = bslib::sidebar(
    width = 360,
    shiny::radioButtons(
      "operation", "Operation",
      choices = c(
        "1 — Generate the config folder" = "operation1",
        "2 — Modify the config folder" = "operation2",
        "3 — Check parameters and data" = "operation3",
        "4 — Visualise parameters and data" = "operation4"
      ), selected = "operation1"
    ),
    shiny::tags$hr(),
    shiny::uiOutput("sidebar_controls"),
    shiny::tags$hr(),
    if (dir.exists(docs_directory)) shiny::tags$a(
      class = "btn btn-outline-secondary btn-sm", href = "canobs-help/configuration_files_guide.html",
      target = "_blank", shiny::icon("book"), "Configuration file guide"
    )
  ),
  shiny::div(
    class = "app-busy-indicator",
    role = "status",
    `aria-live` = "polite",
    shiny::icon("gear", class = "fa-spin"),
    shiny::span("Work in progress…")
  ),
  shiny::uiOutput("main_panel")
)

server <- function(input, output, session) {
  config_directory <- shiny::reactiveVal(NULL)
  operation_result <- shiny::reactiveVal(NULL)
  operation3_check_result <- shiny::reactiveVal(NULL)
  operation3_action_message <- shiny::reactiveVal(NULL)
  raw_processed_value <- shiny::reactiveVal(NULL)
  selected_step <- shiny::reactiveVal("site")
  current_validation <- shiny::reactiveVal(NULL)
  step_saved <- shiny::reactiveVal(FALSE)
  draft_tables <- shiny::reactiveValues()
  draft_version <- shiny::reactiveVal(0L)
  config_structure_version <- shiny::reactiveVal(0L)
  dirty_steps <- shiny::reactiveVal(character())
  baseline_snapshot <- shiny::reactiveVal(NULL)
  modification_mode <- shiny::reactiveVal(FALSE)

  step_labels <- c(
    site = "1. param/site.csv", survey = "2. param/survey.csv", sensor = "3. param/sensor.csv",
    product = "4. param/product.csv", crownfile_param = "5. param/crownfile_param.csv",
    tree_picture_zooms = "6. param/tree_picture_zooms.csv", contributors = "7. reference/contributors.csv",
    plots_list = "8. reference/plots_list.csv", dawkins_param = "9. param/dawkins_param.csv",
    taxa_ref = "10. reference/taxa_ref.csv", generated_files = "11. Generated files",
    UAV_folder = "12. path/UAV_folder.csv", UAV_file_patterns = "13. path/UAV_file_patterns.csv",
    vectors = "14. path/vectors.csv (not inspected)", outputs = "15. observatory.yaml and HTML report"
  )

  step_paths <- c(
    site = "param/site.csv", survey = "param/survey.csv", sensor = "param/sensor.csv",
    product = "param/product.csv", crownfile_param = "param/crownfile_param.csv",
    tree_picture_zooms = "param/tree_picture_zooms.csv", contributors = "reference/contributors.csv",
    plots_list = "reference/plots_list.csv", dawkins_param = "param/dawkins_param.csv",
    taxa_ref = "reference/taxa_ref.csv", UAV_folder = "path/UAV_folder.csv",
    UAV_file_patterns = "path/UAV_file_patterns.csv", vectors = "path/vectors.csv"
  )

  config_exists <- shiny::reactive({
    directory <- config_directory()
    !is.null(directory) && dir.exists(directory) && all(dir.exists(file.path(directory, c("param", "reference", "path"))))
  })

  template_for_step <- function(step) {
    directory <- config_directory()
    surveys <- load_existing_table(file.path(directory, "param", "survey.csv"), survey_template())
    switch(step,
      site = site_template(), survey = survey_template(), sensor = sensor_template(),
      product = products_for_active_surveys(product_template(), surveys),
      crownfile_param = crownfile_param_template(),
      tree_picture_zooms = tree_picture_zooms_template(load_existing_table(file.path(directory, "param", "sensor.csv"), sensor_template())),
      contributors = contributors_template(), plots_list = plots_template(), dawkins_param = dawkins_param_template(),
      taxa_ref = taxa_ref_template(),
      UAV_folder = uav_folder_template(load_existing_table(file.path(directory, "param", "product.csv"), product_template())),
      UAV_file_patterns = uav_file_patterns_template(load_existing_table(file.path(directory, "param", "product.csv"), product_template())),
      vectors = vectors_template(), data.frame()
    )
  }

  read_state <- function() {
    config_structure_version()
    directory <- config_directory()
    surveys <- load_existing_table(file.path(directory, "param", "survey.csv"), survey_template())
    params <- load_existing_table(file.path(directory, "param", "crownfile_param.csv"), crownfile_param_template())
    list(surveys = surveys, params = params, steps = wizard_steps(surveys, params))
  }

  server_alias_state <- shiny::reactive({
    config_structure_version()
    if (!identical(input$operation, "operation3")) return(list(aliases = character(), error = NULL))
    candidate <- trimws(input$check_config %||% config_directory() %||% "")
    tryCatch(
      list(aliases = configured_server_aliases(candidate), error = NULL),
      error = function(error) list(aliases = character(), error = conditionMessage(error))
    )
  })

  server_root_input_id <- function(index) paste0("server_root_", index)

  output$server_root_fields <- shiny::renderUI({
    state <- server_alias_state()
    if (!is.null(state$error)) return(shiny::div(class = "alert alert-warning", state$error))
    if (!length(state$aliases)) return(shiny::div(
      class = "alert alert-warning",
      "No server alias was found in param/crownfile_param.csv or path/UAV_folder.csv."
    ))
    shiny::tagList(
      shiny::p("Detected server aliases — enter the local root corresponding to each alias:"),
      lapply(seq_along(state$aliases), function(index) {
        alias <- state$aliases[[index]]
        example <- if (grepl("^[A-Za-z]$", alias)) paste0(alias, ":/") else "Local or network root"
        shiny::textInput(
          server_root_input_id(index), label = alias, value = "", placeholder = example
        )
      })
    )
  })

  available_steps <- shiny::reactive({
    steps <- read_state()$steps
    if (identical(input$operation, "operation2")) intersect(steps, names(step_paths)) else steps
  })

  active_step <- shiny::reactive({
    step <- input$step %||% selected_step()
    available <- available_steps()
    if (!length(available)) return("")
    if (!step %in% available) available[[1]] else step
  })

  draft_key <- function(step) paste0("draft_", step)
  set_draft <- function(step, data) {
    draft_tables[[draft_key(step)]] <- as_character_table(data)
    draft_version(draft_version() + 1L)
  }
  clear_drafts <- function() {
    for (name in names(shiny::reactiveValuesToList(draft_tables))) draft_tables[[name]] <- NULL
    draft_version(draft_version() + 1L)
    dirty_steps(character())
  }
  mark_dirty <- function(step) dirty_steps(unique(c(dirty_steps(), step)))
  mark_saved <- function(step) dirty_steps(setdiff(dirty_steps(), step))
  load_step_draft <- function(step, force = FALSE) {
    if (!step %in% names(step_paths)) return(invisible(NULL))
    key <- draft_key(step)
    existing <- shiny::isolate(draft_tables[[key]])
    if (isTRUE(force) || is.null(existing)) {
      path <- file.path(config_directory(), step_paths[[step]])
      loaded <- load_existing_table(path, template_for_step(step))
      if (identical(input$operation, "operation1") && identical(step, "product")) {
        surveys <- load_existing_table(
          file.path(config_directory(), "param", "survey.csv"), survey_template()
        )
        loaded <- products_for_active_surveys(loaded, surveys)
      }
      set_draft(step, loaded)
    }
    invisible(NULL)
  }

  output$sidebar_controls <- shiny::renderUI({
    operation <- input$operation
    if (operation == "operation1") {
      shiny::tagList(
        shiny::textInput("parent_directory", "Parent directory for a new config folder", value = getwd()),
        shiny::actionButton("initialize_config", "Initialize config/", class = "btn-success"),
        if (config_exists()) shiny::selectInput(
          "step", "Configuration step",
          choices = stats::setNames(available_steps(), step_labels[available_steps()]),
          selected = selected_step()
        )
      )
    } else if (operation == "operation2") {
      shiny::tagList(
        shiny::textInput("existing_config", "Existing config folder", value = config_directory() %||% "config"),
        shiny::actionButton("load_config", "Load config", class = "btn-success"),
        if (config_exists()) shiny::selectInput(
          "step", "Editable file",
          choices = stats::setNames(available_steps(), step_labels[available_steps()]),
          selected = selected_step()
        )
      )
    } else if (operation == "operation3") {
      shiny::tagList(
        shiny::textInput("check_config", "Config folder", value = config_directory() %||% "config"),
        shiny::uiOutput("server_root_fields"),
        shiny::checkboxInput("check_rgb_dates", "Check dynamic RGB date coverage", TRUE),
        shiny::actionButton("run_checks", "Run operation 3", class = "btn-success")
      )
    } else if (operation == "operation4") {
      shiny::tagList(
        shiny::textInput("view_config", "Config folder", value = config_directory() %||% "config"),
        shiny::selectInput("view_type", "Section", choices = setdiff(CANOBS_CONFIG_DATA_TYPES, c("schema_version", "date_format"))),
        shiny::actionButton("load_view", "Load view", class = "btn-success")
      )
    } else NULL
  })

  shiny::observeEvent(input$initialize_config, {
    result <- tryCatch(operation1_generate_config(input$parent_directory, print_report = FALSE), error = function(e) e)
    if (inherits(result, "error")) shiny::showNotification(conditionMessage(result), type = "error", duration = NULL)
    else {
      config_directory(result)
      config_structure_version(config_structure_version() + 1L)
      baseline_snapshot(capture_config_snapshot(result))
      modification_mode(FALSE)
      clear_drafts(); selected_step("site"); load_step_draft("site", TRUE)
      current_validation(NULL); step_saved(FALSE); operation_result(NULL)
      shiny::showNotification(sprintf("Initialized empty schema 3.1.0 folders: %s", result), type = "message")
    }
  })

  shiny::observeEvent(input$load_config, {
    result <- tryCatch(operation2_modify_config(input$existing_config, print_report = FALSE), error = function(e) e)
    if (inherits(result, "error")) shiny::showNotification(conditionMessage(result), type = "error", duration = NULL)
    else {
      config_directory(result$config_directory)
      config_structure_version(config_structure_version() + 1L)
      baseline_snapshot(result$before_snapshot)
      modification_mode(TRUE)
      clear_drafts(); selected_step("site"); load_step_draft("site", TRUE)
      current_validation(NULL); step_saved(FALSE); operation_result(NULL)
      shiny::showNotification("Configuration loaded.", type = "message")
    }
  })

  shiny::observeEvent(input$step, {
    if (is.null(input$step) || !config_exists()) return()
    selected_step(input$step)
    load_step_draft(input$step)
    current_validation(NULL); step_saved(FALSE); operation_result(NULL)
  })

  current_preview <- shiny::reactive({
    shiny::req(config_exists())
    draft_version()
    step <- active_step()
    if (!step %in% names(step_paths)) return(data.frame())
    data <- draft_tables[[draft_key(step)]]
    if (is.null(data)) {
      data <- load_existing_table(file.path(config_directory(), step_paths[[step]]), template_for_step(step))
      if (identical(input$operation, "operation1") && identical(step, "product")) {
        surveys <- load_existing_table(
          file.path(config_directory(), "param", "survey.csv"), survey_template()
        )
        data <- products_for_active_surveys(data, surveys)
      }
    }
    data
  })

  original_preview <- shiny::reactive({
    shiny::req(config_exists())
    step <- active_step()
    if (!step %in% names(step_paths)) return(data.frame())
    current <- current_preview()
    snapshot_table(
      baseline_snapshot(), step_paths[[step]],
      current[0, , drop = FALSE]
    )
  })

  current_comparison <- shiny::reactive({
    step <- active_step()
    if (!step %in% names(step_paths)) return(NULL)
    compare_config_tables(original_preview(), current_preview(), step_paths[[step]])
  })

  current_impacts <- shiny::reactive({
    comparison <- current_comparison()
    if (is.null(comparison)) return(character())
    config_change_impacts(
      config_directory(), comparison$relative_path,
      comparison$before, comparison$after
    )
  })

  output$main_panel <- shiny::renderUI({
    operation <- input$operation
    if (operation %in% c("operation1", "operation2")) {
      modifying <- identical(operation, "operation2")
      if (modifying && !isTRUE(modification_mode())) return(bslib::card(
        bslib::card_header("Operation 2 — Modify the config folder"),
        shiny::p("Select an existing config folder and click 'Load config'. Its published and candidate tables will then be displayed side by side.")
      ))
      if (!config_exists()) return(bslib::card(
        bslib::card_header(if (modifying) "Operation 2" else "Operation 1"),
        shiny::p(if (modifying) "Load an existing schema 3.1.0 config folder." else "Initialize config/ to create only the empty param/, reference/, and path/ folders.")
      ))
      step <- active_step()
      if (!modifying && step == "generated_files") return(bslib::card(
        bslib::card_header("11. Automatically generated tables"),
        shiny::p("Generate crownfile_vars.csv and the controlled reference tables from the validated crownfile_param.csv."),
        shiny::actionButton("generate_tables", "Generate tables", class = "btn-success"),
        shiny::uiOutput("next_file_button"),
        shiny::verbatimTextOutput("operation1_message")
      ))
      if (!modifying && step == "outputs") return(bslib::card(
        bslib::card_header("15. Publish configuration"),
        shiny::p("Run the complete configuration-only check, archive the previous publication, then create observatory.yaml, site_check.txt, the bilingual site report, and a dated modification report."),
        shiny::actionButton("generate_outputs", "Validate and publish", class = "btn-success"),
        shiny::uiOutput("step_validation"),
        shiny::verbatimTextOutput("operation1_message")
      ))
      relative <- step_paths[[step]]
      policy <- config_table_edit_policy(relative)
      bslib::card(
        bslib::card_header(step_labels[[step]]),
        shiny::p("Edit the table directly, or import a file and continue editing the imported values before validation."),
        if (step == "vectors") shiny::div(class = "alert alert-info", "This CSV may be empty or filled. Its contents are never read and have no effect on the workflow."),
        shiny::fileInput("replacement_file", "Import CSV, TSV, XLSX, or XLS", accept = c(".csv", ".tsv", ".xlsx", ".xls")),
        table_edit_controls("current_table", allow_rows = policy$allow_rows),
        shiny::div(class = "table-actions",
          shiny::actionButton("save_step", "Validate and save", class = "btn-success"),
          shiny::downloadButton("download_template", "Download template"),
          shiny::uiOutput("next_file_button")
        ),
        shiny::div(class = "validation-output", shiny::uiOutput("step_validation")),
        if (modifying) change_legend(),
        if (modifying) bslib::layout_columns(
          col_widths = c(6, 6),
          bslib::card(
            bslib::card_header("Published version before modification"),
            DT::DTOutput("original_table")
          ),
          bslib::card(
            bslib::card_header("Candidate version"),
            DT::DTOutput("current_table")
          )
        ) else DT::DTOutput("current_table"),
        if (modifying) shiny::uiOutput("change_impacts"),
        if (modifying) shiny::div(
          class = "table-actions",
          shiny::actionButton("publish_modifications", "Validate and publish changes", class = "btn-primary")
        ),
        shiny::verbatimTextOutput("operation1_message")
      )
    } else if (operation == "operation3") {
      bslib::card(
        bslib::card_header("Operation 3 — Check parameters and data"),
        shiny::p("Server aliases are detected from crownfile_param.csv and UAV_folder.csv. The crownfile is resolved from the local roots entered for those aliases. vectors.csv is never read."),
        shiny::verbatimTextOutput("operation_result"),
        shiny::uiOutput("operation3_actions"),
        shiny::verbatimTextOutput("operation3_action_message"),
        DT::DTOutput("raw_processed_table")
      )
    } else if (operation == "operation4") {
      bslib::card(bslib::card_header("Operation 4 — Visualise parameters and data"), DT::DTOutput("view_table"), shiny::verbatimTextOutput("view_text"))
    } else NULL
  })

  output$current_table <- DT::renderDT({
    data <- current_preview()
    step <- active_step()
    shiny::req(step %in% names(step_paths))
    relative <- step_paths[[step]]
    fixed <- config_table_edit_policy(relative)$fixed_columns
    disabled <- which(names(data) %in% fixed) - 1L
    editable <- if (length(disabled)) list(target = "cell", disable = list(columns = disabled)) else "cell"
    comparison <- current_comparison()
    DT::datatable(
      data, rownames = FALSE, editable = editable, selection = list(mode = "multiple", target = "row"),
      options = list(
        scrollX = TRUE, pageLength = 20, autoWidth = TRUE,
        rowCallback = diff_row_callback(comparison, "after")
      )
    )
  })

  output$original_table <- DT::renderDT({
    shiny::req(isTRUE(modification_mode()))
    data <- original_preview()
    comparison <- current_comparison()
    DT::datatable(
      data, rownames = FALSE, editable = FALSE,
      options = list(
        scrollX = TRUE, pageLength = 20, autoWidth = TRUE,
        rowCallback = diff_row_callback(comparison, "before")
      )
    )
  })

  output$change_impacts <- shiny::renderUI({
    shiny::req(isTRUE(modification_mode()))
    change_impact_panel(current_impacts(), current_comparison())
  })

  current_proxy <- DT::dataTableProxy("current_table")

  shiny::observeEvent(input$current_table_cell_edit, {
    step <- active_step(); shiny::req(step %in% names(step_paths))
    data <- current_preview()
    policy <- config_table_edit_policy(step_paths[[step]])
    data <- apply_table_cell_edit(data, input$current_table_cell_edit, policy$fixed_columns)
    set_draft(step, data)
    mark_dirty(step)
    current_validation(NULL); step_saved(FALSE); operation_result(NULL)
    DT::replaceData(current_proxy, data, resetPaging = FALSE, rownames = FALSE)
  })

  shiny::observeEvent(input$current_table_add_row, {
    step <- active_step(); shiny::req(step %in% names(step_paths))
    data <- current_preview()
    empty <- as.data.frame(as.list(stats::setNames(rep("", ncol(data)), names(data))), stringsAsFactors = FALSE, check.names = FALSE)
    set_draft(step, rbind(data, empty))
    mark_dirty(step)
    current_validation(NULL); step_saved(FALSE); operation_result(NULL)
  })

  shiny::observeEvent(input$current_table_delete_row, {
    step <- active_step(); shiny::req(step %in% names(step_paths))
    rows <- input$current_table_rows_selected
    if (!length(rows)) {
      shiny::showNotification("Select at least one row to delete.", type = "warning")
      return()
    }
    data <- current_preview()
    set_draft(step, data[-rows, , drop = FALSE])
    mark_dirty(step)
    current_validation(NULL); step_saved(FALSE); operation_result(NULL)
  })

  shiny::observeEvent(input$replacement_file, {
    shiny::req(config_exists(), input$replacement_file)
    step <- active_step(); shiny::req(step %in% names(step_paths))
    imported <- tryCatch(
      if (step == "vectors" && file.info(input$replacement_file$datapath)$size == 0L) vectors_template() else
        read_uploaded_table(input$replacement_file$datapath, tolower(tools::file_ext(input$replacement_file$name))),
      error = function(e) e
    )
    if (inherits(imported, "error")) {
      shiny::showNotification(conditionMessage(imported), type = "error", duration = NULL)
      return()
    }
    set_draft(step, imported)
    mark_dirty(step)
    checked <- if (step == "vectors") validation_result(imported) else validate_modified_config_table(
      imported, step_paths[[step]], config_directory(), repair = FALSE
    )
    current_validation(checked); step_saved(FALSE); operation_result(NULL)
    if (!checked$ok) shiny::showNotification(
      blocking_validation_notification(step_paths[[step]], checked, "import"),
      type = "error", duration = NULL
    ) else shiny::showNotification("Imported table loaded. You can edit it before saving.", type = "message")
  }, ignoreInit = TRUE)

  output$download_template <- shiny::downloadHandler(
    filename = function() basename(step_paths[[active_step()]]),
    content = function(file) readr::write_delim(template_for_step(active_step()), file, delim = ";", na = "")
  )

  shiny::observeEvent(input$save_step, {
    step <- active_step(); shiny::req(step %in% names(step_paths))
    candidate <- current_preview()
    if (identical(input$operation, "operation1") && identical(step, "product")) {
      surveys <- load_existing_table(
        file.path(config_directory(), "param", "survey.csv"), survey_template()
      )
      candidate <- complete_product_catalog(candidate, surveys)
    }
    result <- tryCatch(save_config_table(
      config_directory(), step_paths[[step]], candidate,
      update_outputs = FALSE, cross_validate = FALSE, print_report = FALSE,
      repair = step %in% c("contributors", "plots_list")
    ), error = function(e) e)
    operation_result(result)
    if (inherits(result, "error")) {
      current_validation(NULL); step_saved(FALSE)
      shiny::showNotification(conditionMessage(result), type = "error", duration = NULL)
    } else if (!result$validation$ok) {
      current_validation(result$validation); step_saved(FALSE)
      shiny::showNotification(
        blocking_validation_notification(step_paths[[step]], result$validation, "save"),
        type = "error", duration = NULL
      )
    } else {
      displayed <- result$data
      if (identical(input$operation, "operation1") && identical(step, "product")) {
        surveys <- load_existing_table(
          file.path(config_directory(), "param", "survey.csv"), survey_template()
        )
        displayed <- products_for_active_surveys(displayed, surveys)
      }
      set_draft(step, displayed)
      mark_saved(step)
      if (identical(input$operation, "operation1") && identical(step, "survey")) {
        draft_tables[[draft_key("product")]] <- NULL
        draft_version(draft_version() + 1L)
      }
      config_structure_version(config_structure_version() + 1L)
      current_validation(result$validation); step_saved(TRUE)
      if (file.exists(file.path(config_directory(), "observatory.yaml"))) {
        shiny::showNotification("Saved. Regenerate observatory.yaml to refresh all checks.", type = "warning", duration = NULL)
      } else {
        shiny::showNotification("Validated and saved. Use 'Next file' to continue.", type = "message")
      }
    }
  })

  output$step_validation <- shiny::renderUI(validation_panel(current_validation()))
  output$next_file_button <- shiny::renderUI({
    if (!isTRUE(step_saved()) || active_step() == "outputs") return(NULL)
    shiny::actionButton("next_file", "Next file", class = "btn-primary", icon = shiny::icon("arrow-right"))
  })

  shiny::observeEvent(input$next_file, {
    steps <- available_steps()
    current <- active_step()
    index <- match(current, steps)
    if (is.na(index) || index >= length(steps)) return()
    next_step <- steps[[index + 1L]]
    selected_step(next_step)
    shiny::updateSelectInput(
      session, "step", choices = stats::setNames(steps, step_labels[steps]), selected = next_step
    )
    load_step_draft(next_step)
    current_validation(NULL); step_saved(FALSE); operation_result(NULL)
  })

  shiny::observeEvent(input$generate_tables, {
    result <- tryCatch(write_generated_tables(config_directory(), overwrite = TRUE), error = function(e) e)
    operation_result(result)
    if (inherits(result, "error")) {
      step_saved(FALSE); shiny::showNotification(conditionMessage(result), type = "error", duration = NULL)
    } else {
      step_saved(TRUE); shiny::showNotification("Generated tables written. Use 'Next file' to continue.", type = "message")
    }
  })

  shiny::observeEvent(input$generate_outputs, {
    if (length(dirty_steps())) {
      shiny::showNotification(
        sprintf("Save the unsaved file(s) before publication: %s.", paste(step_labels[dirty_steps()], collapse = ", ")),
        type = "error", duration = NULL
      )
      return()
    }
    result <- tryCatch(generate_config_outputs(
      config_directory(), TRUE, FALSE,
      before_snapshot = baseline_snapshot()
    ), error = function(e) e)
    operation_result(result)
    if (inherits(result, "error")) {
      current_validation(NULL); shiny::showNotification(conditionMessage(result), type = "error", duration = NULL)
    } else {
      current_validation(result$validation)
      if (result$validation$ok) {
        baseline_snapshot(capture_config_snapshot(config_directory()))
        modification_mode(FALSE)
        shiny::showNotification("Configuration published, archived, and documented.", type = "message")
      }
      else shiny::showNotification("Publication stopped. Correct the localized blocking errors below.", type = "error", duration = NULL)
    }
  })

  shiny::observeEvent(input$publish_modifications, {
    shiny::req(isTRUE(modification_mode()), config_exists())
    if (length(dirty_steps())) {
      shiny::showNotification(
        sprintf(
          "Save the unsaved candidate file(s) before publication: %s.",
          paste(step_labels[dirty_steps()], collapse = ", ")
        ),
        type = "error", duration = NULL
      )
      return()
    }
    result <- tryCatch(generate_config_outputs(
      config_directory(), TRUE, FALSE,
      before_snapshot = baseline_snapshot()
    ), error = function(e) e)
    operation_result(result)
    if (inherits(result, "error")) {
      current_validation(NULL)
      shiny::showNotification(conditionMessage(result), type = "error", duration = NULL)
    } else {
      current_validation(result$validation)
      if (result$validation$ok) {
        baseline_snapshot(capture_config_snapshot(config_directory()))
        clear_drafts()
        load_step_draft(active_step(), TRUE)
        shiny::showNotification("Changes validated, archived, published, and documented.", type = "message")
      } else {
        shiny::showNotification("Publication stopped. Correct the localized blocking errors below.", type = "error", duration = NULL)
      }
    }
  })

  read_server_roots <- function() {
    state <- server_alias_state()
    if (!is.null(state$error)) stop(state$error, call. = FALSE)
    if (!length(state$aliases)) stop(
      "No server alias was found in param/crownfile_param.csv or path/UAV_folder.csv.",
      call. = FALSE
    )
    roots <- vapply(seq_along(state$aliases), function(index) {
      trimws(input[[server_root_input_id(index)]] %||% "")
    }, character(1))
    names(roots) <- state$aliases
    missing <- names(roots)[!nzchar(roots)]
    if (length(missing)) stop(sprintf(
      "Enter the local root for server alias(es): %s.", paste(missing, collapse = ", ")
    ), call. = FALSE)
    roots
  }

  shiny::observeEvent(input$run_checks, {
    raw_processed_value(NULL)
    operation3_action_message(NULL)
    roots <- tryCatch(read_server_roots(), error = function(e) e)
    result <- if (inherits(roots, "error")) roots else tryCatch(
      operation3_check_parameters_and_data(
        input$check_config, roots,
        crownfile_path = NULL,
        check_rgb_dates = input$check_rgb_dates, print_report = FALSE
      ),
      error = function(e) e
    )
    operation3_check_result(result)
    operation_result(result)
    if (!inherits(result, "error")) {
      report <- result$details$products$products_check_path %||% NULL
      if (!is.null(report)) operation3_action_message(sprintf("Written: %s", report))
    }
  })

  output$operation3_actions <- shiny::renderUI({
    result <- operation3_check_result()
    if (is.null(result) || inherits(result, "error") || !isTRUE(result$ok)) return(NULL)
    shiny::div(
      class = "operation3-actions",
      shiny::tags$h4("Product inventory actions"),
      shiny::p(
        "The check passed. products_check.txt has been written; you can now write the checked inventory or compare raw and processed products."
      ),
      shiny::div(
        class = "table-actions",
        shiny::actionButton(
          "write_all_products", "Generate or update all_products.csv",
          class = "btn-primary", icon = shiny::icon("file-export")
        ),
        shiny::actionButton(
          "run_raw_processed", "Compare raw and processed products",
          class = "btn-outline-primary", icon = shiny::icon("table")
        )
      ),
      shiny::checkboxInput(
        "group_raw_processed",
        "Group comparison by processed_product and status",
        value = TRUE
      )
    )
  })

  shiny::observeEvent(input$write_all_products, {
    roots <- tryCatch(read_server_roots(), error = function(e) e)
    if (inherits(roots, "error")) {
      operation3_action_message(conditionMessage(roots))
      return()
    }
    fresh <- tryCatch(operation3_check_parameters_and_data(
      input$check_config, roots, crownfile_path = NULL,
      check_rgb_dates = input$check_rgb_dates, print_report = FALSE
    ), error = function(e) e)
    operation3_check_result(fresh)
    operation_result(fresh)
    if (inherits(fresh, "error")) {
      operation3_action_message(conditionMessage(fresh))
      return()
    }
    if (!isTRUE(fresh$ok)) {
      operation3_action_message("all_products.csv was not written because the refreshed check contains blocking errors.")
      return()
    }
    product_check <- fresh$details$products
    destination <- tryCatch(
      write_all_products_csv(product_check, print_report = FALSE),
      error = function(e) e
    )
    if (inherits(destination, "error")) {
      operation3_action_message(conditionMessage(destination))
      return()
    }
    refreshed <- tryCatch(operation3_check_parameters_and_data(
      input$check_config, roots, crownfile_path = NULL,
      check_rgb_dates = input$check_rgb_dates, print_report = FALSE
    ), error = function(e) e)
    operation3_check_result(refreshed)
    operation_result(refreshed)
    report <- if (inherits(refreshed, "error")) NULL else refreshed$details$products$products_check_path %||% NULL
    operation3_action_message(paste(
      sprintf("Written: %s", destination),
      if (is.null(report)) "" else sprintf("Updated: %s", report),
      sep = "\n"
    ))
    shiny::showNotification("all_products.csv and products_check.txt were updated.", type = "message")
  })

  shiny::observeEvent(input$run_raw_processed, {
    result <- operation3_check_result()
    if (is.null(result) || inherits(result, "error") || !isTRUE(result$ok)) return()
    product_check <- result$details$products
    products <- product_check$current_inventory %||% product_check$data
    comparison <- tryCatch(compare_raw_processed(
      config_directory = input$check_config,
      products = products,
      group_by_processed_status = isTRUE(input$group_raw_processed),
      as_datatable = FALSE
    ), error = function(e) e)
    raw_processed_value(comparison)
    if (inherits(comparison, "error")) operation3_action_message(conditionMessage(comparison))
  })

  output$raw_processed_table <- DT::renderDT({
    value <- raw_processed_value()
    shiny::req(is.data.frame(value))
    DT::datatable(
      value, rownames = FALSE, filter = "top",
      options = list(pageLength = 25, scrollX = TRUE)
    )
  })

  output$operation3_action_message <- shiny::renderPrint({
    message <- operation3_action_message()
    if (!is.null(message)) cat(message, "\n")
  })

  output$operation_result <- shiny::renderPrint({
    result <- operation_result(); if (is.null(result)) return(cat("Run the operation to display diagnostics.\n"))
    if (inherits(result, "error")) cat(conditionMessage(result), "\n") else print_check_messages("Result", result)
  })
  output$operation1_message <- shiny::renderPrint({
    result <- operation_result(); if (is.null(result)) return(invisible())
    if (inherits(result, "error")) cat(conditionMessage(result), "\n")
    else if (is.character(result)) cat(paste(result, collapse = "\n"), "\n")
    else if (is.list(result) && !is.null(result$modification_report)) {
      cat("Publication completed.\n")
      cat(sprintf("Modification report: %s\n", result$modification_report))
      if (!is.null(result$archive$archive_directory)) cat(sprintf("Archive: %s\n", result$archive$archive_directory))
    }
    else if (is.list(result) && !is.null(result$complete_config_validation)) print_check_messages("Configuration", result$complete_config_validation)
    else if (is.list(result) && !is.null(result$validation) && !identical(result$validation, current_validation())) print_check_messages("Current file", result$validation)
    else print(result)
  })

  view_value <- shiny::reactiveVal(NULL)
  shiny::observeEvent(input$load_view, {
    result <- tryCatch(observe_config(input$view_config, input$view_type), error = function(e) e)
    view_value(result)
  })
  output$view_table <- DT::renderDT({
    value <- view_value(); shiny::req(is.data.frame(value)); DT::datatable(
      value, rownames = FALSE, filter = "top",
      options = list(scrollX = TRUE, pageLength = 25)
    )
  })
  output$view_text <- shiny::renderPrint({
    value <- view_value(); if (is.null(value) || is.data.frame(value)) return(invisible())
    if (inherits(value, "error")) cat(conditionMessage(value), "\n") else print(value)
  })
}

shiny::shinyApp(ui, server)
