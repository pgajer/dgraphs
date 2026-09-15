
.path.cumulative.distances <- function(X) {
    n <- nrow(X)
    if (n == 1L) return(0)
    lengths <- vapply(seq_len(n - 1L), function(i) {
        delta <- X[i + 1L, ] - X[i, ]
        scale <- max(abs(delta))
        if (!is.finite(scale)) return(Inf)
        if (scale == 0) return(0)
        # Scaling avoids overflow/underflow when squaring finite differences.
        scale * sqrt(sum((delta / scale)^2))
    }, numeric(1))
    distances <- c(0, cumsum(lengths))
    if (any(!is.finite(distances)))
        stop("The total path length exceeds the finite numeric range.", call. = FALSE)
    distances
}

#' Normalized Cumulative Distance Along a Vertex Path
#'
#' @param s Nonempty numeric vector of integer vertex indices in `1:nrow(V)`.
#'   Repeated indices are allowed and the supplied order defines the path.
#' @param V Finite numeric vertex coordinate matrix with at least one row and
#'   one column.
#'
#' @return Numeric vector of length `length(s)`. For a positive-length path,
#'   cumulative Euclidean distances start at zero and end at one. A singleton
#'   or zero-length path returns all zeros. Empty paths and total lengths
#'   exceeding the finite numeric range are rejected.
#' @seealso [path.length()], [subdivide.path()]
#'
#' @examples
#' vertices <- rbind(c(0, 0), c(1, 0), c(1, 2))
#' path.dist(1:3, vertices)
#' path.dist(2, vertices) # a singleton has normalized distance zero
#'
#' @export
path.dist <- function(s, V) {
    V <- .path.coordinates(V, "V")
    if (!is.numeric(s) || is.complex(s) || !is.null(dim(s)) || length(s) == 0L ||
        any(!is.finite(s)) || any(s != floor(s)) ||
        any(s < 1 | s > nrow(V))) {
        stop("s must be a nonempty vector of integer vertex indices in 1:nrow(V).",
             call. = FALSE)
    }
    distances <- .path.cumulative.distances(V[s, , drop = FALSE])
    total <- distances[length(distances)]
    if (total == 0) distances else distances / total
}

#' Compute Euclidean Path Length
#'
#' @param X Finite numeric matrix whose rows are consecutive path points,
#'   with at least one row and one column.
#'
#' @return Total Euclidean length of the polyline. Singleton paths and paths
#'   whose points all coincide have length zero. Empty paths and total lengths
#'   exceeding the finite numeric range are rejected.
#' @seealso [path.dist()], [subdivide.path()]
#'
#' @examples
#' path.length(rbind(c(0, 0), c(1, 0), c(1, 2)))
#' path.length(matrix(c(1, 2), nrow = 1)) # zero
#'
#' @export
path.length <- function(X) {
    X <- .path.coordinates(X, "X")
    distances <- .path.cumulative.distances(X)
    distances[length(distances)]
}

.point.euclidean.distance <- function(p1, p2) {
    sqrt(sum((p1 - p2)^2))
}

