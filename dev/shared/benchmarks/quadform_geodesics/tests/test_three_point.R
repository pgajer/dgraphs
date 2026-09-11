#!/usr/bin/env Rscript
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1]))
adaptive_home <- dirname(dirname(script))
source(file.path(adaptive_home, "interface.R"))
source(file.path(dirname(script), "adaptive_test_helpers.R"))
e <- new.env(parent = globalenv())
sys.source(file.path(adaptive_home, "solvers/adaptive/common.R"), e)
sys.source(file.path(adaptive_home, "solvers/adaptive/local_graph.R"), e)
sys.source(file.path(adaptive_home, "solvers/adaptive/three_point.R"), e)
test_rng <- function() {
  stream <- function(seed) function() { seed <<- (1664525 * seed + 1013904223) %% 2^32; seed / 2^32 }
  list(uniform = stream(3), order_uniform = stream(5), state = function() "TEST DOUBLE",
    versions = list(generator = "TEST DOUBLE"))
}
state <- function(r = req(), control = control_test(), rng = test_rng()) e$qga.state(r, control, rng)
geometry_control <- function(r) {
  A <- qg.matrix(r$geometry$forms[[1]])
  control_test(function(a, b, tighter) {
    d <- b - a
    if (all(d == 0)) return(list(length = 0, error_estimate = 0))
    z <- integrate(function(t) sqrt(sum(d*d) + (2 * as.vector(sweep(outer(t,d),2,a,"+") %*% A %*% d))^2),
      0, 1, rel.tol = 1e-12, abs.tol = 1e-14)
    list(length = z$value, error_estimate = z$abs.error)
  })
}
with_reporter(StopReporter$new(), {
test_that("new adapters leave the old configuration unchanged", {
  for (id in c("three_point_initializer", "three_point_vertex", "three_point_local_graph")) {
    adapter <- source(file.path(adaptive_home, "solvers", paste0(id, ".R")))$value
    expect_identical(adapter$id, id)
    expect_true(adapter$supports(req())$supported)
    expect_false(adapter$supports(req("flat3_box"))$supported)
    expect_error(adapter$prepare(req(), qgs.control(req())), "adaptive_runtime_unaligned")
  }
  expect_identical(qga.config()$protocol, "qg-refine-calibration-v2")
  expect_identical(e$qga.config()$protocol, "qg-three-point-center-v1")
})
test_that("flat initialization has 16 equal edges and exact endpoints", {
  s <- state(); e$qga.initialize(s)
  lengths <- vapply(s$segments, `[[`, 0, "length")
  expect_equal(nrow(s$U), 17L)
  expect_equal(lengths, rep(qga.norm(s$request$to - s$request$from)/16,16), tolerance = 1e-8)
  expect_identical(unname(s$U[1,]), s$request$from)
  expect_identical(unname(s$U[17,]), s$request$to)
  expect_identical(tail(s$control$log$events,1)[[1]]$phase, "initializer")
})
test_that("curved initialization uses surface rather than domain spacing and reverses exactly", {
  r <- req("paraboloid2_high_curvature", "ab")
  s <- state(r, geometry_control(r)); e$qga.initialize(s)
  lengths <- vapply(s$segments, `[[`, 0, "length")
  tolerance <- s$config$arc_abs*r$length_scale+s$config$arc_rel*s$measure$length/16
  expect_lt(max(lengths)-min(lengths), 4*tolerance)
  expect_gt(diff(range(sqrt(rowSums((s$U[-1,]-s$U[-17,])^2)))), 1e-3)
  rr <- r; rr$from <- r$to; rr$to <- r$from
  reverse <- state(rr,geometry_control(rr)); e$qga.initialize(reverse)
  expect_identical(unname(reverse$U), unname(s$U[17:1,]))
  expect_equal(s$measure$length, s$control$log$events[[1]]$candidate$length, tolerance = 1e-11)
  expect_true(all(apply(s$U,1,qg.inside,domain=r$domain)))
})
test_that("identity and near-coincident endpoints stay valid", {
  s <- state(req("flat2_box", "identity"), rng = NULL)
  expect_identical(e$qga.solve(s)$termination,"identity")
  expect_equal(s$measure$length,0)
  s <- state(req("flat2_box", "near")); e$qga.initialize(s)
  expect_true(s$measure$length>0); expect_equal(nrow(s$U),17)
})
test_that("unrepresentable vertices fail explicitly and preserve the direct fallback", {
  r <- req(); r$from <- c(.5,0); r$to <- c(.5+2^-53,0)
  s <- state(r)
  expect_error(e$qga.initialize(s), "unrepresentable")
  expect_identical(s$control$latest()$phase,"direct_fallback")
})
test_that("interrupted equal-length initialization never publishes a partial subdivision", {
  s <- state(control=control_test(budget=2))
  expect_error(e$qga.initialize(s),class="qgs_budget")
  expect_identical(s$control$latest()$phase,"direct_fallback")
  expect_equal(nrow(s$U),2)
})
test_that("failed numerical consistency checks cannot publish an initializer", {
  r <- req(); control <- control_test(function(a,b,t) list(length=qga.norm(b-a)+.01,error_estimate=0))
  s <- state(r,control)
  expect_error(e$qga.initialize(s), "initialization")
  expect_identical(s$control$latest()$phase,"direct_fallback")
})
test_that("center sampling supplies equal counts, clips to D and uses only the current radius", {
  r <- req("flat2_ball"); U <- rbind(c(.8,0),c(.95,0),c(.99,0))
  a <- state(r); b <- state(r)
  R <- e$qga.sample(a,U,U[2,],FALSE); Q <- e$qga.sample(b,U,U[2,],FALSE)
  expect_identical(R,Q); expect_equal(nrow(R),32)
  expect_true(all(apply(R,1,qg.inside,domain=r$domain)))
  expect_true(all(sqrt(rowSums(sweep(R,2,U[2,],"-")^2)) <= .15+1e-14))
  expect_equal(tail(a$diagnostics,1)[[1]]$accepted_draws,32)
  expect_error(e$qga.sample(a,U,U[2,],TRUE),"immediate-neighbor")
  expect_error(e$qga.sample(a,rbind(U,U[3,]),U[2,],FALSE),"immediate-neighbor")
})
test_that("sampling shortfalls and duplicate draws are explicit", {
  r <- req(); r$domain <- list(kind="box",lower=c(-.01,-.01),upper=c(.01,.01))
  s <- state(r,rng=rng_test(.9)); s$config$rejection_cap <- 2L
  expect_null(e$qga.sample(s,rbind(c(-1,0),c(0,0),c(1,0)),c(0,0),FALSE))
  expect_identical(tail(s$diagnostics,1)[[1]]$kind,"sample_shortfall")
  s <- state(rng=rng_test(0)); R <- e$qga.sample(s,rbind(c(-.5,0),c(0,0),c(.5,0)),c(0,0),FALSE)
  expect_equal(nrow(R),1); expect_equal(tail(s$diagnostics,1)[[1]]$accepted_draws,32)
})
test_that("shuffles are permutations and do not consume candidate draws", {
  a <- state(); b <- state()
  first <- e$qg3.shuffle(a,2:16); second <- e$qg3.shuffle(a,2:16)
  expect_identical(sort(first),2:16); expect_false(identical(first,2:16))
  expect_false(identical(first,second)); expect_identical(first,e$qg3.shuffle(b,2:16))
  expect_identical(a$rng$uniform(),b$rng$uniform())
  expect_identical(e$qg3.shuffle(a,integer()),integer())
})
test_that("shuffle rejection and invalid random draws fail explicitly", {
  s <- state(); n <- 0L
  s$rng$order_uniform <- function(){n<<-n+1L; if(n==1L)1-2^-32 else .1}
  expect_identical(sort(e$qg3.shuffle(s,1:3)),1:3); expect_equal(n,3)
  s$rng$order_uniform <- function() NA_real_
  expect_error(e$qg3.shuffle(s,1:3),"invalid uniform")
  s$config$rejection_cap <- 2L; s$rng$order_uniform <- function() 1-2^-32
  expect_error(e$qg3.shuffle(s,1:3),"rejection limit")
})
test_that("an epoch skips deleted anchors and defers inserted ones", {
  local <- new.env(parent=globalenv())
  sys.source(file.path(adaptive_home,"solvers/adaptive/common.R"),local)
  sys.source(file.path(adaptive_home,"solvers/adaptive/three_point.R"),local)
  s <- local$qga.state(req(),control_test(),test_rng()); seed_path(s,cbind(seq(-.8,.8,length.out=5),0))
  local$qg3.shuffle <- function(s,ids) ids
  visited <- integer()
  local$qga.window <- function(s,lo,hi,anchor,use_global,planner) {
    visited <<- c(visited,s$ids[lo+1L])
    if (length(visited)==1L) {
      s$U <- s$U[-3L,,drop=FALSE]; s$ids <- s$ids[-3L]
      s$U <- rbind(s$U[1:2,],c(0,.1),s$U[3:4,]); s$ids <- append(s$ids,6L,after=2L)
    }
    FALSE
  }
  local$qga.sweep(s)
  expect_identical(visited,c(2L,4L)); expect_identical(s$queue,2:4)
  expect_identical(s$queue_position,4L)
})
test_that("both planners shorten a bent flat window and keep a straight one", {
  for(planner in list(e$qga.vertex.plan,e$qga.local.graph.plan)) {
    s <- state(); U <- rbind(c(-.5,0),c(0,.5),c(.5,0)); seed_path(s,U)
    before <- s$measure$length
    expect_true(e$qga.window(s,1,3,U[2,],FALSE,planner))
    expect_lt(s$measure$length,before); expect_equal(s$U[c(1,nrow(s$U)),],U[c(1,3),])
    s <- state(); U <- rbind(c(-.5,0),c(0,0),c(.5,0)); seed_path(s,U)
    expect_false(e$qga.window(s,1,3,U[2,],FALSE,planner)); expect_identical(s$U,U)
  }
})
test_that("numerical uncertainty still prevents accepting a nominal improvement", {
  s <- state(control=control_test(function(a,b,t) list(length=qga.norm(b-a),error_estimate=10)))
  U <- rbind(c(-.5,0),c(0,.5),c(.5,0)); seed_path(s,U)
  expect_false(e$qga.window(s,1,3,U[2,],FALSE)); expect_identical(s$U,U)
  expect_true(any(vapply(s$control$log$edges,`[[`,TRUE,"tighter")))
})
test_that("publication interruption leaves the old local path unchanged", {
  s <- state(); U <- rbind(c(-.5,0),c(0,.5),c(.5,0)); seed_path(s,U)
  s$control$publish <- function(...) budget_failure()
  expect_error(e$qga.window(s,1,3,U[2,],FALSE),class="qgs_budget")
  expect_identical(s$U,U)
})
test_that("the bounded schedule keeps three-point windows and no forced subdivision", {
  s <- state(); s$config$candidate_draws <- 2L
  result <- e$qga.solve(s)
  expect_identical(result$termination,"schedule_exhausted"); expect_equal(s$sweep,2)
  expect_equal(nrow(s$U),17); expect_false(any(s$global_history))
  windows <- Filter(function(z)z$kind=="window",s$diagnostics)
  expect_true(all(vapply(windows,function(z)z$hi-z$lo==2L,logical(1))))
  values <- vapply(s$control$log$events,function(z)z$candidate$length,0)
  expect_true(all(diff(values)<=1e-10))
})
test_that("PCG64 streams reproduce independently without changing R random state", {
  if (!requireNamespace("reticulate",quietly=TRUE)) stop("PCG64 verification requires reticulate")
  set.seed(21); before <- .Random.seed
  a <- e$qga.pcg64("0123456789abcdef"); b <- e$qga.pcg64("0123456789abcdef")
  expect_identical(a$uniform(),b$uniform()); a$order_uniform(); a$order_uniform()
  expect_identical(a$uniform(),b$uniform()); expect_identical(.Random.seed,before)
  expect_false(identical(a$state()$seeds[[1]],a$state()$seeds[[2]]))
})
})
cat("Three-point focused verification passed.\n")
