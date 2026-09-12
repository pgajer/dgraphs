# Frozen campaign plans, conservative job-boundary resume and comparison exports.
qgs.calibration.pairs <- function() {
  choices <- list(flat2_ball = c("identity", "grid_direction"), flat2_box = "grid_direction",
    paraboloid2_disk = c("radial", "ab", "antipodal"), saddle2_disk = c("ruling", "ab", "antipodal"),
    paraboloid2_high_curvature = "ab", saddle2_high_curvature = "ab", anisotropic2_disk = "ab",
    cross_term2_square = "ab", regression_paraboloid4101 = c("11_155", "77_155"),
    regression_paraboloid4102 = "2_3")
  do.call(rbind, lapply(names(choices), function(id) data.frame(case_id = id, pair_id = choices[[id]])))
}

qgs.cohorts <- function() list(
  edge = list(metric = "edges", values = c(10000, 50000, 200000),
    limits = qgs.limits(list(edge_calls = 200000, seconds = 120))),
  time = list(metric = "seconds", values = c(1, 5, 20),
    limits = qgs.limits(list(edge_calls = 2000000, seconds = 20))))

qgs.campaign.plan <- function(collection, pairs = qgs.calibration.pairs(), repeats = 4101:4105,
    bindings = c(I = "adaptive_initializer", A = "adaptive_vertex", B = "adaptive_local_graph"),
    parameters = list(I = list(), A = list(), B = list()), cohorts = qgs.cohorts(),
    seconds = 14400, protocol = "qg-refine-calibration-v2") {
  qg.assert(setequal(names(bindings), c("I", "A", "B")) &&
              all(grepl("^[a-z][a-z0-9_]*$", bindings)), "Invalid method bindings")
  qg.assert(is.data.frame(pairs) && all(c("case_id", "pair_id") %in% names(pairs)) &&
              nrow(pairs) > 0 && !anyDuplicated(paste(pairs$case_id, pairs$pair_id)), "Invalid pairs")
  qg.assert(length(repeats) > 0 && !anyDuplicated(repeats) && all(repeats >= 0 & repeats %% 1 == 0),
            "Invalid repeats")
  qg.assert(qgs.scalar(seconds) && seconds > 0, "Invalid campaign budget")
  qg.assert(length(cohorts) > 0 && !is.null(names(cohorts)) &&
              all(grepl("^[a-z][a-z0-9_]*$", names(cohorts))), "Invalid cohorts")
  jobs <- list()
  add <- function(role, pair, cohort, direction, rep.label) {
    c <- cohorts[[cohort]]
    request <- qgs.request(collection, pair$case_id, pair$pair_id, direction,
      as.character(rep.label), parameters[[role]], c$limits)
    values <- as.double(unlist(c$values))
    cap <- if (c$metric == "edges") request$limits$edge_calls else request$limits$seconds
    qg.assert(c$metric %in% c("edges", "seconds") && length(values) > 0 &&
      all(is.finite(values)) && all(values > 0 & values <= cap) && !anyDuplicated(values) &&
      !is.unsorted(values), "Invalid cohort checkpoints")
    request$budget <- list(metric = c$metric, values = values)
    request$method_id <- unname(bindings[[role]])
    request$config_id <- digest::digest(list(protocol, role, c, parameters[[role]]), algo = "sha256")
    jobs[[length(jobs) + 1L]] <<- list(id = sprintf("%05d", length(jobs) + 1L), role = role,
      cohort = cohort, attempt_id = 1L, request = request)
  }
  for (p in seq_len(nrow(pairs))) for (cohort in names(cohorts)) for (direction in c("forward", "reverse")) {
    add("I", pairs[p, ], cohort, direction, 0L)
  }
  for (rep.label in repeats) for (p in seq_len(nrow(pairs))) for (cohort in names(cohorts)) {
    for (direction in c("forward", "reverse")) for (role in if (rep.label %% 2) c("A", "B") else c("B", "A")) {
      add(role, pairs[p, ], cohort, direction, rep.label)
    }
  }
  list(interface_version = qgs.version, protocol = protocol, collection_sha256 = attr(collection, "sha256"),
    seconds = seconds, pairs = pairs, repeats = repeats, bindings = bindings, parameters = parameters,
    cohorts = cohorts, jobs = jobs,
    qualification = "Plan only; no solver evidence, no fallback for missing initializer adapter")
}

