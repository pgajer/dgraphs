#!/usr/bin/env Rscript
script <- normalizePath(sub("^--file=", "", grep("^--file=",commandArgs(),value=TRUE)[1]))
adaptive_home <- dirname(dirname(script))
source(file.path(adaptive_home,"interface.R"))
source(file.path(dirname(script),"adaptive_test_helpers.R"))
source(file.path(adaptive_home,"solvers/adaptive/local_graph.R"))
with_reporter(StopReporter$new(), {
test_that("local-graph adapter uses the same applicability and runtime gates", {
  a <- source(file.path(adaptive_home,"solvers/adaptive_local_graph.R"))$value
  expect_identical(a$id,"adaptive_local_graph")
  expect_true(a$supports(req())$supported)
  expect_error(a$prepare(req(),qgs.control(req())),"adaptive_runtime_unaligned")
})
test_that("local graph can find a two-pivot route that vertex replacement cannot", {
  # Deterministic graph costs deliberately isolate route-search expressiveness.
  # These test weights are not claimed to be surface lengths.
  old <- rbind(c(0,0),c(0,1),c(1,1)); R <- rbind(c(.25,.25),c(.75,.75))
  cheap <- c(qga.edge.key(old[1,],R[1,]), qga.edge.key(R[1,],R[2,]), qga.edge.key(R[2,],old[3,]))
  c <- control_test(function(a,b,t) list(length=if(qga.edge.key(a,b)%in%cheap)1 else 10,error_estimate=0))
  s <- qga.state(req(),c,rng_test()); vp <- qga.vertex.plan(old,R); gp <- qga.local.graph.plan(old,R)
  vertex <- vp$choose(qga.batch(s,vp$edges),c)
  graph <- gp$choose(qga.batch(s,gp$edges),c)
  expect_equal(vertex$measure$length,10)
  expect_equal(graph$measure$length,3)
  expect_equal(graph$vertices,rbind(old[1,],R,old[3,]))
})
test_that("complete graph batches have quadratic cost and canonical order", {
  old <- rbind(c(-.5,0),c(0,.5),c(.5,0))
  R <- cbind(seq(-.4,.4,length.out=32), rep(.2,32))
  vp <- qga.vertex.plan(old,R); gp <- qga.local.graph.plan(old,R)
  expect_equal(length(qga.edge.list(vp$edges)),67L) # 65 candidates + 2 old edges
  expect_equal(length(qga.edge.list(gp$edges)),595L)
  c <- control_test(); s <- qga.state(req(),c,rng_test()); qga.batch(s,gp$edges)
  actual <- vapply(c$log$edges,`[[`,"","key")
  expect_identical(actual,sort(actual,method="radix"))
})
test_that("equal cost graph routes retain old path and candidate order is irrelevant", {
  old <- rbind(c(-.5,0),c(0,0),c(.5,0)); R <- rbind(c(-.2,0),c(.2,0))
  s <- qga.state(req(),control_test(),rng_test())
  a <- qga.local.graph.plan(old,R); b <- qga.local.graph.plan(old,R[2:1,])
  expect_identical(names(qga.edge.list(a$edges)),names(qga.edge.list(b$edges)))
  expect_identical(a$choose(qga.batch(s,a$edges),s$control)$vertices,old)
})
test_that("vertex cap rejects oversized graph proposal without truncating", {
  old <- rbind(c(-.5,0),c(0,.5),c(.5,0)); c <- control_test()
  s <- qga.state(req(),c,rng_test(0)); seed_path(s,old); s$config$max_vertices <- 3L
  planner <- function(old,R) list(edges=qga.path.edges(old), choose=function(batch,control)
    list(vertices=rbind(old[1,],c(-.2,0),c(.2,0),old[3,]),measure=list(length=0,error_estimate=0)))
  expect_false(qga.window(s,1L,3L,old[2,],FALSE,planner))
  expect_identical(s$U,old)
  expect_identical(tail(s$diagnostics,1)[[1]]$kind,"proposal_vertex_cap")
})
test_that("graph budget interrupt preserves the published initializer", {
  c <- control_test(budget=4); s <- qga.state(req(),c,rng_test(.25))
  old <- rbind(c(-.5,0),c(0,.5),c(.5,0)); seed_path(s,old)
  expect_error(qga.window(s,1L,3L,old[2,],FALSE,qga.local.graph.plan),class="qgs_budget")
  expect_identical(s$U,old); expect_length(c$log$events,1L)
})
test_that("both planners shorten a curved-surface detour with the shared kernel", {
  r <- req("paraboloid2_disk","ab")
  U <- rbind(c(-.5,0),c(0,.5),c(.5,0)); r$from <- U[1,]; r$to <- U[3,]
  forms <- lapply(r$geometry$forms,qg.matrix)
  for (planner in list(qga.vertex.plan,qga.local.graph.plan)) {
    c <- control_test(function(a,b,t) qgs.kernel(a,b,forms,r$length_scale,t,function(){},function(n){}))
    s <- qga.state(r,c,rng_test(0)); seed_path(s,U); original <- s$measure$length
    expect_true(qga.window(s,1L,3L,U[2,],FALSE,planner))
    expect_lt(s$measure$length,original)
    expect_true(all(apply(s$U,1,qg.inside,domain=r$domain)))
  }
})
test_that("local graph executes the shared finite schedule", {
  c <- control_test(); s <- qga.state(req(),c,rng_test(),"adaptive_local_graph")
  s$config$grid_intervals <- 2L; s$h0 <- s$bounds$width/2
  s$config$samples <- 1L; s$config$global_samples <- 1L
  result <- qga.solve(s,qga.local.graph.plan)
  expect_identical(result$termination,"schedule_exhausted")
  expect_equal(s$stage,2L); expect_lte(s$sweep,27L)
  expect_identical(result$diagnostics$protocol_compliance,"unqualified_pending_shared_runtime_and_independent_audit")
})
})
cat("adaptive_local_graph focused tests passed; not protocol qualification.\n")
