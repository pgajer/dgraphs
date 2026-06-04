.normalize.prune.method <- function(prune.method,
                                    supported = c("none", "local.geodesic",
                                                  "global.geodesic.ratio")) {
    if (length(prune.method) > 1L) {
        prune.method <- prune.method[[1L]]
    }
    if (!is.character(prune.method) || length(prune.method) != 1L ||
        is.na(prune.method) || !(prune.method %in% supported)) {
        stop(sprintf(
            "'arg' should be one of %s.",
            paste(sprintf("\"%s\"", supported), collapse = ", ")
        ), call. = FALSE)
    }
    prune.method
}

.normalize.local.prune.controls <- function(n,
                                            k,
                                            prune.tau,
                                            prune.local.k,
                                            with.pruned.edge.stats) {
    if (is.null(prune.tau)) {
        prune.tau <- 1.05
    }
    if (!is.numeric(prune.tau) || length(prune.tau) != 1L ||
        !is.finite(prune.tau) || prune.tau <= 1) {
        stop("'prune.tau' must be a finite numeric scalar greater than 1.", call. = FALSE)
    }
    if (is.null(prune.local.k)) {
        prune.local.k <- k
    }
    if (!is.numeric(prune.local.k) || length(prune.local.k) != 1L ||
        !is.finite(prune.local.k) || prune.local.k != floor(prune.local.k) ||
        prune.local.k < 1L || prune.local.k >= n) {
        stop("'prune.local.k' must be a positive integer smaller than nrow(X).",
             call. = FALSE)
    }
    if (!is.logical(with.pruned.edge.stats) || length(with.pruned.edge.stats) != 1L ||
        is.na(with.pruned.edge.stats)) {
        stop("'with.pruned.edge.stats' must be TRUE or FALSE.", call. = FALSE)
    }
    list(
        prune.tau = as.numeric(prune.tau),
        prune.local.k = as.integer(prune.local.k),
        with.pruned.edge.stats = isTRUE(with.pruned.edge.stats)
    )
}

.empty.pruned.edge.stats <- function() {
    data.frame(
        u = integer(),
        v = integer(),
        edge_length = numeric(),
        alt_path_length = numeric(),
        path_edge_ratio = numeric()
    )
}

.normalize.global.ratio.prune.controls <- function(max.path.edge.ratio.deviation.thld,
                                                   path.edge.ratio.percentile,
                                                   threshold.percentile = 0) {
    if (!is.numeric(max.path.edge.ratio.deviation.thld) ||
        length(max.path.edge.ratio.deviation.thld) != 1L ||
        !is.finite(max.path.edge.ratio.deviation.thld) ||
        max.path.edge.ratio.deviation.thld < 0 ||
        max.path.edge.ratio.deviation.thld >= 0.2) {
        stop("'max.path.edge.ratio.deviation.thld' must be in [0, 0.2).",
             call. = FALSE)
    }
    if (!is.numeric(path.edge.ratio.percentile) ||
        length(path.edge.ratio.percentile) != 1L ||
        !is.finite(path.edge.ratio.percentile) ||
        path.edge.ratio.percentile < 0 ||
        path.edge.ratio.percentile > 1) {
        stop("'path.edge.ratio.percentile' must be in [0, 1].", call. = FALSE)
    }
    if (!is.numeric(threshold.percentile) ||
        length(threshold.percentile) != 1L ||
        !is.finite(threshold.percentile) ||
        threshold.percentile < 0 ||
        threshold.percentile > 0.5) {
        stop("'threshold.percentile' must be in [0, 0.5].", call. = FALSE)
    }
    list(
        max.path.edge.ratio.deviation.thld = as.numeric(max.path.edge.ratio.deviation.thld),
        path.edge.ratio.percentile = as.numeric(path.edge.ratio.percentile),
        threshold.percentile = as.numeric(threshold.percentile)
    )
}

.exact.knn.index <- function(X, k) {
    n <- nrow(X)
    out <- matrix(NA_integer_, nrow = n, ncol = k)
    for (i in seq_len(n)) {
        d <- rowSums((t(t(X) - X[i, ]))^2)
        d[[i]] <- Inf
        out[i, ] <- order(d, seq_len(n))[seq_len(k)]
    }
    out
}

