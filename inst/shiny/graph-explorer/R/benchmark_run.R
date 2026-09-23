# Graph explorer component, migrated from dggraphui.
# Copyright Pawel Gajer. License: GPL (>= 3).
dg_stage_key <- function(dataset_id, setting_id, stage) {
  paste(as.character(dataset_id %||% ""), as.character(setting_id %||% ""), as.character(stage %||% ""), sep = "||")
}

dg_split_stage_key <- function(key) {
  parts <- strsplit(dg_scalar_chr(key), "||", fixed = TRUE)[[1]]
  if (length(parts) != 3L) {
    return(list(dataset_id = "", setting_id = "", stage = ""))
  }
  list(dataset_id = parts[[1]], setting_id = parts[[2]], stage = parts[[3]])
}

dg_required_run_files <- function(run_dir) {
  root <- dg_normalize_path(run_dir, must_work = TRUE)
  list(
    manifest_rds = file.path(root, "quadform_benchmark_manifest.rds"),
    manifest_json = file.path(root, "quadform_benchmark_manifest.json"),
    dataset_manifest_file = file.path(root, "dataset_manifest.csv"),
    metrics_file = file.path(root, "metrics.csv"),
    dataset_assets_file = file.path(root, "dataset_assets.csv"),
    graph_assets_file = file.path(root, "graph_assets.csv"),
    layout_assets_file = file.path(root, "layout_assets.csv"),
    graph_diagnostics_file = file.path(root, "graph_diagnostics.csv")
  )
}

dg_summarize_table <- function(tbl, key_cols = character(0)) {
  if (!is.data.frame(tbl) || nrow(tbl) < 1L) {
    return(list(n_rows = 0L, columns = character(0)))
  }
  out <- list(n_rows = as.integer(nrow(tbl)), columns = names(tbl))
  for (col in key_cols) {
    if (col %in% names(tbl)) {
      vals <- unique(as.character(tbl[[col]]))
      vals <- vals[!is.na(vals) & nzchar(vals)]
      out[[paste0("n_", col)]] <- as.integer(length(vals))
    }
  }
  out
}

dg_normalize_stage_table <- function(tbl, root, path_col) {
  if (!is.data.frame(tbl) || nrow(tbl) < 1L) {
    return(data.frame())
  }
  out <- tbl
  for (cc in c("dataset_id", "setting_id", "stage")) {
    if (!(cc %in% names(out))) {
      out[[cc]] <- ""
    }
    out[[cc]] <- as.character(out[[cc]])
  }
  if (path_col %in% names(out)) {
    out[[path_col]] <- vapply(out[[path_col]], dg_normalize_path, character(1), root = root, must_work = FALSE)
  }
  out$stage_key <- dg_stage_key(out$dataset_id, out$setting_id, out$stage)
  rownames(out) <- NULL
  out
}

dg_extract_graph_settings <- function(manifest, metrics, run_dir) {
  if (is.list(manifest) && is.data.frame(manifest$graph_settings)) {
    return(manifest$graph_settings)
  }
  graph_settings_file <- file.path(run_dir, "graph_settings.csv")
  if (file.exists(graph_settings_file)) {
    return(dg_read_csv(graph_settings_file))
  }
  if (is.data.frame(metrics) && nrow(metrics) > 0L &&
      all(c("dataset_id", "setting_id") %in% names(metrics))) {
    return(metrics[!duplicated(metrics[, c("dataset_id", "setting_id"), drop = FALSE]), , drop = FALSE])
  }
  data.frame()
}

