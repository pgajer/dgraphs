.dgraphs.remove.edge <- function(graph, weights, i, j) {
    idx <- which(graph[[i]] == j)
    if (length(idx)) {
        graph[[i]] <- graph[[i]][-idx[[1L]]]
        weights[[i]] <- weights[[i]][-idx[[1L]]]
    }
    idx <- which(graph[[j]] == i)
    if (length(idx)) {
        graph[[j]] <- graph[[j]][-idx[[1L]]]
        weights[[j]] <- weights[[j]][-idx[[1L]]]
    }
    list(graph = graph, weights = weights)
}

.dgraphs.edge.max.on.path <- function(graph, weights, path) {
    if (length(path) < 2L) return(numeric(0))
    vals <- numeric(length(path) - 1L)
    for (k in seq_len(length(path) - 1L)) {
        idx <- which(graph[[path[[k]]]] == path[[k + 1L]])
        vals[[k]] <- weights[[path[[k]]]][[idx[[1L]]]]
    }
    vals
}

.dgraphs.shortest.path.sequence <- function(graph, weights, i, j, banned.edge = NULL) {
    n <- length(graph)
    dist <- rep(Inf, n)
    parent <- rep(NA_integer_, n)
    visited <- rep(FALSE, n)
    dist[[i]] <- 0
    repeat {
        available <- which(!visited)
        if (length(available) == 0L) break
        v <- available[which.min(dist[available])]
        if (!is.finite(dist[[v]]) || v == j) break
        visited[[v]] <- TRUE
        for (k in seq_along(graph[[v]])) {
            u <- graph[[v]][[k]]
            if (!is.null(banned.edge) &&
                ((v == banned.edge[[1L]] && u == banned.edge[[2L]]) ||
                 (v == banned.edge[[2L]] && u == banned.edge[[1L]]))) {
                next
            }
            proposed <- dist[[v]] + weights[[v]][[k]]
            if (proposed < dist[[u]]) {
                dist[[u]] <- proposed
                parent[[u]] <- v
            }
        }
    }
    if (!is.finite(dist[[j]])) {
        return(list(distance = Inf, path = integer(0)))
    }
    list(distance = dist[[j]], path = .dgraphs.reconstruct.path(parent, i, j))
}

#' Prune Long Edges in a Weighted Graph
#'
#' @param graph A graph adjacency list.
#' @param edge.lengths Edge-length list matching `graph`.
#' @param alt.path.len.ratio.thld Alternative-path threshold.
#' @param use.total.length.constraint If `TRUE`, compare total alternative path
#'   length with the original edge. Otherwise require every edge on the
#'   alternative path to be shorter than the original edge times the threshold.
#' @param verbose Logical progress flag.
#'
#' @return A list with pruned adjacency and edge-length lists.
#'
#' @export
wgraph.prune.long.edges <- function(graph,
                                    edge.lengths,
                                    alt.path.len.ratio.thld,
                                    use.total.length.constraint = TRUE,
                                    verbose = FALSE) {
    graph <- .dgraphs.validate.adj.list(graph)
    edge.lengths <- .dgraphs.validate.weight.list(graph, edge.lengths)
    if (!is.numeric(alt.path.len.ratio.thld) ||
        length(alt.path.len.ratio.thld) != 1L ||
        !is.finite(alt.path.len.ratio.thld) ||
        alt.path.len.ratio.thld < 0) {
        stop("'alt.path.len.ratio.thld' must be a non-negative scalar.",
             call. = FALSE)
    }

    edges <- data.frame(i = integer(0), j = integer(0), length = numeric(0))
    for (i in seq_along(graph)) {
        for (k in seq_along(graph[[i]])) {
            j <- graph[[i]][[k]]
            if (i < j) {
                edges <- rbind(edges, data.frame(
                    i = i,
                    j = j,
                    length = edge.lengths[[i]][[k]]
                ))
            }
        }
    }
    if (nrow(edges) > 0L) {
        edges <- edges[order(edges$length, decreasing = TRUE), , drop = FALSE]
    }

    path.lengths <- numeric(0)
    edge.length.record <- numeric(0)
    for (row in seq_len(nrow(edges))) {
        i <- edges$i[[row]]
        j <- edges$j[[row]]
        original <- edges$length[[row]]
        if (!(j %in% graph[[i]])) next
        alt <- .dgraphs.shortest.path.sequence(
            graph,
            edge.lengths,
            i,
            j,
            banned.edge = c(i, j)
        )
        if (!is.finite(alt$distance)) next
        prune <- if (isTRUE(use.total.length.constraint)) {
            alt$distance < alt.path.len.ratio.thld * original
        } else {
            all(.dgraphs.edge.max.on.path(graph, edge.lengths, alt$path) <
                    alt.path.len.ratio.thld * original)
        }
        if (isTRUE(prune)) {
            if (isTRUE(verbose)) {
                message("Pruning edge ", i, "-", j)
            }
            updated <- .dgraphs.remove.edge(graph, edge.lengths, i, j)
            graph <- updated$graph
            edge.lengths <- updated$weights
            path.lengths <- c(path.lengths, alt$distance)
            edge.length.record <- c(edge.length.record, original)
        }
    }
    list(
        adj_list = graph,
        edge_lengths_list = edge.lengths,
        path_lengths = path.lengths,
        edge_lengths = edge.length.record
    )
}
