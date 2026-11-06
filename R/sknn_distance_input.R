# Distance input is validated once before a scalar construction or series.
.validate.sknn.distances <- function(X) {
    if (inherits(X, "dist")) X <- as.matrix(X)
    if (!is.matrix(X) || !is.numeric(X) || nrow(X) != ncol(X) || nrow(X) < 2L)
        stop("Distance input must be a square numeric matrix or dist object of order >= 2.", call. = FALSE)
    if (any(!is.finite(X)) || any(X < 0))
        stop("Distances must be finite and nonnegative.", call. = FALSE)
    rn <- rownames(X); cn <- colnames(X)
    if ((!is.null(rn) || !is.null(cn)) &&
        (!identical(rn, cn) || anyNA(rn) || any(!nzchar(rn)) || anyDuplicated(rn)))
        stop("Distance row and column names must be identical, nonmissing and unique.", call. = FALSE)
    tol <- 1e-12 * max(1, max(X))
    if (max(abs(diag(X))) > tol || max(abs(X - t(X))) > tol)
        stop("Distance input must be symmetric with zero diagonal (relative tolerance 1e-12).", call. = FALSE)
    X <- X / 2 + t(X) / 2
    diag(X) <- 0
    storage.mode(X) <- "double"
    X
}

.sknn.distance.rankings <- function(D, k) {
    n <- nrow(D)
    out <- matrix(NA_integer_, n, k)
    for (i in seq_len(n)) {
        candidates <- seq_len(n)[-i]
        out[i, ] <- candidates[order(D[i, candidates], candidates)[seq_len(k)]]
    }
    out
}

# Shared distance-only worker: D and any cached rankings are private, validated inputs.
.create.sknn.distance.graph <- function(D, k, cached.index = NULL,
        prune.edges = FALSE, prune.method = c("none", "local.geodesic", "global.geodesic.ratio"),
        with.pruned.edge.stats = FALSE, connect.components = FALSE,
        connect.method = c("component.mst", "component.mst.ann", "global.mst"),
        edge.weight = "distance", neighbor.method = c("exact", "ann"), ann.eps = 0,
        knn.index = NULL, graph.detail = c("full", "minimal"),
        bridge.k = NULL, bridge.k.max = NULL, bridge.growth = 2,
        prune.tau = 1.05, prune.local.k = NULL,
        max.path.edge.ratio.deviation.thld = 0.1, path.edge.ratio.percentile = 0.5) {
    n <- nrow(D)
    k <- .validate.k.values(k, n)
    if (length(k) != 1L) stop("k must be a scalar.", call. = FALSE)
    connect.method <- match.arg(connect.method)
    neighbor.method <- match.arg(neighbor.method)
    graph.detail <- match.arg(graph.detail)
    prune.method <- .normalize.prune.method(prune.method)
    edge.weight <- match.arg(edge.weight, "distance")
    for (value in list(connect.components, prune.edges, with.pruned.edge.stats))
        if (!is.logical(value) || length(value) != 1L || is.na(value))
            stop("Logical controls must be TRUE or FALSE.", call. = FALSE)
    if (prune.edges || prune.method != "none" || with.pruned.edge.stats ||
        !is.null(prune.local.k) || !identical(prune.tau, 1.05) ||
        !identical(max.path.edge.ratio.deviation.thld, 0.1) ||
        !identical(path.edge.ratio.percentile, 0.5))
        stop("Pruning is not supported for distance input.", call. = FALSE)
    if (neighbor.method != "exact" || connect.method == "component.mst.ann" ||
        !is.null(bridge.k) || !is.null(bridge.k.max) || !identical(bridge.growth, 2) ||
        !is.numeric(ann.eps) || length(ann.eps) != 1L || !is.finite(ann.eps) || ann.eps != 0)
        stop("Distance input requires exact search and cannot use ANN controls or repair.", call. = FALSE)
    if (!is.null(knn.index))
        stop("For distance input knn.index is computed internally.", call. = FALSE)
    if (graph.detail == "minimal" && connect.components)
        stop("graph.detail = 'minimal' requires connect.components = FALSE.", call. = FALSE)
    if (is.null(cached.index)) cached.index <- .sknn.distance.rankings(D, k)
    nn <- cached.index[, seq_len(k), drop = FALSE]
    storage.mode(nn) <- "integer"
    method <- if (connect.method == "component.mst") 0L else 1L
    native <- function(repair) .Call("S_create_sknn_graph", D, k, repair, method,
        2L, 0, nn, matrix(integer(), 0L, 0L), 1L, n - 1L, 2,
        FALSE, 0L, 1.05, k, FALSE, PACKAGE = "dgraphs")
    raw <- native(FALSE)
    repaired <- if (graph.detail == "full") native(TRUE) else raw
    result <- if (connect.components) repaired else raw
    result$raw_adj_list <- raw$adj_list
    result$raw_weight_list <- raw$weight_list
    result$pruned_adj_list <- raw$adj_list
    result$pruned_weight_list <- raw$weight_list
    if (graph.detail == "full") {
        for (prefix in c("raw_repaired_", "pruned_repaired_", "repaired_pruned_")) {
            result[[paste0(prefix, "adj_list")]] <- repaired$adj_list
            result[[paste0(prefix, "weight_list")]] <- repaired$weight_list
        }
        result$n_edges_in_raw_graph <- raw$n_edges
        result$n_edges_in_raw_repaired_graph <- repaired$n_edges
        result$n_edges_in_pruned_repaired_graph <- repaired$n_edges
        result$n_edges_in_repaired_pruned_graph <- repaired$n_edges
        result$n_components_raw <- raw$n_components_before
        result$n_components_pruned <- raw$n_components_before
        result$n_components_raw_repaired <- repaired$n_components_after
        result$n_components_pruned_repaired <- repaired$n_components_after
        result$n_components_repaired_pruned <- repaired$n_components_after
        for (prefix in c("raw_repaired_", "pruned_repaired_")) {
            result[[paste0(prefix, "mst_edge_matrix")]] <- repaired$mst_edge_matrix
            result[[paste0(prefix, "mst_edge_weight")]] <- repaired$mst_edge_weight
        }
    }
    result$edge.weight <- edge.weight
    result$prune_method <- "none"
    result$graph_detail <- graph.detail
    result$lifecycle_branches <- graph.detail == "full"
    result$input_type <- "distances"
    result$vertex_names <- rownames(D)
    result$distance_ties <- "distance.then.vertex.index"
    class(result) <- c("sknn_graph", "list")
    .dgraph.from.native(result)
}
