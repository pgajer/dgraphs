#!/usr/bin/env Rscript
home <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
fixture.home <- normalizePath(file.path(home, "../../fixtures/quadform_geodesics"))
source(file.path(fixture.home, "collection.R"))
source(file.path(home, "interface.R"))
source(file.path(home, "runner.R"))
library(testthat)
x <- qg.read(file.path(fixture.home, "v1"))
adapter <- qgs.load.adapter(file.path(home, "solvers/direct_connector.R"), "direct_connector")
request <- function(case = "flat2_ball", pair = "grid_direction", ...) qgs.request(x, case, pair, ...)

test_that("registry distinguishes planned algorithms from the working control", {
  registry <- qgs.registry(home)
  expect_gte(length(registry), 11)
  expect_gte(sum(vapply(registry, function(m) m$status == "implemented", logical(1))), 1)
  planned <- Filter(function(m) m$status == "planned", registry)
  if (length(planned)) expect_error(qgs.run(home, file.path(fixture.home, "v1"), planned[[1]]$id, tempfile()), "planned")
  expect_error(qgs.run(home, file.path(fixture.home, "v1"), "missing", tempfile()), "Unknown method")
})

test_that("requests preserve the target without leaking reference answers", {
  a <- request(); b <- request(direction = "reverse")
  expect_identical(a$from, b$to); expect_identical(a$to, b$from)
  expect_identical(a$seed_digest, request()$seed_digest)
  expect_false(identical(a$seed_digest, b$seed_digest))
  expect_match(a$seed_hex, "^[0-9a-f]{16}$")
  expect_false(any(c("exact", "bounds", "pairs") %in% names(a)))
  text <- paste("qg-refine-v1", attr(x, "sha256"), "flat2_ball", "grid_direction", "forward", "4101", sep = "|")
  expect_identical(a$seed_digest, digest::digest(text, algo = "sha256", serialize = FALSE))
  expect_error(request(case = "missing"), "Unknown case")
  expect_error(request(pair = "missing"), "Unknown pair")
  expect_error(request(repeat_label = "bad|token"), "repeat")
  expect_error(request(repeat_label = "04101"), "repeat")
  expect_error(request(parameters = list(1)), "named list")
  expect_match(jsonlite::toJSON(request()$parameters, auto_unbox = TRUE), "^\\{\\}$")
  expect_error(qgs.limits(list(seconds = -1)), "Invalid")
  expect_error(qgs.limits(list(typo = 2)), "Unknown")
})

test_that("edge cache is exact, query-local and fidelity-aware", {
  r <- request(); c <- qgs.control(r)
  edge <- c$edge(r$from, r$to)
  expect_equal(edge$length, sqrt(0.8^2 + 0.4^2), tolerance = 1e-13)
  expect_identical(c$edge(r$to, r$from), edge)
  expect_equal(c$stats()$edge_calls, 1)
  expect_equal(c$stats()$cache_hits, 1)
  c$edge(r$from, r$to, tighter = TRUE)
  expect_equal(c$stats()$edge_calls, 2)
  c$edge(r$from, r$to + c(1e-14, 0))
  expect_equal(c$stats()$edge_calls, 3)
  expect_equal(qgs.control(r)$stats()$edge_calls, 0)
  expect_error(c$edge(r$from, c(2, 0)), "Invalid connector")
  limited <- qgs.control(request(limits = list(edge_calls = 1)))
  limited$edge(r$from, r$to)
  expect_error(limited$edge(r$from, r$to, tighter = TRUE), "edge_budget", class = "qgs_budget")
})

test_that("direct control works on identity, short, scaled and multi-height fixtures", {
  for (case in c("flat2_ball", "paraboloid2_disk", "paraboloid2_small_units",
                 "paraboloid2_large_units", "paraboloid2_rigid_frame", "multi_form2_square", "mixed4_box")) {
    for (pair in c("identity", "near", "ab")) {
      r <- request(case, pair)
      result <- qgs.execute(adapter, r)
      expect_identical(result$status, "candidate")
      audited <- qgs.audit(result$incumbent$candidate, r)
      expect_identical(audited$status, "passed")
      if (pair == "identity") expect_identical(audited$length, 0)
      else expect_gt(audited$length, 0)
    }
  }
})

test_that("audit rejects wrong endpoints, domain escapes and false lengths", {
  r <- request(); good <- qgs.execute(adapter, r)$incumbent$candidate
  wrong <- good; wrong$path$vertices[1, 1] <- 0.1
  expect_error(qgs.audit(wrong, r), "endpoints")
  wrong <- good; wrong$path$vertices <- rbind(r$from, c(2, 2), r$to)
  expect_error(qgs.audit(wrong, r), "leaves declared domain")
  wrong <- good; wrong$length <- good$length * 1.1
  expect_identical(qgs.audit(wrong, r)$status, "length_mismatch")
  wrong <- good; wrong$length <- NaN
  expect_error(qgs.audit(wrong, r), "finite nonnegative")
  wrong <- good; wrong$path$vertices <- rbind(r$from, r$from, r$to)
  expect_identical(qgs.audit(wrong, r)$status, "passed")
  native <- good; native$path <- list(kind = "native", format = "bvp_cubic", data = list(example = TRUE))
  expect_identical(qgs.audit(native, r)$status, "representation_not_audited")
})

