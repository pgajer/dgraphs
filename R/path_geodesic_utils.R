.dist.to.knn <- function(d, k) {
    stopifnot(isSymmetric(d))

    n <- nrow(d)
    nn.i <- matrix(0, nrow = n, ncol = k)
    nn.d <- matrix(0, nrow = n, ncol = k)
    for (i in seq(n)) {
        x <- as.numeric(d[i, ])
        o <- order(x)
        nn.i[i, ] <- o[seq(k)]
        nn.d[i, ] <- x[o[seq(k)]]
    }

    list(nn.i = nn.i, nn.d = nn.d)
}

#' Normalized Cumulative Distance Along a Vertex Path
#'
#' @param s Sequence of vertex indices.
#' @param V Vertex coordinate matrix.
#' @param edge.col Legacy argument retained for compatibility.
#'
#' @return Numeric vector of cumulative path distances normalized to end at 1.
#'
#' @examples
#' vertices <- rbind(c(0, 0), c(1, 0), c(1, 2))
#' path.dist(1:3, vertices)
#'
#' @export
path.dist <- function(s, V, edge.col = "gray") {
    n <- length(s)
    d <- numeric(n)
    for (i in 2:n) {
        M <- rbind(V[s[i - 1], ], V[s[i], ])
        d[i] <- d[i - 1] + as.numeric(stats::dist(M))
    }
    d / d[n]
}

#' Compute Euclidean Path Length
#'
#' @param X Numeric matrix whose rows are consecutive path points.
#'
#' @return Total Euclidean length of the path.
#'
#' @examples
#' path.length(rbind(c(0, 0), c(1, 0), c(1, 2)))
#'
#' @export
path.length <- function(X) {
    stopifnot(is.numeric(X))
    stopifnot(is.finite(X))
    nrX <- nrow(X)

    path.len <- 0
    for (i in 2:nrX) {
        path.len <- path.len + sqrt(sum((X[i, ] - X[i - 1, ])^2))
    }

    path.len
}

.point.euclidean.distance <- function(p1, p2) {
    sqrt(sum((p1 - p2)^2))
}

#' Subdivide a Path into Arc-Length Spaced Points
#'
#' @param path Matrix of consecutive path points.
#' @param n.subdivision.pts Number of output points.
#'
#' @return Matrix of subdivided path coordinates.
#'
#' @examples
#' path <- rbind(c(0, 0), c(1, 0), c(1, 2))
#' subdivide.path(path, n.subdivision.pts = 5)
#'
#' @export
subdivide.path <- function(path, n.subdivision.pts) {
    n.pts <- dim(path)[1]
    length.list <- sapply(
        seq(n.pts - 1),
        function(i) .point.euclidean.distance(path[i, ], path[i + 1, ])
    )
    total.length <- sum(length.list)
    subdiv.dist <- total.length / (n.subdivision.pts - 1)

    subdivision.pts <- matrix(nrow = n.subdivision.pts, ncol = ncol(path))

    start.offset <- 0
    edge.subdivision.dist <- start.offset
    subdivision.ix <- 1
    path.pt <- 1

    while (path.pt < n.pts) {
        edge.subdivision.dist <- edge.subdivision.dist + subdiv.dist

        while (edge.subdivision.dist <= length.list[path.pt]) {
            if (edge.subdivision.dist > 0) {
                v <- path[path.pt + 1, ] - path[path.pt, ]
                unit.v <- v / sqrt(sum(v^2))
                subdivision.pts[subdivision.ix, ] <-
                    path[path.pt, ] + edge.subdivision.dist * unit.v
            } else {
                subdivision.pts[subdivision.ix, ] <- path[path.pt, ]
            }

            subdivision.ix <- subdivision.ix + 1
            edge.subdivision.dist <- edge.subdivision.dist + subdiv.dist
        }

        start.offset <- edge.subdivision.dist - length.list[path.pt]
        edge.subdivision.dist <- start.offset
        path.pt <- path.pt + 1
    }

    subdivision.pts[n.subdivision.pts, ] <- path[n.pts, ]

    subdivision.pts
}

