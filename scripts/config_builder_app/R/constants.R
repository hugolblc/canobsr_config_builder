`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

CANOBS_SCHEMA_VERSION <- "3.1.0"
CANOBS_SITE_PARAMETERS <- c("id_site", "name", "location", "crs")
CANOBS_SURVEYS <- c("RGB", "MS", "DLS", "tree_pictures")
CANOBS_CROWNFILE_TYPES <- c("light", "dynamic")
CANOBS_CROWNFILE_PARAMETERS <- c("path", "server", "crownfile_type", "plots_list", "taxa_ref", "dawkins")
CANOBS_DRONE_STATUSES <- c("active", "not active")
CANOBS_ZOOM_TYPES <- c("native", "digital")
CANOBS_DATE_FORMAT <- "yyyymmdd"

CANOBS_SURVEY_PRODUCTS <- list(
  RGB = c("RGB_raw", "RGB_orthomosaic", "RGB_DEM", "RGB_vignette", "RGB_indices", "RGB_phenophase"),
  MS = c("MS_raw", "MS_orthomosaic", "MS_DEM", "MS_vignette", "MS_indices"),
  DLS = c("DLS_raw", "DLS_CHM", "DLS_DTM", "DLS_indices"),
  tree_pictures = c("raw_tree_picture", "sorted_tree_picture")
)

CANOBS_DAWKINS_PARAMETERS <- c(
  "daw5_H_ratio", "daw5_ratio_mean", "daw3_H_ratio", "daw3_ratio_mean",
  "daw5b_ratio_min_strict", "daw5b_ratio_min_souple", "daw5b_slope_norm",
  "daw4c_ratio_above1", "daw4c_ratio_cv", "daw4a_ratio_above1",
  "daw3c_openness", "daw3c_ratio_above1", "daw3a_ratio_above1", "daw3a_openness"
)

CANOBS_PATTERN_BASE_TOKENS <- c(
  "product", "date", "date:%Y-%m-%d", "date:%Y_%m_%d", "sensor", "site",
  "zoom", "capture.picture_code", "original_name", "extension"
)
CANOBS_DATE_PATTERN_FORMATS <- c(
  "date" = "%Y%m%d", "date:%Y-%m-%d" = "%Y-%m-%d", "date:%Y_%m_%d" = "%Y_%m_%d"
)
CANOBS_CROWN_TRANSFORMS <- "space_to_hyphen"

CANOBS_EDITABLE_PATHS <- c(
  file.path("param", "site.csv"), file.path("param", "survey.csv"),
  file.path("param", "sensor.csv"), file.path("param", "product.csv"),
  file.path("param", "crownfile_param.csv"), file.path("param", "tree_picture_zooms.csv"),
  file.path("reference", "contributors.csv"), file.path("reference", "plots_list.csv"),
  file.path("param", "dawkins_param.csv"), file.path("reference", "taxa_ref.csv"),
  file.path("path", "UAV_folder.csv"), file.path("path", "UAV_file_patterns.csv"),
  file.path("path", "vectors.csv")
)

CANOBS_GENERATED_PATHS <- c(
  file.path("param", "crownfile_vars.csv"), file.path("reference", "dawkins.csv"),
  file.path("reference", "dbh_types.csv"), file.path("reference", "geom_modif.csv"),
  file.path("reference", "lianas.csv"), file.path("reference", "tree_status.csv"),
  file.path("reference", "type_obs.csv")
)

named_value_or <- function(values, name, default = "") {
  if (is.null(values) || !length(values) || is.null(names(values)) || !name %in% names(values)) return(default)
  value <- values[[name]]
  if (is.null(value) || !length(value) || is.na(value[[1]])) return(default)
  as.character(value[[1]])
}

is_true_value <- function(values, name) identical(named_value_or(values, name), "TRUE")

site_template <- function() {
  data.frame(param = CANOBS_SITE_PARAMETERS, site_value = "", stringsAsFactors = FALSE, check.names = FALSE)
}

survey_template <- function() {
  data.frame(
    survey = CANOBS_SURVEYS, status = c("TRUE", "FALSE", "FALSE", "FALSE"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

sensor_template <- function() {
  data.frame(
    sensor = "", survey = "", start_date = "", end_date = "", status = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

product_template <- function() {
  rows <- do.call(rbind, lapply(names(CANOBS_SURVEY_PRODUCTS), function(survey) {
    data.frame(
      survey = survey, product = CANOBS_SURVEY_PRODUCTS[[survey]], status = "FALSE",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }))
  rownames(rows) <- NULL
  rows
}

products_for_active_surveys <- function(products = product_template(), surveys = survey_template()) {
  products <- as.data.frame(products, stringsAsFactors = FALSE, check.names = FALSE)
  surveys <- as.data.frame(surveys, stringsAsFactors = FALSE, check.names = FALSE)
  if (!all(c("survey", "status") %in% names(surveys)) || !"survey" %in% names(products)) {
    return(products)
  }
  active <- surveys$survey[surveys$status == "TRUE"]
  result <- products[products$survey %in% active, , drop = FALSE]
  rownames(result) <- NULL
  result
}

complete_product_catalog <- function(products, surveys = survey_template()) {
  products <- as.data.frame(products, stringsAsFactors = FALSE, check.names = FALSE)
  complete <- product_template()
  if (!all(c("survey", "product", "status") %in% names(products))) return(products)
  active <- products_for_active_surveys(complete, surveys)
  visible_keys <- paste(products$survey, products$product, sep = "|")
  active_keys <- paste(active$survey, active$product, sep = "|")
  if (nrow(products) != nrow(active) || anyDuplicated(visible_keys) || !setequal(visible_keys, active_keys)) {
    return(products)
  }
  complete_keys <- paste(complete$survey, complete$product, sep = "|")
  complete$status[match(visible_keys, complete_keys)] <- products$status
  complete
}

crownfile_param_template <- function() {
  data.frame(
    param = CANOBS_CROWNFILE_PARAMETERS,
    value = c("", "", "dynamic", "FALSE", "FALSE", "FALSE"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

tree_picture_zooms_template <- function(sensors = NULL) {
  sensors <- as.data.frame(sensors %||% data.frame(), stringsAsFactors = FALSE)
  names_ok <- all(c("sensor", "survey") %in% names(sensors))
  values <- if (names_ok) unique(sensors$sensor[sensors$survey == "tree_pictures"]) else ""
  values <- values[!is.na(values) & nzchar(trimws(values))]
  if (!length(values)) values <- ""
  data.frame(
    sensor = values, zoom = "", zoom_type = "", effective_focal = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

contributors_template <- function() data.frame(contributor = "", stringsAsFactors = FALSE, check.names = FALSE)
plots_template <- function() data.frame(plot_name = "", stringsAsFactors = FALSE, check.names = FALSE)

dawkins_param_template <- function() {
  defaults <- c(1.5, 1.3, 1.1, 1.0, 1.3, 1.1, -0.015, 0.88, 0.2, 0.62, 0.08, 0.38, 0.25, -0.05)
  data.frame(
    param = CANOBS_DAWKINS_PARAMETERS, value = as.character(defaults),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

taxa_ref_template <- function() data.frame(taxa_id = "", stringsAsFactors = FALSE, check.names = FALSE)

uav_folder_template <- function(products = NULL) {
  products <- as.data.frame(products %||% product_template(), stringsAsFactors = FALSE)
  if (!all(c("survey", "product", "status") %in% names(products))) products <- product_template()
  data.frame(
    survey = products$survey, product = products$product, server = "", path = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

uav_file_patterns_template <- function(products = NULL) {
  products <- as.data.frame(products %||% product_template(), stringsAsFactors = FALSE)
  if (!all(c("survey", "product", "status") %in% names(products))) products <- product_template()
  data.frame(
    survey = products$survey, product = products$product,
    directory_pattern = "", filename_pattern = "",
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

vectors_template <- function() {
  data.frame(
    file = character(), server = character(), path = character(), description = character(),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

survey_product_catalog <- function() {
  data.frame(
    survey = rep(names(CANOBS_SURVEY_PRODUCTS), lengths(CANOBS_SURVEY_PRODUCTS)),
    product = unlist(CANOBS_SURVEY_PRODUCTS, use.names = FALSE),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

crownfile_vars_template <- function(
    crownfile_type = "dynamic", plots_list = FALSE, taxa_ref = FALSE, dawkins = FALSE) {
  crownfile_type <- tolower(trimws(as.character(crownfile_type[[1]])))
  if (!crownfile_type %in% CANOBS_CROWNFILE_TYPES) stop("crownfile_type must be light or dynamic.", call. = FALSE)

  geometry <- data.frame(
    layer = "geometry",
    var_name = c("site", "geom_id", "id", "date", "Tree_Status", "version", "Geom_Modif", "geometry"),
    type = c("chr", "integer PK", "integer FK", "date", "chr FK", "integer", "chr FK", "MULTIPOLYGON"),
    reference_tables = c("", "", "crowns.gpkg", "", "tree_status.csv", "", "geom_modif.csv", ""),
    reference_layer = c("", "", "infos", "", "", "", "", ""),
    exemple = c("mba", "23", "112", "20221125", "Alive", "2", "Geometrical_Correction", "NA"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  infos <- data.frame(
    layer = "infos",
    var_name = c("site", "id", "tax_sp_level", "tax_gen", "tax_fam", "Type_Obs", "lianas", "comments", "creator", "dbh", "dbh_type", "crown_area"),
    type = c("chr", "integer PK", "chr", "chr", "chr", "chr FK", "integer FK", "chr", "chr FK", "dbl", "chr FK", "dbl"),
    reference_tables = c("", "", "", "", "", "type_obs.csv", "lianas.csv", "", "contributors.csv", "", "dbh_types.csv", ""),
    reference_layer = "",
    exemple = c("mba", "112", "Lophira alata", "Lophira", "Ochnaceae", "Field", "0", "", "Alex", "25.6", "measured", "741"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  conditional <- list()
  if (isTRUE(plots_list)) conditional[[length(conditional) + 1L]] <- data.frame(
    layer = "infos", var_name = "plot_name", type = "chr FK", reference_tables = "plots_list.csv",
    reference_layer = "", exemple = "mbalmayo003", stringsAsFactors = FALSE, check.names = FALSE
  )
  if (isTRUE(taxa_ref)) conditional[[length(conditional) + 1L]] <- data.frame(
    layer = "infos", var_name = "taxa_id", type = "integer FK", reference_tables = "taxa_ref.csv",
    reference_layer = "", exemple = "1289", stringsAsFactors = FALSE, check.names = FALSE
  )
  if (isTRUE(dawkins)) conditional[[length(conditional) + 1L]] <- data.frame(
    layer = "infos", var_name = "dawkins_code", type = "chr FK", reference_tables = "dawkins.csv",
    reference_layer = "", exemple = "4c - Canopy", stringsAsFactors = FALSE, check.names = FALSE
  )
  if (identical(crownfile_type, "light")) {
    geometry <- geometry[geometry$var_name %in% c("site", "id", "date", "geometry"), , drop = FALSE]
    id_row <- geometry$var_name == "id"
    geometry$type[id_row] <- "integer PK"
    geometry$reference_tables[id_row] <- ""
    geometry$reference_layer[id_row] <- ""
    infos <- infos[!infos$var_name %in% c("site", "id"), , drop = FALSE]
    result <- do.call(rbind, c(list(geometry, infos), conditional))
    result$layer <- "crowns"
    result <- result[, c("layer", setdiff(names(result), "layer")), drop = FALSE]
  } else {
    result <- do.call(rbind, c(list(geometry, infos), conditional))
  }
  rownames(result) <- NULL
  result
}

default_reference_tables <- function(crownfile_type = "dynamic", dawkins = FALSE) {
  tables <- list(
    "dbh_types.csv" = data.frame(dbh_types = c("estimated", "measured"), check.names = FALSE),
    "lianas.csv" = data.frame(lianas = c("0", "1"), check.names = FALSE),
    "type_obs.csv" = data.frame(Type_Obs = c("Field", "Photo", "Remote_sensing"), check.names = FALSE)
  )
  if (identical(tolower(crownfile_type), "dynamic")) {
    tables[["geom_modif.csv"]] <- data.frame(Geom_Modif = c("Initial", "Geometrical_Correction", "Geometrical_Change"), check.names = FALSE)
    tables[["tree_status.csv"]] <- data.frame(Tree_Status = c("Alive", "Dead", "Fallen", "Missing", "Recruited"), check.names = FALSE)
  }
  if (isTRUE(dawkins)) {
    tables[["dawkins.csv"]] <- data.frame(
      Dawkins = c("3a - Some overhead light", "3b - Some overhead light", "3c - Lower canopy", "4a - Full overhead light", "4b - Full overhead light", "4c - Canopy", "5a - Emergent", "5b - Emergent"),
      check.names = FALSE
    )
  }
  tables
}

wizard_steps <- function(surveys = survey_template(), crown_params = crownfile_param_template()) {
  survey_values <- stats::setNames(surveys$status, surveys$survey)
  params <- stats::setNames(crown_params$value, crown_params$param)
  c(
    "site", "survey", "sensor", "product", "crownfile_param",
    if (identical(survey_values[["tree_pictures"]], "TRUE")) "tree_picture_zooms",
    "contributors", if (identical(params[["plots_list"]], "TRUE")) "plots_list",
    if (identical(params[["dawkins"]], "TRUE")) "dawkins_param",
    if (identical(params[["taxa_ref"]], "TRUE")) "taxa_ref",
    "generated_files", "UAV_folder", "UAV_file_patterns", "vectors", "outputs"
  )
}

resolve_directory_roots <- function(roots) {
  resolved <- if (is.function(roots)) roots() else roots
  if (is.null(names(resolved))) stop("Directory roots must be named.", call. = FALSE)
  resolved
}

parse_directory_selection <- function(roots, selection) shinyFiles::parseDirPath(resolve_directory_roots(roots), selection)
