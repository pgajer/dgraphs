script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1L]))
home <- dirname(dirname(dirname(script)))
source(file.path(home,"native/standalone/solver.R"))
Sys.setenv(RETICULATE_PYTHON = "/intentionally-unavailable-python")
api <- qgn.load(home)
for (rule in c("neighbors","fixed_disk","fixed_span")) {
  x <- api$solve(diag(c(8,8)),c(-.45,-.2),c(.4,-.1),
    list(kind = "ball",center = c(0,0),radius = 1),method = "local_network",neighborhood = rule,
    seed = 50001,length_scale = 32.0624390837628,max_epochs = 10000L,plateau_epochs = 10001L,
    max_edge_calls = 200000,trace = FALSE)
  stopifnot(x$status == "candidate",x$termination == "edge_limit",x$counters$edge_calls == 200000,
    x$counters$cache_entries <= 65536L,length(x$trace) == 0L,x$length <= x$initial_length)
  U <- x$path
  stopifnot(all(rowSums(U^2) <= 1),identical(unname(U[1,]),c(-.45,-.2)),
    identical(unname(U[nrow(U),]),c(.4,-.1)))
  length <- sum(vapply(seq_len(nrow(U)-1L),function(i) {
    a <- U[i,]; h <- U[i+1L,]-a
    integrate(function(t) sqrt(sum(h*h)+(16*sum(a*h)+16*t*sum(h*h))^2),0,1,
      rel.tol = 1e-12,abs.tol = 1e-13,subdivisions = 1000L)$value
  },0))
  stopifnot(abs(length-x$length) <= x$error_estimate+1e-10)
  cat(rule,":",x$counters$edge_calls,"edge integrations;",x$counters$cache_entries,
    "cached edges;",x$counters$cache_evictions,"evictions;",nrow(x$path),"path points;",
    x$counters$elapsed_seconds,"seconds; audited length",length,"\n")
}
stopifnot(!"reticulate" %in% loadedNamespaces())
cat("Memory smoke checks passed. Peak process memory is reported by /usr/bin/time -l.\n")
