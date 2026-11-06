# Graph explorer component, migrated from dggraphui.
# Copyright Pawel Gajer. License: GPL (>= 3).
dg_selector_label <- function(x) {
  switch(
    as.character(x),
    selection_mode = "Selection mode",
    metric_target = "Metric target",
    surface = "Surface",
    curvature_label = "Curvature",
    domain_shape = "Domain",
    sampling_profile = "Sampling",
    n = "n",
    seed = "Seed",
    graph_family = "Graph family",
    k = "k",
    radius_rank = "Radius rank",
    k_scale = "k scale",
    radius_rule = "Radius rule",
    radius_factor = "Radius factor",
    delta = "delta",
    prune_method = "Pruning",
    stage = "Stage",
    as.character(x)
  )
}

dg_dataset_selector_fields <- function(index_df) {
  base <- c("surface", "curvature_label", "domain_shape", "sampling_profile", "n", "seed")
  base[base %in% names(index_df)]
}

dg_family_param_fields <- function(family) {
  fam <- dg_scalar_chr(family)
  if (fam %in% c("sknn", "mknn", "iknn")) {
    return("k")
  }
  if (identical(fam, "fixed_radius")) {
    return("radius_rank")
  }
  if (identical(fam, "adaptive_radius")) {
    return(c("k_scale", "radius_rule", "radius_factor"))
  }
  if (identical(fam, "cknn")) {
    return(c("k_scale", "delta"))
  }
  character(0)
}

dg_field_spec <- function(field, choices, selected, any = FALSE) {
  vals <- as.character(choices)
  vals <- vals[!is.na(vals) & nzchar(vals)]
  named <- stats::setNames(vals, vals)
  if (isTRUE(any)) {
    named <- c(Any = "", named)
  }
  list(
    id = field,
    input_id = paste0("dg_", field),
    label = dg_selector_label(field),
    choices = named,
    selected = selected
  )
}

dg_mode_field <- function(selected = "manual") {
  sel <- dg_scalar_chr(selected, "manual")
  if (!sel %in% c("manual", "optimal")) {
    sel <- "manual"
  }
  list(
    id = "selection_mode",
    input_id = "dg_selection_mode",
    label = "Selection mode",
    choices = c(Manual = "manual", Optimal = "optimal"),
    selected = sel
  )
}

dg_metric_target_field <- function(metrics, selected = "") {
  vals <- if (is.data.frame(metrics) && "target" %in% names(metrics)) dg_order_values(metrics$target, "target") else character(0)
  if (length(vals) < 1L) {
    vals <- "surface"
  }
  sel <- dg_scalar_chr(selected)
  if (!sel %in% vals) {
    sel <- vals[[1]]
  }
  dg_field_spec("metric_target", vals, sel)
}

dg_stage_key_from_row <- function(row) {
  if (!is.data.frame(row) || nrow(row) < 1L) {
    return("")
  }
  dg_stage_key(row$dataset_id[[1]], row$setting_id[[1]], row$stage[[1]])
}

dg_manual_selector_state <- function(index_df, input_values = list()) {
  if (!is.data.frame(index_df) || nrow(index_df) < 1L) {
    return(list(error = "No benchmark graph-stage rows are available.", fields = list(), row = data.frame()))
  }
  candidate <- index_df
  fields <- list(dg_mode_field("manual"))

  add_field <- function(field) {
    if (!(field %in% names(candidate))) {
      return(invisible(NULL))
    }
    vals <- dg_order_values(candidate[[field]], field)
    if (length(vals) < 1L) {
      return(invisible(NULL))
    }
    input_val <- dg_scalar_chr(input_values[[field]])
    selected <- if (input_val %in% vals) input_val else vals[[1]]
    fields[[length(fields) + 1L]] <<- dg_field_spec(field, vals, selected)
    candidate <<- candidate[as.character(candidate[[field]]) == selected, , drop = FALSE]
    invisible(NULL)
  }

  for (field in dg_dataset_selector_fields(index_df)) {
    add_field(field)
  }
  add_field("graph_family")
  family_selected <- ""
  for (field_spec in fields) {
    if (identical(field_spec$id, "graph_family")) {
      family_selected <- field_spec$selected
    }
  }
  for (field in dg_family_param_fields(family_selected)) {
    add_field(field)
  }
  for (field in c("prune_method", "stage")) {
    add_field(field)
  }

  status <- if (nrow(candidate) == 1L) "ok" else if (nrow(candidate) < 1L) "no_match" else "ambiguous"
  list(
    error = NULL,
    mode = "manual",
    status = status,
    fields = fields,
    row = if (nrow(candidate) > 0L) candidate[seq_len(min(50L, nrow(candidate))), , drop = FALSE] else data.frame(),
    n_matches = as.integer(nrow(candidate)),
    key = if (nrow(candidate) == 1L) dg_stage_key_from_row(candidate[1, , drop = FALSE]) else ""
  )
}

