#!/usr/bin/env Rscript
home <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
helpers <- file.path(home, "../../fixtures/quadform_geodesics/collection.R")
source(helpers); source(file.path(home, "interface.R")); source(file.path(home, "runner.R"))
source(file.path(home, "campaign.R")); library(testthat)
x <- qg.read(file.path(home, "../../fixtures/quadform_geodesics/v1"))
req <- function() qgs.request(x, "flat2_ball", "grid_direction")
direct <- qgs.load.adapter(file.path(home, "solvers/direct_connector.R"), "direct_connector")

test_that("kernel budget conditions propagate without becoming cached failures", {
  calls <- 0L
  kernel <- function(...) { calls <<- calls + 1L; qgs.budget("backend_interrupted") }
  r <- req(); c <- qgs.control.v2(r, kernel = kernel)
  for (i in 1:2) expect_error(c$edge(r$from, r$to), "backend_interrupted", class = "qgs_budget")
  expect_equal(calls, 2)
  expect_length(c$snapshot()$cache, 0)
  expect_equal(c$stats()$failure_hits, 0)
})

test_that("range-safe tangent and domain norms preserve positive finite distances", {
  for (size in c(1e-200, 1e200)) {
    r <- req(); r$from <- c(0, 0); r$to <- c(size, 0)
    r$domain <- list(kind = "box", lower = c(0, 0), upper = c(size, size))
    c <- qgs.control(r); e <- c$edge(r$from, r$to)
    expect_equal(e$length / size, 1)
    candidate <- qgs.candidate(rbind(r$from, r$to), e$length, e$error_estimate)
    a <- qgs.audit.queue(list(terminal = candidate), r)$terminal
    expect_identical(a$status, "passed")
    expect_equal(a$length / size, 1)
    candidate$length <- 0
    expect_identical(qgs.audit.queue(list(terminal = candidate), r)$terminal$status, "length_mismatch")
  }
  domain <- list(kind = "ball", center = c(0, 0), radius = 1e-200)
  expect_false(qg.inside(c(2e-200, 0), domain))
  expect_true(qg.inside(c(1e-200, 0), domain))
})

test_that("numeric endpoint equality preserves the distinct signed-zero key convention", {
  r <- req(); r$from <- c(-0, 0); r$to <- c(0.5, 0)
  candidate <- qgs.candidate(rbind(c(0, 0), r$to), 0.5, 0)
  expect_silent(qgs.vertices(candidate, r))
  expect_false(identical(qgs.vertex.key(r$from), qgs.vertex.key(candidate$path$vertices[1, ])))
  candidate$path$vertices[1, 1] <- .Machine$double.eps
  expect_error(qgs.vertices(candidate, r), "endpoint")
})

test_that("numerical integration errors preserve established path feasibility", {
  r <- req(); r$from <- c(0, 0); r$to <- c(1e200, 0)
  r$domain <- list(kind = "box", lower = c(0, 0), upper = c(1e200, 1e200))
  r$geometry$forms <- list(list(c(1e200, 0), c(0, 1e200)))
  candidate <- qgs.candidate(rbind(r$from, r$to), 1e200, 0)
  a <- qgs.audit.queue(list(terminal = candidate), r)$terminal
  expect_identical(a$status, "integration_failure")
  expect_identical(a$feasibility, "entire_lifted_segments_in_convex_domain")
  candidate$path$vertices[2, 1] <- -1
  expect_identical(qgs.audit.queue(list(terminal = candidate), r)$terminal$status, "invalid_path")
})

test_that("supervisor cleans external descendants on success, error and timeout", {
  for (mode in c("return", "error", "timeout")) {
    file <- tempfile("qgs-child-"); on.exit(unlink(file), add = TRUE)
    result <- qgs.supervise(function(file, mode) {
      child <- processx::process$new("/bin/sleep", "20", cleanup = FALSE, supervise = FALSE)
      h <- ps::ps_handle(child$get_pid())
      saveRDS(list(pid = ps::ps_pid(h), time = ps::ps_create_time(h)), file)
      if (mode == "timeout") Sys.sleep(20)
      if (mode == "error") stop("deliberate worker failure")
      TRUE
    }, list(file, mode), seconds = if (mode == "timeout") 1 else 5)
    expect_true(file.exists(file))
    child <- readRDS(file)
    alive <- tryCatch(ps::ps_is_running(ps::ps_handle(child$pid, child$time)), error = function(e) FALSE)
    if (isTRUE(alive)) ps::ps_kill(ps::ps_handle(child$pid, child$time))
    expect_false(isTRUE(alive))
    expect_identical(result$termination, switch(mode, return = NULL, error = "worker_failure", timeout = "time_budget"))
  }
})