test_that("phase errors and unsupported scopes never silently fall back", {
  supports <- function(r) list(supported = TRUE, reason = "test")
  prepare <- function(r, c) NULL
  fail <- qgs.adapter("test", supports, function(r, c) stop("broken prepare"), adapter$solve)
  expect_identical(qgs.execute(fail, request())$termination, "prepare_error")
  unsupported <- qgs.adapter("test", function(r) list(supported = FALSE, reason = "scope"),
                              function(...) stop("must not execute"), function(...) stop("must not execute"))
  expect_identical(qgs.execute(unsupported, request())$status, "unsupported")
  missing <- qgs.adapter("test", supports, prepare, function(...) list(status = "candidate", termination = "done"))
  expect_identical(qgs.execute(missing, request())$status, "failed")
  capped <- qgs.adapter("test", supports, prepare, function(s, r, control) {
    e <- control$edge(r$from, r$to)
    control$publish(qgs.candidate(rbind(r$from, r$to), e$length, e$error_estimate))
    control$edge(r$from, r$to, tighter = TRUE)
  })
  result <- qgs.execute(capped, request(limits = list(edge_calls = 1)))
  expect_identical(result$status, "candidate")
  expect_identical(result$termination, "edge_budget")
  expect_false(is.null(result$incumbent))
  timed <- qgs.adapter("test", supports, prepare, function(s, r, control) {
    Sys.sleep(0.02); control$poll()
  })
  expect_identical(qgs.execute(timed, request(limits = list(seconds = 0.001)))$termination, "time_budget")
})

test_that("process runner persists a full ledger and gates independently audited answers", {
  output <- tempfile("qgs-integration-")
  on.exit(unlink(output, recursive = TRUE), add = TRUE)
  rows <- qg.template(x)
  selection <- rows[rows$case_id == "flat2_ball" & rows$pair_id %in% c("identity", "grid_direction"),
                    c("case_id", "pair_id", "direction")]
  result <- qgs.run(home, file.path(fixture.home, "v1"), "direct_connector", output, selection)
  expect_equal(nrow(result$rows), 394)
  expect_equal(sum(result$rows$status == "ok"), 4)
  expect_equal(sum(result$rows$status == "not_run"), 390)
  expect_identical(result$verdict$status, "consistent")
  expect_false(result$verdict$complete)
  expect_true(file.exists(file.path(output, "results.csv")))
  expect_equal(length(list.files(file.path(output, "queries"), pattern = "record.json", recursive = TRUE)), 4)
  csv <- read.csv(file.path(output, "results.csv"), na.strings = "", stringsAsFactors = FALSE,
                  colClasses = c(distance = "numeric", elapsed_seconds = "numeric"))
  expect_false(qg.check.results(x, csv)$complete)
  expect_error(qgs.run(home, file.path(fixture.home, "v1"), "direct_connector", output, selection), "new directory")
  expect_error(qgs.run(home, file.path(fixture.home, "v1"), "direct_connector", tempfile(), selection[FALSE, ]), "Empty")
  expect_error(qgs.run(home, file.path(fixture.home, "v1"), "direct_connector", tempfile(), rbind(selection, selection)), "Invalid selection")
  expect_error(qgs.run(home, file.path(fixture.home, "v1"), "direct_connector",
                       file.path(fixture.home, "v1", "must-not-exist"), selection), "inside frozen")
  expect_false(file.exists(file.path(fixture.home, "v1", "must-not-exist")))
})

test_that("abnormal process exits and non-cooperative hangs are isolated", {
  method <- list(id = "test_fault", file = "tests/fault_adapter.R")
  helpers <- file.path(fixture.home, "collection.R")
  sources <- qgs.sources(home, method, helpers)
  root <- tempfile("qgs-faults-"); dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  for (behavior in c("exit", "hang", "error")) {
    directory <- file.path(root, behavior); dir.create(directory)
    r <- request(parameters = list(behavior = behavior), limits = list(seconds = 0.05))
    record <- qgs.job(home, helpers, file.path(home, method$file), method, r, directory, sources)
    expect_identical(record$search$status, "failed")
    expect_null(record$search$incumbent)
    expect_identical(record$final_audit$status, "unavailable")
    expect_lt(record$end_to_end_seconds, 15)
  }
})

test_that("an audited but inaccurate feasible route stays in companion evidence", {
  r <- request("paraboloid2_disk", "radial")
  r$method_id <- "test_detour"
  U <- rbind(r$from, c(-0.3, 0.1), r$to)
  c <- qgs.control(r)
  edges <- lapply(seq_len(nrow(U) - 1L), function(i) c$edge(U[i, ], U[i + 1L, ]))
  candidate <- qgs.candidate(U, sum(vapply(edges, `[[`, 0, "length")),
                             sum(vapply(edges, `[[`, 0, "error_estimate")))
  record <- list(request = r, search = list(status = "candidate", termination = "test_detour"),
                 final_audit = qgs.audit(candidate, r), end_to_end_seconds = 0)
  expect_identical(record$final_audit$status, "passed")
  expect_gt(record$final_audit$length, 0)
  row <- qgs.row(x, record, "test-only")
  expect_identical(row$status, "failed")
  expect_true(is.na(row$distance))
  expect_match(row$diagnostic, "geometric bounds|Exact-control")
})

test_that("changed sources are detected", {
  path <- tempfile(); on.exit(unlink(path), add = TRUE)
  writeLines("first", path)
  sources <- list(list(path = path, sha256 = digest::digest(file = path, algo = "sha256")))
  expect_silent(qgs.verify.sources(sources))
  writeLines("changed", path)
  expect_error(qgs.verify.sources(sources), "Source changed")
})
cat("Unified interface tests complete. No comparison solver is certified.\n")