#' Subdivide a Path into Arc-Length Spaced Points
#'
#' @param path Finite numeric matrix of consecutive path points, with at least
#'   one row and one column. Repeated consecutive points are allowed.
#' @param n.subdivision.pts Integer number of output points, at least two.
#'
#' @return Numeric matrix with `n.subdivision.pts` rows and `ncol(path)` columns,
#'   preserving coordinate column names. The first and last rows are the path
#'   endpoints. A singleton or zero-length path repeats its location in every
#'   output row. Empty paths are rejected.
#'
#' @details
#' Points are interpolated at equally spaced cumulative Euclidean distances
#' along the input polyline. Zero-length segments are skipped. Equal spacing
#' along the polyline does not imply equal straight-line distances between
#' output points that straddle a corner, and an interior vertex need not appear
#' in the output. Distances are evaluated in floating-point arithmetic; paths
#' whose total length exceeds the finite numeric range are rejected.
#' @seealso [path.length()], [path.dist()]
#'
#' @examples
#' path <- rbind(c(0, 0), c(1, 0), c(1, 2))
#' subdivide.path(path, n.subdivision.pts = 5)
#' # Arc distances 0, 0.75, 1.5, 2.25, 3 give:
#' # (0, 0), (0.75, 0), (1, 0.5), (1, 1.25), (1, 2).
#' subdivide.path(matrix(c(1, 2), nrow = 1), n.subdivision.pts = 3)
#'
#' @export
subdivide.path <- function(path, n.subdivision.pts) {
    path <- .path.coordinates(path, "path")
    if (!is.numeric(n.subdivision.pts) || is.complex(n.subdivision.pts) ||
        !is.null(dim(n.subdivision.pts)) || length(n.subdivision.pts) != 1L ||
        !is.finite(n.subdivision.pts) || n.subdivision.pts < 2 ||
        n.subdivision.pts != floor(n.subdivision.pts) ||
        n.subdivision.pts > .Machine$integer.max) {
        stop("n.subdivision.pts must be an integer between 2 and .Machine$integer.max.",
             call. = FALSE)
    }
    distances <- .path.cumulative.distances(path)
    total <- distances[length(distances)]
    if (total == 0) {
        out <- path[rep.int(1L, n.subdivision.pts), , drop = FALSE]
    } else {
        # Strictly increasing knots avoid division by zero at repeated points.
        keep <- c(TRUE, diff(distances) > 0)
        knots <- distances[keep]
        points <- path[keep, , drop = FALSE]
        targets <- seq(0, 1, length.out = n.subdivision.pts) * total
        segment <- pmin(findInterval(targets, knots), length(knots) - 1L)
        fraction <- (targets - knots[segment]) /
            (knots[segment + 1L] - knots[segment])
        out <- (1 - fraction) * points[segment, , drop = FALSE] +
            fraction * points[segment + 1L, , drop = FALSE]
        out[1L, ] <- path[1L, ]
        out[n.subdivision.pts, ] <- path[nrow(path), ]
    }
    rownames(out) <- NULL
    out
}

#' Compare Paths Across Hop Limits
#'
#' @param path.result A `path.graph.series` object.
#' @param from Source vertex index.
#' @param to Target vertex index.
#'
#' @return Data frame describing path availability and length by hop limit.
#'
#' @examples
#' graph <- list(2L, c(1L, 3L), 2L)
#' lengths <- list(1, c(1, 2), 2)
#' series <- create.path.graph(dgraph(graph, lengths), h.values = 1:2)
#' compare.paths(series, from = 1, to = 3)
#'
#' @export compare.paths
#' @usage compare.paths(path.result, from, to)
compare.paths <- function(path.result, from, to) {
    if (!inherits(path.result, "path.graph.series")) {
        stop("'path.result' must be a path.graph.series object.", call. = FALSE)
    }

    h.values <- sapply(path.result, attr, "h")
    results <- data.frame(
        h = h.values,
        path_exists = logical(length(path.result)),
        path_length = numeric(length(path.result)),
        n_hops = integer(length(path.result)),
        stringsAsFactors = FALSE
    )
    results$path <- vector("list", length(path.result))

    for (i in seq_along(path.result)) {
        path.info <- get.shortest.path(path.result[[i]], from, to)
        results$path_exists[i] <- !is.null(path.info)

        if (!is.null(path.info)) {
            results$path_length[i] <- path.info$length
            results$n_hops[i] <- path.info$hops
            results$path[[i]] <- path.info$path
        } else {
            results$path_length[i] <- NA_real_
            results$n_hops[i] <- NA_integer_
        }
    }

    results
}

#' Find the Minimum Hop Limit for Path Existence
#'
#' @param path.result A `path.graph.series` object.
#' @param from Source vertex index.
#' @param to Target vertex index.
#'
#' @return Minimum hop limit where the path exists, or `NULL`.
#'
#' @examples
#' graph <- list(2L, c(1L, 3L), 2L)
#' lengths <- list(1, c(1, 2), 2)
#' series <- create.path.graph(dgraph(graph, lengths), h.values = 1:2)
#' minh.limit(series, from = 1, to = 3)
#'
#' @export
minh.limit <- function(path.result, from, to) {
    if (!inherits(path.result, "path.graph.series")) {
        stop("'path.result' must be a path.graph.series object.", call. = FALSE)
    }

    for (i in seq_along(path.result)) {
        if (!is.null(get.shortest.path(path.result[[i]], from, to))) {
            return(attr(path.result[[i]], "h"))
        }
    }

    NULL
}

