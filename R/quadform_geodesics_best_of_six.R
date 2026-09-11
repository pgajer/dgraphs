#' Select a path from six quadratic-surface refinement searches
#'
#' Run both refinement methods with all three neighborhood rules and return
#' the shortest usable result. Each search starts afresh from the same seeded
#' equal-surface-length initialization. This is a finite-budget heuristic,
#' not a certificate of a globally shortest surface path.
#'
#' @inheritParams quadform_geodesics_solver
#' @param max_epochs Rounds per search, default 64. Plateau stopping is disabled.
#' @param max_edge_calls,max_seconds Safety allowances for each of the six
#'   searches, not combined allowances. Defaults are unlimited; rounds still
#'   bound the search. Interrupted searches retain their original statuses.
#' @param cache_edges Cache capacity per search; default zero.
#'
#' @return The selected solver result, with an additional `ensemble` list.
#'   `ensemble$results` retains all six solver results and `ensemble$summary`
#'   records methods, rules, seeds, lengths, error estimates, statuses, round
#'   completion and costs. `selected_index` identifies the minimum estimated
#'   length; exact length ties prefer the earlier row. `tied_indices` also
#'   includes usable results whose difference from the selected length is no
#'   larger than their combined estimated errors. These estimates are not
#'   rigorous intervals. Numerical ties never cause a longer estimated path
#'   to replace the minimum. `status` within `ensemble` is `"complete"` when
#'   all six round budgets complete (or endpoints coincide), `"partial"` when
#'   at least one usable path is available but some search is incomplete, and
#'   `"no_path"` when none is usable. In the latter case `selected_index` is
#'   missing and the top-level result is the first no-path solver result.
#'   Top-level counters describe the selected search only; total cost is in
#'   `ensemble$total_edge_calls`, `total_solver_seconds`, and
#'   `total_call_seconds`. Input errors and unexpected R errors propagate.
#' @details Searches use the same seed to preserve their initialization, but
#'   may diverge in their candidate draws and visits as their paths change.
#'   They execute serially and do not change R's random state. Parallelize
#'   independent endpoint pairs in separate R processes rather than nesting
#'   workers inside this function. No state files are saved.
#' @keywords internal
quadform_geodesics_best_of_six <- function(A, from, to, domain, seed = 1,
    length_scale = 1, initial_edges = 16L, candidates = 32L,
    max_epochs = 64L, max_vertices = 257L, max_edge_calls = Inf,
    max_seconds = Inf, cache_edges = 0L, rejection_cap = 1000L,
    random_orientation = TRUE, trace = FALSE, trace_limit = 1000L) {
  if (!is.numeric(max_epochs) || length(max_epochs) != 1L ||
      !is.finite(max_epochs) || max_epochs < 0 || max_epochs > 100000 ||
      max_epochs != floor(max_epochs))
    stop("max_epochs must be a whole number between 0 and 100000")
  inputs <- as.list(environment())
  inputs$plateau_epochs <- as.integer(max_epochs + 1)
  methods <- rep(c("single_point", "local_network"), each = 3L)
  rules <- rep(c("neighbors", "fixed_disk", "fixed_span"), 2L)
  elapsed <- numeric(6L)
  results <- lapply(seq_len(6L), function(i) {
    start <- proc.time()[["elapsed"]]
    result <- do.call(quadform_geodesics_solver,
      c(inputs, list(method = methods[i], neighborhood = rules[i])))
    elapsed[i] <<- proc.time()[["elapsed"]] - start
    result
  })
  usable <- vapply(results, function(r) {
    is.finite(r$length) && is.finite(r$error_estimate) && r$error_estimate >= 0 &&
      r$status %in% c("candidate", "direct_fallback") && is.matrix(r$path) &&
      nrow(r$path) >= 2L && ncol(r$path) == 2L && all(is.finite(r$path)) &&
      identical(unname(r$path[1L, ]), as.double(from)) &&
      identical(unname(r$path[nrow(r$path), ]), as.double(to))
  }, FALSE)
  complete <- vapply(results, function(r)
    r$termination == "identity" || (r$status == "candidate" &&
      r$termination == "epoch_limit" && r$counters$completed_epochs == max_epochs), FALSE)
  lengths <- vapply(results, `[[`, 0, "length")
  errors <- vapply(results, `[[`, 0, "error_estimate")
  selected <- if (any(usable)) which(usable)[which.min(lengths[usable])] else NA_integer_
  tied <- if (is.na(selected)) integer() else
    which(usable & abs(lengths - lengths[selected]) <= errors + errors[selected])
  result <- results[[if (is.na(selected)) 1L else selected]]
  edge_calls <- vapply(results, function(r) r$counters$edge_calls, 0)
  solver_seconds <- vapply(results, function(r) r$counters$elapsed_seconds, 0)
  result$ensemble <- list(
    status = if (!any(usable)) "no_path" else if (all(usable & complete)) "complete" else "partial",
    selected_index = selected, tied_indices = tied,
    summary = data.frame(method = methods, neighborhood = rules, seed = rep(seed, 6L),
      length = lengths, error_estimate = errors, usable = usable, rounds_completed = complete,
      status = vapply(results, `[[`, "", "status"),
      termination = vapply(results, `[[`, "", "termination"),
      completed_epochs = vapply(results, function(r) r$counters$completed_epochs, 0),
      edge_calls = edge_calls, solver_seconds = solver_seconds, call_seconds = elapsed),
    total_edge_calls = sum(edge_calls), total_solver_seconds = sum(solver_seconds),
    total_call_seconds = sum(elapsed), results = results)
  result
}