qgs.campaign.create <- function(home, collection.directory, output, plan) {
  collection <- qg.read(collection.directory)
  qg.assert(identical(plan$collection_sha256, attr(collection, "sha256")) &&
              identical(plan$interface_version, qgs.version), "Plan fixture/version mismatch")
  qg.assert(!file.exists(output) && dir.exists(dirname(output)), "New output with existing parent required")
  output <- file.path(normalizePath(dirname(output)), basename(output))
  qg.assert(!startsWith(output, paste0(normalizePath(collection.directory), "/")), "Cannot write inside frozen collection")
  sources <- qgs.sources(home, list(file = "campaign.R"), file.path(collection.directory, "../collection.R"))
  registry <- qgs.registry(home)
  for (method in registry) if (method$id %in% unname(plan$bindings) && identical(method$status, "implemented")) {
    sources <- c(sources, qgs.sources(home, method, file.path(collection.directory, "../collection.R")))
  }
  sources <- sources[!duplicated(vapply(sources, `[[`, "", "path"))]
  dir.create(output)
  qgs.binary(plan, file.path(output, "plan.rds")); qgs.write(plan, file.path(output, "plan.json"))
  manifest <- list(plan_sha256 = digest::digest(file = file.path(output, "plan.rds"), algo = "sha256"),
    sources = sources, collection_directory = normalizePath(collection.directory),
    environment = list(R = R.version.string, platform = as.list(Sys.info()),
      libraries = lapply(c("jsonlite", "digest", "callr", "ps", "processx"), function(p)
        list(package = p, version = as.character(utils::packageVersion(p))))))
  qgs.write(manifest, file.path(output, "manifest.json"))
  state <- list(status = rep("not_run", length(plan$jobs)), charged_seconds = 0, active_job = NULL,
                manifest_sha256 = digest::digest(file = file.path(output, "manifest.json"), algo = "sha256"))
  qgs.binary(state, file.path(output, "state.rds"))
  qgs.campaign.export(output, plan, state, collection)
  invisible(output)
}

qgs.campaign.read <- function(output) {
  manifest <- jsonlite::fromJSON(file.path(output, "manifest.json"), simplifyVector = FALSE)
  state <- readRDS(file.path(output, "state.rds"))
  qg.assert(identical(state$manifest_sha256, digest::digest(file = file.path(output, "manifest.json"), algo = "sha256")) &&
              identical(manifest$plan_sha256, digest::digest(file = file.path(output, "plan.rds"), algo = "sha256")),
            "Campaign manifest/plan changed")
  plan <- readRDS(file.path(output, "plan.rds"))
  collection <- qg.read(manifest$collection_directory)
  qg.assert(identical(plan$collection_sha256, attr(collection, "sha256")), "Campaign fixture changed")
  qgs.verify.sources(manifest$sources)
  list(plan = plan, manifest = manifest, state = state, collection = collection)
}

