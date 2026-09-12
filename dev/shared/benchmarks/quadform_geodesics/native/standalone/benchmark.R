script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]))
home <- dirname(dirname(dirname(script)))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Supply a new private output directory")
output <- path.expand(args[1L])
parent <- normalizePath(dirname(output),mustWork = TRUE)
repo <- normalizePath(file.path(home,"../../../.."))
if (startsWith(paste0(parent,"/"),paste0(repo,"/")) || file.exists(output))
  stop("Output must be new and outside the checkout")
dir.create(output)
source(file.path(home,"native/standalone/solver.R"))
source(file.path(home,"native/standalone/reference.R"))
source(file.path(home,"native/load.R"))
api <- qgn.load(home)
sources <- c(file.path(repo,"src",c("quadform_geodesics_solver.cpp","quadform_geodesics_solver.h",
    "quadform_geodesics_solver_rcpp.cpp","RcppExports.cpp","Makevars","Makevars.win")),
  file.path(repo,"R",c("quadform_geodesics_solver.R","RcppExports.R")),
  getLoadedDLLs()[["dgraphs"]][["path"]],system.file("R","dgraphs.rdb",package = "dgraphs"),
  file.path(home,"native/standalone",c("solver.R","reference.R","benchmark.R","tests.R")),
  file.path(home,"native",c("core.cpp","load.R")),file.path(home,"runtime.R"),
  file.path(home,"solvers/adaptive",c("common.R","local_graph.R","three_point.R","sensitivity.R")))
hashes <- function() vapply(sources,function(p) digest::digest(file = p,algo = "sha256"),"")
before <- hashes()
Sys.setenv(RETICULATE_PYTHON = "/intentionally-unavailable-python")
old_native <- qgc.load(home)
A <- diag(c(8,8)); from <- c(-.45,-.2); to <- c(.4,-.1)
domain <- list(kind = "ball",center = c(0,0),radius = 1)
scale <- 32.0624390837628; rows <- list()
for (method in c("single_point","local_network")) for (rule in c("neighbors","fixed_disk","fixed_span")) {
  for (repetition in 1:3) {
    # Both implementations consume the new C++ random stream. No Python startup,
    # compilation, reference loading or random-tape preparation is timed.
    r <- qgn.reference(home,api,A,from,to,domain,method,rule,seed = 50001,
      length_scale = scale,max_epochs = 8L,native_helpers = old_native)
    call <- function(cache) api$solve(A,from,to,domain,method = method,neighborhood = rule,
      seed = 50001,length_scale = scale,max_epochs = 8L,cache_edges = cache,random_orientation = FALSE)
    x <- call(0L); cached <- call(65536L)
    stopifnot(isTRUE(all.equal(x$path,r$path,tolerance = 1e-13)),
      isTRUE(all.equal(x$length,r$length,tolerance = 1e-13)),x$counters$edge_calls == r$edge_calls,
      x$counters$candidate_uniforms == r$candidate_uniforms,x$counters$order_uniforms == r$order_uniforms,
      isTRUE(all.equal(cached$path,x$path,tolerance = 1e-13)))
    # Repeated native calls avoid millisecond-resolution R timer rounding.
    n <- 20L
    elapsed <- system.time(for (i in seq_len(n)) call(0L))[["elapsed"]]/n
    cached_elapsed <- system.time(for (i in seq_len(n)) call(65536L))[["elapsed"]]/n
    rows[[length(rows)+1L]] <- data.frame(method = method,neighborhood = rule,repetition = repetition,
      r_integration_cpp_helpers_seconds = r$elapsed_seconds,cpp_seconds = elapsed,
      cpp_cache_seconds = cached_elapsed,length = x$length,
      edge_calls = x$counters$edge_calls,cached_edge_calls = cached$counters$edge_calls,
      completed_epochs = x$counters$completed_epochs,accepted = x$counters$accepted_replacements,
      agreement = TRUE)
    cat(method,rule,repetition,": R integration",r$elapsed_seconds,"s; C++",elapsed,"s\n")
    flush.console()
  }
}
table <- do.call(rbind,rows)
write.csv(table,file.path(output,"timings.csv"),row.names = FALSE)
capture.output(sessionInfo(),file = file.path(output,"session-info.txt"))
stopifnot(identical(before,hashes()))
write.csv(data.frame(file = sources,sha256 = before),file.path(output,"sources.csv"),row.names = FALSE)
cat("All matched-work timing comparisons passed. Output:",normalizePath(output),"\n")
