#!/usr/bin/env Rscript
script <- normalizePath(sub("^--file=", "", grep("^--file=",commandArgs(),value=TRUE)[1]))
adaptive_home <- dirname(dirname(script))
source(file.path(adaptive_home,"interface.R"))
source(file.path(dirname(script),"adaptive_test_helpers.R"))

# Testthat stop reporter gives a nonzero process exit on any failed expectation.
with_reporter(StopReporter$new(), {
test_that("adapter follows the contract and refuses the unaligned shared runtime", {
  a <- source(file.path(adaptive_home,"solvers/adaptive_vertex.R"))$value
  expect_identical(a$id,"adaptive_vertex")
  expect_true(a$supports(req())$supported)
  expect_false(a$supports(req("flat3_box"))$supported)
  expect_error(a$prepare(req(),qgs.control(req())),"adaptive_runtime_unaligned")
  r <- req(); r$parameters <- list(samples=4)
  expect_error(a$supports(r),"no parameter overrides")
})
test_that("exact keys preserve bits and resolve numeric versus key path ties", {
  expect_false(identical(qga.key(c(0,0)),qga.key(c(-0,0))))
  expect_false(identical(qga.key(c(1,0)),qga.key(c(1+.Machine$double.eps,0))))
  U <- rbind(c(0,0),c(-2,0),c(-1,0),c(2,0))
  es <- list(U[c(1,2),],U[c(2,4),],U[c(1,3),],U[c(3,4),])
  s <- qga.state(req(),control_test(function(a,b,t) list(length=1,error_estimate=0)),rng_test())
  b <- qga.batch(s,es)
  path <- qga.dijkstra(U,es,b,1L,4L,s$control)
  expect_equal(path,U[c(1,3,4),]) # encoded negative keys: -1 precedes -2
  expect_identical(qga.config()$tie_order,qga.tie)
})
test_that("batches sort and deduplicate without a persistent local cache", {
  c <- control_test(); s <- qga.state(req(),c,rng_test())
  es <- list(rbind(c(0,0),c(1,1)),rbind(c(1,0),c(0,0)),rbind(c(1,1),c(0,0)))
  qga.batch(s,es); qga.batch(s,es,TRUE)
  keys <- vapply(c$log$edges,`[[`,"","key")
  expect_equal(length(keys),4L); expect_identical(keys[1:2],sort(unique(keys),method="radix"))
  expect_true(all(vapply(c$log$edges[3:4],`[[`,TRUE,"tighter")))
})
test_that("failed subdivisions skip the edge, progress elsewhere and retry next pass", {
  r <- req(); c <- control_test(function(a,b,t) {
    len <- qga.norm(b-a)
    if (identical(qga.edge.key(a,b),qga.edge.key(c(-1,0),c(0,0)))) len <- len+.2
    list(length=len,error_estimate=0)
  })
  s <- qga.state(r,c,rng_test()); seed_path(s,rbind(c(-1,0),c(0,0),c(.8,0)))
  qga.subdivide(s,.6)
  failed <- qga.edge.key(c(-1,0),c(0,0))
  expect_true(failed %in% s$pass_excluded)
  expect_true(any(s$U[,1]==.4)); expect_equal(nrow(s$U),4L)
  attempts <- Filter(function(x)x$kind=="subdivision_attempt" && x$edge==failed,s$diagnostics)
  expect_length(attempts,1L); expect_true(attempts[[1]]$tighter)
  qga.subdivide(s,.6)
  attempts <- Filter(function(x)x$kind=="subdivision_attempt" && x$edge==failed,s$diagnostics)
  expect_length(attempts,2L)
})
test_that("unrepresentable midpoints are permanently excluded without kernel work", {
  r <- req(); a <- c(.5,0); b <- c(.5+2^-53,0)
  c <- control_test(); s <- qga.state(r,c,rng_test()); seed_path(s,rbind(a,b))
  before <- length(c$log$edges)
  qga.subdivide(s,1e-20); qga.subdivide(s,1e-20)
  expect_equal(length(c$log$edges),before)
  expect_length(s$permanent_excluded,1L); expect_equal(nrow(s$U),2L)
})
test_that("recoverable failures finish the batch; budgets and programming faults propagate", {
  c <- control_test(function(a,b,t) if(!t) edge_failure() else list(length=qga.norm(b-a),error_estimate=0))
  s <- qga.state(req(),c,rng_test()); es <- list(rbind(c(0,0),c(1,0)),rbind(c(0,0),c(0,1)))
  b <- qga.batch(s,es); expect_length(b$failed,2L)
  expect_length(qga.batch(s,es,TRUE)$failed,0L)
  s$control <- control_test(budget=1)
  expect_error(qga.batch(s,es),class="qgs_budget")
  s$control <- control_test(function(...)stop("programming error"))
  expect_error(qga.batch(s,es),"programming error")
})
test_that("single-pivot refinement shortens a bent path and preserves endpoints", {
  r <- req(); c <- control_test(); s <- qga.state(r,c,rng_test(0))
  U <- rbind(c(-.5,0),c(0,.5),c(.5,0)); seed_path(s,U)
  before <- s$measure$length
  expect_true(qga.window(s,1L,3L,U[2,],FALSE))
  expect_lt(s$measure$length,before)
  expect_equal(s$U[c(1,nrow(s$U)),],U[c(1,3),])
  expect_equal(s$measure,qga.measure.records(s$segments))
  expect_identical(tail(c$log$events,1)[[1]]$phase,"refinement")
})
test_that("an equal-cost route keeps the incumbent even if its key is larger", {
  old <- rbind(c(-.5,0),c(0,0),c(.5,0)); R <- rbind(c(.1,0))
  s <- qga.state(req(),control_test(),rng_test()); p <- qga.vertex.plan(old,R)
  best <- p$choose(qga.batch(s,p$edges),s$control)
  expect_identical(best$vertices,old)
})
test_that("sampling has fixed draw order and clipped-domain shortfalls stay explicit", {
  used <- 0L; rng <- rng_test(); rng$uniform <- function(){used<<-used+1L; .25}
  s <- qga.state(req(),control_test(),rng); s$config$samples <- 2L; s$config$global_samples <- 1L
  R <- qga.sample(s,rbind(c(-.5,0),c(0,0),c(.5,0)),c(0,0),TRUE)
  expect_equal(used,8L); expect_true(all(apply(R,1,qg.inside,domain=s$request$domain)))
  expect_identical(qga.keys(R),sort(qga.keys(R),method="radix"))
  s$request$domain <- list(kind="box",lower=c(0,0),upper=c(.01,.01))
  s$config$rejection_cap <- 2L
  expect_null(qga.sample(s,rbind(c(1,1),c(2,2)),c(1,1),FALSE))
  expect_identical(tail(s$diagnostics,1)[[1]]$kind,"sample_shortfall")
})
test_that("initializer direct tie and edge-budget interruption retain the acknowledged path", {
  c <- control_test(); s <- qga.state(req(),c,rng_test()); qga.initialize(s)
  expect_equal(nrow(s$U),2L)
  expect_equal(s$measure$length,qga.norm(s$request$to-s$request$from))
  expect_identical(c$log$edges[[1]]$key,qga.edge.key(s$request$from,s$request$to))
  c <- control_test(budget=1); s <- qga.state(req(),c,rng_test())
  expect_error(qga.initialize(s),class="qgs_budget")
  expect_identical(c$latest()$phase,"direct_fallback")
})
test_that("bounded schedule reaches all stages, inserts vertices and forces exploration", {
  c <- control_test(); s <- qga.state(req(),c,rng_test())
  # Smaller explicit test configuration exercises the same schedule without a campaign.
  s$config$grid_intervals <- 2L; s$h0 <- s$bounds$width/2
  s$config$samples <- 1L; s$config$global_samples <- 1L
  result <- qga.solve(s)
  expect_identical(result$termination,"schedule_exhausted")
  expect_equal(s$stage,2L); expect_lte(s$sweep,27L); expect_gt(s$inserted,0)
  expect_true(any(s$global_history)); expect_true(all(vapply(c$log$events,function(e)
    is.finite(e$candidate$length),logical(1))))
  expect_true(any(vapply(c$log$states,function(z) z$phase=="subdivision",logical(1))))
})
test_that("identity takes no stochastic path", {
  s <- qga.state(req("flat2_ball","identity"),control_test(),NULL)
  expect_identical(qga.solve(s)$termination,"identity")
  expect_equal(s$measure$length,0)
})
test_that("ambiguous shortening retries the entire ordered comparison once", {
  r <- req(); c <- control_test(function(a,b,t) list(length=qga.norm(b-a),error_estimate=if(t)0 else 1))
  s <- qga.state(r,c,rng_test(0)); U <- rbind(c(-.5,0),c(0,.5),c(.5,0)); seed_path(s,U)
  start <- length(c$log$edges)
  expect_true(qga.window(s,1L,3L,U[2,],FALSE))
  calls <- c$log$edges[seq.int(start+1L,length(c$log$edges))]
  base <- calls[!vapply(calls,`[[`,TRUE,"tighter")]; tight <- calls[vapply(calls,`[[`,TRUE,"tighter")]
  expect_gt(length(base),0L)
  expect_identical(vapply(base,`[[`,"","key"),vapply(tight,`[[`,"","key"))
})
test_that("a failed or interrupted publication does not change local accepted vertices", {
  c <- control_test(); s <- qga.state(req(),c,rng_test(0))
  U <- rbind(c(-.5,0),c(0,.5),c(.5,0)); seed_path(s,U)
  s$control$publish <- function(...)budget_failure()
  expect_error(qga.window(s,1L,3L,U[2,],FALSE),class="qgs_budget")
  expect_identical(s$U,U); expect_identical(c$latest()$candidate$path$vertices,U)
  expect_equal(s$accepted,0L); expect_equal(s$deleted,0L); expect_equal(s$next_id,4L)
})
test_that("deleting an anchor skips its stale queue entry, without visiting new vertices", {
  c <- control_test(); s <- qga.state(req(),c,rng_test(0))
  U <- rbind(c(-.5,0),c(-.2,.5),c(.2,.5),c(.5,0)); seed_path(s,U)
  s$stage <- 1L; s$h0 <- 2 # suppress insertion during this one explicit test sweep
  s$config$insertion_every <- 100L
  qga.sweep(s,FALSE,qga.vertex.plan)
  expect_identical(s$queue,c(2L,3L)); expect_equal(nrow(s$U),2L)
  windows <- Filter(function(x)x$kind=="window",s$diagnostics)
  expect_length(windows,1L)
})
test_that("published segment estimates are frozen and unaffected segments need no extra lookup", {
  c <- control_test(); s <- qga.state(req(),c,rng_test(0))
  U <- rbind(c(-.8,0),c(-.5,0),c(0,.5),c(.5,0),c(.8,0)); seed_path(s,U)
  old <- c$latest()$candidate; before <- length(c$log$edges)
  expect_true(qga.window(s,2L,4L,U[3,],FALSE))
  keys <- vapply(c$log$edges[seq.int(before+1L,length(c$log$edges))],`[[`,"","key")
  expect_false(qga.edge.key(U[1,],U[2,]) %in% keys)
  expect_identical(c$log$events[[1]]$candidate,old)
  expect_equal(length(s$segments),nrow(s$U)-1L)
})
test_that("a new occurrence of an outside coordinate gets its own persistent ID", {
  U <- rbind(c(-.8,0),c(-.5,0),c(0,.9),c(.5,0),c(.8,0))
  route <- U[c(2,1,4),]
  cheap <- vapply(qga.path.edges(route),function(e)qga.edge.key(e[1,],e[2,]),"")
  c <- control_test(function(a,b,t)list(length=if(qga.edge.key(a,b)%in%cheap).5 else 10,error_estimate=0))
  s <- qga.state(req(),c,rng_test(0)); seed_path(s,U)
  planner <- function(old,R)list(edges=c(qga.path.edges(old),qga.path.edges(route)),
    choose=function(batch,control)list(vertices=route,measure=qga.measure(route,batch)))
  expect_true(qga.window(s,2L,4L,U[3,],FALSE,planner))
  expect_equal(s$U[1,],s$U[3,]); expect_false(s$ids[1]==s$ids[3])
  expect_equal(anyDuplicated(s$ids),0L)
})
test_that("NumPy PCG64 keeps the exact seed and reproducible state", {
  skip_if_not_installed("reticulate")
  g <- qga.pcg64("ffffffffffffffff"); h <- qga.pcg64("ffffffffffffffff")
  expect_identical(g$state(),h$state())
  known <- qga.pcg64("ffffffffffffffff")
  expect_equal(vapply(1:3,function(i)known$uniform(),0),
    c(0.6800266789616931,0.8453117585624743,0.007403081599260064), tolerance=0)
  expect_identical(vapply(1:8,function(i)g$uniform(),0),vapply(1:8,function(i)h$uniform(),0))
  expect_match(g$versions$generator,"PCG64")
  expect_false(identical(g$state(),qga.pcg64("fffffffffffffffe")$state()))
})
})
cat("adaptive_vertex focused tests passed; not protocol qualification.\n")
