#!/usr/bin/env Rscript
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]))
adaptive_home <- dirname(dirname(script))
source(file.path(adaptive_home, "interface.R"))
source(file.path(adaptive_home, "runner.R"))
source(file.path(dirname(script), "adaptive_test_helpers.R"))
source(file.path(adaptive_home, "experiments/sensitivity.R"))
namespace <- function(experiment = TRUE) {
  e <- new.env(parent = globalenv())
  files <- c("common.R", "local_graph.R", "three_point.R", if (experiment) "sensitivity.R")
  for (file in files) sys.source(file.path(adaptive_home, "solvers/adaptive", file), e)
  e
}
e <- namespace()
test_rng <- function() {
  stream <- function(seed) function() { seed <<- (1664525 * seed + 1013904223) %% 2^32; seed / 2^32 }
  list(uniform = stream(3), order_uniform = stream(5), state = function() "TEST DOUBLE")
}
state <- function(policy = "neighbors", r = req()) {
  s <- e$qga.state(r, control_test(), test_rng())
  s$config$neighborhood <- policy; s$config$cohort <- "epochs"
  s
}
with_reporter(StopReporter$new(), {
test_that("default plan has 100 independent runs in each direction of every cell", {
  p <- qgx.plan()
  expect_equal(nrow(p), 3600L)
  counts <- table(p$method, p$direction, p$neighborhood, p$cohort)
  expect_true(all(counts == 100L)); expect_identical(p, qgx.plan())
  expect_equal(length(unique(p$repeat_label)), 100L)
  expect_error(qgx.plan(0)); expect_error(qgx.plan(1.5)); expect_error(qgx.plan(cases = "unknown"))
  expect_error(qgx.plan(cohorts = c("epochs", "epochs")))
})
test_that("direction seeds differ but methods and neighborhoods share repeat seeds", {
  p <- qgx.plan(2, cohorts = "epochs")
  requests <- lapply(seq_len(nrow(p)), function(i) qgx.request(fixture, p[i, ]))
  seeds <- vapply(requests, `[[`, "", "seed_hex")
  expect_equal(length(unique(seeds)), 4L)
  for (g in split(seq_len(nrow(p)), interaction(p$repeat_label, p$direction)))
    expect_equal(length(unique(seeds[g])), 1L)
  expect_equal(qgx.limits("edges")$edge_calls, 10000L)
  expect_equal(qgx.limits("seconds")$seconds, 10)
  expect_equal(qgx.limits("epochs")$rss_mib, 1024)
})
test_that("experimental adapters reject unknown settings and isolate schedule changes", {
  expect_error(e$qgx.settings(list()), "require")
  expect_error(e$qgx.settings(list(neighborhood = "unknown", cohort = "epochs")), "require")
  for (id in qgx.methods) {
    adapter <- source(file.path(adaptive_home, "solvers", paste0(id, ".R")))$value
    for (cohort in qgx.cohorts) {
      r <- req(); r$parameters <- list(neighborhood = "fixed_disk", cohort = cohort)
      expect_true(adapter$supports(r)$supported)
      s <- adapter$prepare(r, qgs.control(r, persist.state = function(state) NULL))
      expect_equal(s$config$max_epochs, if (cohort == "epochs") 8L else 1000L)
      expect_equal(s$config$plateau_sweeps, if (cohort == "epochs") 2L else 1001L)
      expect_identical(s$request, r)
    }
  }
  expect_identical(namespace(FALSE)$qga.config()$protocol, "qg-three-point-center-v1")
})
test_that("baseline paths and random states remain unchanged by instrumentation", {
  old <- namespace(FALSE)
  a <- old$qga.state(req(), control_test(), test_rng()); b <- state()
  a$config$candidate_draws <- b$config$candidate_draws <- 4L
  old$qga.solve(a); e$qga.solve(b)
  expect_identical(a$U, b$U); expect_identical(a$measure, b$measure)
  expect_equal(a$control$stats()$edge_calls, b$control$stats()$edge_calls)
  expect_identical(a$rng$uniform(), b$rng$uniform())
  expect_identical(a$rng$order_uniform(), b$rng$order_uniform())
})
test_that("fixed radius is derived only from the common initial path and is reversal invariant", {
  s <- state("fixed_disk"); e$qga.initialize(s)
  r <- req(direction = "reverse"); reverse <- state("fixed_disk", r); e$qga.initialize(reverse)
  expect_identical(s$config$reference_radius, reverse$config$reference_radius)
  expect_equal(s$config$reference_radius, qga.norm(r$to - r$from) / 16, tolerance = 1e-8)
  radius <- s$config$reference_radius
  U <- rbind(c(-.001, 0), c(0, 0), c(.001, 0))
  expect_equal(e$qg3.radius(s, U, U[2, ]), radius)
  s$config$neighborhood <- "neighbors"
  expect_equal(e$qg3.radius(s, U, U[2, ]), .001)
})
test_that("distance-based windows cover the same scale after point densification", {
  s <- state("fixed_span"); s$config$reference_radius <- .4
  s$U <- cbind(seq(-1, 1, by = .1), 0)
  indices <- e$qg3.window.indices(s, 11L)
  expect_true(indices[1L] < 10L && indices[2L] > 12L)
  ends <- s$U[indices, ]
  expect_true(all(abs(ends[, 1]) >= .4 - 1e-14))
  s$U <- cbind(seq(-1, 1, by = .05), 0)
  indices <- e$qg3.window.indices(s, 21L)
  expect_true(all(abs(s$U[indices, 1]) >= .4 - 1e-14))
  expect_true(all(abs(s$U[indices, 1]) <= .45 + 1e-14))
  expect_equal(e$qg3.window.indices(s, 2L)[1L], 1L)
  s$config$neighborhood <- "fixed_disk"
  expect_identical(e$qg3.window.indices(s, 21L), c(20L, 22L))
})
test_that("all policies retain the same candidate count and domain clipping", {
  for (policy in qgx.policies) {
    a <- state(policy, req("flat2_ball")); b <- state(policy, req("flat2_ball"))
    a$config$reference_radius <- b$config$reference_radius <- .15
    U <- rbind(c(.8, 0), c(.95, 0), c(.99, 0))
    R <- e$qga.sample(a, U, U[2, ], FALSE); Q <- e$qga.sample(b, U, U[2, ], FALSE)
    expect_identical(R, Q); expect_equal(nrow(R), 32L)
    expect_true(all(apply(R, 1L, qg.inside, domain = a$request$domain)))
    expect_true(all(sqrt(rowSums(sweep(R, 2L, U[2, ], "-")^2)) <= .15 + 1e-14))
    expect_equal(tail(a$diagnostics, 1)[[1]]$accepted_draws, 32L)
  }
})
test_that("multi-point sections preserve endpoints and demonstrate shortening", {
  for (planner in list(e$qga.vertex.plan, e$qga.local.graph.plan)) {
    s <- state("fixed_span"); s$config$reference_radius <- .5
    U <- rbind(c(-.5, 0), c(-.25, .2), c(0, .4), c(.25, .2), c(.5, 0))
    seed_path(s, U); before <- s$measure$length
    expect_true(e$qga.window(s, 1L, 5L, U[3L, ], FALSE, planner))
    expect_lt(s$measure$length, before)
    expect_equal(s$U[c(1L, nrow(s$U)), ], U[c(1L, 5L), ])
    s <- state("fixed_span"); s$config$reference_radius <- .5
    s$control <- control_test(function(a, b, t) list(length = qga.norm(b-a), error_estimate = 10))
    seed_path(s, U)
    expect_false(e$qga.window(s, 1L, 5L, U[3L, ], FALSE, planner))
    expect_identical(s$U, U)
  }
})
test_that("local-network minimum includes the single-point minimum on identical sections", {
  s <- state("fixed_span")
  for (n in c(3L, 7L)) {
    U <- cbind(seq(-.5, .5, length.out = n), .3 * sin(seq(0, pi, length.out = n)))
    for (offset in c(-.1, 0, .1)) {
      R <- cbind(seq(-.4, .4, length.out = 8), offset)
      single <- e$qga.vertex.plan(U, R); network <- e$qga.local.graph.plan(U, R)
      batch <- e$qga.batch(s, c(single$edges, network$edges), TRUE)
      expect_lte(network$choose(batch, s$control)$measure$length,
        single$choose(batch, s$control)$measure$length + 1e-14)
    }
  }
})
test_that("per-round diagnostics include scale, length, vertices, and work", {
  s <- state("fixed_span"); s$config$candidate_draws <- 2L
  e$qga.solve(s)
  epochs <- Filter(function(d) d$kind == "epoch_end", s$diagnostics)
  expect_equal(length(epochs), 2L)
  expect_true(all(vapply(epochs, function(d) is.finite(d$median_radius) &&
    is.finite(d$median_section_length) && d$counters$edge_calls > 0L && d$vertices >= 2L, TRUE)))
})
test_that("distribution summaries preserve failures and detect an injected directional shift", {
  p <- qgx.plan(4, cohorts = "epochs")
  rows <- do.call(rbind, lapply(seq_len(nrow(p)), function(i) qgx.row(p[i, ])))
  rows$run_status <- "recorded"; rows$available <- TRUE
  rows$length <- ifelse(rows$direction == "forward", 3, 2)
  d <- qgx.directions(rows, draws = 100L)
  expect_true(all(d$mean_difference == 1)); expect_true(all(d$mean_low == 1 & d$mean_high == 1))
  expect_true(all(d$cumulative_distribution_gap == 1))
  rows$available[1L] <- FALSE; rows$length[1L] <- NA_real_; rows$termination[1L] <- "memory_budget"
  distributions <- qgx.distributions(rows)
  expect_equal(sum(distributions$planned), nrow(p)); expect_equal(sum(distributions$available), nrow(p) - 1L)
  expect_equal(sum(distributions$memory_stops), 1L)
  rows$available <- FALSE; rows$length <- NA_real_
  expect_true(all(is.na(qgx.directions(rows, draws = 100L)$mean_difference)))
})
test_that("paired method and neighborhood contrasts use matched independent repeats", {
  p <- qgx.plan(4, cohorts = "epochs")
  rows <- do.call(rbind, lapply(seq_len(nrow(p)), function(i) qgx.row(p[i, ])))
  rows$available <- TRUE; rows$length <- 2
  rows$length[rows$method == "sensitivity_local_graph"] <- 3
  rows$length[rows$method == "sensitivity_local_graph" & rows$neighborhood != "neighbors"] <- 2.5
  result <- qgx.paired(rows, draws = 100L)
  expect_true(all(result$neighborhood_effects$mean_difference == -.5))
  expect_true(all(result$neighborhood_effects$available == 4L))
  expect_equal(qgx.interval(1, 2)["mean_difference"], c(mean_difference = -1))
  expect_true(is.na(qgx.interval(1, 2)["mean_low"]))
})
test_that("bootstrap preserves R RNG state and keeps paired observations together", {
  set.seed(19); old <- .Random.seed
  a <- qgx.interval(1:20, 1:20 + 3, paired = TRUE, draws = 100L)
  expect_identical(.Random.seed, old); expect_true(all(a == -3))
  expect_identical(a, qgx.interval(1:20, 1:20 + 3, paired = TRUE, draws = 100L))
  expect_error(qgx.interval(1:3, 1:2, paired = TRUE))
})
test_that("initializer mismatch disqualifies comparisons without losing retained records", {
  p <- qgx.plan(1, cohorts = "epochs")
  rows <- do.call(rbind, lapply(seq_len(nrow(p)), function(i) qgx.row(p[i, ])))
  rows$available <- TRUE; rows$length <- 2; rows$initializer_key <- "same"
  expect_true(all(qgx.initializer.gate(rows)$available))
  rows$initializer_key[1L] <- "different"
  gated <- qgx.initializer.gate(rows)
  expect_false(any(gated$available)); expect_true(all(is.na(gated$length)))
  expect_equal(nrow(gated), nrow(rows))
})
test_that("expected budget stops qualify but competing stops and missing audits do not", {
  job <- qgx.plan(1, cases = "flat2_box", cohorts = "edges")[1, ]
  r <- qgx.request(fixture, job)
  U <- rbind(r$from, r$to); length <- qga.norm(r$to - r$from)
  candidate <- qgs.candidate(U, length)
  audit <- list(status = "passed", length = length, error_estimate = 0, rounding_allowance = 1e-14)
  record <- list(request = r, end_to_end_seconds = 1,
    search = list(status = "candidate", termination = "edge_budget",
    initializer = list(candidate = candidate), incumbent = list(candidate = candidate)),
    audits = list(initializer = audit), final_audit = audit)
  row <- qgx.row(job, record, fixture)
  expect_true(row$available); expect_equal(row$length, length)
  record$search$termination <- "time_budget"
  row <- qgx.row(job, record, fixture)
  expect_false(row$available); expect_true(is.na(row$length))
  expect_equal(row$retained_audited_length, length)
  record$search$termination <- "edge_budget"; record$audits$initializer$status <- "unavailable"
  expect_false(qgx.row(job, record, fixture)$available)
  record$audits$initializer <- audit; record$final_audit$status <- "length_mismatch"
  expect_false(qgx.row(job, record, fixture)$available)
  record$final_audit <- audit; record$search$status <- "failed"
  expect_false(qgx.row(job, record, fixture)$available)
})
test_that("return grace changes only the search worker's outer deadline", {
  job <- qgx.supervisor(adaptive_home)
  supervise <- environment(job)$qgs.supervise
  environment(supervise)$original <- function(func, args, seconds, rss_mib, start.file, ...) {
    list(seconds = seconds, request = args$request, rss_mib = rss_mib)
  }
  r <- req(limits = list(seconds = 10))
  search <- supervise(identity, list(request = r), 10, 1024, "started.rds")
  audit <- supervise(identity, list(request = r), 10, 1024)
  expect_equal(search$seconds, 15); expect_equal(search$request$limits$seconds, 10)
  expect_equal(audit$seconds, 10); expect_equal(search$rss_mib, 1024)
})
})
cat("Sensitivity experiment tests passed.\n")
