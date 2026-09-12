# Study definitions and derived summaries; raw per-run records remain authoritative.
qgx.cases <- c("paraboloid2_high_curvature", "flat2_box", "saddle2_disk")
qgx.policies <- c("neighbors", "fixed_disk", "fixed_span")
qgx.cohorts <- c("epochs", "edges", "seconds")
qgx.methods <- c("sensitivity_vertex", "sensitivity_local_graph")
qgx.plan <- function(repeats = 100L, cases = qgx.cases[1L], cohorts = qgx.cohorts) {
  stopifnot(length(repeats) == 1L, is.finite(repeats), repeats >= 1L,
    repeats <= 10000L, repeats %% 1 == 0, length(cases) > 0L,
    all(cases %in% qgx.cases), !anyDuplicated(cases), length(cohorts) > 0L,
    all(cohorts %in% qgx.cohorts), !anyDuplicated(cohorts))
  plan <- expand.grid(method = qgx.methods, direction = c("forward", "reverse"),
    neighborhood = qgx.policies, cohort = cohorts, case = cases,
    repeat_label = as.character(seq_len(repeats) + 50000L), stringsAsFactors = FALSE)
  plan$pair <- ifelse(plan$case == "flat2_box", "grid_direction", "ab")
  # Deterministic randomized execution order reduces systematic machine-load drift.
  keys <- apply(plan, 1L, function(row)
    digest::digest(paste(c("sensitivity-execution-order-v1", row), collapse = "|"),
      algo = "sha256", serialize = FALSE))
  plan <- plan[order(keys, method = "radix"), ]; rownames(plan) <- NULL
  plan$job <- seq_len(nrow(plan))
  plan
}
qgx.limits <- function(cohort) {
  stopifnot(cohort %in% qgx.cohorts, length(cohort) == 1L)
  qgs.limits(list(seconds = if (cohort == "seconds") 10 else 120,
    edge_calls = if (cohort == "edges") 10000L else 200000L,
    rss_mib = 1024, max_vertices = 257L))
}
qgx.method <- function(id) {
  stopifnot(id %in% qgx.methods)
  list(id = id, file = paste0("solvers/", id, ".R"), sources = c(
    "solvers/adaptive/common.R", "solvers/adaptive/three_point.R",
    "solvers/adaptive/sensitivity.R", "solvers/adaptive/local_graph.R",
    "experiments/sensitivity.R", "run_sensitivity.R"))
}
qgx.request <- function(collection, job) {
  request <- qgs.request(collection, job$case, job$pair, job$direction,
    as.character(job$repeat_label), parameters = list(neighborhood = job$neighborhood,
      cohort = job$cohort), limits = qgx.limits(job$cohort))
  request$method_id <- job$method
  request$config_id <- paste("qg-three-point-sensitivity-v1", job$neighborhood, job$cohort, sep = "/")
  request
}
qgx.supervisor <- function(home) {
  e <- new.env(parent = globalenv())
  sys.source(file.path(home, "supervisor.R"), e)
  original <- e$qgs.supervise
  e$qgs.supervise <- function(func, args, seconds, rss_mib = 512, start.file = NULL, ...) {
    # Only the outer process-return deadline changes; request/search limits do not.
    original(func, args, seconds + if (is.null(start.file)) 0 else 5,
      rss_mib = rss_mib, start.file = start.file, ...)
  }
  e$qgs.job.v2
}
qgx.num <- function(x) if (qgs.scalar(x)) x else NA_real_
qgx.text <- function(x) if (qgs.string(x)) x else "unavailable"
qgx.row <- function(job, record = NULL, collection = NULL) {
  row <- job
  row$run_status <- if (is.null(record)) "not_run" else "recorded"
  row$search_status <- qgx.text(record$search$status)
  row$termination <- qgx.text(record$search$termination)
  row$initializer_audit <- qgx.text(record$audits$initializer$status)
  row$terminal_audit <- qgx.text(record$final_audit$status)
  row$fixture_check <- "unavailable"
  if (!is.null(record)) row$fixture_check <- qgs.row(collection, record, "sensitivity-v1")$status
  row$audited <- row$search_status == "candidate" && row$initializer_audit == "passed" &&
    row$terminal_audit == "passed" && row$fixture_check == "ok"
  row$budget_reached <- row$termination == switch(job$cohort,
    epochs = "schedule_exhausted", edges = "edge_budget", seconds = "time_budget")
  row$available <- row$audited && row$budget_reached
  row$initial_length <- if (row$initializer_audit == "passed")
    qgx.num(record$audits$initializer$length) else NA_real_
  row$retained_audited_length <- if (row$audited) qgx.num(record$final_audit$length) else NA_real_
  if (row$audited) {
    allowance <- record$audits$initializer$error_estimate + record$audits$initializer$rounding_allowance +
      record$final_audit$error_estimate + record$final_audit$rounding_allowance
    row$available <- row$available && isTRUE(row$retained_audited_length <= row$initial_length + allowance)
  }
  row$length <- if (row$available) row$retained_audited_length else NA_real_
  row$initializer_key <- NA_character_
  if (row$initializer_audit == "passed") {
    U <- record$search$initializer$candidate$path$vertices
    if (job$direction == "reverse") U <- U[nrow(U):1L, , drop = FALSE]
    row$initializer_key <- digest::digest(unname(U), algo = "sha256")
  }
  s <- record$search$adapter_state
  row$vertices <- qgx.num(nrow(s$vertices)); row$epochs <- qgx.num(s$sweep)
  row$calls <- qgx.num(record$search$counters$edge_calls)
  row$seconds <- qgx.num(record$search$counters$algorithm_seconds)
  row$peak_mib <- qgx.num(record$search_monitor$peak_rss_bytes) / 1024^2
  row$reference_radius <- qgx.num(s$configuration$reference_radius)
  row
}
qgx.initializer.gate <- function(rows) {
  # Every configuration and direction must start from the same geometric path.
  for (case in unique(rows$case)) {
    hit <- rows$case == case
    keys <- unique(na.omit(rows$initializer_key[hit]))
    if (length(keys) > 1L) {
      rows$available[hit] <- FALSE; rows$length[hit] <- NA_real_
      rows$fixture_check[hit] <- "initializer_mismatch"
    }
  }
  rows
}
qgx.trajectory <- function(job, record) {
  epochs <- Filter(function(d) d$kind == "epoch_end", record$search$adapter_state$diagnostics)
  if (!length(epochs)) return(NULL)
  do.call(rbind, lapply(epochs, function(d) cbind(job, data.frame(
    epoch = d$sweep, estimated_length = d$length, vertices = d$vertices,
    median_radius = d$median_radius, median_section_length = d$median_section_length,
    visits = d$visits, accepted_total = d$accepted,
    calls = d$counters$edge_calls, seconds = d$counters$algorithm_seconds))))
}
qgx.with.seed <- function(seed, code) {
  old <- get0(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  kind <- RNGkind()
  on.exit({
    do.call(RNGkind, as.list(kind))
    if (is.null(old)) {
      if (exists(".Random.seed", .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
    } else assign(".Random.seed", old, envir = .GlobalEnv)
  })
  RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(seed)
  force(code)
}
qgx.interval <- function(x, y = NULL, paired = FALSE, draws = 2000L) {
  # Seeded percentile bootstrap; direction samples are unpaired, method contrasts paired.
  stopifnot(draws >= 2L, draws %% 1L == 0L)
  if (is.null(y)) y <- rep(0, length(x))
  if (paired) {
    stopifnot(length(x) == length(y))
    good <- is.finite(x) & is.finite(y); x <- x[good]; y <- y[good]
  } else { x <- x[is.finite(x)]; y <- y[is.finite(y)] }
  result <- c(mean_difference = NA_real_, mean_low = NA_real_, mean_high = NA_real_,
    median_difference = NA_real_, median_low = NA_real_, median_high = NA_real_)
  if (!length(x) || !length(y)) return(result)
  result[c(1L, 4L)] <- c(mean(x) - mean(y), median(x) - median(y))
  if (min(length(x), length(y)) < 2L) return(result)
  boot <- qgx.with.seed(731902L, replicate(draws, {
    i <- sample.int(length(x), length(x), replace = TRUE)
    j <- if (paired) i else sample.int(length(y), length(y), replace = TRUE)
    c(mean(x[i]) - mean(y[j]), median(x[i]) - median(y[j]))
  }))
  result[2:3] <- quantile(boot[1, ], c(.025, .975), names = FALSE)
  result[5:6] <- quantile(boot[2, ], c(.025, .975), names = FALSE)
  result
}
qgx.groups <- function(rows, columns) {
  split(rows, interaction(rows[columns], drop = TRUE, lex.order = TRUE))
}
qgx.distributions <- function(rows) {
  keys <- c("case", "cohort", "neighborhood", "method", "direction")
  do.call(rbind, lapply(qgx.groups(rows, keys), function(z) {
    x <- z$length[z$available]
    qs <- if (length(x)) quantile(x, c(.05, .25, .5, .75, .95), names = FALSE) else rep(NA_real_, 5)
    cbind(z[1, keys], data.frame(planned = nrow(z), recorded = sum(z$run_status == "recorded"),
      available = length(x), unavailable = nrow(z) - length(x),
      memory_stops = sum(z$termination == "memory_budget"),
      time_stops = sum(z$termination == "time_budget"),
      calculation_stops = sum(z$termination == "edge_budget"),
      mean = if (length(x)) mean(x) else NA_real_, sd = if (length(x) > 1L) sd(x) else NA_real_,
      p05 = qs[1], p25 = qs[2], median = qs[3], p75 = qs[4], p95 = qs[5]))
  }))
}
qgx.directions <- function(rows, draws = 2000L) {
  keys <- c("case", "cohort", "neighborhood", "method")
  do.call(rbind, lapply(qgx.groups(rows, keys), function(z) {
    f <- z[z$direction == "forward", ]; r <- z[z$direction == "reverse", ]
    x <- f$length[f$available]; y <- r$length[r$available]
    distance <- if (length(x) && length(y)) {
      points <- sort(unique(c(x, y)))
      max(abs(ecdf(x)(points) - ecdf(y)(points)))
    } else NA_real_
    cbind(z[1, keys], data.frame(forward_planned = nrow(f), reverse_planned = nrow(r),
      forward_available = length(x), reverse_available = length(y),
      all_runs_available = all(z$available),
      cumulative_distribution_gap = distance),
      as.data.frame(as.list(qgx.interval(x, y, draws = draws))))
  }))
}
qgx.paired <- function(rows, draws = 2000L) {
  keys <- c("case", "cohort", "neighborhood", "direction", "repeat_label")
  columns <- c(keys, "length", "available")
  pairs <- merge(rows[rows$method == "sensitivity_vertex", columns],
    rows[rows$method == "sensitivity_local_graph", columns], by = keys, all = TRUE,
    suffixes = c("_single", "_network"))
  pairs$both_available <- pairs$available_single %in% TRUE & pairs$available_network %in% TRUE
  pairs$difference <- ifelse(pairs$both_available, pairs$length_network - pairs$length_single, NA_real_)
  groups <- c("case", "cohort", "neighborhood", "direction")
  summaries <- do.call(rbind, lapply(qgx.groups(pairs, groups), function(z) cbind(z[1, groups],
    data.frame(planned = nrow(z), available = sum(z$both_available)),
    as.data.frame(as.list(qgx.interval(z$length_network, z$length_single, paired = TRUE, draws = draws))))))
  # Difference-in-differences: did changing scale alter the network/single gap?
  impacts <- list()
  join <- c("case", "cohort", "direction", "repeat_label")
  for (policy in setdiff(qgx.policies, "neighbors")) {
    p <- merge(pairs[pairs$neighborhood == policy, c(join, "difference")],
      pairs[pairs$neighborhood == "neighbors", c(join, "difference")],
      by = join, all = TRUE, suffixes = c("_changed", "_original"))
    if (!nrow(p)) next
    impacts[[policy]] <- do.call(rbind, lapply(qgx.groups(p, join[1:3]), function(z)
      cbind(z[1, join[1:3]], data.frame(neighborhood = policy, planned = nrow(z),
        available = sum(is.finite(z$difference_changed) & is.finite(z$difference_original))),
        as.data.frame(as.list(qgx.interval(z$difference_changed, z$difference_original,
          paired = TRUE, draws = draws))))))
  }
  list(pairs = pairs, methods = summaries, neighborhood_effects = do.call(rbind, impacts))
}
qgx.write.summaries <- function(rows, trajectories, output) {
  rows <- qgx.initializer.gate(rows)
  csv <- function(x, name) if (!is.null(x)) write.csv(x, file.path(output, name), row.names = FALSE)
  csv(rows, "runs.csv"); csv(trajectories, "rounds.csv")
  csv(qgx.distributions(rows), "distributions.csv")
  csv(qgx.directions(rows), "direction-comparison.csv")
  paired <- qgx.paired(rows)
  csv(paired$pairs, "matched-method-runs.csv"); csv(paired$methods, "method-comparison.csv")
  csv(paired$neighborhood_effects, "neighborhood-effects.csv")
  qgs.write(list(planned = nrow(rows), recorded = sum(rows$run_status == "recorded"),
    available = sum(rows$available), all_recorded = all(rows$run_status == "recorded"),
    all_available = all(rows$available),
    interpretation = "Lengths and intervals are conditional on available runs; missing results are not wins, ties, or infinite lengths.",
    uncertainty = "Pointwise 95% percentile bootstrap intervals, 2000 resamples. No multiplicity correction or equivalence claim.",
    direction_sign = "Positive means forward paths are longer.",
    method_sign = "Positive means local-network paths are longer.",
    neighborhood_effect_sign = "Negative means the changed neighborhood reduces the network-minus-single length gap.",
    trajectory_caveat = "Per-round lengths are search estimates, not independently audited at every round."),
    file.path(output, "summary.json"))
  invisible(rows)
}