dg_metric_settings_index <- function(index_df, metrics) {
  if (!is.data.frame(metrics) || nrow(metrics) < 1L) {
    return(data.frame())
  }
  out <- metrics
  for (cc in c("dataset_id", "setting_id")) {
    if (!(cc %in% names(out))) {
      out[[cc]] <- ""
    }
    out[[cc]] <- as.character(out[[cc]])
  }
  if (!is.data.frame(index_df) || nrow(index_df) < 1L) {
    return(out)
  }
  setting_cols <- setdiff(names(index_df), c("stage", "stage_key", "graph_asset_file"))
  setting_cols <- unique(c("dataset_id", "setting_id", setting_cols))
  setting_cols <- intersect(setting_cols, names(index_df))
  setting_index <- index_df[, setting_cols, drop = FALSE]
  setting_index <- setting_index[!duplicated(setting_index[, c("dataset_id", "setting_id"), drop = FALSE]), , drop = FALSE]
  add_cols <- setdiff(names(setting_index), names(out))
  if (length(add_cols) < 1L) {
    return(out)
  }
  merge(out, setting_index[, c("dataset_id", "setting_id", add_cols), drop = FALSE],
    by = c("dataset_id", "setting_id"), all.x = TRUE, sort = FALSE
  )
}

dg_optimal_selector_state <- function(index_df, metrics, input_values = list()) {
  if (!is.data.frame(index_df) || nrow(index_df) < 1L) {
    return(list(error = "No benchmark graph-stage rows are available.", fields = list(), row = data.frame()))
  }
  if (!is.data.frame(metrics) || nrow(metrics) < 1L) {
    return(list(error = "No benchmark metric rows are available.", fields = list(), row = data.frame()))
  }
  candidate <- dg_metric_settings_index(index_df, metrics)
  fields <- list(dg_mode_field("optimal"))

  target <- dg_metric_target_field(candidate, input_values$metric_target)
  fields[[length(fields) + 1L]] <- target
  if ("target" %in% names(candidate)) {
    candidate <- candidate[as.character(candidate$target) == target$selected, , drop = FALSE]
  }

  add_filter <- function(field, any = FALSE) {
    if (!(field %in% names(candidate))) {
      return(invisible(NULL))
    }
    vals <- dg_order_values(candidate[[field]], field)
    if (length(vals) < 1L) {
      return(invisible(NULL))
    }
    input_val <- dg_scalar_chr(input_values[[field]])
    selected <- if (isTRUE(any)) {
      if (input_val %in% vals) input_val else ""
    } else {
      if (input_val %in% vals) input_val else vals[[1]]
    }
    fields[[length(fields) + 1L]] <<- dg_field_spec(field, vals, selected, any = any)
    if (nzchar(selected)) {
      candidate <<- candidate[as.character(candidate[[field]]) == selected, , drop = FALSE]
    }
    invisible(NULL)
  }

  dataset_fields <- dg_dataset_selector_fields(candidate)
  for (field in setdiff(dataset_fields, "seed")) {
    add_filter(field, any = FALSE)
  }
  for (field in c("seed", "graph_family", "prune_method")) {
    add_filter(field, any = TRUE)
  }

  err_col <- dg_first_col(candidate, c("rel_rms_error", "rel_geodesic_stress", "rel_abs_error_median", "error"))
  if (!nzchar(err_col)) {
    return(list(error = "Metric table does not contain an error column for optimal selection.", fields = fields, row = data.frame()))
  }
  err <- suppressWarnings(as.numeric(candidate[[err_col]]))
  keep <- is.finite(err)
  if (!any(keep)) {
    return(list(error = NULL, mode = "optimal", status = "no_metric", fields = fields, row = data.frame(), n_matches = 0L, key = ""))
  }
  candidate <- candidate[keep, , drop = FALSE]
  err <- err[keep]
  ord <- order(err, as.character(candidate$dataset_id), as.character(candidate$setting_id), na.last = TRUE)
  best_metric <- candidate[ord[[1]], , drop = FALSE]

  stage_rows <- index_df[
    as.character(index_df$dataset_id) == as.character(best_metric$dataset_id[[1]]) &
      as.character(index_df$setting_id) == as.character(best_metric$setting_id[[1]]),
    ,
    drop = FALSE
  ]
  if (!is.data.frame(stage_rows) || nrow(stage_rows) < 1L) {
    return(list(error = NULL, mode = "optimal", status = "missing_graph", fields = fields, row = data.frame(), n_matches = 0L, key = "", optimal_metric = best_metric, error_column = err_col))
  }
  stage_vals <- dg_order_values(stage_rows$stage, "stage")
  metric_stage <- dg_scalar_chr(best_metric$metric_stage %||% best_metric$stage)
  stage_selected <- dg_scalar_chr(input_values$stage)
  if (!stage_selected %in% stage_vals) {
    stage_selected <- if (metric_stage %in% stage_vals) metric_stage else stage_vals[[1]]
  }
  fields[[length(fields) + 1L]] <- dg_field_spec("stage", stage_vals, stage_selected)
  selected_row <- stage_rows[as.character(stage_rows$stage) == stage_selected, , drop = FALSE]
  selected_row <- selected_row[1, , drop = FALSE]

  list(
    error = NULL,
    mode = "optimal",
    status = "ok",
    fields = fields,
    row = selected_row,
    n_matches = as.integer(nrow(candidate)),
    key = dg_stage_key_from_row(selected_row),
    optimal_metric = best_metric,
    error_column = err_col
  )
}