qgs.campaign.run.local <- function(home, output, max_jobs = Inf) {
  data <- qgs.campaign.read(output); plan <- data$plan; state <- data$state
  qg.assert(qgs.scalar(max_jobs) && max_jobs >= 1 && max_jobs %% 1 == 0 || identical(max_jobs, Inf),
            "Invalid max_jobs")
  registry <- qgs.registry(home)
  for (id in unique(unname(plan$bindings))) {
    index <- match(id, vapply(registry, `[[`, "", "id"))
    method <- if (is.na(index)) NULL else registry[[index]]
    qg.assert(!is.null(method) && identical(method$status, "implemented"),
              paste("Campaign blocked: adapter not implemented:", id))
  }
  if (!is.null(state$active_job)) {
    state$status[state$active_job] <- "interrupted"
    state$active_job <- NULL
    # Its full reservation remains charged; never rerun this attempt automatically.
    qgs.binary(state, file.path(output, "state.rds"))
  }
  completed <- 0L; segment <- qgs.clock()
  for (i in which(state$status == "not_run")) {
    if (completed >= max_jobs) break
    overhead <- qgs.clock() - segment
    state$charged_seconds <- state$charged_seconds + overhead
    segment <- qgs.clock()
    request <- plan$jobs[[i]]$request
    reservation <- request$limits$seconds + 22
    if (state$charged_seconds + reservation > plan$seconds) break
    state$status[i] <- "running"; state$active_job <- i
    state$charged_seconds <- state$charged_seconds + reservation
    qgs.binary(state, file.path(output, "state.rds"))
    job.start <- qgs.clock()
    id <- request$method_id
    method <- registry[[match(id, vapply(registry, `[[`, "", "id"))]]
    directory <- file.path(output, "jobs", plan$jobs[[i]]$id)
    qg.assert(!file.exists(directory), "Existing attempt directory cannot be overwritten")
    dir.create(directory, recursive = TRUE)
    qgs.binary(request, file.path(directory, "request.rds")); qgs.write(request, file.path(directory, "request.json"))
    record <- qgs.job(home, file.path(data$manifest$collection_directory, "../collection.R"),
      file.path(home, method$file), method, request, directory, data$manifest$sources)
    qgs.binary(record, file.path(directory, "record.rds")); qgs.write(record, file.path(directory, "record.json"))
    state$status[i] <- if (record$search$status == "failed") "failed" else "complete"
    state$active_job <- NULL
    state$charged_seconds <- state$charged_seconds - reservation + qgs.clock() - job.start
    qgs.binary(state, file.path(output, "state.rds"))
    completed <- completed + 1L; segment <- qgs.clock()
  }
  qgs.campaign.export(output, plan, state, data$collection)
  state$charged_seconds <- state$charged_seconds + qgs.clock() - segment
  qgs.binary(state, file.path(output, "state.rds"))
  list(completed_this_call = completed, remaining_not_run = sum(state$status == "not_run"),
       charged_seconds = state$charged_seconds, budget_seconds = plan$seconds)
}

qgs.campaign.run <- function(home, output, max_jobs = Inf) {
  lock <- file.path(output, "run.lock")
  qg.assert(dir.create(lock, showWarnings = FALSE), "Campaign lock exists; confirm owner is stopped before removing it")
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  qgs.write(list(pid = Sys.getpid(), host = Sys.info()[["nodename"]]), file.path(lock, "owner.json"))
  data <- qgs.campaign.read(output)
  remaining <- data$plan$seconds - data$state$charged_seconds
  if (remaining <= 0) return(list(termination = "campaign_budget", remaining_not_run = sum(data$state$status == "not_run")))
  result <- qgs.supervise(function(home, output, max_jobs, helpers) {
    source(helpers); source(file.path(home, "interface.R")); source(file.path(home, "runner.R"))
    source(file.path(home, "campaign.R"))
    qgs.campaign.run.local(home, output, max_jobs)
  }, list(home, output, max_jobs, file.path(data$manifest$collection_directory, "../collection.R")),
  seconds = remaining, rss_mib = Inf)
  state <- readRDS(file.path(output, "state.rds"))
  if (identical(result$termination, "time_budget")) state$charged_seconds <- data$plan$seconds
  else state$charged_seconds <- max(state$charged_seconds, data$state$charged_seconds + result$elapsed_seconds)
  if (!is.null(result$termination)) {
    if (!is.null(state$active_job)) { state$status[state$active_job] <- "interrupted"; state$active_job <- NULL }
  }
  qgs.binary(state, file.path(output, "state.rds"))
  if (!is.null(result$termination)) return(list(termination = result$termination,
    diagnostic = result$value$diagnostic, charged_seconds = state$charged_seconds,
    exports_may_be_stale = TRUE))
  result$value$charged_seconds <- state$charged_seconds
  result$value
}