.local.dijkstra.distance <- function(adj.list,
                                     weight.list,
                                     local.vertices,
                                     source,
                                     target,
                                     excluded.u,
                                     excluded.v,
                                     cutoff) {
    n <- length(adj.list)
    in.local <- rep(FALSE, n)
    in.local[local.vertices] <- TRUE
    in.local[[source]] <- TRUE
    in.local[[target]] <- TRUE
    dist <- rep(Inf, n)
    visited <- rep(FALSE, n)
    dist[[source]] <- 0
    repeat {
        candidates <- which(in.local & !visited & is.finite(dist))
        if (!length(candidates)) {
            return(Inf)
        }
        u <- candidates[[which.min(dist[candidates])]]
        du <- dist[[u]]
        if (du > cutoff) {
            return(Inf)
        }
        if (u == target) {
            return(du)
        }
        visited[[u]] <- TRUE
        nbrs <- adj.list[[u]]
        weights <- weight.list[[u]]
        if (!length(nbrs)) {
            next
        }
        for (pos in seq_along(nbrs)) {
            v <- nbrs[[pos]]
            if (!in.local[[v]] || visited[[v]]) {
                next
            }
            if ((u == excluded.u && v == excluded.v) ||
                (u == excluded.v && v == excluded.u)) {
                next
            }
            nd <- du + weights[[pos]]
            if (nd < dist[[v]] && nd <= cutoff) {
                dist[[v]] <- nd
            }
        }
    }
}

.remove.undirected.edge <- function(adj.list, weight.list, u, v) {
    remove.one <- function(a, w, from, to) {
        pos <- which(a[[from]] == to)
        if (length(pos)) {
            keep <- seq_along(a[[from]])[-pos[[1]]]
            a[[from]] <- as.integer(a[[from]][keep])
            w[[from]] <- as.numeric(w[[from]][keep])
        }
        list(adj = a, weight = w)
    }
    first <- remove.one(adj.list, weight.list, u, v)
    second <- remove.one(first$adj, first$weight, v, u)
    list(adj_list = second$adj, weight_list = second$weight)
}

.prune.graph.local.geodesic <- function(X,
                                        adj.list,
                                        weight.list,
                                        k,
                                        prune.tau = 1.05,
                                        prune.local.k = NULL,
                                        with.pruned.edge.stats = FALSE) {
    if (!(is.matrix(X) || is.data.frame(X))) {
        stop("'X' must be a matrix or data frame.", call. = FALSE)
    }
    X <- as.matrix(X)
    if (!is.numeric(X)) {
        stop("'X' must contain numeric data.", call. = FALSE)
    }
    if (any(!is.finite(X))) {
        stop("'X' cannot contain NA, NaN, or Inf values.", call. = FALSE)
    }
    if (!is.double(X)) {
        storage.mode(X) <- "double"
    }
    n <- nrow(X)
    controls <- .normalize.local.prune.controls(
        n, k, prune.tau, prune.local.k, with.pruned.edge.stats
    )
    .Call(
        "S_prune_graph_local_geodesic",
        X,
        adj.list,
        weight.list,
        as.numeric(controls$prune.tau),
        as.integer(controls$prune.local.k),
        as.logical(controls$with.pruned.edge.stats),
        PACKAGE = "dgraphs"
    )
}

.edge.count.from.adj.list <- function(adj.list) {
    sum(lengths(adj.list)) / 2
}