test_that("supervisor retains sampling exceptions without weakening its stop rule", {
  result <- qgs.supervise(function() Sys.sleep(20), list(), seconds = 5,
    memory.info = function(h) stop("injected RSS observation failure"))
  expect_identical(result$termination, "monitor_unavailable")
  expect_equal(result$rss_error_count, 3)
  expect_length(result$rss_errors, 3)
  expect_false(result$rss_errors_truncated)
  expect_true(all(vapply(result$rss_errors, function(e)
    identical(e$message, "injected RSS observation failure") &&
    identical(e$scope, "worker_tree") && e$pid == result$pid &&
    is.character(e$process_status) && is.logical(e$worker_alive), logical(1))))
  expect_equal(tail(result$rss_trace, 1)[[1]]$consecutive_missing, 3)
  expect_true(is.na(result$last_rss_bytes))
  expect_false(tryCatch(ps::ps_is_running(ps::ps_handle(result$pid)), error = function(e) FALSE))
})

test_that("readiness planning is bounded, source sealed, and does not activate adapters", {
  source(file.path(home, "readiness.R"))
  plan <- qgs.readiness.plan(x)
  expect_length(plan$jobs, 24)
  expect_equal(plan$repeats, 4103)
  expect_equal(plan$seconds, 1800)
  expect_identical(plan$cohorts, qgs.cohorts())
  expect_identical(plan$protocol, "qg-readiness-pilot-v1")
  expect_true(all(vapply(plan$jobs, function(j) j$request$limits$rss_mib == 512, logical(1))))
  expect_equal(table(vapply(plan$jobs, `[[`, "", "role")), table(rep(c("A", "B", "I"), each = 8)))
  output <- tempfile("qgs-readiness-plan-")
  on.exit(unlink(output, recursive = TRUE), add = TRUE)
  before <- digest::digest(file = file.path(home, "registry.json"), algo = "sha256")
  qgs.readiness.create(home, file.path(home, "../../fixtures/quadform_geodesics/v1"), output)
  data <- qgs.campaign.read(output)
  expect_identical(data$plan, plan)
  expect_true(all(data$state$status == "not_run"))
  expect_false(dir.exists(file.path(output, "jobs")))
  expect_true(all(c("readiness.R", "adaptive_initializer.R", "adaptive_vertex.R", "adaptive_local_graph.R") %in%
    basename(vapply(data$manifest$sources, `[[`, "", "path"))))
  expect_error(qgs.campaign.run.local(home, output), "adapter not implemented")
  expect_identical(digest::digest(file = file.path(home, "registry.json"), algo = "sha256"), before)
  # Deliberately uncommitted provenance must never launch a pilot.
  manifest <- data$manifest; manifest$git$status <- " M uncommitted-source"
  qgs.write(manifest, file.path(output, "manifest.json"))
  state <- data$state
  state$manifest_sha256 <- digest::digest(file = file.path(output, "manifest.json"), algo = "sha256")
  qgs.binary(state, file.path(output, "state.rds"))
  expect_error(qgs.readiness.run(home, output), "clean, unchanged committed")
  expect_false(dir.exists(file.path(output, "jobs")))
})

