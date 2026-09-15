# Graph explorer component, migrated from dggraphui.
# Copyright Pawel Gajer. License: GPL (>= 3).
dg_run_id <- function(run) {
  if (!is.list(run)) {
    return("run")
  }
  paste0(basename(run$run_dir), "-", digest::digest(
    dg_normalize_path(run$run_dir), algo = "xxhash64", serialize = FALSE))
}

dg_selected_metrics <- function(run, row) {
  metrics <- if (is.list(run) && is.data.frame(run$metrics)) run$metrics else data.frame()
  if (!is.data.frame(metrics) || nrow(metrics) < 1L || !is.data.frame(row) || nrow(row) < 1L) {
    return(data.frame())
  }
  metrics[
    as.character(metrics$dataset_id) == as.character(row$dataset_id[[1]]) &
      as.character(metrics$setting_id) == as.character(row$setting_id[[1]]),
    ,
    drop = FALSE
  ]
}

dg_selected_diagnostics <- function(run, row) {
  diagnostics <- if (is.list(run) && is.data.frame(run$diagnostics)) run$diagnostics else data.frame()
  if (!is.data.frame(diagnostics) || nrow(diagnostics) < 1L || !is.data.frame(row) || nrow(row) < 1L) {
    return(data.frame())
  }
  keep <- as.character(diagnostics$dataset_id) == as.character(row$dataset_id[[1]]) &
    as.character(diagnostics$setting_id) == as.character(row$setting_id[[1]])
  if ("stage" %in% names(diagnostics)) {
    keep <- keep & as.character(diagnostics$stage) == as.character(row$stage[[1]])
  }
  diagnostics[keep, , drop = FALSE]
}