.prune.graph.global.geodesic <- function(adj.list,
                                         weight.list,
                                         max.ratio.threshold,
                                         path.edge.ratio.percentile,
                                         with.pruned.edge.stats = FALSE) {
    edges <- .graph.edge.table(adj.list, weight.list)
    n.edges.before <- nrow(edges)
    if (!n.edges.before || max.ratio.threshold <= 1) {
        return(list(
            adj_list = adj.list,
            weight_list = weight.list,
            n_edges_before_pruning = n.edges.before,
            n_edges_after_pruning = n.edges.before,
            n_pruned_edges = 0L,
            pruned_edge_stats = .empty.pruned.edge.stats()
        ))
    }

    edges.asc <- edges[order(edges$weight, edges$from, edges$to), , drop = FALSE]
    if (path.edge.ratio.percentile <= 0) {
        threshold.weight <- edges.asc$weight[[1L]] - 1
    } else if (path.edge.ratio.percentile >= 1) {
        threshold.weight <- edges.asc$weight[[nrow(edges.asc)]] + 1
    } else {
        threshold.index <- min(
            nrow(edges.asc),
            as.integer(floor(nrow(edges.asc) * path.edge.ratio.percentile)) + 1L
        )
        threshold.weight <- edges.asc$weight[[threshold.index]]
    }

    candidates <- vector("list", nrow(edges.asc))
    cursor <- 0L
    for (r in seq_len(nrow(edges.asc))) {
        edge.length <- edges.asc$weight[[r]]
        if (edge.length < threshold.weight) {
            next
        }
        u <- edges.asc$from[[r]]
        v <- edges.asc$to[[r]]
        alt <- .local.dijkstra.distance(
            adj.list = adj.list,
            weight.list = weight.list,
            local.vertices = seq_along(adj.list),
            source = u,
            target = v,
            excluded.u = u,
            excluded.v = v,
            cutoff = Inf
        )
        if (is.finite(alt) && alt / edge.length <= max.ratio.threshold) {
            cursor <- cursor + 1L
            candidates[[cursor]] <- data.frame(
                u = u,
                v = v,
                edge_length = edge.length,
                alt_path_length = alt,
                path_edge_ratio = alt / edge.length
            )
        }
    }
    if (!cursor) {
        return(list(
            adj_list = adj.list,
            weight_list = weight.list,
            n_edges_before_pruning = n.edges.before,
            n_edges_after_pruning = n.edges.before,
            n_pruned_edges = 0L,
            pruned_edge_stats = .empty.pruned.edge.stats()
        ))
    }

    candidates <- do.call(rbind, candidates[seq_len(cursor)])
    candidates <- candidates[order(-candidates$edge_length, candidates$u, candidates$v),
                             , drop = FALSE]
    stats <- vector("list", nrow(candidates))
    stats.cursor <- 0L
    tol <- 1e-12
    for (r in seq_len(nrow(candidates))) {
        u <- candidates$u[[r]]
        v <- candidates$v[[r]]
        current <- .graph.edge.table(adj.list, weight.list)
        key <- current$from == u & current$to == v
        if (!any(key)) {
            next
        }
        edge.length <- current$weight[which(key)[[1L]]]
        alt <- .local.dijkstra.distance(
            adj.list = adj.list,
            weight.list = weight.list,
            local.vertices = seq_along(adj.list),
            source = u,
            target = v,
            excluded.u = u,
            excluded.v = v,
            cutoff = Inf
        )
        if (is.finite(alt) && alt / edge.length <= max.ratio.threshold + tol) {
            removed <- .remove.undirected.edge(adj.list, weight.list, u, v)
            adj.list <- removed$adj_list
            weight.list <- removed$weight_list
            if (isTRUE(with.pruned.edge.stats)) {
                stats.cursor <- stats.cursor + 1L
                stats[[stats.cursor]] <- data.frame(
                    u = u,
                    v = v,
                    edge_length = edge.length,
                    alt_path_length = alt,
                    path_edge_ratio = alt / edge.length
                )
            }
        }
    }

    stats.df <- if (isTRUE(with.pruned.edge.stats) && stats.cursor > 0L) {
        do.call(rbind, stats[seq_len(stats.cursor)])
    } else {
        .empty.pruned.edge.stats()
    }
    n.edges.after <- nrow(.graph.edge.table(adj.list, weight.list))
    list(
        adj_list = adj.list,
        weight_list = weight.list,
        n_edges_before_pruning = n.edges.before,
        n_edges_after_pruning = n.edges.after,
        n_pruned_edges = n.edges.before - n.edges.after,
        pruned_edge_stats = stats.df
    )
}

.prune.graph.global.geodesic.ratio <- function(adj.list,
                                               weight.list,
                                               max.ratio.threshold,
                                               path.edge.ratio.percentile,
                                               with.pruned.edge.stats = FALSE) {
    out <- .Call(
        "S_prune_graph_global_geodesic_ratio",
        adj.list,
        weight.list,
        as.numeric(max.ratio.threshold),
        as.numeric(path.edge.ratio.percentile),
        as.logical(with.pruned.edge.stats),
        PACKAGE = "dgraphs"
    )
    out$max_path_edge_ratio_threshold <- as.numeric(max.ratio.threshold)
    out$path_edge_ratio_percentile <- as.numeric(path.edge.ratio.percentile)
    out$with_pruned_edge_stats <- isTRUE(with.pruned.edge.stats)
    out
}

