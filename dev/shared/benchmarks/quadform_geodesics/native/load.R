qgc.load <- function(home) {
  source <- file.path(home, "native/core.cpp")
  cache <- Sys.getenv("QGC_BUILD_CACHE")
  if (!nzchar(cache)) stop("Set QGC_BUILD_CACHE to a private build directory")
  dir.create(cache, recursive = TRUE, showWarnings = FALSE)
  old <- Sys.getenv("PKG_CXXFLAGS", unset = NA_character_)
  on.exit(if (is.na(old)) Sys.unsetenv("PKG_CXXFLAGS") else Sys.setenv(PKG_CXXFLAGS = old))
  Sys.setenv(PKG_CXXFLAGS = "-ffp-contract=off -fno-fast-math")
  native <- new.env(parent = globalenv())
  Rcpp::sourceCpp(source, env = native, cacheDir = cache, rebuild = FALSE, showOutput = FALSE)
  native
}
qgc.install <- function(e, native, runtime) {
  e$qga.key <- native$qgc_key
  e$qga.keys <- native$qgc_keys
  e$qga.sum <- native$qgc_sum
  e$qga.edge.key <- function(a, b) native$qgc_edge_key(a, b)$key
  e$qga.edge.list <- function(edges) {
    if (!length(edges)) return(list())
    order <- native$qgc_edge_order(edges)
    out <- lapply(seq_along(order$indices), function(i) {
      edge <- edges[[order$indices[i]]]
      if (order$reverse[i]) edge[2:1, , drop = FALSE] else edge
    })
    names(out) <- order$keys
    out
  }
  e$qga.dijkstra <- function(U, edges, batch, from, to, control) {
    indices <- native$qgc_dijkstra(U, edges, batch$records, from, to, control$poll)
    if (!length(indices)) NULL else U[indices, , drop = FALSE]
  }
  # Keep planner closures in the adapter's private environment.
  evalq(qga.local.graph.plan <- function(old, R) {
    U <- rbind(old, R); U <- U[!duplicated(qga.keys(U)), , drop = FALSE]
    U <- U[order(qga.keys(U), method = "radix"), , drop = FALSE]
    edges <- .native$qgc_complete_edges(U)
    from <- match(qga.key(old[1, ]), qga.keys(U))
    to <- match(qga.key(old[nrow(old), ]), qga.keys(U))
    list(edges = c(edges, qga.path.edges(old)), choose = function(batch, control) {
      path <- qga.dijkstra(U, edges, batch, from, to, control)
      incumbent <- qga.measure(old, batch)
      if (is.null(path)) return(list(vertices = old, measure = incumbent))
      candidate <- qga.measure(path, batch)
      if (candidate$length >= incumbent$length) list(vertices = old, measure = incumbent)
      else list(vertices = path, measure = candidate)
    })
  }, e)
  e$.native <- native
  runtime$qgs.vertex.key <- native$qgc_key
  runtime$qgs.edge.key <- native$qgc_edge_key
  runtime$qgs.kernel <- function(a, b, forms, scale, tighter, poll, count) {
    h <- b - a
    if (all(h == 0)) return(list(length = 0, error_estimate = 0))
    alpha <- vapply(forms, function(A) 2 * sum(a * (A %*% h)), numeric(1))
    beta <- vapply(forms, function(A) 2 * sum(h * (A %*% h)), numeric(1))
    factor <- if (tighter) .01 else 1
    value <- stats::integrate(function(t) {
      poll(); count(length(t)); native$qgc_speeds(t, h, alpha, beta)
    }, 0, 1, subdivisions = 1000L, rel.tol = 1e-10 * factor, abs.tol = 1e-12 * scale * factor)
    list(length = value$value, error_estimate = value$abs.error)
  }
  invisible(e)
}
qgc.adapter <- function(home, id) {
  e <- new.env(parent = environment(qgs.adapter))
  for (file in c("common.R", "local_graph.R", "three_point.R", "sensitivity.R"))
    sys.source(file.path(home, "solvers/adaptive", file), e)
  qgc.install(e, qgc.load(home), environment(qgs.control.v2))
  adapter <- e$qgx.adapter(id, if (id == "sensitivity_vertex") e$qga.vertex.plan else e$qga.local.graph.plan)
  prepare <- adapter$prepare
  adapter$prepare <- function(request, control) {
    s <- prepare(request, control)
    s$config$backend <- "cpp-core-v1"
    s
  }
  adapter
}