dg_selector_state <- function(run, input_values = list()) {
  mode <- dg_scalar_chr(input_values$selection_mode, "manual")
  if (identical(mode, "optimal")) {
    return(dg_optimal_selector_state(run$index, run$metrics, input_values))
  }
  dg_manual_selector_state(run$index, input_values)
}

dg_selection_summary <- function(selection) {
  if (!is.list(selection) || !identical(selection$status, "ok") || !is.data.frame(selection$row)) {
    return("")
  }
  row <- selection$row
  bits <- c(
    sprintf("dataset=%s", dg_scalar_chr(row$dataset_id[[1]])),
    sprintf("setting=%s", dg_scalar_chr(row$setting_id[[1]])),
    sprintf("stage=%s", dg_scalar_chr(row$stage[[1]]))
  )
  if (identical(selection$mode, "optimal") && is.data.frame(selection$optimal_metric)) {
    metric <- selection$optimal_metric
    err_col <- dg_scalar_chr(selection$error_column, "rel_rms_error")
    err_val <- if (err_col %in% names(metric)) dg_format_number(metric[[err_col]][[1]]) else ""
    bits <- c(
      sprintf("optimal target=%s", dg_scalar_chr(metric$target[[1]])),
      sprintf("%s=%s", err_col, err_val),
      sprintf("family=%s", dg_scalar_chr(row$graph_family[[1]])),
      sprintf("k=%s", dg_scalar_chr(row$k[[1]])),
      sprintf("radius_rank=%s", dg_scalar_chr(row$radius_rank[[1]])),
      sprintf("k_scale=%s", dg_scalar_chr(row$k_scale[[1]])),
      sprintf("rule=%s", dg_scalar_chr(row$radius_rule[[1]])),
      sprintf("factor=%s", dg_scalar_chr(row$radius_factor[[1]])),
      sprintf("delta=%s", dg_scalar_chr(row$delta[[1]])),
      sprintf("stage=%s", dg_scalar_chr(row$stage[[1]]))
    )
  }
  bits <- bits[nzchar(sub("^[^=]+=", "", bits))]
  paste(bits, collapse = ", ")
}