qgs.csv <- function(rows, path) {
  tmp <- tempfile(".csv-", tmpdir = dirname(path)); on.exit(unlink(tmp), add = TRUE)
  write.csv(rows, tmp, row.names = FALSE, na = "")
  qg.assert(file.rename(tmp, path), "Cannot publish CSV")
}

qgs.campaign.export <- function(output, plan, state, collection) {
  rows <- list(); exports <- list(); export.dir <- file.path(output, "fixture_exports")
  template <- qg.template(collection)
  fixtures <- list()
  for (case in collection$cases) for (pair in case$pairs) {
    fixtures[[paste(case$id, pair$id, sep = "/")]] <- pair
  }
  dir.create(export.dir, showWarnings = FALSE)
  revision <- digest::digest(file = file.path(output, "manifest.json"), algo = "sha256")
  for (i in seq_along(plan$jobs)) {
    job <- plan$jobs[[i]]; request <- job$request
    fixture <- fixtures[[paste(request$case_id, request$pair_id, sep = "/")]]
    truth <- if (is.null(fixture$exact$value)) NA_real_ else fixture$exact$value
    file <- file.path(output, "jobs", job$id, "record.rds")
    record <- if (file.exists(file)) readRDS(file) else NULL
    eligible <- identical(state$status[i], "complete") && identical(record$search$status, "candidate")
    telemetry <- qgs.report.record(record, request, eligible)
    for (k in seq_along(request$budget$values)) {
      cp <- record$search$checkpoints[[k]]; audit <- record$audits[[paste0("checkpoint_", k)]]
      initial <- record$audits$initializer
      initializer.required <- job$role %in% c("A", "B")
      comparison.status <- qgs.comparison.status(state$status[i], record$search$status,
        cp$status, audit$status, initial$status, initializer.required)
      usable <- identical(comparison.status, "qualified")
      shortening <- allowance <- relative.shortening <- NA_real_; shortening.status <- "unavailable"
      if (usable && identical(initial$status, "passed")) {
        shortening <- initial$length - audit$length
        allowance <- initial$error_estimate + audit$error_estimate +
          initial$rounding_allowance + audit$rounding_allowance
        relative.shortening <- shortening / max(initial$length, 1e-12 * request$length_scale)
        shortening.status <- if (shortening > allowance) "improved" else if (shortening < -allowance) "increased" else "unresolved"
      }
      group <- paste(job$role, job$cohort, request$repeat_label, k, sep = "-")
      if (is.null(exports[[group]])) exports[[group]] <- template
      if (usable) {
        cp.record <- record; cp.record$final_audit <- audit
        cp.record$search$termination <- paste(record$search$termination, cp$status)
        row <- qgs.row(collection, cp.record, revision)
      } else {
        row <- template
        row <- row[row$case_id == request$case_id & row$pair_id == request$pair_id & row$direction == request$direction, ]
        if (!is.null(record)) {
          row$status <- if (identical(record$search$status, "unsupported")) "unsupported" else "failed"
          row$method <- request$method_id; row$solver_revision <- revision
          row$elapsed_seconds <- record$end_to_end_seconds
          row$diagnostic <- paste(record$search$termination, comparison.status)
        }
      }
      index <- with(exports[[group]], which(case_id == request$case_id & pair_id == request$pair_id & direction == request$direction))
      exports[[group]][index, ] <- row
      rows[[length(rows) + 1L]] <- cbind(data.frame(job_id = job$id, role = job$role, method = request$method_id,
        cohort = job$cohort, repeat_label = request$repeat_label, case_id = request$case_id,
        pair_id = request$pair_id, direction = request$direction, budget = request$budget$values[k],
        group = group, run_status = state$status[i], checkpoint_status = if (is.null(cp)) {
          if (state$status[i] == "not_run") "not_run" else "unavailable"
        } else cp$status,
        termination = if (is.null(record)) state$status[i] else record$search$termination,
        search_status = if (is.null(record)) "not_run" else record$search$status,
        path_feasibility = if (is.null(audit$feasibility)) "unavailable" else audit$feasibility,
        audit_status = if (is.null(audit)) "unavailable" else audit$status,
        initializer_required = initializer.required, comparison_status = comparison.status,
        audited_length = if (usable) audit$length else NA_real_, fixture_row_status = row$status,
        length_scale = request$length_scale, exact_distance = truth,
        analytic_absolute_error = if (usable && is.finite(truth)) abs(audit$length - truth) else NA_real_,
        analytic_relative_error = if (usable && is.finite(truth) && truth > 0) abs(audit$length - truth) / truth else NA_real_,
        chord_to_path_gap = if (usable) audit$length - fixture$bounds$chord_lower else NA_real_,
        shortening = shortening, shortening_allowance = allowance, relative_shortening = relative.shortening,
        shortening_status = shortening.status, stringsAsFactors = FALSE), telemetry)
    }
  }
  table <- do.call(rbind, rows)
  table$collection_gate <- NA_character_
  for (group in names(exports)) {
    qgs.csv(exports[[group]], file.path(export.dir, paste0(group, ".csv")))
    verdict <- tryCatch(c(list(status = "consistent"), qg.check.results(collection, exports[[group]])),
                        error = function(e) list(status = "failed", diagnostic = conditionMessage(e)))
    qgs.write(verdict, file.path(export.dir, paste0(group, "-gate.json")))
    table$collection_gate[table$group == group] <- verdict$status
  }
  qgs.csv(table, file.path(output, "checkpoints.csv"))
  grouping <- interaction(table$role, table$cohort, table$case_id, table$pair_id, table$direction, table$budget, drop = TRUE)
  summaries <- lapply(split(table, grouping), function(z) {
    v <- z$audited_length[is.finite(z$audited_length)]
    cbind(z[1, c("role", "method", "cohort", "case_id", "pair_id", "direction", "budget")],
      data.frame(planned = nrow(z), usable = length(v), not_run = sum(z$run_status == "not_run"),
        failed = sum(z$run_status %in% c("failed", "interrupted")),
        unsupported = sum(z$search_status == "unsupported"),
        censored = sum(z$checkpoint_status %in% c("censored", "initializer_incomplete", "unavailable")),
        audit_unavailable = sum(qgs.audit.unavailable(z$audit_status) |
          (z$initializer_required & qgs.audit.unavailable(z$initializer_audit_status))),
        audit_failed = sum(qgs.audit.failed(z$audit_status) |
          (z$initializer_required & qgs.audit.failed(z$initializer_audit_status))),
        checkpoint_audit_unavailable = sum(qgs.audit.unavailable(z$audit_status)),
        checkpoint_audit_failed = sum(qgs.audit.failed(z$audit_status)),
        initializer_audit_unavailable = sum(z$initializer_required & qgs.audit.unavailable(z$initializer_audit_status)),
        initializer_audit_failed = sum(z$initializer_required & qgs.audit.failed(z$initializer_audit_status)),
        unusable = sum(!is.finite(z$audited_length)),
        fixture_failed = sum(z$fixture_row_status == "failed"),
        failed_fraction = mean(z$run_status %in% c("failed", "interrupted")),
        censored_fraction = mean(z$checkpoint_status %in% c("censored", "initializer_incomplete", "unavailable")),
        unusable_fraction = mean(!is.finite(z$audited_length)),
        median_conditional = if (length(v)) median(v) else NA_real_,
        min_conditional = if (length(v)) min(v) else NA_real_, max_conditional = if (length(v)) max(v) else NA_real_,
        sd_conditional = if (length(v) > 1) stats::sd(v) else NA_real_))
  })
  qgs.csv(do.call(rbind, summaries), file.path(output, "summary.csv"))
  qgs.report.comparisons(table, output)
  invisible(table)
}

source(file.path(qgs.home, "reporting.R"), local = environment())