test_that("campaigns exclude failed searches and uncommitted ledger outcomes from lengths", {
  out <- tempfile("qgs-export-regression-"); on.exit(unlink(out, recursive = TRUE), add = TRUE)
  plan <- qgs.campaign.plan(x, pairs = data.frame(case_id = "flat2_ball", pair_id = "grid_direction"),
    repeats = 4101, bindings = c(I = "direct_connector", A = "direct_connector", B = "direct_connector"),
    cohorts = list(edge = list(metric = "edges", values = c(1, 2), limits = qgs.limits())),
    protocol = "synthetic-export-regression")
  qgs.campaign.create(home, file.path(home, "../../fixtures/quadform_geodesics/v1"), out, plan)
  state <- qgs.campaign.read(out)$state
  fault <- direct; fault$solve <- function(state, request, control) {
    direct$solve(state, request, control); stop("failure after accepted initializer")
  }
  for (i in seq_along(plan$jobs)) {
    r <- plan$jobs[[i]]$request; search <- qgs.execute(fault, r)
    expect_identical(search$status, "failed")
    record <- list(request = r, search = search, audits = qgs.audit.queue(qgs.targets(search), r), end_to_end_seconds = 0)
    dir.create(file.path(out, "jobs", plan$jobs[[i]]$id), recursive = TRUE)
    qgs.binary(record, file.path(out, "jobs", plan$jobs[[i]]$id, "record.rds"))
  }
  for (ledger in c("failed", "complete", "interrupted", "not_run")) {
    state$status[] <- ledger
    z <- qgs.campaign.export(out, plan, state, x)
    expect_true(all(is.na(z$audited_length)))
    expect_false(any(z$fixture_row_status == "ok"))
    expect_true(all(is.na(read.csv(file.path(out, "paired.csv"))$difference_A_minus_B)))
    expect_true(all(is.na(read.csv(file.path(out, "directional.csv"))$relative_discrepancy)))
  }
  expect_true(all(c("relative_shortening", "shortening_allowance", "accepted_proposals",
    "final_stage", "target_edge_calls", "target_seconds", "path_feasibility") %in% names(z)))
  expect_true(file.exists(file.path(out, "ablations.csv")))
  expect_true(file.exists(file.path(out, "equal-pair-summary.csv")))
  s <- read.csv(file.path(out, "summary.csv"))
  expect_true(all(c("unsupported", "censored", "audit_unavailable", "audit_failed", "unusable") %in% names(s)))
  # Synthetic ablation metadata isolates the reporting rules from solver behavior.
  for (i in seq_along(plan$jobs)) {
    r <- plan$jobs[[i]]$request; search <- qgs.execute(direct, r)
    search$adapter_state <- list(accepted = 0L, inserted = 0L, deleted = 0L, stage = 0L, sweep = 0L,
      diagnostics = list(list(kind = "subdivision_end", stage = 0L, sweep = 0L)))
    record <- list(request = r, search = search, audits = qgs.audit.queue(qgs.targets(search), r), end_to_end_seconds = 0)
    qgs.binary(record, file.path(out, "jobs", plan$jobs[[i]]$id, "record.rds"))
  }
  state$status[] <- "complete"
  qgs.campaign.export(out, plan, state, x)
  expect_true(all(read.csv(file.path(out, "ablations.csv"))$ablation_status == "matched"))
  b <- which(vapply(plan$jobs, function(j) j$role == "B", logical(1)))[1]
  file <- file.path(out, "jobs", plan$jobs[[b]]$id, "record.rds")
  record <- readRDS(file); original <- record
  record$audits$initializer$length <- record$audits$initializer$length + 1
  qgs.binary(record, file); qgs.campaign.export(out, plan, state, x)
  expect_true(any(read.csv(file.path(out, "ablations.csv"))$ablation_status == "invalid_initializer_mismatch"))
  record <- original
  event <- record$search$history[[1]]; event$phase <- "subdivision"
  event$adapter <- list(stage = 0L, sweep = 0L)
  U <- event$candidate$path$vertices
  event$candidate$path$vertices <- rbind(U[1, ], (U[1, ] + U[2, ]) / 2, U[2, ])
  record$search$history[[2]] <- event
  qgs.binary(record, file); qgs.campaign.export(out, plan, state, x)
  expect_true(any(read.csv(file.path(out, "ablations.csv"))$ablation_status == "invalid_subdivision_mismatch"))
  record <- original; qgs.binary(record, file)
  state$status[b] <- "interrupted"
  z <- qgs.campaign.export(out, plan, state, x)
  expect_true(all(is.na(z$audited_length[z$job_id == plan$jobs[[b]]$id])))
  expect_true(any(read.csv(file.path(out, "ablations.csv"))$ablation_status == "unavailable"))
})