.prune.graph.long.edges <- function(adj.list, weight.list, threshold.percentile) {
    edges <- .graph.edge.table(adj.list, weight.list)
    if (!nrow(edges) || threshold.percentile <= 0) {
        return(list(adj_list = adj.list, weight_list = weight.list, n_pruned_edges = 0L))
    }

    edges <- edges[order(-edges$weight, edges$from, edges$to), , drop = FALSE]
    if (threshold.percentile >= 1) {
        threshold.weight <- edges$weight[[1L]] + 1
    } else {
        threshold.index <- min(
            nrow(edges),
            as.integer(floor(nrow(edges) * threshold.percentile)) + 1L
        )
        threshold.weight <- edges$weight[[threshold.index]]
    }

    n.pruned <- 0L
    for (r in seq_len(nrow(edges))) {
        if (edges$weight[[r]] < threshold.weight) {
            break
        }
        u <- edges$from[[r]]
        v <- edges$to[[r]]
        current <- .graph.edge.table(adj.list, weight.list)
        key <- current$from == u & current$to == v
        if (!any(key)) {
            next
        }
        removed <- .remove.undirected.edge(adj.list, weight.list, u, v)
        if (is.finite(.local.dijkstra.distance(
            adj.list = removed$adj_list,
            weight.list = removed$weight_list,
            local.vertices = seq_along(adj.list),
            source = u,
            target = v,
            excluded.u = -1L,
            excluded.v = -1L,
            cutoff = Inf
        ))) {
            adj.list <- removed$adj_list
            weight.list <- removed$weight_list
            n.pruned <- n.pruned + 1L
        }
    }
    list(adj_list = adj.list, weight_list = weight.list, n_pruned_edges = n.pruned)
}

.prune.graph.by.method <- function(X,
                                   adj.list,
                                   weight.list,
                                   k,
                                   prune.method,
                                   max.path.edge.ratio.deviation.thld = 0,
                                   path.edge.ratio.percentile = 0.5,
                                   threshold.percentile = 0,
                                   prune.tau = 1.05,
                                   prune.local.k = NULL,
                                   with.pruned.edge.stats = FALSE) {
    n.edges.before <- nrow(.graph.edge.table(adj.list, weight.list))
    if (identical(prune.method, "local.geodesic")) {
        out <- .prune.graph.local.geodesic(
            X = X,
            adj.list = adj.list,
            weight.list = weight.list,
            k = k,
            prune.tau = prune.tau,
            prune.local.k = prune.local.k,
            with.pruned.edge.stats = with.pruned.edge.stats
        )
    } else if (identical(prune.method, "global.geodesic.ratio")) {
        out <- .prune.graph.global.geodesic.ratio(
            adj.list = adj.list,
            weight.list = weight.list,
            max.ratio.threshold = 1 + max.path.edge.ratio.deviation.thld,
            path.edge.ratio.percentile = path.edge.ratio.percentile,
            with.pruned.edge.stats = with.pruned.edge.stats
        )
        out$prune_tau <- prune.tau
        out$prune_local_k <- if (is.null(prune.local.k)) k else as.integer(prune.local.k)
    } else if (identical(prune.method, "global.geodesic")) {
        out <- .prune.graph.global.geodesic(
            adj.list = adj.list,
            weight.list = weight.list,
            max.ratio.threshold = 1 + max.path.edge.ratio.deviation.thld,
            path.edge.ratio.percentile = path.edge.ratio.percentile,
            with.pruned.edge.stats = with.pruned.edge.stats
        )
    } else {
        out <- list(
            adj_list = adj.list,
            weight_list = weight.list,
            n_edges_before_pruning = n.edges.before,
            n_edges_after_pruning = n.edges.before,
            n_pruned_edges = 0L,
            pruned_edge_stats = .empty.pruned.edge.stats(),
            prune_tau = prune.tau,
            prune_local_k = if (is.null(prune.local.k)) k else as.integer(prune.local.k),
            with_pruned_edge_stats = isTRUE(with.pruned.edge.stats)
        )
    }

    n.after.geometric <- nrow(.graph.edge.table(out$adj_list, out$weight_list))
    quantile <- .prune.graph.long.edges(out$adj_list, out$weight_list, threshold.percentile)
    n.after <- nrow(.graph.edge.table(quantile$adj_list, quantile$weight_list))
    out$adj_list <- quantile$adj_list
    out$weight_list <- quantile$weight_list
    out$n_edges_before_pruning <- n.edges.before
    out$n_edges_after_pruning <- n.after
    out$n_pruned_edges <- n.edges.before - n.after
    out$n_quantile_pruned_edges <- n.after.geometric - n.after
    out
}