dg_view_state <- function(run, selection) {
  if (!is.list(run)) {
    return(list(status = "error", message = "No benchmark run is loaded."))
  }
  if (!is.list(selection) || !is.null(selection$error)) {
    return(list(status = "error", message = dg_scalar_chr(selection$error, "Selection unavailable."), selection = selection))
  }
  if (!identical(selection$status, "ok")) {
    return(list(
      status = selection$status,
      message = sprintf("Selection matched %s graph-stage rows.", as.integer(selection$n_matches %||% 0L)),
      selection = selection
    ))
  }
  key <- dg_scalar_chr(selection$key)
  selected_row <- selection$row[1, , drop = FALSE]

  graph_hit <- dg_exact_graph_row(run, key)
  if (!identical(graph_hit$status, "ok")) {
    return(list(status = "missing_graph", message = sprintf("Could not resolve graph asset row for key %s.", key), key = key, selection = selection, selected_row = selected_row))
  }
  graph_row <- graph_hit$row
  graph_path <- dg_scalar_chr(graph_row$graph_asset_file[[1]])
  graph <- dg_parse_graph_asset(graph_path)
  if (!identical(graph$status, "ok")) {
    return(list(status = "missing_graph", message = graph$message, key = key, selection = selection, selected_row = selected_row, graph_row = graph_row, graph_asset_file = graph_path))
  }

  dataset <- dg_dataset_coords(run, selected_row$dataset_id[[1]])
  metrics <- dg_selected_metrics(run, selected_row)
  diagnostics <- dg_selected_diagnostics(run, selected_row)

  cache_path <- dg_generated_layout_cache_path(dg_run_id(run), key)
  layout <- NULL
  layout_source <- "missing"
  layout_path <- ""
  existing_cache <- if (file.exists(cache_path)) cache_path else dg_legacy_layout_cache_path(run, key, graph_path)
  if (nzchar(existing_cache)) {
    parsed <- dg_parse_layout_asset(existing_cache)
    if (!identical(parsed$status, "ok")) {
      return(list(
        status = "layout_error",
        message = parsed$message,
        key = key,
        selection = selection,
        selected_row = selected_row,
        graph_row = graph_row,
        graph = graph,
        graph_asset_file = graph_path,
        layout_asset_file = existing_cache,
        layout_source = "dggraphui_cache",
        cache_path = cache_path,
        dataset = dataset,
        metrics = metrics,
        diagnostics = diagnostics
      ))
    }
    layout <- parsed
    layout_source <- "dggraphui_cache"
    layout_path <- existing_cache
  } else {
    layout_hit <- dg_exact_layout_row(run, key, method = "weighted_grip")
    if (identical(layout_hit$status, "ok")) {
      layout_row <- layout_hit$row
      benchmark_layout_path <- dg_scalar_chr(layout_row$layout_asset_file[[1]])
      parsed <- dg_parse_layout_asset(benchmark_layout_path)
      if (!identical(parsed$status, "ok")) {
        return(list(
          status = "missing_layout",
          message = parsed$message,
          key = key,
          selection = selection,
          selected_row = selected_row,
          graph_row = graph_row,
          graph = graph,
          graph_asset_file = graph_path,
          layout_row = layout_row,
          layout_asset_file = benchmark_layout_path,
          layout_source = "benchmark",
          cache_path = cache_path,
          dataset = dataset,
          metrics = metrics,
          diagnostics = diagnostics
        ))
      }
      layout <- parsed
      layout_source <- "benchmark"
      layout_path <- benchmark_layout_path
    }
  }

  if (is.null(layout)) {
    return(list(
      status = "missing_layout",
      message = "No weighted GRIP layout is available for the selected graph-stage.",
      key = key,
      selection = selection,
      selected_row = selected_row,
      graph_row = graph_row,
      graph = graph,
      graph_asset_file = graph_path,
      layout_source = "missing",
      cache_path = cache_path,
      dataset = dataset,
      metrics = metrics,
      diagnostics = diagnostics
    ))
  }

  list(
    status = "ok",
    message = "",
    key = key,
    selection = selection,
    selected_row = selected_row,
    graph_row = graph_row,
    graph = graph,
    graph_asset_file = graph_path,
    layout = layout,
    layout_coords = layout$coords,
    layout_asset_file = layout_path,
    layout_source = layout_source,
    cache_path = cache_path,
    dataset = dataset,
    metrics = metrics,
    diagnostics = diagnostics
  )
}

dg_metric_table <- function(metrics) {
  if (!is.data.frame(metrics) || nrow(metrics) < 1L) {
    return(data.frame())
  }
  keep <- intersect(
    c(
      "target", "status", "rel_rms_error", "rel_geodesic_stress",
      "rel_abs_error_median", "rel_abs_error_q95", "distortion_median",
      "pearson_cor", "spearman_cor", "signed_bias", "shortcut_fraction"
    ),
    names(metrics)
  )
  out <- metrics[, keep, drop = FALSE]
  for (cc in names(out)) {
    if (is.numeric(out[[cc]])) {
      out[[cc]] <- vapply(out[[cc]], dg_format_number, character(1))
    } else {
      out[[cc]] <- as.character(out[[cc]])
    }
  }
  out
}

dg_parameter_scan <- function(run, selected_row, target = "surface") {
  if (!is.list(run) || !is.data.frame(run$metrics) || !is.data.frame(selected_row) || nrow(selected_row) < 1L) {
    return(data.frame())
  }
  metrics <- dg_metric_settings_index(run$index, run$metrics)
  if ("target" %in% names(metrics)) {
    metrics <- metrics[as.character(metrics$target) == dg_scalar_chr(target, "surface"), , drop = FALSE]
  }
  filter_cols <- intersect(c("surface", "curvature_label", "domain_shape", "sampling_profile", "n", "seed"), names(selected_row))
  for (cc in filter_cols) {
    if (cc %in% names(metrics)) {
      metrics <- metrics[as.character(metrics[[cc]]) == as.character(selected_row[[cc]][[1]]), , drop = FALSE]
    }
  }
  metrics
}