test_that("refined comparison exports require a passed own initializer audit", {
  evidence <- Sys.getenv("QGS_REGRESSION_EVIDENCE")
  out <- if (nzchar(evidence)) file.path(evidence, "initializer-qualification") else tempfile("qgs-initializer-gate-")
  dir.create(out, recursive = TRUE)
  if (!nzchar(evidence)) on.exit(unlink(out, recursive = TRUE), add = TRUE)
  plan <- qgs.campaign.plan(x, pairs = data.frame(case_id = "flat2_ball", pair_id = "grid_direction"),
    repeats = 4105, bindings = c(I = "direct_connector", A = "direct_connector", B = "direct_connector"),
    cohorts = list(edge = list(metric = "edges", values = c(2, 3), limits = qgs.limits())),
    protocol = "synthetic-initializer-qualification-regression")
  for (mode in c("passed", "length_mismatch", "missing_target", "mixed")) {
    output <- file.path(out, mode)
    qgs.campaign.create(home, file.path(home, "../../fixtures/quadform_geodesics/v1"), output, plan)
    excluded.jobs <- character(); record.files <- character()
    for (job in plan$jobs) {
      r <- job$request
      fault <- job$role %in% c("A", "B") && mode != "passed" &&
        (mode != "mixed" || (job$role == "A" && r$direction == "forward"))
      expected <- if (!fault) "passed" else if (mode == "missing_target") "missing_target" else "length_mismatch"
      adapter <- direct
      adapter$solve <- function(state, request, control) {
        e <- control$edge(request$from, request$to)
        U <- rbind(request$from, request$to)
        if (expected != "missing_target") control$publish(qgs.candidate(U,
          e$length * if (expected == "length_mismatch") 1.2 else 1, e$error_estimate), "initializer")
        control$publish(qgs.candidate(U, e$length, e$error_estimate), "refinement")
        list(status = "candidate", termination = "schedule_exhausted")
      }
      search <- qgs.execute(adapter, r)
      audits <- qgs.audit.queue(qgs.targets(search), r)
      expect_identical(search$status, "candidate")
      expect_identical(audits$initializer$status, expected)
      expect_true(all(vapply(audits[c("terminal", "checkpoint_1", "checkpoint_2")],
        function(a) identical(a$status, "passed"), logical(1))))
      file <- file.path(output, "jobs", job$id, "record.rds")
      dir.create(dirname(file), recursive = TRUE)
      qgs.binary(list(request = r, search = search, audits = audits, end_to_end_seconds = 0), file)
      record.files <- c(record.files, file)
      if (fault) excluded.jobs <- c(excluded.jobs, job$id)
    }
    hashes <- vapply(record.files, function(f) digest::digest(file = f, algo = "sha256"), "")
    z <- qgs.campaign.export(output, plan, list(status = rep("complete", length(plan$jobs))), x)
    excluded <- z$job_id %in% excluded.jobs
    expect_equal(nrow(z), 12)
    expect_identical(is.na(z$audited_length), excluded)
    expect_true(all(z$audit_status == "passed"))
    expect_true(all(z$comparison_status[!excluded] == "qualified"))
    expect_true(all(z$comparison_status[excluded] == paste0("initializer_audit_", z$initializer_audit_status[excluded])))
    expect_true(all(z$fixture_row_status[excluded] == "failed"))
    expect_true(all(z$fixture_row_status[!excluded] == "ok"))
    expect_true(all(is.na(z[excluded, c("relative_shortening", "analytic_absolute_error",
      "analytic_relative_error", "chord_to_path_gap")])))
    s <- read.csv(file.path(output, "summary.csv"))
    expect_equal(sum(s$usable), sum(!excluded))
    expect_equal(sum(s$unusable), sum(excluded))
    expect_true(all(is.na(s$median_conditional[s$usable == 0])))
    expect_equal(sum(s$initializer_audit_failed), if (mode == "missing_target") 0 else sum(excluded))
    expect_equal(sum(s$initializer_audit_unavailable), if (mode == "missing_target") sum(excluded) else 0)
    expect_equal(s$audit_failed, s$initializer_audit_failed)
    expect_equal(s$audit_unavailable, s$initializer_audit_unavailable)
    expect_true(all(s$checkpoint_audit_failed == 0 & s$checkpoint_audit_unavailable == 0))
    paired <- read.csv(file.path(output, "paired.csv"))
    expect_equal(nrow(paired), 4)
    expect_equal(sum(paired$paired_available), switch(mode, passed = 4, mixed = 2, 0))
    expect_true(all(is.na(paired$difference_A_minus_B[!paired$paired_available])))
    expect_equal(sum(read.csv(file.path(output, "paired-summary.csv"))$paired_usable), sum(paired$paired_available))
    d <- read.csv(file.path(output, "directional.csv"))
    expect_equal(sum(d$directional_available), switch(mode, passed = 6, mixed = 4, 2))
    expect_true(all(is.na(d$relative_discrepancy[!d$directional_available])))
    a <- read.csv(file.path(output, "ablations.csv"))
    expect_true(all(is.na(a$baseline_difference[a$job_id %in% excluded.jobs])))
    expect_equal(sum(read.csv(file.path(output, "pair-summary.csv"))$usable_observations), sum(!excluded))
    equal <- read.csv(file.path(output, "equal-pair-summary.csv"))
    expect_true(all(is.na(equal$mean_analytic_absolute_error_conditional[equal$usable_pairs == 0])))
    for (group in unique(z$group)) {
      fixture <- read.csv(file.path(output, "fixture_exports", paste0(group, ".csv")))
      expect_equal(nrow(fixture), 394)
      expect_equal(sum(fixture$status == "ok"), sum(!excluded & z$group == group))
    }
    expect_identical(vapply(record.files, function(f) digest::digest(file = f, algo = "sha256"), ""), hashes)
  }
})

