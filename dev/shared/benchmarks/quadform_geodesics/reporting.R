# Derived readouts retain all planned rows; raw records remain authoritative.
qgs.audit.unavailable <- function(status) status %in% c("unavailable", "missing_target",
  "audit_unavailable_budget", "audit_unavailable_worker", "representation_not_audited")
qgs.audit.failed <- function(status) status %in% c("invalid_path", "integration_failure", "length_mismatch")

qgs.comparison.status <- function(ledger, search, checkpoint, audit, initializer, initializer.required) {
  label <- function(x) if (is.null(x)) "unavailable" else x
  if (!identical(ledger, "complete")) return(paste0("ledger_", label(ledger)))
  if (!identical(search, "candidate")) return(paste0("search_", label(search)))
  if (!isTRUE(checkpoint %in% c("observed", "carried"))) return(paste0("checkpoint_", label(checkpoint)))
  if (!identical(audit, "passed")) return(paste0("checkpoint_audit_", label(audit)))
  if (initializer.required && !identical(initializer, "passed"))
    return(paste0("initializer_audit_", label(initializer)))
  "qualified"
}

qgs.report.record <- function(record, request, eligible) {
  value <- function(x) if (qgs.scalar(x)) x else NA_real_
  path.key <- function(event) if (is.null(event$candidate)) NA_character_ else
    qgs.path.key(event$candidate, request)
  initial <- record$audits$initializer
  initial.ok <- eligible && identical(initial$status, "passed")
  state <- record$search$adapter_state
  diagnostics <- state$diagnostics
  subdivisions <- Filter(function(d) identical(d$kind, "subdivision_attempt"), diagnostics)
  initial.attempts <- Filter(function(d) identical(d$stage, 0L) && identical(d$sweep, 0L), subdivisions)
  initial.ends <- Filter(function(d) identical(d$kind, "subdivision_end") &&
    identical(d$stage, 0L) && identical(d$sweep, 0L), diagnostics)
  identity <- all(request$from == request$to)
  history <- record$search$history
  first.subdivision <- Filter(function(e) identical(e$phase, "subdivision") &&
    identical(e$adapter$stage, 0L) && identical(e$adapter$sweep, 0L), history)
  sub.event <- if (length(first.subdivision)) tail(first.subdivision, 1)[[1]] else record$search$initializer
  sub.complete <- eligible && (identity || length(initial.ends) > 0L)
  bad <- function(z) sum(vapply(z, function(d) !isTRUE(d$result$ok), logical(1)))
  result <- list(initializer_audit_status = if (is.null(initial$status)) "unavailable" else initial$status,
    initializer_length = if (initial.ok) value(initial$length) else NA_real_,
    initializer_uncertainty = if (initial.ok) value(initial$error_estimate + initial$rounding_allowance) else NA_real_,
    initializer_path_key = if (initial.ok) path.key(record$search$initializer) else NA_character_,
    initial_subdivision_complete = sub.complete,
    initial_subdivision_key = if (sub.complete) path.key(sub.event) else NA_character_,
    initial_subdivision_identity_failures = if (is.null(state)) NA_real_ else bad(initial.attempts),
    subdivision_identity_failures = if (is.null(state)) NA_real_ else bad(subdivisions),
    accepted_proposals = value(state$accepted), inserted_vertices = value(state$inserted),
    deleted_vertices = value(state$deleted), final_stage = value(state$stage), final_sweep = value(state$sweep),
    initializer_vertices = value(nrow(record$search$initializer$candidate$path$vertices)),
    terminal_vertices = value(nrow(record$search$incumbent$candidate$path$vertices)),
    raw_grid_audit_status = if (is.null(record$audits$raw_grid$status)) "unavailable" else record$audits$raw_grid$status,
    raw_direct_audit_status = if (is.null(record$audits$raw_direct$status)) "unavailable" else record$audits$raw_direct$status,
    raw_grid_length = if (eligible && identical(record$audits$raw_grid$status, "passed"))
      value(record$audits$raw_grid$length) else NA_real_,
    raw_direct_length = if (eligible && identical(record$audits$raw_direct$status, "passed"))
      value(record$audits$raw_direct$length) else NA_real_,
    target_fraction = 0.001, target_status = "unavailable", target_edge_calls = NA_real_,
    target_seconds = NA_real_, target_publication = NA_real_, target_prefix_fully_audited = FALSE)
  if (initial.ok && length(history)) {
    prefix <- TRUE; reached <- FALSE
    for (i in seq_along(history)) {
      a <- record$audits[[paste0("publication_", i)]]
      qualified <- identical(a$status, "passed")
      prefix <- prefix && qualified
      if (!qualified) next
      allowance <- initial$error_estimate + initial$rounding_allowance + a$error_estimate + a$rounding_allowance
      threshold <- 0.001 * max(initial$length, 1e-12 * request$length_scale)
      if (initial$length - a$length > threshold + allowance) {
        result$target_status <- "reached_at_audited_publication"
        result$target_edge_calls <- value(history[[i]]$counters$edge_calls)
        result$target_seconds <- value(history[[i]]$counters$algorithm_seconds)
        result$target_publication <- i; result$target_prefix_fully_audited <- prefix
        reached <- TRUE; break
      }
    }
    if (!reached) {
      result$target_status <- if (prefix) "not_reached_within_observed_work" else "unavailable_incomplete_audit"
      result$target_prefix_fully_audited <- prefix
    }
  }
  as.data.frame(result, stringsAsFactors = FALSE)
}