#' Estimate Geodesic Nearest Neighbors Within a Point Cloud
#'
#' @param X Numeric matrix of observations.
#' @param k Number of nearest neighbors to return.
#' @param k.graph Number of other neighbors used to construct the auxiliary
#'   symmetric kNN graph, including when `k.graph = 1`. Components are not
#'   automatically connected. Ignored when `graph` is supplied.
#' @param graph Optional `dgraph` containing stored edge lengths.
#'
#' @return A list with `nn.index` and `nn.dist` matrices.
#'
#' @examples
#' X <- cbind(seq(0, 1, length.out = 8), 0)
#' geodesic.knn(X, k = 2, k.graph = 3)
#'
#' @export
geodesic.knn <- function(X, k, k.graph = 5, graph = NULL) {
    if (!is.matrix(X)) {
        X <- try(as.matrix(X), silent = TRUE)
        if (inherits(X, "try-error")) {
            stop("X must be a matrix or coercible to a matrix")
        }
    }
    if (!is.numeric(X)) {
        stop("X must contain numeric values")
    }
    if (any(is.na(X)) || any(is.infinite(X))) {
        stop("X cannot contain NA, NaN, or Inf values")
    }
    stopifnot(k > 0)
    if (!is.null(graph) && graph.order(graph) != nrow(X))
        stop("graph and X must have the same vertex count.")
    d <- if (is.null(graph)) graph.geodesic.distances(points = X, k = k.graph) else
        graph.geodesic.distances(graph = graph)
    r <- .dist.to.knn(d, k)
    list(nn.index = r$nn.i, nn.dist = r$nn.d)
}



#' Estimate Geodesic Nearest Neighbors from Grid Points to Data Points
#'
#' @param X Numeric data matrix.
#' @param X.grid Numeric grid matrix associated with `X`.
#' @param k Number of nearest data neighbors returned for each grid point.
#' @param method Legacy graph construction method argument.
#' @param k.graph Number of neighbors used to construct the auxiliary graph.
#'
#' @return A list with graph vertices, graph edges, `nn.index`, and `nn.dist`.
#'
#' @examples
#' X.grid <- as.matrix(expand.grid(x = 0:2, y = 0:2))
#' X <- rbind(c(0.2, 0.2), c(1.2, 0.8), c(1.8, 1.7))
#' geodesic.knnx(X, X.grid, k = 2)
#'
#' @export
geodesic.knnx <- function(X, X.grid, k, method = "knn.graph", k.graph = 5) {
    if (!is.matrix(X)) {
        X <- try(as.matrix(X), silent = TRUE)
        if (inherits(X, "try-error")) {
            stop("X must be a matrix or coercible to a matrix")
        }
    }
    if (!is.numeric(X)) {
        stop("X must contain numeric values")
    }
    if (any(is.na(X)) || any(is.infinite(X))) {
        stop("X cannot contain NA, NaN, or Inf values")
    }
    stopifnot(k > 0)
    n <- nrow(X)
    N <- nrow(X.grid)
    dimK <- 2 * ncol(X)
    nn <- FNN::get.knn(X.grid, k = dimK)
    E.grid <- matrix(nrow = dimK * N, ncol = 2)
    ii <- seq(N)
    for (i in seq(dimK)) {
        E.grid[ii, ] <- cbind(seq(N), nn$nn.index[, i])
        ii <- ii + N
    }
    if (length(k.graph) != 1L || !is.finite(k.graph) || k.graph != floor(k.graph) ||
        k.graph < 1 || k.graph > nrow(X.grid)) stop("k.graph must be a valid neighbor count for X.grid.")
    nn <- FNN::get.knnx(X.grid, X, k = k.graph)
    nn.i <- nn$nn.index
    E <- matrix(nrow = k.graph * n, ncol = 2)
    l <- 1
    for (i in seq(n)) {
        for (j in seq(k.graph)) {
            E[l, ] <- c(i + N, nn.i[i, j])
            l <- l + 1
        }
    }
    V <- rbind(X.grid, X)
    E <- rbind(E.grid, E)
    A <- .graph.adj.mat(V, E)
    G <- igraph::graph_from_adjacency_matrix(A, mode = "undirected", weighted = TRUE)
    d <- igraph::distances(G)
    dd <- as.numeric(d)
    dd <- dd[is.finite(dd)]
    max.d <- max(dd)
    nn.i <- matrix(0, nrow = N, ncol = k)
    nn.d <- matrix(0, nrow = N, ncol = k)
    for (i in seq(N)) {
        x <- as.numeric(d[i, ])
        o <- order(x)
        x <- x[o]
        ii <- o
        idx <- ii > N
        ii <- ii[idx]
        x <- x[idx]
        x[!is.finite(x)] <- max.d
        nn.i[i, ] <- ii[seq(k)] - N
        nn.d[i, ] <- x[seq(k)]
    }
    list(V = V, E = E, nn.index = nn.i, nn.dist = nn.d)
}

