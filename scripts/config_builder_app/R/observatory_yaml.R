table_as_records <- function(data) {
  data <- as_character_table(data)
  if (!nrow(data)) return(list())
  # drop = TRUE removes the column name from one-column tables. YAML then
  # serializes them as unnamed values and the round-trip comparison reports a
  # false difference for every generated reference table. Keeping a data frame
  # preserves the field name for both one- and multi-column records.
  lapply(seq_len(nrow(data)), function(i) as.list(data[i, , drop = FALSE]))
}

read_yaml_table <- function(config_directory, relative_path) {
  path <- file.path(config_directory, relative_path)
  if (!file.exists(path)) return(data.frame())
  read_delimited_table(path)
}

yaml_section <- function(relative_path, data = data.frame(), status = NULL) {
  section <- list(path = paste0("config/", gsub("\\\\", "/", relative_path)))
  if (!is.null(status)) section$status <- status
  section$data <- table_as_records(data)
  section
}

build_observatory_definition <- function(config_directory) {
  directory <- resolve_existing_config_directory(config_directory)
  surveys <- read_yaml_table(directory, file.path("param", "survey.csv"))
  crown_params_table <- read_yaml_table(directory, file.path("param", "crownfile_param.csv"))
  params <- table_to_named(crown_params_table, "param", "value")
  tree_active <- any(surveys$survey == "tree_pictures" & surveys$status == "TRUE")
  dynamic <- identical(named_value_or(params, "crownfile_type"), "dynamic")
  dawkins <- is_true_value(params, "dawkins")
  plots <- is_true_value(params, "plots_list")

  conditional <- function(relative, active) {
    yaml_section(relative, if (active) read_yaml_table(directory, relative) else data.frame(), if (active) "activated" else "non activated")
  }
  list(
    schema_version = CANOBS_SCHEMA_VERSION,
    date_format = CANOBS_DATE_FORMAT,
    site = yaml_section(file.path("param", "site.csv"), read_yaml_table(directory, file.path("param", "site.csv"))),
    survey = yaml_section(file.path("param", "survey.csv"), surveys),
    sensor = yaml_section(file.path("param", "sensor.csv"), read_yaml_table(directory, file.path("param", "sensor.csv"))),
    product = yaml_section(file.path("param", "product.csv"), read_yaml_table(directory, file.path("param", "product.csv"))),
    crownfile_param = yaml_section(file.path("param", "crownfile_param.csv"), crown_params_table),
    tree_picture_zooms = conditional(file.path("param", "tree_picture_zooms.csv"), tree_active),
    contributors = yaml_section(file.path("reference", "contributors.csv"), read_yaml_table(directory, file.path("reference", "contributors.csv"))),
    plots_list = conditional(file.path("reference", "plots_list.csv"), plots),
    dawkins_param = conditional(file.path("param", "dawkins_param.csv"), dawkins),
    crownfile_vars = yaml_section(file.path("param", "crownfile_vars.csv"), read_yaml_table(directory, file.path("param", "crownfile_vars.csv"))),
    dawkins = conditional(file.path("reference", "dawkins.csv"), dawkins),
    dbh_types = yaml_section(file.path("reference", "dbh_types.csv"), read_yaml_table(directory, file.path("reference", "dbh_types.csv"))),
    geom_modif = conditional(file.path("reference", "geom_modif.csv"), dynamic),
    lianas = yaml_section(file.path("reference", "lianas.csv"), read_yaml_table(directory, file.path("reference", "lianas.csv"))),
    tree_status = conditional(file.path("reference", "tree_status.csv"), dynamic),
    type_obs = yaml_section(file.path("reference", "type_obs.csv"), read_yaml_table(directory, file.path("reference", "type_obs.csv"))),
    UAV_folder = yaml_section(file.path("path", "UAV_folder.csv"), read_yaml_table(directory, file.path("path", "UAV_folder.csv"))),
    UAV_file_patterns = yaml_section(file.path("path", "UAV_file_patterns.csv"), read_yaml_table(directory, file.path("path", "UAV_file_patterns.csv")))
  )
}

write_observatory_yaml <- function(config_directory) {
  definition <- build_observatory_definition(config_directory)
  destination <- file.path(config_directory, "observatory.yaml")
  temporary <- tempfile("canobs-yaml-", tmpdir = config_directory, fileext = ".tmp")
  on.exit(unlink(temporary), add = TRUE)
  yaml::write_yaml(definition, temporary, fileEncoding = "UTF-8")
  if (!file.rename(temporary, destination) && !file.copy(temporary, destination, overwrite = TRUE)) {
    stop("Could not write observatory.yaml.", call. = FALSE)
  }
  normalizePath(destination, winslash = "/", mustWork = TRUE)
}

