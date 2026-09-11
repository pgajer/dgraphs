script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]))
home <- dirname(dirname(dirname(script)))
source(file.path(home, "native/standalone/solver.R"))
source(file.path(home, "native/standalone/reference.R"))
library(testthat)
Sys.setenv(RETICULATE_PYTHON = "/intentionally-unavailable-python", PYTHONDONTWRITEBYTECODE = "1")
api <- qgn.load(home)
disk <- list(kind = "ball", center = c(0,0), radius = 1)
box <- list(kind = "box", lower = c(-1,-1), upper = c(1,1))
from <- c(-.45,-.2); to <- c(.4,-.1); scale <- 32.0624390837628
solve <- function(...) api$solve(diag(c(8,8)),from,to,disk,length_scale = scale,...)
without_time <- function(x) { x$counters$elapsed_seconds <- NULL; x }
audit <- function(x,A,domain,expected_from = from,expected_to = to) {
  U <- x$path
  stopifnot(nrow(U) >= 2, all(is.finite(U)), all(is.finite(x$surface_path)))
  if (domain$kind == "ball") stopifnot(all(rowSums(sweep(U,2,domain$center)^2) <= domain$radius^2+1e-14))
  else stopifnot(all(sweep(U,2,domain$lower) >= 0), all(sweep(U,2,domain$upper) <= 0))
  # Independent R integral, with a different implementation of the tangent norm.
  total <- error <- 0
  for (i in seq_len(nrow(U)-1L)) {
    a <- U[i,]; h <- U[i+1L,]-a
    z <- integrate(function(t) sqrt(sum(h*h)+(2*sum(a*(A%*%h))+2*t*sum(h*(A%*%h)))^2),
      0,1,rel.tol = 1e-12,abs.tol = 1e-13,subdivisions = 1000L)
    total <- total+z$value; error <- error+z$abs.error
  }
  expect_lte(abs(total-x$length),error+x$error_estimate+1e-11)
  if (is.finite(x$initial_length)) expect_lte(total,x$initial_length+x$initial_error_estimate+error+1e-11)
  expect_equal(U[1,],expected_from,tolerance = 0); expect_equal(U[nrow(U),],expected_to,tolerance = 0)
  expect_equal(x$surface_path[,3],rowSums((U%*%A)*U),tolerance = 1e-14)
}
with_reporter(StopReporter$new(), {
test_that("normal execution needs no Python, modifies no R RNG and creates no files", {
  dir <- tempfile("qgn-no-files-"); dir.create(dir); old <- getwd()
  on.exit({setwd(old); unlink(dir,recursive = TRUE)},add = TRUE); setwd(dir)
  set.seed(331); rng <- .Random.seed
  x <- solve(max_epochs = 2L)
  expect_identical(.Random.seed,rng)
  expect_identical(list.files(dir,all.files = TRUE,no.. = TRUE),character())
  expect_false("reticulate" %in% loadedNamespaces())
  expect_identical(x$trace,list()); expect_false(x$state_saving)
  expect_identical(x$status,"candidate"); expect_lt(x$length,x$initial_length)
  expect_true(x$configuration$random_orientation)
  rm(".Random.seed",envir = .GlobalEnv)
  invisible(solve(max_epochs = 0L))
  expect_false(exists(".Random.seed",envir = .GlobalEnv,inherits = FALSE))
})
test_that("input validation fails explicitly", {
  expect_error(solve(seed = NA_real_),"seed")
  expect_error(solve(seed = .5),"seed")
  expect_error(solve(candidates = 0),"candidates")
  expect_error(solve(max_epochs = -1),"max_epochs")
  expect_error(solve(max_vertices = 16),"max_vertices")
  expect_error(solve(trace = NA),"trace")
  expect_error(solve(max_edge_calls = .5),"max_edge_calls")
  expect_error(solve(length_scale = NA_real_))
  expect_error(api$solve(diag(3),from,to,disk),"2 by 2")
  expect_error(api$solve(matrix(1:4,2),from,to,disk),"symmetric")
  expect_error(api$solve(diag(c(Inf,1)),from,to,disk),"finite")
  expect_error(api$solve(diag(2),c(2,0),to,disk),"inside")
  expect_error(api$solve(diag(2),from,to,list(kind = "other")),"kind")
  expect_error(api$solve(diag(2),from,to,list(kind = "box",lower = c(0,0),upper = c(0,1))),"bounds")
})
test_that("initialization is equal length and reversal symmetric", {
  x <- solve(max_epochs = 0L,random_orientation = FALSE)
  y <- api$solve(diag(c(8,8)),to,from,disk,length_scale = scale,max_epochs = 0L,random_orientation = FALSE)
  expect_identical(x$path,y$path[nrow(y$path):1L,])
  expect_equal(nrow(x$path),17L); expect_equal(x$initial_length,3.1533750092197,tolerance = 1e-12)
  lengths <- vapply(seq_len(16),function(i) {
    U <- x$path; a <- U[i,]; h <- U[i+1L,]-a
    integrate(function(t)sqrt(sum(h*h)+(16*sum(a*h)+16*t*sum(h*h))^2),0,1,
      rel.tol = 1e-12)$value
  },0)
  expect_lt(max(abs(lengths-mean(lengths))),2e-8)
  audit(x,diag(c(8,8)),disk)
})
test_that("flat and identity paths do not acquire artificial improvements", {
  x <- api$solve(matrix(0,2,2),from,to,box)
  expect_equal(x$length,sqrt(sum((to-from)^2)),tolerance = 1e-13)
  expect_equal(x$counters$accepted_replacements,0L)
  y <- api$solve(diag(2),from,from,disk)
  expect_identical(y$termination,"identity"); expect_equal(y$length,0)
  expect_equal(nrow(y$path),2L)
})
test_that("both methods and all neighborhoods return feasible audited paths", {
  for (method in c("single_point","local_network")) for (rule in c("neighbors","fixed_disk","fixed_span")) {
    x <- solve(method = method,neighborhood = rule,trace = TRUE,max_epochs = 3L)
    audit(x,diag(c(8,8)),disk)
    changes <- Filter(function(e)e$event == "replacement",x$trace)
    expect_true(length(changes) > 0L)
    expect_true(all(vapply(changes,function(e)e$decrease > e$required_decrease,TRUE)))
    expect_true(all(diff(vapply(x$trace,`[[`,0,"length")) <= 1e-12))
    expect_lte(nrow(x$path),257L)
  }
})
test_that("tracing is bounded, optional and does not alter calculation", {
  for (method in c("single_point","local_network")) {
    x <- solve(method = method,max_epochs = 2L)
    y <- solve(method = method,max_epochs = 2L,trace = TRUE,trace_limit = 3L)
    expect_identical(x$path,y$path); expect_identical(x$length,y$length)
    xc <- x$counters; yc <- y$counters; xc$elapsed_seconds <- yc$elapsed_seconds <- NULL
    expect_identical(xc,yc); expect_true(y$trace_truncated); expect_length(y$trace,3L)
    expect_gt(y$trace_events_omitted,0L)
  }
})
test_that("seeds reproduce runs and select varying orientations", {
  expect_identical(without_time(solve(seed = 43)),without_time(solve(seed = 43)))
  expect_false(identical(solve(seed = 43)$path,solve(seed = 44)$path))
  orientations <- vapply(1:20,function(seed) solve(seed = seed,max_epochs = 0L)$internal_orientation_reversed,TRUE)
  expect_setequal(unique(orientations),c(TRUE,FALSE))
  for (seed in 1:4) {
    x <- api$solve(diag(c(8,8)),to,from,disk,seed = seed,max_epochs = 1L)
    expect_identical(unname(x$path[1,]),to); expect_identical(unname(x$path[nrow(x$path),]),from)
  }
})
test_that("budgets preserve only completed paths and cache size is bounded", {
  x <- solve(max_edge_calls = 0); expect_identical(x$status,"no_path"); expect_true(is.na(x$length))
  expect_identical(x$termination,"edge_limit"); expect_equal(nrow(x$path),0L)
  x <- solve(max_edge_calls = 1); expect_identical(x$status,"direct_fallback"); expect_equal(nrow(x$path),2L)
  audit(x,diag(c(8,8)),disk)
  x <- solve(max_edge_calls = 1000,max_epochs = 100L,plateau_epochs = 101L)
  expect_identical(x$termination,"edge_limit"); expect_equal(x$counters$edge_calls,1000)
  audit(x,diag(c(8,8)),disk)
  x <- solve(max_seconds = 0); expect_identical(x$termination,"time_limit"); expect_identical(x$status,"no_path")
  x <- solve(cache_edges = 7L,max_epochs = 1L)
  expect_lte(x$counters$cache_entries,7L); expect_gt(x$counters$cache_evictions,0)
  audit(x,diag(c(8,8)),disk)
  x <- solve(cache_edges = 0L,max_epochs = 1L)
  expect_equal(x$counters$cache_entries,0L); expect_equal(x$counters$cache_hits,0)
})
test_that("moderate matched-stream searches retain their reference paths", {
  for (A in list(diag(c(8,8)),diag(c(2,-1)),matrix(c(2,.5,.5,1),2)))
    for (method in c("single_point","local_network")) for (rule in c("neighbors","fixed_disk","fixed_span")) {
      x <- api$solve(A,from,to,disk,method = method,neighborhood = rule,seed = 7,
        length_scale = scale,max_epochs = 2L,candidates = 8L,cache_edges = 0L,
        random_orientation = FALSE,trace = TRUE)
      r <- qgn.reference(home,api,A,from,to,disk,method,rule,seed = 7,length_scale = scale,
        max_epochs = 2L,candidates = 8L)
      expect_equal(x$initial_path,r$initial_path,tolerance = 0)
      expect_equal(x$path,r$path,tolerance = 1e-13)
      expect_equal(x$length,r$length,tolerance = 1e-13)
      # Analytic roundoff and quadrature error estimates are different quantities.
      expect_lte(abs(x$length-r$length),x$error_estimate+r$error_estimate+
        64*.Machine$double.eps*max(1,x$length))
      expect_equal(x$counters$candidate_uniforms,r$candidate_uniforms)
      expect_equal(x$counters$order_uniforms,r$order_uniforms)
      expect_equal(x$counters$accepted_replacements,r$accepted)
      expect_equal(x$counters$edge_calls,r$edge_calls)
      xp <- Filter(function(e)e$event == "replacement",x$trace)
      rp <- Filter(function(e)e$phase == "refinement",r$published)
      expect_equal(length(xp),length(rp))
      for (i in seq_along(xp)) expect_equal(xp[[i]]$path,rp[[i]]$candidate$path$vertices,tolerance = 1e-13)
      audit(x,A,disk)
    }
})
test_that("cache eviction and reuse preserve the solution", {
  for (method in c("single_point","local_network")) {
    reference <- solve(method = method,max_epochs = 3L,cache_edges = 0L)
    for (capacity in c(7L,65536L)) {
      x <- solve(method = method,max_epochs = 3L,cache_edges = capacity)
      expect_identical(x$path,reference$path)
      expect_equal(x$length,reference$length,tolerance = 1e-13)
      expect_equal(x$counters$accepted_replacements,reference$counters$accepted_replacements)
      expect_equal(x$counters$candidate_uniforms,reference$counters$candidate_uniforms)
    }
  }
})
test_that("numerical overflow is reported without inventing a path", {
  x <- api$solve(diag(c(1.7e308,1.7e308)),c(-.9,0),c(.9,0),disk)
  expect_identical(x$termination,"initialization_numerical_failure")
  expect_identical(x$status,"no_path"); expect_true(is.na(x$length))
})
test_that("clipping, incomplete sampling and vertex limits are handled", {
  a <- c(-.9,.99); b <- c(.9,.99)
  for (method in c("single_point","local_network")) {
    call <- function(cap) api$solve(diag(c(8,8)),a,b,box,method = method,max_epochs = 1L,
      seed = 13,random_orientation = FALSE,rejection_cap = cap)
    x <- call(1000L)
    expect_gt(x$counters$sampling_attempts,32*x$counters$visited_points)
    expect_equal(x$counters$sampling_shortfalls,0)
    audit(x,diag(c(8,8)),box,a,b)
    x <- call(1L)
    expect_gt(x$counters$sampling_shortfalls,0)
    expect_identical(x$path,x$initial_path)
    audit(x,diag(c(8,8)),box,a,b)
  }
  x <- solve(method = "local_network",initial_edges = 2L,max_vertices = 3L,
    max_epochs = 4L,seed = 13,random_orientation = FALSE)
  expect_gt(x$counters$vertex_limit_rejections,0)
  expect_lte(nrow(x$path),3L)
  audit(x,diag(c(8,8)),disk)
})
})
cat("Self-contained solver tests passed; Python was unavailable throughout.\n")