test_that("comparison qualification fails closed for missing and unavailable audits", {
  for (status in list(NULL, "missing_target", "audit_unavailable_budget", "audit_unavailable_worker",
                      "representation_not_audited", "length_mismatch", "future_status")) {
    expect_identical(qgs.comparison.status("complete", "candidate", "carried", "passed", status, TRUE),
      paste0("initializer_audit_", if (is.null(status)) "unavailable" else status))
  }
  expect_identical(qgs.comparison.status("complete", "candidate", NULL, "passed", "passed", TRUE),
    "checkpoint_unavailable")
  expect_identical(qgs.comparison.status("complete", "candidate", "observed", "passed", "passed", TRUE), "qualified")
  expect_identical(qgs.comparison.status("complete", "candidate", "carried", "passed", "length_mismatch", FALSE), "qualified")
})

test_that("initializer baseline calls the shared deterministic initializer without RNG", {
  a <- qgs.load.adapter(file.path(home, "solvers/adaptive_initializer.R"), "adaptive_initializer")
  file <- tempfile("qgs-initializer-"); on.exit(unlink(file), add = TRUE)
  r <- req(); result <- qgs.execute(a, r, persist.state = function(s) qgs.binary(s, file))
  expect_identical(result$status, "candidate")
  expect_identical(result$termination, "initializer_complete")
  expect_null(result$adapter_state$rng_state)
  expect_equal(result$adapter_state$accepted, 0)
  expect_equal(result$adapter_state$inserted, 0)
  expect_equal(result$adapter_state$measure$length, qg.norm(r$to - r$from))
  expect_true(file.exists(file))
})

test_that("target reporting distinguishes observed improvement from incomplete qualification", {
  r <- req(); search <- qgs.execute(direct, r)
  record <- list(search = search, audits = qgs.audit.queue(qgs.targets(search), r))
  # Explicit synthetic reporting inputs, not a geometric accuracy experiment.
  record$audits$initializer$length <- 10
  record$audits$publication_1$length <- 9
  record$search$history[[1]]$counters <- list(edge_calls = 7L, algorithm_seconds = 0.5)
  z <- qgs.report.record(record, r, TRUE)
  expect_identical(z$target_status, "reached_at_audited_publication")
  expect_equal(z$target_edge_calls, 7)
  expect_equal(z$target_seconds, 0.5)
  record$audits$publication_1$status <- "audit_unavailable_budget"
  expect_identical(qgs.report.record(record, r, TRUE)$target_status, "unavailable_incomplete_audit")
  expect_identical(qgs.report.record(record, r, FALSE)$target_status, "unavailable")
})
cat("Regression tests complete; synthetic reporting probes are not calibration evidence.\n")