#' Select Graph Endpoints by Core-Eccentricity Geometry
#'
#' @param adj.list Graph adjacency list using 1-based vertex indices.
#' @param length.list Edge-length list aligned with `adj.list`.
#' @param core.quantile Numeric in `(0, 1)` defining the low-eccentricity core.
#' @param endpoint.quantile Numeric in `[0, 1]` for endpoint candidate scores.
#' @param use.approx.eccentricity Use landmark-based eccentricity approximation.
#' @param n.landmarks Number of landmarks when approximation is used.
#' @param max.endpoints Optional positive cap on returned endpoints.
#' @param seed Integer seed for landmark initialization.
#' @param verbose Print backend progress.
#'
#' @return A `geodesic_core_endpoints` list of endpoints and diagnostics.
#'
#' @examples
#' graph <- create.graph("chain", n = 8)
#' endpoints <- geodesic.core.endpoints(graph.adjacency(graph), graph.lengths(graph),
#'     use.approx.eccentricity = FALSE)
#' endpoints$endpoints
#'
#' @export
geodesic.core.endpoints <- function(adj.list,
                                    length.list,
                                    core.quantile = 0.10,
                                    endpoint.quantile = 0.90,
                                    use.approx.eccentricity = TRUE,
                                    n.landmarks = 64L,
                                    max.endpoints = NULL,
                                    seed = 1L,
                                    verbose = FALSE) {
    if (!is.list(adj.list)) stop("'adj.list' must be a list.")
    if (!is.list(length.list)) stop("'length.list' must be a list.")
    if (length(adj.list) != length(length.list)) {
        stop("'adj.list' and 'length.list' must have the same length.")
    }
    if (!is.numeric(core.quantile) || length(core.quantile) != 1L ||
        !is.finite(core.quantile) || core.quantile <= 0 || core.quantile >= 1) {
        stop("'core.quantile' must be a finite scalar in (0, 1).")
    }
    if (!is.numeric(endpoint.quantile) || length(endpoint.quantile) != 1L ||
        !is.finite(endpoint.quantile) ||
        endpoint.quantile < 0 || endpoint.quantile > 1) {
        stop("'endpoint.quantile' must be a finite scalar in [0, 1].")
    }
    if (!is.logical(use.approx.eccentricity) ||
        length(use.approx.eccentricity) != 1L) {
        stop("'use.approx.eccentricity' must be a scalar logical.")
    }
    if (!is.numeric(n.landmarks) || length(n.landmarks) != 1L ||
        !is.finite(n.landmarks) || n.landmarks < 1) {
        stop("'n.landmarks' must be a finite scalar >= 1.")
    }
    if (!is.null(max.endpoints)) {
        if (!is.numeric(max.endpoints) || length(max.endpoints) != 1L ||
            !is.finite(max.endpoints) || max.endpoints < 1) {
            stop("'max.endpoints' must be NULL or a finite scalar >= 1.")
        }
    }
    if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed)) {
        stop("'seed' must be a finite scalar.")
    }
    if (!is.logical(verbose) || length(verbose) != 1L) {
        stop("'verbose' must be a scalar logical.")
    }

    adj.list.0 <- lapply(adj.list, function(x) as.integer(x - 1L))
    max.endpoints.int <- if (is.null(max.endpoints)) 0L else as.integer(max.endpoints)

    res <- .Call(
        "S_geodesic_core_endpoints",
        adj.list.0,
        length.list,
        as.double(core.quantile),
        as.double(endpoint.quantile),
        as.logical(use.approx.eccentricity),
        as.integer(n.landmarks),
        as.integer(max.endpoints.int),
        as.integer(seed),
        as.logical(verbose),
        PACKAGE = "dgraphs"
    )

    if (!is.null(res$endpoints)) {
        res$endpoints <- as.integer(res$endpoints) + 1L
    }
    if (!is.null(res$core_vertices)) {
        res$core_vertices <- as.integer(res$core_vertices) + 1L
    }
    if (!is.null(res$landmarks)) {
        res$landmarks <- as.integer(res$landmarks) + 1L
    }
    if (!is.null(res$summary) &&
        is.data.frame(res$summary) &&
        "vertex" %in% names(res$summary)) {
        res$summary$vertex <- as.integer(res$summary$vertex) + 1L
    }

    names(res)[names(res) == "core_vertices"] <- "core.vertices"
    names(res)[names(res) == "distance_to_core"] <- "distance.to.core"
    names(res)[names(res) == "is_core"] <- "is.core"
    names(res)[names(res) == "is_endpoint"] <- "is.endpoint"
    names(res)[names(res) == "is_local_max"] <- "is.local.max"
    names(res)[names(res) == "endpoint_rank"] <- "endpoint.rank"
    names(res)[names(res) == "core_threshold"] <- "core.threshold"
    names(res)[names(res) == "endpoint_threshold"] <- "endpoint.threshold"
    names(res)[names(res) == "used_approx_eccentricity"] <-
        "used.approx.eccentricity"
    names(res)[names(res) == "n_landmarks_used"] <- "n.landmarks.used"

    class(res) <- c("geodesic_core_endpoints", class(res))
    res
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