escape_html <- function(x) {
  x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

html_table <- function(data) {
  data <- as_character_table(data)
  if (!ncol(data)) return("<p class='empty'>No data / Aucune donnée</p>")
  header <- paste0("<th>", escape_html(names(data)), "</th>", collapse = "")
  rows <- if (!nrow(data)) "" else paste(vapply(seq_len(nrow(data)), function(i) {
    paste0("<tr>", paste0("<td>", escape_html(unlist(data[i, , drop = FALSE])), "</td>", collapse = ""), "</tr>")
  }, character(1)), collapse = "\n")
  paste0("<div class='table-wrap'><table><thead><tr>", header, "</tr></thead><tbody>", rows, "</tbody></table></div>")
}

observatory_report_sections <- function(config_directory) {
  definition <- build_observatory_definition(config_directory)
  keys <- setdiff(names(definition), c("schema_version", "date_format"))
  sections <- lapply(keys, function(key) {
    section <- definition[[key]]
    relative <- sub("^config/", "", section$path)
    exists <- file.exists(file.path(config_directory, relative))
    if (!is.null(section$status) && !exists) return(NULL)
    list(
      key = key, path = section$path, status = section$status %||% "activated",
      data = if (exists) read_yaml_table(config_directory, relative) else data.frame()
    )
  })
  Filter(Negate(is.null), sections)
}

write_observatory_report <- function(config_directory) {
  site <- read_yaml_table(config_directory, file.path("param", "site.csv"))
  values <- table_to_named(site, "param", "site_value")
  site_name <- named_value_or(values, "name", "observatory")
  destination <- file.path(config_directory, config_report_filename(site_name))
  sections <- observatory_report_sections(config_directory)
  cards <- paste(vapply(sections, function(section) {
    status_class <- if (section$status == "activated") "on" else "off"
    paste0(
      "<section><div class='section-title'><h2>", escape_html(section$key), "</h2>",
      "<span class='status ", status_class, "'>", escape_html(section$status), "</span></div>",
      "<p class='path'>", escape_html(section$path), "</p>", html_table(section$data), "</section>"
    )
  }, character(1)), collapse = "\n")
  document <- c(
    "<!doctype html><html lang='en'><head><meta charset='utf-8'>",
    "<meta name='viewport' content='width=device-width,initial-scale=1'>",
    paste0("<title>", escape_html(site_name), " — canObsR</title>"),
    "<style>",
    "body{font-family:system-ui,sans-serif;margin:0;background:#f4f7f5;color:#17342a}header,main{max-width:1120px;margin:auto;padding:24px}header{display:flex;justify-content:space-between;gap:20px;align-items:center}h1{margin:0}section{background:#fff;border:1px solid #d9e5de;border-radius:12px;padding:18px;margin:14px 0}.section-title{display:flex;justify-content:space-between;align-items:center}.section-title h2{margin:0}.status{padding:4px 9px;border-radius:99px;font-size:.8rem}.on{background:#daf3e5}.off{background:#eee;color:#666}.path{font-family:monospace;color:#557268}.table-wrap{overflow:auto}table{border-collapse:collapse;width:100%}th,td{padding:8px;border-bottom:1px solid #e6ece8;text-align:left}th{background:#f1f7f3}.fr{display:none}html[lang='fr'] .en{display:none}html[lang='fr'] .fr{display:inline}button{border:1px solid #217346;background:#fff;color:#217346;padding:8px 12px;border-radius:8px;cursor:pointer}@media print{button{display:none}body{background:#fff}section{break-inside:avoid}}",
    "</style></head><body><header><div><h1>", escape_html(site_name), "</h1>",
    "<p><span class='en'>Observatory configuration — schema 3.1.0</span><span class='fr'>Configuration de l’observatoire — schéma 3.1.0</span></p></div>",
    "<button id='language' type='button'>Français</button></header><main>", cards, "</main>",
    "<script>(function(){var b=document.getElementById('language');b.onclick=function(){var fr=document.documentElement.lang!=='fr';document.documentElement.lang=fr?'fr':'en';b.textContent=fr?'English':'Français';};})();</script>",
    "</body></html>"
  )
  write_utf8_text_file(document, destination)
}

write_observatory_outputs <- function(config_directory) {
  c(yaml = write_observatory_yaml(config_directory), html = write_observatory_report(config_directory))
}
