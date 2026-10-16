filled_site <- function() {
  data.frame(
    param = CANOBS_SITE_PARAMETERS,
    site_value = c("mba", "Mbalmayo", "Cameroon", "EPSG:32632"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

filled_surveys <- function() {
  data.frame(
    survey = CANOBS_SURVEYS,
    status = c("TRUE", "FALSE", "FALSE", "FALSE"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

filled_products <- function() {
  products <- product_template()
  products$status[products$product %in% c("RGB_raw", "RGB_orthomosaic")] <- "TRUE"
  products
}

filled_crownfile_params <- function(crownfile_type = "dynamic") {
  params <- crownfile_param_template()
  params$value[params$param == "path"] <- "observatories/mbalmayo/crowns.gpkg"
  params$value[params$param == "server"] <- "work"
  params$value[params$param == "crownfile_type"] <- crownfile_type
  params
}

make_config_v310 <- function(crownfile_type = "dynamic") {
  parent <- tempfile("canobs-v310-"); dir.create(parent)
  directory <- create_config_skeleton(parent)
  initialize_config_templates(directory)
  write_semicolon_csv(filled_site(), file.path(directory, "param", "site.csv"))
  write_semicolon_csv(filled_surveys(), file.path(directory, "param", "survey.csv"))
  write_semicolon_csv(data.frame(
    sensor = "Mavic2", survey = "RGB", start_date = "20220101", end_date = "",
    status = "active", stringsAsFactors = FALSE, check.names = FALSE
  ), file.path(directory, "param", "sensor.csv"))
  write_semicolon_csv(filled_products(), file.path(directory, "param", "product.csv"))
  params <- filled_crownfile_params(crownfile_type)
  write_semicolon_csv(params, file.path(directory, "param", "crownfile_param.csv"))
  write_semicolon_csv(data.frame(contributor = "Alex", stringsAsFactors = FALSE), file.path(directory, "reference", "contributors.csv"))
  write_generated_tables(directory)
  directory
}

testthat::test_that("schema version and canonical catalogs are exact", {
  testthat::expect_identical(CANOBS_SCHEMA_VERSION, "3.1.0")
  testthat::expect_identical(CANOBS_SITE_PARAMETERS, c("id_site", "name", "location", "crs"))
  testthat::expect_identical(CANOBS_SURVEYS, c("RGB", "MS", "DLS", "tree_pictures"))
  testthat::expect_equal(nrow(product_template()), 17L)
  testthat::expect_true(all(c("RGB_indices", "MS_indices", "DLS_indices", "sorted_tree_picture") %in% product_template()$product))
  testthat::expect_identical(
    crownfile_param_template()$param,
    c("path", "server", "crownfile_type", "plots_list", "taxa_ref", "dawkins")
  )
})

testthat::test_that("crownfile address is required, portable, and resolved from a named server root", {
  params <- filled_crownfile_params()
  testthat::expect_true(validate_crownfile_param(params)$ok)
  absolute <- params; absolute$value[absolute$param == "path"] <- "C:/data/crowns.gpkg"
  testthat::expect_false(validate_crownfile_param(absolute)$ok)
  wrong_extension <- params; wrong_extension$value[wrong_extension$param == "path"] <- "observatories/mbalmayo/crowns.shp"
  testthat::expect_false(validate_crownfile_param(wrong_extension)$ok)
  testthat::expect_match(
    paste(validate_crownfile_param(wrong_extension)$errors, collapse = " "),
    "GeoPackage.*[.]gpkg"
  )
  missing_server <- params; missing_server$value[missing_server$param == "server"] <- ""
  testthat::expect_false(validate_crownfile_param(missing_server)$ok)

  directory <- make_config_v310()
  resolved <- resolve_configured_crownfile_path(
    directory, c(work = file.path("mounted_servers", "work"))
  )
  testthat::expect_equal(
    resolved,
    normalizePath(file.path("mounted_servers", "work", "observatories", "mbalmayo", "crowns.gpkg"), winslash = "/", mustWork = FALSE)
  )
})

testthat::test_that("configured server aliases are collected from crown and UAV files", {
  directory <- make_config_v310()
  folders <- data.frame(
    survey = c("RGB", "RGB"), product = c("RGB_raw", "RGB_orthomosaic"),
    server = c("safe", "work"), path = c("raw", "ortho"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  write_semicolon_csv(folders, file.path(directory, "path", "UAV_folder.csv"))
  testthat::expect_identical(configured_server_aliases(directory), c("work", "safe"))
})

testthat::test_that("site and survey schemas are strict", {
  testthat::expect_true(validate_site(filled_site())$ok)
  extra <- rbind(filled_site(), data.frame(param = "extra", site_value = "x"))
  testthat::expect_false(validate_site(extra)$ok)
  testthat::expect_true(validate_survey(filled_surveys()[c(4, 1, 3, 2), ])$ok)
  none <- filled_surveys(); none$status <- "FALSE"
  testthat::expect_false(validate_survey(none)$ok)
  invalid_id <- filled_site(); invalid_id$site_value[invalid_id$param == "id_site"] <- "mb a"
  invalid_check <- validate_site(invalid_id)
  testthat::expect_false(invalid_check$ok)
  testthat::expect_match(paste(invalid_check$errors, collapse = " "), "row 1.*mb a.*Spaces")
})

testthat::test_that("initialization creates folders only and the first table can be saved", {
  parent <- tempfile("canobs-empty-"); dir.create(parent)
  directory <- operation1_generate_config(parent, print_report = FALSE)
  testthat::expect_true(all(dir.exists(file.path(directory, c("param", "reference", "path")))))
  testthat::expect_length(list.files(directory, recursive = TRUE, all.files = FALSE), 0L)
  saved <- save_config_table(directory, "param/site.csv", filled_site(), print_report = FALSE)
  testthat::expect_true(saved$validation$ok)
  testthat::expect_true(file.exists(file.path(directory, "param", "site.csv")))
  testthat::expect_false(file.exists(file.path(directory, "param", "survey.csv")))
})

testthat::test_that("sensor periods are inclusive and keys are exact", {
  surveys <- filled_surveys()
  sensors <- data.frame(
    sensor = c("A", "B"), survey = c("RGB", "RGB"),
    start_date = c("20260101", "20260110"), end_date = c("20260110", "20260120"),
    status = c("not active", "not active"), stringsAsFactors = FALSE
  )
  checked <- validate_sensor(sensors, surveys)
  testthat::expect_false(checked$ok)
  testthat::expect_match(paste(checked$errors, collapse = " "), "inclusive overlapping")
  sensors$start_date[[2]] <- "20260111"
  testthat::expect_true(validate_sensor(sensors, surveys)$ok)
})

testthat::test_that("product dependencies are blocking while individual FALSE is a warning", {
  products <- filled_products()
  checked <- validate_product(products, filled_surveys())
  testthat::expect_true(checked$ok)
  testthat::expect_true(length(checked$warnings) > 0L)
  products$status[products$product == "RGB_raw"] <- "FALSE"
  testthat::expect_false(validate_product(products, filled_surveys())$ok)
  products$status[products$product == "RGB_orthomosaic"] <- "FALSE"
  testthat::expect_false(validate_product(products, filled_surveys())$ok)
})

testthat::test_that("operation 1 can show active-survey products and save the complete catalogue", {
  surveys <- survey_template()
  surveys$status[surveys$survey %in% c("RGB", "DLS")] <- "TRUE"
  visible <- products_for_active_surveys(product_template(), surveys)
  testthat::expect_identical(unique(visible$survey), c("RGB", "DLS"))
  testthat::expect_equal(nrow(visible), 10L)
  visible$status[visible$product %in% c("RGB_raw", "DLS_raw")] <- "TRUE"
  complete <- complete_product_catalog(visible, surveys)
  testthat::expect_equal(nrow(complete), 17L)
  testthat::expect_true(all(complete$status[complete$survey %in% c("MS", "tree_pictures")] == "FALSE"))
  testthat::expect_true(validate_product(complete, surveys)$ok)
})

testthat::test_that("crownfile_vars follows light, dynamic, and conditional flags", {
  dynamic <- crownfile_vars_template("dynamic", TRUE, TRUE, TRUE)
  light <- crownfile_vars_template("light", FALSE, FALSE, FALSE)
  testthat::expect_true(all(c("Geom_Modif", "Tree_Status", "plot_name", "taxa_id", "dawkins_code") %in% dynamic$var_name))
  testthat::expect_true("layer" %in% names(light))
  testthat::expect_identical(unique(light$layer), "crowns")
  testthat::expect_identical(light$type[light$var_name == "id"], "integer PK")
  testthat::expect_identical(light$reference_layer[light$var_name == "id"], "")
  testthat::expect_false(any(c("Geom_Modif", "Tree_Status", "plot_name", "taxa_id", "dawkins_code", "subplot_name", "plot_id") %in% light$var_name))
  testthat::expect_identical(dynamic$reference_tables[dynamic$var_name == "Geom_Modif"], "geom_modif.csv")
})

testthat::test_that("tree picture zoom syntax and triple key are enforced", {
  sensors <- data.frame(
    sensor = "M3E", survey = "tree_pictures", start_date = "20240101", end_date = "",
    status = "active", stringsAsFactors = FALSE
  )
  zooms <- data.frame(
    sensor = "M3E", zoom = "x14", zoom_type = "digital", effective_focal = "90.8",
    stringsAsFactors = FALSE
  )
  testthat::expect_true(validate_tree_picture_zooms(zooms, sensors)$ok)
  zooms$zoom <- "14"
  testthat::expect_false(validate_tree_picture_zooms(zooms, sensors)$ok)
})

testthat::test_that("generated references use exact 3.1.0 models", {
  tables <- default_reference_tables("dynamic", TRUE)
  testthat::expect_identical(tables[["lianas.csv"]]$lianas, c("0", "1"))
  testthat::expect_identical(names(tables[["geom_modif.csv"]]), "Geom_Modif")
  testthat::expect_true("tree_status.csv" %in% names(tables))
  testthat::expect_false("tree_status.csv" %in% names(default_reference_tables("light", FALSE)))
})

testthat::test_that("UAV patterns are immediate-name patterns with exact date and crown syntax", {
  products <- filled_products()
  folders <- data.frame(
    survey = "RGB", product = "RGB_raw", server = "safe", path = "uav/rgb",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  crown <- crownfile_vars_template("dynamic", FALSE, FALSE, FALSE)
  valid <- data.frame(
    survey = "RGB", product = "RGB_raw",
    directory_pattern = "{product}__{date:%Y-%m-%d}__{sensor}", filename_pattern = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  testthat::expect_true(validate_uav_file_patterns(valid, products, folders, crown)$ok)
  both <- valid; both$filename_pattern <- "{date}.tif"
  testthat::expect_false(validate_uav_file_patterns(both, products, folders, crown)$ok)
  recursive <- valid; recursive$directory_pattern <- "child/{date}"
  testthat::expect_false(validate_uav_file_patterns(recursive, products, folders, crown)$ok)
  no_date <- valid; no_date$directory_pattern <- "{product}__{sensor}"
  testthat::expect_false(validate_uav_file_patterns(no_date, products, folders, crown)$ok)
  transformed <- valid; transformed$directory_pattern <- "{date}__{crownfile.infos.tax_sp_level|space_to_hyphen}"
  testthat::expect_true(validate_uav_file_patterns(transformed, products, folders, crown)$ok)
  light <- crownfile_vars_template("light", FALSE, FALSE, FALSE)
  light_pattern <- valid; light_pattern$directory_pattern <- "{product}__{date}__{crownfile.id}"
  testthat::expect_true(validate_uav_file_patterns(light_pattern, products, folders, light)$ok)
  layered_light <- valid; layered_light$directory_pattern <- "{product}__{date}__{crownfile.geometry.id}"
  testthat::expect_false(validate_uav_file_patterns(layered_light, products, folders, light)$ok)
})

testthat::test_that("the documented UAV pattern file is accepted", {
  testthat::expect_identical(
    extract_pattern_tokens("{product}__{date}__{sensor}"),
    c("product", "date", "sensor")
  )
  products <- product_template()
  products$status[products$product %in% c(
    "RGB_raw", "RGB_orthomosaic", "RGB_DEM",
    "MS_raw", "MS_orthomosaic", "MS_DEM",
    "DLS_raw", "DLS_CHM", "DLS_DTM",
    "raw_tree_picture", "sorted_tree_picture"
  )] <- "TRUE"
  patterns <- data.frame(
    survey = c(rep("RGB", 3), rep("MS", 3), rep("DLS", 3), rep("tree_pictures", 2)),
    product = c(
      "RGB_raw", "RGB_orthomosaic", "RGB_DEM",
      "MS_raw", "MS_orthomosaic", "MS_DEM",
      "DLS_raw", "DLS_CHM", "DLS_DTM",
      "raw_tree_picture", "sorted_tree_picture"
    ),
    directory_pattern = c(
      "{product}__{date}__{sensor}", "", "",
      "{product}__{date}__{sensor}", "", "",
      "{product}__{date}__{sensor}", "", "",
      "{product}__{date}__{sensor}", "ID__{crownfile.infos.id}__{crownfile.infos.tax_sp_level}"
    ),
    filename_pattern = c(
      "", "{product}__{date}__{site}__ORTHO_aligned_local.tif", "{product}__{date}__{site}.tif",
      "", "{product}__{date}__{site}__ORTHO_aligned_local.tif", "{product}__{date}__{site}.tif",
      "", "{product}__{date}__{sensor}.tif", "{product}__{date}__{sensor}.tif",
      "", ""
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  crown <- crownfile_vars_template("dynamic", FALSE, FALSE, FALSE)
  checked <- validate_uav_file_patterns(patterns, products, crownfile_vars = crown)
  testthat::expect_true(checked$ok, info = paste(checked$errors, collapse = "\n"))
})

testthat::test_that("operation 1 ignores UAV paths and vectors contents", {
  directory <- make_config_v310()
  writeLines("not;a;valid;csv\nanything", file.path(directory, "path", "vectors.csv"))
  checked <- validate_config_input_files(directory, check_uav_paths = FALSE)
  testthat::expect_true(checked$ok)
  testthat::expect_false("path/vectors.csv" %in% names(checked$details))
})

testthat::test_that("YAML has fixed conditional sections and omits taxa_ref and vectors", {
  directory <- make_config_v310("light")
  definition <- build_observatory_definition(directory)
  testthat::expect_identical(definition$schema_version, "3.1.0")
  testthat::expect_identical(definition$tree_status$status, "non activated")
  testthat::expect_identical(definition$geom_modif$status, "non activated")
  testthat::expect_false("taxa_ref" %in% names(definition))
  testthat::expect_false("vectors" %in% names(definition))
  testthat::expect_identical(names(definition$site)[[1]], "path")
})

testthat::test_that("site HTML sections omit optional files that do not exist", {
  directory <- make_config_v310("light")
  sections <- observatory_report_sections(directory)
  keys <- vapply(sections, `[[`, character(1), "key")
  testthat::expect_false(any(c(
    "tree_picture_zooms", "plots_list", "dawkins_param", "dawkins",
    "geom_modif", "tree_status"
  ) %in% keys))
  testthat::expect_true(all(c("site", "survey", "product", "crownfile_vars") %in% keys))
})

testthat::test_that("light crownfiles require the single layer crowns", {
  directory <- make_config_v310("light")
  schema <- crownfile_vars_template("light", FALSE, FALSE, FALSE)
  empty_layer <- as.data.frame(
    stats::setNames(replicate(nrow(schema), character(), simplify = FALSE), schema$var_name),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  environment <- environment(check_crown_schema_values)
  original_names <- get("crownfile_layer_names", envir = environment)
  original_read <- get("read_crown_layer", envir = environment)
  on.exit({
    assign("crownfile_layer_names", original_names, envir = environment)
    assign("read_crown_layer", original_read, envir = environment)
  }, add = TRUE)
  assign("read_crown_layer", function(path, layer) empty_layer, envir = environment)
  assign("crownfile_layer_names", function(path) "crowns", envir = environment)
  accepted <- check_crown_schema_values(directory, "unused.gpkg")
  testthat::expect_true(accepted$ok, info = paste(accepted$errors, collapse = "\n"))
  assign("crownfile_layer_names", function(path) "other", envir = environment)
  wrong_name <- check_crown_schema_values(directory, "unused.gpkg")
  testthat::expect_false(wrong_name$ok)
  testthat::expect_match(paste(wrong_name$errors, collapse = " "), "layer named 'crowns'", fixed = TRUE)
  assign("crownfile_layer_names", function(path) c("crowns", "extra"), envir = environment)
  extra_layer <- check_crown_schema_values(directory, "unused.gpkg")
  testthat::expect_false(extra_layer$ok)
})

testthat::test_that("one-column YAML tables retain names and round-trip without false differences", {
  records <- table_as_records(data.frame(
    contributor = c("Alex", "Bea"), stringsAsFactors = FALSE
  ))
  testthat::expect_identical(names(records[[1]]), "contributor")
  testthat::expect_identical(records[[1]]$contributor, "Alex")
  testthat::expect_length(
    compare_nested_config_values(c("Alex", "Bea"), records, "contributors.data"),
    0L
  )

  directory <- make_config_v310()
  expected <- build_observatory_definition(directory)
  yaml_path <- tempfile(fileext = ".yaml")
  yaml::write_yaml(expected, yaml_path, fileEncoding = "UTF-8")
  actual <- yaml::read_yaml(yaml_path)
  testthat::expect_length(compare_nested_config_values(actual, expected), 0L)
})

testthat::test_that("conditional generation steps follow saved survey and crown flags", {
  surveys <- survey_template(); surveys$status <- "TRUE"
  params <- filled_crownfile_params()
  params$value[params$param %in% c("plots_list", "taxa_ref", "dawkins")] <- "TRUE"
  steps <- wizard_steps(surveys, params)
  testthat::expect_true(all(c(
    "tree_picture_zooms", "plots_list", "dawkins_param", "taxa_ref"
  ) %in% steps))
  testthat::expect_lt(match("tree_picture_zooms", steps), match("generated_files", steps))
  testthat::expect_lt(match("plots_list", steps), match("generated_files", steps))
  testthat::expect_lt(match("dawkins_param", steps), match("generated_files", steps))
  testthat::expect_lt(match("taxa_ref", steps), match("generated_files", steps))
})

testthat::test_that("conditional taxa reference has presence warnings and no content check", {
  directory <- make_config_v310()
  params <- filled_crownfile_params(); params$value[params$param == "taxa_ref"] <- "TRUE"
  write_semicolon_csv(params, file.path(directory, "param", "crownfile_param.csv"))
  write_generated_tables(directory)
  missing <- validate_config_input_files(directory)
  testthat::expect_true(missing$ok)
  testthat::expect_match(paste(missing$warnings, collapse = " "), "taxa_ref.csv")
  writeLines("anything;goes\na;b", file.path(directory, "reference", "taxa_ref.csv"))
  present <- validate_config_input_files(directory)
  testthat::expect_true(present$ok)
})

testthat::test_that("unknown plot and creator are warnings while taxa_id values are ignored", {
  directory <- make_config_v310("dynamic")
  params <- filled_crownfile_params("dynamic")
  params$value[params$param %in% c("plots_list", "taxa_ref")] <- "TRUE"
  write_semicolon_csv(params, file.path(directory, "param", "crownfile_param.csv"))
  write_semicolon_csv(data.frame(plot_name = "expected_plot"), file.path(directory, "reference", "plots_list.csv"))
  write_semicolon_csv(data.frame(anything = "accepted"), file.path(directory, "reference", "taxa_ref.csv"))
  write_generated_tables(directory)
  schema <- crownfile_vars_template("dynamic", TRUE, TRUE, FALSE)
  mock_layers <- list()
  for (layer in unique(schema$layer)) {
    rows <- schema[schema$layer == layer, ]
    values <- as.list(rows$exemple); names(values) <- rows$var_name
    mock_layers[[layer]] <- as.data.frame(values, stringsAsFactors = FALSE, check.names = FALSE)
  }
  mock_layers$infos$creator <- "unknown_creator"
  mock_layers$infos$plot_name <- "unknown_plot"
  mock_layers$infos$taxa_id <- "not_an_integer"
  environment <- environment(check_crown_schema_values)
  original <- get("read_crown_layer", envir = environment)
  on.exit(assign("read_crown_layer", original, envir = environment), add = TRUE)
  assign("read_crown_layer", function(path, layer) mock_layers[[layer]], envir = environment)
  checked <- check_crown_schema_values(directory, "unused.gpkg")
  testthat::expect_true(checked$ok)
  testthat::expect_match(paste(checked$warnings, collapse = " "), "infos.plot_name")
  testthat::expect_match(paste(checked$warnings, collapse = " "), "infos.creator")
  testthat::expect_false(any(grepl("taxa_id", checked$errors)))
})

testthat::test_that("generated reference differences are blocking", {
  directory <- make_config_v310()
  write_semicolon_csv(data.frame(lianas = c("0", "1", "2")), file.path(directory, "reference", "lianas.csv"))
  checked <- validate_config_input_files(directory)
  testthat::expect_false(checked$ok)
  testthat::expect_match(paste(checked$errors, collapse = " "), "generated model")
})

testthat::test_that("site_check only lists files with diagnostics", {
  directory <- make_config_v310()
  checked <- validate_config_input_files(directory)
  path <- write_site_check_report(directory, checked)
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  testthat::expect_match(text, "config/param/product.csv")
  testthat::expect_false(grepl("config/param/site.csv", text, fixed = TRUE))
})

testthat::test_that("table comparison marks modified, added, and deleted values", {
  before <- data.frame(
    contributor = c("Alex", "Bea"), role = c("pilot", "observer"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  after <- data.frame(
    contributor = c("Alex", "Chris"), role = c("coordinator", "analyst"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  compared <- compare_config_tables(before, after, "reference/contributors.csv")
  testthat::expect_true(compared$changed)
  testthat::expect_identical(unname(compared$summary), c(1L, 1L, 1L))
  testthat::expect_identical(compared$before_row_status, c("modified", "deleted"))
  testthat::expect_identical(compared$after_row_status, c("modified", "added"))
  testthat::expect_identical(compared$before_modified_cells[[1]], 2L)
  testthat::expect_identical(compared$after_modified_cells[[1]], 2L)
})

testthat::test_that("crownfile parameter preview describes conditional dependencies", {
  directory <- make_config_v310()
  before <- filled_crownfile_params()
  after <- before
  after$value[after$param %in% c("plots_list", "dawkins")] <- "TRUE"
  impacts <- config_change_impacts(directory, "param/crownfile_param.csv", before, after)
  text <- paste(impacts, collapse = " ")
  testthat::expect_match(text, "reference/plots_list.csv", fixed = TRUE)
  testthat::expect_match(text, "param/dawkins_param.csv", fixed = TRUE)
  testthat::expect_match(text, "reference/dawkins.csv", fixed = TRUE)
})

testthat::test_that("publication archives prior outputs and increments same-day reports", {
  directory <- make_config_v310()
  first_snapshot <- capture_config_snapshot(directory)
  first <- generate_config_outputs(
    directory, print_report = FALSE,
    before_snapshot = first_snapshot,
    publication_date = as.Date("2026-08-29")
  )
  testthat::expect_true(first$validation$ok)
  testthat::expect_true(dir.exists(file.path(directory, "archive")))
  testthat::expect_true(file.exists(file.path(directory, "modification_20260829.txt")))
  testthat::expect_false(any(grepl(
    "_observatory_infos[.]html$", names(capture_config_snapshot(directory)$files)
  )))

  second_snapshot <- capture_config_snapshot(directory)
  contributors <- read_delimited_table(file.path(directory, "reference", "contributors.csv"))
  contributors <- rbind(contributors, data.frame(contributor = "Bea", stringsAsFactors = FALSE))
  save_config_table(
    directory, "reference/contributors.csv", contributors,
    update_outputs = FALSE, cross_validate = FALSE, print_report = FALSE
  )
  second <- generate_config_outputs(
    directory, print_report = FALSE,
    before_snapshot = second_snapshot,
    publication_date = as.Date("2026-08-29")
  )
  testthat::expect_true(second$validation$ok)
  testthat::expect_identical(second$archive$id, "20260829_2")
  testthat::expect_true(file.exists(file.path(directory, "archive", "modification_20260829.txt")))
  testthat::expect_true(file.exists(file.path(directory, "archive", "observatory_before_20260829_2.yaml")))
  testthat::expect_true(file.exists(file.path(directory, "archive", "site_check_before_20260829_2.txt")))
  report <- file.path(directory, "modification_20260829_2.txt")
  testthat::expect_true(file.exists(report))
  report_text <- paste(readLines(report, warn = FALSE), collapse = "\n")
  testthat::expect_match(report_text, "[MODIFIED] config/reference/contributors.csv", fixed = TRUE)
  testthat::expect_match(report_text, "BEFORE — RAW CSV", fixed = TRUE)
  testthat::expect_match(report_text, "AFTER — RAW CSV", fixed = TRUE)
  testthat::expect_match(report_text, "contributor\nAlex\n", fixed = TRUE)
  testthat::expect_false(grepl("  | contributor", report_text, fixed = TRUE))
  contributor_position <- regexpr("config/reference/contributors.csv", report_text, fixed = TRUE)[[1]]
  yaml_position <- regexpr("config/observatory.yaml", report_text, fixed = TRUE)[[1]]
  testthat::expect_gt(yaml_position, contributor_position)
  testthat::expect_match(report_text, "BEFORE — RAW YAML", fixed = TRUE)
  testthat::expect_match(report_text, "AFTER — RAW YAML", fixed = TRUE)
  testthat::expect_false(grepl("  | schema_version:", report_text, fixed = TRUE))
  testthat::expect_false(grepl("Mbalmayo_observatory_infos.html", report_text, fixed = TRUE))
})

testthat::test_that("sf geometry columns are normalized immediately after reading", {
  layer <- sf::st_sf(
    id = "crown-1",
    geom = sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326),
    sf_column_name = "geom"
  )
  testthat::expect_identical(attr(layer, "sf_column"), "geom")
  normalized <- normalize_sf_geometry_column(layer)
  testthat::expect_true("geometry" %in% names(normalized))
  testthat::expect_false("geom" %in% names(normalized))
  testthat::expect_identical(attr(normalized, "sf_column"), "geometry")
  testthat::expect_s3_class(sf::st_geometry(normalized), "sfc")
})

testthat::test_that("successful checks distinguish warnings in their printed status", {
  output <- capture.output(print_check_messages(
    "Result", validation_result(warnings = "A non-blocking finding.")
  ))
  testthat::expect_true(any(output == "Status: PASS WITH WARNINGS"))
})

testthat::test_that("raw and processed comparisons can be grouped by product and status", {
  products <- data.frame(
    survey = rep("RGB", 5),
    product = c(
      "RGB_raw", "RGB_raw", "RGB_orthomosaic",
      "RGB_raw", "RGB_orthomosaic"
    ),
    date = c("20260101", "20260101", "20260101", "20260102", "20260103"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  detailed <- compare_raw_processed(products = products)
  testthat::expect_true("completed" %in% detailed$status)
  grouped <- compare_raw_processed(
    products = products,
    group_by_processed_status = TRUE
  )
  completed <- grouped[
    grouped$processed_product == "RGB_orthomosaic" & grouped$status == "completed",
    , drop = FALSE
  ]
  missing <- grouped[
    grouped$processed_product == "RGB_orthomosaic" & grouped$status == "missing_processed",
    , drop = FALSE
  ]
  without_raw <- grouped[
    grouped$processed_product == "RGB_orthomosaic" & grouped$status == "processed_without_raw",
    , drop = FALSE
  ]
  testthat::expect_equal(completed$raw_count, 2)
  testthat::expect_equal(missing$raw_count, 1)
  testthat::expect_equal(without_raw$raw_count, 0)
})

testthat::test_that("the product check report is written and refreshed with the inventory", {
  directory <- tempfile("canobs-product-report-")
  dir.create(directory)
  products <- data.frame(
    survey = "RGB", product = "RGB_raw", date = "20260101",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  check <- validation_result(
    products,
    warnings = c("all_products.csv has not been generated.", "A retained warning.")
  )
  check$config_directory <- directory
  check$current_inventory <- products
  check$inconsistencies <- character()
  check$products_check_path <- write_products_check_report(
    directory, products, warnings = check$warnings, inventory_written = FALSE
  )
  testthat::expect_true(file.exists(check$products_check_path))
  destination <- write_all_products_csv(check, print_report = FALSE)
  testthat::expect_true(file.exists(destination))
  report <- paste(readLines(check$products_check_path, warn = FALSE), collapse = "\n")
  testthat::expect_match(report, "all_products.csv: present", fixed = TRUE)
  testthat::expect_false(grepl("has not been generated", report, fixed = TRUE))
  testthat::expect_match(report, "A retained warning.", fixed = TRUE)
})

testthat::test_that("the four public operations are available", {
  testthat::expect_true(is.function(operation1_generate_config))
  testthat::expect_true(is.function(operation2_modify_config))
  testthat::expect_true(is.function(operation3_check_parameters_and_data))
  testthat::expect_true(is.function(operation4_visualize_parameters_and_data))
})
