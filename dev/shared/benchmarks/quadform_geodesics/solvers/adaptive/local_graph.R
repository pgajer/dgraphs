# Complete-window search variant; all scheduling and control accounting is shared
# with adaptive_vertex. No new cache, numerical kernel, auditor, or runner.
qga.local.graph.plan <- function(old, R) {
  U <- rbind(old, R); U <- U[!duplicated(qga.keys(U)), , drop = FALSE]
  U <- U[order(qga.keys(U), method = "radix"), , drop = FALSE]
  edges <- list()
  if (nrow(U) > 1L) for (i in seq_len(nrow(U) - 1L)) for (j in seq.int(i + 1L, nrow(U))) {
    if (!all(U[i, ] == U[j, ])) edges[[length(edges) + 1L]] <- U[c(i, j), , drop = FALSE]
  }
  # Keep every old-route record, including any zero-length robustness input.
  needed <- c(edges, qga.path.edges(old))
  from <- match(qga.key(old[1, ]), qga.keys(U))
  to <- match(qga.key(old[nrow(old), ]), qga.keys(U))
  list(edges = needed, choose = function(batch, control) {
    path <- qga.dijkstra(U, edges, batch, from, to, control)
    incumbent <- qga.measure(old, batch)
    if (is.null(path)) return(list(vertices = old, measure = incumbent))
    candidate <- qga.measure(path, batch)
    # Incumbent takes precedence over all other equal-cost path-key ties.
    if (candidate$length >= incumbent$length) list(vertices = old, measure = incumbent)
    else list(vertices = path, measure = candidate)
  })
}