qgs.report.comparisons <- function(table, output) {
  status <- c("run_status", "search_status", "termination", "checkpoint_status", "audit_status",
    "initializer_required", "initializer_audit_status", "comparison_status",
    "fixture_row_status", "collection_gate", "audited_length", "initializer_length", "initializer_uncertainty",
    "initializer_path_key", "initial_subdivision_complete", "initial_subdivision_key",
    "initial_subdivision_identity_failures", "relative_shortening", "shortening_allowance")
  keys <- c("cohort", "repeat_label", "case_id", "pair_id", "direction", "budget")
  paired <- merge(table[table$role == "A", c(keys, status)], table[table$role == "B", c(keys, status)],
    by = keys, all = TRUE, suffixes = c("_A", "_B"))
  paired$difference_A_minus_B <- paired$audited_length_A - paired$audited_length_B
  paired$paired_available <- paired$comparison_status_A %in% "qualified" &
    paired$comparison_status_B %in% "qualified" & is.finite(paired$difference_A_minus_B)
  paired$difference_A_minus_B[!paired$paired_available] <- NA_real_
  qgs.csv(paired, file.path(output, "paired.csv"))
  groups <- interaction(paired$cohort, paired$case_id, paired$pair_id, paired$direction, paired$budget, drop = TRUE)
  paired.summary <- lapply(split(paired, groups), function(z) {
    v <- z$difference_A_minus_B[z$paired_available]
    cbind(z[1, c("cohort", "case_id", "pair_id", "direction", "budget")], data.frame(
      planned = nrow(z), paired_usable = length(v), paired_fraction = length(v) / nrow(z),
      median_difference_conditional = if (length(v)) median(v) else NA_real_,
      min_difference_conditional = if (length(v)) min(v) else NA_real_,
      max_difference_conditional = if (length(v)) max(v) else NA_real_,
      sd_difference_conditional = if (length(v) > 1) stats::sd(v) else NA_real_))
  })
  qgs.csv(do.call(rbind, paired.summary), file.path(output, "paired-summary.csv"))
  keys <- c("role", "cohort", "repeat_label", "case_id", "pair_id", "budget", "length_scale")
  directional <- merge(table[table$direction == "forward", c(keys, status)],
    table[table$direction == "reverse", c(keys, status)], by = keys, all = TRUE,
    suffixes = c("_forward", "_reverse"))
  directional$difference <- directional$audited_length_forward - directional$audited_length_reverse
  directional$directional_available <- directional$comparison_status_forward %in% "qualified" &
    directional$comparison_status_reverse %in% "qualified" & is.finite(directional$difference)
  directional$difference[!directional$directional_available] <- NA_real_
  directional$relative_discrepancy <- abs(directional$difference) /
    pmax(directional$audited_length_forward / 2 + directional$audited_length_reverse / 2,
         1e-12 * directional$length_scale)
  qgs.csv(directional, file.path(output, "directional.csv"))
  base.keys <- c("cohort", "case_id", "pair_id", "direction", "budget")
  ablation <- merge(table[table$role %in% c("A", "B"), ],
    table[table$role == "I", c(base.keys, status)], by = base.keys, all.x = TRUE, suffixes = c("", "_I"))
  ablation$ablation_status <- "unavailable"
  ablation$baseline_difference <- NA_real_
  for (i in seq_len(nrow(ablation))) {
    z <- ablation[i, ]
    other <- table[table$role == (if (z$role == "A") "B" else "A") &
      table$cohort == z$cohort & table$repeat_label == z$repeat_label & table$case_id == z$case_id &
      table$pair_id == z$pair_id & table$direction == z$direction & table$budget == z$budget, ]
    ready <- nrow(other) == 1L && all(is.finite(c(z$audited_length, z$audited_length_I,
      z$initializer_length, z$initializer_length_I, other$initializer_length))) &&
      isTRUE(z$initial_subdivision_complete) && isTRUE(other$initial_subdivision_complete)
    if (!ready) next
    initial.match <- abs(z$initializer_length - z$initializer_length_I) <=
      z$initializer_uncertainty + z$initializer_uncertainty_I &&
      abs(z$initializer_length - other$initializer_length) <=
      z$initializer_uncertainty + other$initializer_uncertainty &&
      identical(z$initializer_path_key, z$initializer_path_key_I) &&
      identical(z$initializer_path_key, other$initializer_path_key)
    subdivision.match <- identical(z$initial_subdivision_key, other$initial_subdivision_key) &&
      isTRUE(z$initial_subdivision_identity_failures == 0) && isTRUE(other$initial_subdivision_identity_failures == 0)
    ablation$ablation_status[i] <- if (!isTRUE(initial.match)) "invalid_initializer_mismatch" else
      if (!subdivision.match) "invalid_subdivision_mismatch" else "matched"
    if (ablation$ablation_status[i] == "matched")
      ablation$baseline_difference[i] <- z$audited_length_I - z$audited_length
  }
  qgs.csv(ablation, file.path(output, "ablations.csv"))
  # No pooled inference: per-pair means have equal weights within control classes.
  cell <- interaction(table$role, table$cohort, table$budget, table$case_id, table$pair_id, drop = TRUE)
  pairs <- lapply(split(table, cell), function(z) {
    finite.mean <- function(v) if (any(is.finite(v))) mean(v[is.finite(v)]) else NA_real_
    data.frame(role = z$role[1], cohort = z$cohort[1], budget = z$budget[1], case_id = z$case_id[1],
      pair_id = z$pair_id[1], control_class = if (is.finite(z$exact_distance[1])) "analytic" else "unknown",
      planned_observations = nrow(z), usable_observations = sum(is.finite(z$audited_length)),
      mean_relative_shortening = finite.mean(z$relative_shortening),
      mean_analytic_absolute_error = finite.mean(z$analytic_absolute_error),
      mean_analytic_relative_error = finite.mean(z$analytic_relative_error),
      mean_chord_to_path_gap = finite.mean(z$chord_to_path_gap))
  })
  pair.table <- do.call(rbind, pairs)
  qgs.csv(pair.table, file.path(output, "pair-summary.csv"))
  group <- interaction(pair.table$role, pair.table$cohort, pair.table$budget, pair.table$control_class, drop = TRUE)
  pooled <- lapply(split(pair.table, group), function(z) {
    finite.mean <- function(v) if (any(is.finite(v))) mean(v[is.finite(v)]) else NA_real_
    data.frame(role = z$role[1], cohort = z$cohort[1], budget = z$budget[1], control_class = z$control_class[1],
      planned_pairs = nrow(z), usable_pairs = sum(z$usable_observations > 0),
      complete_pairs = sum(z$usable_observations == z$planned_observations),
      relative_shortening_pairs = sum(is.finite(z$mean_relative_shortening)),
      mean_relative_shortening_conditional = finite.mean(z$mean_relative_shortening),
      mean_analytic_absolute_error_conditional = finite.mean(z$mean_analytic_absolute_error),
      mean_analytic_relative_error_conditional = finite.mean(z$mean_analytic_relative_error),
      mean_chord_to_path_gap_conditional = finite.mean(z$mean_chord_to_path_gap))
  })
  qgs.csv(do.call(rbind, pooled), file.path(output, "equal-pair-summary.csv"))
  invisible(NULL)
}