#' Create a Path Length Matrix Graph Structure
#'
#' @param adj.list Adjacency list using 1-based vertex indices.
#' @param length.list Edge-length list matching `adj.list`.
#' @param h Odd positive integer maximum path length in hops.
#'
#' @return An object of class `path.graph.plm`.
#'
#' @examples
#' graph <- list(2L, c(1L, 3L), 2L)
#' lengths <- list(1, c(1, 2), 2)
#' create.plm.graph(graph, lengths, h = 3)
#'
#' @export
create.plm.graph <- function(adj.list, length.list, h) {
    if (!is.list(adj.list) || length(adj.list) == 0) {
        stop("'adj.list' must be a non-empty list.", call. = FALSE)
    }
    if (!is.list(length.list) || length(length.list) == 0) {
        stop("'length.list' must be a non-empty list.", call. = FALSE)
    }
    if (length(adj.list) != length(length.list)) {
        stop("'adj.list' and 'length.list' must have the same length.", call. = FALSE)
    }

    for (i in seq_along(adj.list)) {
        if (!is.numeric(adj.list[[i]]) && length(adj.list[[i]]) > 0) {
            stop(sprintf("adj.list[[%d]] must be numeric or empty.", i), call. = FALSE)
        }
        if (!is.numeric(length.list[[i]]) && length(length.list[[i]]) > 0) {
            stop(sprintf("length.list[[%d]] must be numeric or empty.", i), call. = FALSE)
        }
        if (length(adj.list[[i]]) != length(length.list[[i]])) {
            stop(sprintf(
                "adj.list[[%d]] and length.list[[%d]] must have the same length.",
                i,
                i
            ), call. = FALSE)
        }
        if (length(length.list[[i]]) > 0 && any(length.list[[i]] <= 0)) {
            stop(sprintf(
                "All edge lengths in length.list[[%d]] must be positive.",
                i
            ), call. = FALSE)
        }
        if (length(adj.list[[i]]) > 0) {
            invalid.idx <- adj.list[[i]] < 1 | adj.list[[i]] > length(adj.list)
            if (any(invalid.idx)) {
                stop(sprintf(
                    "Invalid vertex indices in adj.list[[%d]]: indices must be between 1 and %d.",
                    i,
                    length(adj.list)
                ), call. = FALSE)
            }
        }
    }

    if (!is.numeric(h) || length(h) != 1 || !is.finite(h)) {
        stop("'h' must be a single finite numeric value.", call. = FALSE)
    }
    h <- as.integer(h)
    if (h < 1) {
        stop("'h' must be at least 1.", call. = FALSE)
    }
    if (h %% 2 == 0) {
        stop("'h' must be odd (1, 3, 5, ...).", call. = FALSE)
    }

    for (i in seq_along(adj.list)) {
        for (j.idx in seq_along(adj.list[[i]])) {
            j <- adj.list[[i]][j.idx]
            if (!(i %in% adj.list[[j]])) {
                warning(sprintf(
                    "Graph may not be undirected: edge %d->%d exists but %d->%d does not.",
                    i,
                    j,
                    j,
                    i
                ), call. = FALSE)
            }
        }
    }

    graph.0based <- lapply(adj.list, function(x) {
        if (length(x) == 0) integer(0) else as.integer(x - 1)
    })

    res <- .Call(
        "S_create_path_graph_plm",
        graph.0based,
        length.list,
        h,
        PACKAGE = "dgraphs"
    )

    graph <- dgraph(res$adj_list, res$edge_length_list, edge.attributes = list(hops = res$hop_list))
    structure(list(graph = graph, h = h, shortest.paths = res$shortest_paths, vertex.paths = res$vertex_paths),
              class = "path.graph.plm")
}

#' Print a Path-Length-Metric Graph
#'
#' @param x A `path.graph.plm` object from [create.plm.graph()].
#' @param ... Unused.
#' @return Invisibly returns `x` unchanged after printing its vertex, edge and
#'   stored-path counts and maximum path length.
#' @inherit create.plm.graph examples
#' @export
print.path.graph.plm <- function(x, ...) {
    cat("PLM Path Graph\n")
    cat("  Number of vertices:", length(graph.adjacency(x$graph)), "\n")
    cat("  Maximum path length (h):", x$h, "\n")
    cat("  Number of stored paths:", length(x$shortest.paths$paths), "\n")

    n.edges <- sum(sapply(graph.adjacency(x$graph), length)) / 2
    cat("  Number of edges:", n.edges, "\n")

    invisible(x)
}