#' Load A Data-Geodesic Benchmark Run
#'
#' Reads the benchmark manifest and asset tables produced by the data geodesic
#' reconstruction benchmark runner. The benchmark runner asset tables are
#' treated as read-only source-of-truth files.
#'
#' @param run_dir Benchmark run directory.
#'
#' @return A normalized benchmark-run list.
load_benchmark_run <- function(run_dir) {
  root <- dg_normalize_path(run_dir, must_work = TRUE)
  files <- dg_required_run_files(root)
  missing <- names(files)[!file.exists(unlist(files, use.names = FALSE))]
  if (length(missing) > 0L) {
    stop(sprintf("Missing benchmark run file(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }

  manifest <- tryCatch(readRDS(files$manifest_rds), error = function(e) NULL)
  if (!is.list(manifest)) {
    stop("Could not read quadform_benchmark_manifest.rds.", call. = FALSE)
  }

  dataset_manifest <- dg_read_csv(files$dataset_manifest_file)
  metrics <- dg_read_csv(files$metrics_file)
  dataset_assets <- dg_read_csv(files$dataset_assets_file)
  graph_assets <- dg_normalize_stage_table(dg_read_csv(files$graph_assets_file), root, "graph_asset_file")
  layout_assets <- dg_normalize_stage_table(dg_read_csv(files$layout_assets_file), root, "layout_asset_file")
  diagnostics <- dg_read_csv(files$graph_diagnostics_file)

  if (is.data.frame(dataset_assets) && nrow(dataset_assets) > 0L) {
    path_col <- dg_first_col(dataset_assets, c("dataset_asset_file", "path", "file"))
    if (nzchar(path_col)) {
      dataset_assets[[path_col]] <- vapply(dataset_assets[[path_col]], dg_normalize_path, character(1), root = root, must_work = FALSE)
    }
  }

  graph_settings <- dg_extract_graph_settings(manifest, metrics, root)
  if (is.data.frame(graph_settings) && nrow(graph_settings) > 0L && "stage" %in% names(graph_settings)) {
    names(graph_settings)[names(graph_settings) == "stage"] <- "metric_stage"
  }

  index <- graph_assets
  if (nrow(index) > 0L && is.data.frame(graph_settings) && nrow(graph_settings) > 0L) {
    join_cols <- intersect(c("dataset_id", "setting_id"), intersect(names(index), names(graph_settings)))
    if (length(join_cols) == 2L) {
      index <- merge(index, graph_settings, by = join_cols, all.x = TRUE, sort = FALSE, suffixes = c("", "_setting"))
    }
  }
  if (nrow(index) > 0L && is.data.frame(dataset_manifest) && nrow(dataset_manifest) > 0L &&
      "dataset_id" %in% names(dataset_manifest)) {
    dm <- dataset_manifest
    names(dm) <- gsub("\\.", "_", names(dm))
    add_cols <- setdiff(names(dm), names(index))
    index <- merge(index, dm[, c("dataset_id", add_cols), drop = FALSE], by = "dataset_id", all.x = TRUE, sort = FALSE)
  }
  index$stage_key <- dg_stage_key(index$dataset_id, index$setting_id, index$stage)
  rownames(index) <- NULL

  list(
    run_dir = root,
    manifest = manifest,
    files = files,
    dataset_manifest = dataset_manifest,
    dataset_assets = dataset_assets,
    graph_assets = graph_assets,
    layout_assets = layout_assets,
    metrics = metrics,
    graph_settings = graph_settings,
    diagnostics = diagnostics,
    index = index,
    summary = list(
      datasets = dg_summarize_table(dataset_assets, "dataset_id"),
      graph_assets = dg_summarize_table(graph_assets, c("dataset_id", "setting_id", "stage")),
      layout_assets = dg_summarize_table(layout_assets, c("dataset_id", "setting_id", "stage")),
      metrics = dg_summarize_table(metrics, c("dataset_id", "setting_id", "target"))
    )
  )
}

dg_exact_graph_row <- function(run, key) {
  ga <- if (is.list(run)) run$graph_assets else data.frame()
  if (!is.data.frame(ga) || nrow(ga) < 1L || !("stage_key" %in% names(ga))) {
    return(list(status = "missing_index", row = data.frame()))
  }
  hit <- which(as.character(ga$stage_key) == as.character(key))
  if (length(hit) == 1L) {
    return(list(status = "ok", row = ga[hit, , drop = FALSE]))
  }
  list(status = if (length(hit) < 1L) "no_match" else "ambiguous", row = if (length(hit) > 0L) ga[hit, , drop = FALSE] else data.frame())
}

dg_exact_layout_row <- function(run, key, method = "weighted_grip") {
  la <- if (is.list(run)) run$layout_assets else data.frame()
  if (!is.data.frame(la) || nrow(la) < 1L || !("stage_key" %in% names(la))) {
    return(list(status = "missing_index", row = data.frame()))
  }
  hit <- which(as.character(la$stage_key) == as.character(key))
  if ("method" %in% names(la) && nzchar(dg_scalar_chr(method))) {
    hit <- hit[tolower(as.character(la$method[hit])) == tolower(dg_scalar_chr(method))]
  }
  if (length(hit) == 1L) {
    return(list(status = "ok", row = la[hit, , drop = FALSE]))
  }
  list(status = if (length(hit) < 1L) "no_match" else "ambiguous", row = if (length(hit) > 0L) la[hit, , drop = FALSE] else data.frame())
}

dg_parse_graph_asset <- function(path) {
  pp <- dg_scalar_chr(path)
  if (!nzchar(pp) || !file.exists(pp)) {
    return(list(status = "missing_graph", message = "Graph asset file is missing.", path = pp))
  }
  obj <- tryCatch(readRDS(pp), error = function(e) e)
  if (inherits(obj, "error")) {
    return(list(status = "error", message = conditionMessage(obj), path = pp))
  }
  adj <- obj$adj_list %||% obj$adj.list
  weight <- obj$weight_list %||% obj$weight.list %||% obj$edge.length.list
  if (!is.list(adj) || length(adj) < 1L) {
    return(list(status = "error", message = "Graph asset does not contain adj_list.", path = pp))
  }
  if (!is.list(weight) || length(weight) != length(adj)) {
    return(list(status = "error", message = "Graph asset does not contain weight_list matching adj_list.", path = pp))
  }
  list(status = "ok", obj = obj, adj_list = adj, weight_list = weight, n_vertices = length(adj), path = pp)
}

dg_parse_layout_asset <- function(path) {
  pp <- dg_scalar_chr(path)
  if (!nzchar(pp) || !file.exists(pp)) {
    return(list(status = "missing_layout", message = "Layout asset file is missing.", path = pp))
  }
  obj <- tryCatch(readRDS(pp), error = function(e) e)
  if (inherits(obj, "error")) {
    return(list(status = "error", message = conditionMessage(obj), path = pp))
  }
  coords <- if (is.list(obj) && !is.null(obj$coords)) obj$coords else obj
  coords <- dg_coord_matrix(coords)
  if (is.null(coords)) {
    return(list(status = "error", message = "Layout asset does not contain a 3-column coordinate matrix.", path = pp))
  }
  list(status = "ok", obj = obj, coords = coords, path = pp)
}

dg_cache_root <- function() {
  opt <- getOption("dgraphs.graph_explorer_cache_dir", NULL)
  if (!is.null(opt) && nzchar(dg_scalar_chr(opt))) {
    return(dg_normalize_path(opt, must_work = FALSE))
  }
  file.path(tools::R_user_dir("dgraphs", "cache"), "layouts")
}

dg_generated_layout_cache_path <- function(run_id, key) {
  parts <- dg_split_stage_key(key)
  file.path(
    dg_cache_root(),
    dg_safe_token(run_id, "run"),
    dg_safe_token(parts$dataset_id, "dataset"),
    dg_safe_token(parts$setting_id, "setting"),
    sprintf("%s_weighted_grip_3d.rds", dg_safe_token(parts$stage, "stage"))
  )
}

# This boundary translates three retained layout-schema fields to the public
# grip API. Saved assets and UI fields keep their existing spellings.
dg.weighted.layout.adapter <- function(layout.fun) {
  if (!is.function(layout.fun)) return(NULL)
  formal.names <- names(formals(layout.fun))
  common <- c("dim", "rounds", "seed", "metric")
  current <- all(c(common, "adj.list", "weight.list", "final.rounds") %in% formal.names)
  previous <- all(c(common, "adj_list", "weight_list", "final_rounds") %in% formal.names)
  if (!current && !previous) return(NULL)
  function(...) {
    args <- list(...)
    aliases <- c(adj_list = "adj.list", weight_list = "weight.list", final_rounds = "final.rounds")
    if (!current) aliases <- setNames(names(aliases), unname(aliases))
    renamed <- names(args)
    hit <- renamed %in% names(aliases)
    renamed[hit] <- unname(aliases[renamed[hit]])
    if (anyDuplicated(renamed)) stop("Ambiguous old and new GRIP argument names.", call. = FALSE)
    names(args) <- renamed
    if ("metric" %in% names(args)) stop("The explorer fixes the GRIP metric to edge_length.", call. = FALSE)
    do.call(layout.fun, c(args, list(metric = "edge_length")))
  }
}

dg_weighted_layout_fun <- function() {
  if (!requireNamespace("grip", quietly = TRUE)) return(NULL)
  # Prefer the public interface; never call the deprecated weighted alias.
  dg.weighted.layout.adapter(getExportedValue("grip", "grip"))
}

dg_generate_weighted_layout <- function(graph_asset_path, output_path, params = list(), weighted_layout_fun = dg_weighted_layout_fun()) {
  graph <- dg_parse_graph_asset(graph_asset_path)
  if (!identical(graph$status, "ok")) {
    return(list(status = graph$status, message = graph$message %||% "Graph asset unavailable."))
  }
  if (!is.function(weighted_layout_fun)) {
    return(list(status = "unavailable", message = "Package `grip` with `grip(metric = \"edge_length\")` is required."))
  }
  params_use <- list(dim = 3L, rounds = 8L, final_rounds = 12L, seed = 6L)
  if (is.list(params) && length(params) > 0L) {
    params_use[names(params)] <- params
  }
  layout <- tryCatch(
    do.call(weighted_layout_fun, c(list(adj_list = graph$adj_list, weight_list = graph$weight_list), params_use)),
    error = function(e) e
  )
  if (inherits(layout, "error")) {
    return(list(status = "error", message = conditionMessage(layout)))
  }
  coords <- if (is.list(layout) && !is.null(layout$coords)) layout$coords else layout
  coords <- dg_coord_matrix(coords)
  if (is.null(coords)) {
    return(list(status = "error", message = "Weighted layout result did not contain 3D coordinates."))
  }
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(
    list(
      method = "weighted_grip",
      coords = coords,
      params = params_use,
      graph_asset_file = dg_normalize_path(graph_asset_path, must_work = FALSE),
      created_at = dg_now()
    ),
    output_path
  )
  list(status = "ok", path = dg_normalize_path(output_path, must_work = FALSE), coords = coords)
}

dg_dataset_coords <- function(run, dataset_id) {
  ds_assets <- if (is.list(run) && is.data.frame(run$dataset_assets)) run$dataset_assets else data.frame()
  if (!is.data.frame(ds_assets) || nrow(ds_assets) < 1L || !("dataset_id" %in% names(ds_assets))) {
    return(list(status = "missing_dataset", message = "Dataset asset index is missing."))
  }
  hit <- which(as.character(ds_assets$dataset_id) == as.character(dataset_id))
  if (length(hit) != 1L) {
    return(list(status = if (length(hit) < 1L) "missing_dataset" else "ambiguous_dataset", message = "Could not resolve one dataset asset row."))
  }
  path_col <- dg_first_col(ds_assets, c("dataset_asset_file", "path", "file"))
  pp <- if (nzchar(path_col)) dg_scalar_chr(ds_assets[[path_col]][[hit]]) else ""
  if (!nzchar(pp) || !file.exists(pp)) {
    return(list(status = "missing_dataset", message = "Dataset asset file is missing.", path = pp))
  }
  obj <- tryCatch(readRDS(pp), error = function(e) e)
  if (inherits(obj, "error")) {
    return(list(status = "error", message = conditionMessage(obj), path = pp))
  }
  coords <- dg_coord_matrix(obj$X_embed %||% obj$X %||% obj$coords)
  if (is.null(coords)) {
    return(list(status = "error", message = "Dataset asset does not contain 3D coordinates.", path = pp))
  }
  list(status = "ok", coords = coords, obj = obj, path = pp)
}
