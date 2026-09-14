#' Validate an adjacency list
#'
#' @param adj.list A list of 1-based integer or numeric neighbor vectors.
#' @param allow.empty Logical; if `FALSE`, require at least one vertex.
#'
#' @return The normalized adjacency list with integer neighbor vectors.
#'
#' @keywords internal
.dgraphs.validate.adj.list <- function(adj.list, allow.empty = FALSE) {
    if (!is.list(adj.list)) {
        stop("'adj.list' must be a list.", call. = FALSE)
    }
    if (!allow.empty && length(adj.list) == 0L) {
        stop("'adj.list' must not be empty.", call. = FALSE)
    }
    n <- length(adj.list)
    for (i in seq_along(adj.list)) {
        nbrs <- adj.list[[i]]
        if (is.null(nbrs) || length(nbrs) == 0L) {
            adj.list[[i]] <- integer(0)
            next
        }
        if (!is.numeric(nbrs)) {
            stop("adj.list[[", i, "]] must be numeric.", call. = FALSE)
        }
        if (any(!is.finite(nbrs)) || any(nbrs != floor(nbrs))) {
            stop("adj.list[[", i, "]] must contain finite integer indices.",
                 call. = FALSE)
        }
        nbrs <- as.integer(nbrs)
        if (any(nbrs < 1L | nbrs > n)) {
            stop("adj.list[[", i, "]] contains indices outside 1..", n,
                 ".", call. = FALSE)
        }
        if (anyDuplicated(nbrs)) stop("adj.list must not contain duplicate neighbors.", call. = FALSE)
        adj.list[[i]] <- nbrs
    }
    adj.list
}

.dgraphs.validate.length.list <- function(adj.list, length.list) {
    if (!is.list(length.list)) {
        stop("'length.list' must be a list.", call. = FALSE)
    }
    if (length(length.list) != length(adj.list)) {
        stop("'length.list' must have the same length as 'adj.list'.",
             call. = FALSE)
    }
    for (i in seq_along(length.list)) {
        w <- length.list[[i]]
        if (is.null(w)) w <- numeric(0)
        if (!is.numeric(w) || any(!is.finite(w)) || any(w < 0)) {
            stop("length.list[[", i, "]] must contain finite non-negative ",
                 "edge lengths.", call. = FALSE)
        }
        if (length(w) != length(adj.list[[i]])) {
            stop("adj.list[[", i, "]] and length.list[[", i,
                 "]] must have matching lengths.", call. = FALSE)
        }
        length.list[[i]] <- as.numeric(w)
    }
    length.list
}

#' Create a Complete Graph
#'
#' @param n Integer number of vertices.
#'
#' @return A `dgraph` object. Use [graph.adjacency()], [graph.lengths()],
#'   [graph.edges()] and [graph.stages()] to inspect its stored graph stages.
#'   Construction and diagnostic information is stored in `metadata`.
#'
#' @examples
#' complete <- create.complete.graph(4)
#' complete[[1]]
#'
#' @export
create.complete.graph <- function(n) {
    n <- as.integer(n)
    if (length(n) != 1L || is.na(n) || n < 1L) {
        stop("'n' must be a positive integer.", call. = FALSE)
    }
    dgraph(lapply(seq_len(n), function(i) as.integer(setdiff(seq_len(n), i))))
}

#' Create an Empty Graph
#'
#' @param n Integer number of vertices.
#'
#' @return A `dgraph` object. Use [graph.adjacency()], [graph.lengths()],
#'   [graph.edges()] and [graph.stages()] to inspect its stored graph stages.
#'   Construction and diagnostic information is stored in `metadata`.
#'
#' @examples
#' lengths(create.empty.graph(3))
#'
#' @export
create.empty.graph <- function(n) {
    n <- as.integer(n)
    if (length(n) != 1L || is.na(n) || n < 1L) {
        stop("'n' must be a positive integer.", call. = FALSE)
    }
    dgraph(replicate(n, integer(0), simplify = FALSE))
}

#' Construct the Nerve Graph of a Cover
#'
#' @param covering.list List of integer vectors, one for each set in the cover.
#' @param n.cores Number of parallel workers. Use `1` for serial execution.
#'
#' @return A `dgraph` with no lengths and overlap cardinalities stored in the
#'   `overlap` edge attribute.
#'
#' @examples
#' cover <- list(c(1, 2, 3), c(3, 4), c(5, 6))
#' graph.edges(nerve.graph(cover, n.cores = 1))
#'
#' @export
nerve.graph <- function(covering.list, n.cores = 1) {
    n <- length(covering.list)
    if (n < 2L) {
        return(dgraph(rep(list(integer()), n),
                      edge.attributes = list(overlap = rep(list(integer()), n))))
    }

    if (is.null(n.cores)) {
        n.cores <- min(2L, max(1L, parallel::detectCores()))
    }
    n.cores <- as.integer(n.cores)
    if (length(n.cores) != 1L || is.na(n.cores) || n.cores < 1L) {
        stop("'n.cores' must be a positive integer or NULL.", call. = FALSE)
    }

    adj <- matrix(0, nrow = n, ncol = n)

    if (n.cores == 1L) {
        for (i in seq_len(n - 1L)) {
            ci <- covering.list[[i]]
            for (j in (i + 1L):n) {
                w <- length(intersect(ci, covering.list[[j]]))
                if (w) adj[i, j] <- adj[j, i] <- w
            }
        }
    } else {
        cl <- parallel::makeCluster(n.cores)
        on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
        parallel::clusterExport(cl, c("covering.list"), envir = environment())
        results <- parallel::parLapply(cl, seq_len(n - 1L), function(i) {
            ci <- covering.list[[i]]
            v <- integer(length(covering.list))
            for (j in (i + 1L):length(covering.list)) {
                v[j] <- length(intersect(ci, covering.list[[j]]))
            }
            v
        })
        for (i in seq_len(n - 1L)) {
            idx <- which(results[[i]] > 0L)
            if (length(idx)) {
                adj[i, idx] <- results[[i]][idx]
                adj[idx, i] <- results[[i]][idx]
            }
        }
    }

    A <- if (requireNamespace("Matrix", quietly = TRUE)) {
        Matrix::Matrix(adj, sparse = TRUE)
    } else {
        adj
    }
    L <- convert.weighted.adjacency.matrix.to.adjacency.list(adj)
    dgraph(L$adj.list, edge.attributes = list(overlap = L$weight.list))
}

#' Create a Bipartite Graph
#'
#' @param n1 Number of vertices in the first part.
#' @param n2 Number of vertices in the second part.
#'
#' @return An unweighted `dgraph` connecting all pairs across the two parts.
#'
#' @examples
#' graph <- create.bipartite.graph(2, 3)
#' graph[[1]]
#'
#' @export
create.bipartite.graph <- function(n1, n2) {
    n1 <- as.integer(n1)
    n2 <- as.integer(n2)
    if (length(n1) != 1L || is.na(n1) || n1 < 1L ||
        length(n2) != 1L || is.na(n2) || n2 < 1L) {
        stop("'n1' and 'n2' must be positive integers.", call. = FALSE)
    }
    graph <- vector("list", n1 + n2)
    for (i in seq_len(n1)) {
        graph[[i]] <- as.integer((n1 + 1L):(n1 + n2))
    }
    for (i in (n1 + 1L):(n1 + n2)) {
        graph[[i]] <- as.integer(seq_len(n1))
    }
    dgraph(graph)
}

#' Join Two Adjacency-List Graphs
#'
#' @param graph1 First `dgraph`.
#' @param graph2 Second `dgraph`.
#' @param i1 Vertex in `graph1` to connect.
#' @param i2 Vertex in `graph2` to connect.
#'
#' @return A `dgraph` with vertices `i1` and `i2` identified. Both inputs must
#'   have lengths or both omit them, and must share their edge-attribute names.
#'
#' @examples
#' first <- dgraph(list(2L, 1L))
#' second <- dgraph(list(2L, 1L))
#' join.graphs(first, second, i1 = 2, i2 = 1)
#'
#' @export
join.graphs <- function(graph1, graph2, i1, i2) {
    a <- graph.adjacency(graph1); b <- graph.adjacency(graph2)
    if (length(i1) != 1L || length(i2) != 1L || !i1 %in% seq_along(a) || !i2 %in% seq_along(b))
        stop("i1 and i2 must be valid vertices.")
    len1 <- graph.lengths(graph1); len2 <- graph.lengths(graph2)
    if (is.null(len1) != is.null(len2)) stop("Both graphs must have lengths, or both must omit them.")
    attrs1 <- .dgraph.get.stage(graph1, "final")$edge.attributes
    attrs2 <- .dgraph.get.stage(graph2, "final")$edge.attributes
    if (!setequal(names(attrs1), names(attrs2))) stop("Both graphs must have the same named edge attributes.")
    map <- integer(length(b)); map[i2] <- i1
    map[-i2] <- length(a) + seq_len(length(b) - 1L)
    merge.values <- function(x, y) {
        out <- c(x, lapply(y[-i2], function(v) v[FALSE]))
        for (i in seq_along(y)) out[[map[i]]] <- c(out[[map[i]]], y[[i]])
        out
    }
    mapped <- lapply(b, function(v) map[v])
    adj <- merge.values(a, mapped)
    attrs <- lapply(names(attrs1), function(name) merge.values(attrs1[[name]], attrs2[[name]]))
    names(attrs) <- names(attrs1)
    dgraph(adj, if (!is.null(len1)) merge.values(len1, len2), attrs)
}

.dgraphs.chain.graph <- function(n.vertices) {
    n.vertices <- as.integer(n.vertices)
    if (length(n.vertices) != 1L || is.na(n.vertices) || n.vertices < 1L) {
        stop("'n.vertices' must be a positive integer.", call. = FALSE)
    }
    adj.list <- vector("list", n.vertices)
    for (i in seq_len(n.vertices)) {
        adj.list[[i]] <- as.integer(c(
            if (i > 1L) i - 1L else integer(0),
            if (i < n.vertices) i + 1L else integer(0)
        ))
    }
    adj.list
}

#' Create a Bi-kNN Chain Graph
#'
#' @param n.vertices Number of vertices, ignored when `x` is supplied.
#' @param k Number of neighbors on each side of a vertex in sorted order.
#' @param x Optional numeric coordinate used to order vertices.
#' @param y Optional response vector sorted along with `x`.
#'
#' @return A `dgraph` object. Use [graph.adjacency()], [graph.lengths()],
#'   [graph.edges()] and [graph.stages()] to inspect its stored graph stages.
#'   Construction and diagnostic information is stored in `metadata`.
#'
#' @examples
#' chain <- create.bi.kNN.chain.graph(x = c(3, 1, 2, 4), k = 1)
#' graph.adjacency(chain)
#' chain$metadata$x.sorted
#'
#' @export
create.bi.kNN.chain.graph <- function(n.vertices = 5, k = 1, x = NULL, y = NULL) {
    if (!is.null(x)) {
        n.vertices <- length(x)
    }
    n.vertices <- as.integer(n.vertices)
    k <- as.integer(k)
    if (length(n.vertices) != 1L || is.na(n.vertices) || n.vertices < 2L) {
        stop("A chain graph must have at least two vertices.", call. = FALSE)
    }
    if (length(k) != 1L || is.na(k) || k < 1L) {
        stop("'k' must be a positive integer.", call. = FALSE)
    }

    adj.list <- vector("list", n.vertices)
    edge.lengths <- vector("list", n.vertices)
    x.sorted <- NULL
    y.sorted <- NULL

    if (!is.null(x)) {
        o <- order(x)
        x.sorted <- x[o]
        if (!is.null(y)) {
            if (length(y) != n.vertices) {
                stop("Length of y must equal n.vertices.", call. = FALSE)
            }
            y.sorted <- y[o]
        }
    }

    for (i in seq_len(n.vertices)) {
        neighbors <- max(1L, i - k):min(n.vertices, i + k)
        neighbors <- setdiff(neighbors, i)
        adj.list[[i]] <- as.integer(neighbors)
        edge.lengths[[i]] <- if (!is.null(x.sorted)) {
            as.numeric(abs(x.sorted[i] - x.sorted[neighbors]))
        } else {
            rep(1.0, length(neighbors))
        }
    }

    graph <- dgraph(adj.list, edge.lengths)
    graph$metadata <- list(x.sorted = x.sorted, y.sorted = y.sorted)
    graph
}

#' Create a Chain Graph
#'
#' @param n.vertices Number of vertices. Required when `x` is `NULL`.
#' @param x Optional coordinate vector; if supplied, vertices are ordered by `x`.
#' @param y Optional response vector sorted along with `x`.
#'
#' @return A `dgraph` object. Use [graph.adjacency()], [graph.lengths()],
#'   [graph.edges()] and [graph.stages()] to inspect its stored graph stages.
#'   Construction and diagnostic information is stored in `metadata`.
#'
#' @examples
#' chain <- create.chain.graph(x = c(3, 1, 2))
#' graph.adjacency(chain)
#' graph.lengths(chain)
#'
#' @export
create.chain.graph <- function(n.vertices = NULL, x = NULL, y = NULL) {
    if (!is.null(x)) {
        n.vertices <- length(x)
        o <- order(x)
        x.sorted <- x[o]
        y.sorted <- if (!is.null(y)) {
            if (length(y) != n.vertices) {
                stop("Length of y must equal length of x.", call. = FALSE)
            }
            y[o]
        } else {
            NULL
        }
    } else {
        if (is.null(n.vertices)) {
            stop("Either n.vertices or x must be provided.", call. = FALSE)
        }
        x.sorted <- NULL
        y.sorted <- NULL
    }

    n.vertices <- as.integer(n.vertices)
    if (length(n.vertices) != 1L || is.na(n.vertices) || n.vertices < 2L) {
        stop("A chain has to have at least two vertices.", call. = FALSE)
    }

    adj.list <- .dgraphs.chain.graph(n.vertices)
    edge.lengths <- if (!is.null(x.sorted)) {
        lapply(seq_len(n.vertices), function(i) {
            abs(x.sorted[i] - x.sorted[adj.list[[i]]])
        })
    } else {
        lapply(adj.list, function(neighbors) rep(1, length(neighbors)))
    }

    graph <- dgraph(adj.list, edge.lengths)
    graph$metadata <- list(x.sorted = x.sorted, y.sorted = y.sorted)
    graph
}

#' Create a Circular Graph
#'
#' @param n Number of vertices.
#'
#' @return A `dgraph` object. Use [graph.adjacency()], [graph.lengths()],
#'   [graph.edges()] and [graph.stages()] to inspect its stored graph stages.
#'   Construction and diagnostic information is stored in `metadata`.
#'
#' @examples
#' create.circular.graph(5)
#'
#' @export
create.circular.graph <- function(n) {
    n <- as.integer(n)
    if (length(n) != 1L || is.na(n) || n < 3L) {
        stop("'n' must be an integer >= 3.", call. = FALSE)
    }
    adj.list <- lapply(seq_len(n), function(i) {
        if (i == 1L) {
            as.integer(c(2L, n))
        } else if (i == n) {
            as.integer(c(n - 1L, 1L))
        } else {
            as.integer(c(i - 1L, i + 1L))
        }
    })
    dgraph(adj.list)
}

#' Create a Star Graph by Joining Chains
#'
#' @param sizes Positive integer chain lengths attached to the central vertex.
#'
#' @return A `dgraph` object. Use [graph.adjacency()], [graph.lengths()],
#'   [graph.edges()] and [graph.stages()] to inspect its stored graph stages.
#'   Construction and diagnostic information is stored in `metadata`.
#'
#' @examples
#' star <- create.star.graph(c(2, 3, 1))
#' lengths(star)
#'
#' @export
create.star.graph <- function(sizes) {
    if (!is.numeric(sizes) || length(sizes) < 2L ||
        any(!is.finite(sizes)) || any(sizes <= 0)) {
        stop("'sizes' must contain at least two positive chain lengths.",
             call. = FALSE)
    }
    sizes <- as.integer(sizes)
    star.graph <- dgraph(.dgraphs.chain.graph(sizes[[1L]] + 1L))
    for (i in seq.int(2L, length(sizes))) {
        star.graph <- join.graphs(
            star.graph,
            dgraph(.dgraphs.chain.graph(sizes[[i]] + 1L)),
            1L,
            1L
        )
    }
    star.graph
}

#' Generate a Weighted Circle Graph
#'
#' @param n Number of vertices.
#' @param type Angle distribution, either `"random"` or `"uniform"`.
#' @param seed Optional random seed used when `type = "random"`.
#'
#' @return A `dgraph` with circle chord lengths and coordinates in `metadata`.
#'
#' @examples
#' circle <- generate.circle.graph(6, type = "uniform")
#' graph.adjacency(circle)[[1]]
#' graph.lengths(circle)[[1]]
#'
#' @export
generate.circle.graph <- function(n, type = "random", seed = NULL) {
    n <- as.integer(n)
    if (length(n) != 1L || is.na(n) || n < 3L) {
        stop("'n' must be an integer >= 3.", call. = FALSE)
    }
    type <- match.arg(type, c("uniform", "random"))
    if (!is.null(seed)) set.seed(seed)
    angles <- if (type == "uniform") {
        seq(0, 2 * pi, length.out = n + 1L)[-1L]
    } else {
        sort(stats::runif(n, min = 0, max = 2 * pi))
    }

    adj.list <- lapply(seq_len(n), function(i) {
        as.integer(c(if (i == 1L) n else i - 1L,
                     if (i == n) 1L else i + 1L))
    })
    names(adj.list) <- seq_len(n)
    weight.list <- vector("list", n)
    for (i in seq_len(n)) {
        prev.vertex <- adj.list[[i]][[1L]]
        next.vertex <- adj.list[[i]][[2L]]
        angle.to.prev <- abs(angles[i] - angles[prev.vertex])
        angle.to.next <- abs(angles[i] - angles[next.vertex])
        if (angle.to.prev > pi) angle.to.prev <- 2 * pi - angle.to.prev
        if (angle.to.next > pi) angle.to.next <- 2 * pi - angle.to.next
        weight.list[[i]] <- c(angle.to.prev, angle.to.next)
        names(weight.list[[i]]) <- as.character(adj.list[[i]])
    }
    names(weight.list) <- seq_len(n)
    dgraph(adj.list, weight.list)
}

#' Create a Random Undirected Graph
#'
#' @param n_vertices Integer number of vertices.
#' @param avg_degree Target average degree.
#' @param connected Logical; if `TRUE`, first build a random spanning tree.
#'
#' @return A `dgraph` object. Use [graph.adjacency()], [graph.lengths()],
#'   [graph.edges()] and [graph.stages()] to inspect its stored graph stages.
#'   Construction and diagnostic information is stored in `metadata`.
#'
#' @examples
#' set.seed(1)
#' graph <- create.random.graph(8, avg_degree = 2)
#' sum(lengths(graph.adjacency(graph)))/2
#'
#' @export
create.random.graph <- function(n_vertices, avg_degree, connected = TRUE) {
    n_vertices <- as.integer(n_vertices)
    if (length(n_vertices) != 1L || is.na(n_vertices) || n_vertices < 1L) {
        stop("'n_vertices' must be a positive integer.", call. = FALSE)
    }
    if (!is.numeric(avg_degree) || length(avg_degree) != 1L ||
        !is.finite(avg_degree) || avg_degree < 0) {
        stop("'avg_degree' must be a non-negative scalar.", call. = FALSE)
    }
    if (avg_degree > n_vertices - 1L) stop("avg_degree cannot exceed n_vertices - 1.")
    connected <- isTRUE(connected)

    adj.list <- vector("list", n_vertices)
    weight.list <- vector("list", n_vertices)
    n.edges <- floor(n_vertices * avg_degree / 2)

    for (i in seq_len(n_vertices)) {
        adj.list[[i]] <- integer(0)
        weight.list[[i]] <- numeric(0)
    }

    if (connected) {
        connected.vertices <- 1L
        unconnected.vertices <- setdiff(seq_len(n_vertices), connected.vertices)
        while (length(unconnected.vertices) > 0L) {
            v2 <- unconnected.vertices[sample.int(length(unconnected.vertices), 1L)]
            v1 <- connected.vertices[sample.int(length(connected.vertices), 1L)]

            adj.list[[v1]] <- c(adj.list[[v1]], v2)
            weight.list[[v1]] <- c(weight.list[[v1]], 1.0)
            adj.list[[v2]] <- c(adj.list[[v2]], v1)
            weight.list[[v2]] <- c(weight.list[[v2]], 1.0)

            connected.vertices <- c(connected.vertices, v2)
            unconnected.vertices <- setdiff(unconnected.vertices, v2)
        }
        n.edges <- n.edges - (n_vertices - 1L)
    }

    edges.added <- 0L
    while (edges.added < n.edges) {
        vertices <- sample(n_vertices, 2L)
        v1 <- vertices[[1L]]
        v2 <- vertices[[2L]]
        if (!(v2 %in% adj.list[[v1]])) {
            adj.list[[v1]] <- c(adj.list[[v1]], v2)
            weight.list[[v1]] <- c(weight.list[[v1]], 1.0)
            adj.list[[v2]] <- c(adj.list[[v2]], v1)
            weight.list[[v2]] <- c(weight.list[[v2]], 1.0)
            edges.added <- edges.added + 1L
        }
    }

    for (i in seq_len(n_vertices)) for (j in seq_along(adj.list[[i]])) {
        v <- adj.list[[i]][j]
        if (i < v) {
            value <- stats::runif(1L, 0.5, 1.5)
            weight.list[[i]][j] <- value
            weight.list[[v]][match(i, adj.list[[v]])] <- value
        }
    }
    dgraph(adj.list, weight.list)
}

#' Assign Vertices to Connected Components
#'
#' @param graph A `dgraph`.
#' @param stage Stored graph stage.
#'
#' @return Integer vector of component IDs, one per vertex.
#'
#' @examples
#' graph <- dgraph(list(2L, 1L, integer()))
#' graph.connected.components(graph)
#' @export
graph.connected.components <- function(graph, stage = "final") {
    adj.list <- graph.adjacency(graph, stage)
    n <- length(adj.list)
    component <- integer(n)
    for (start in seq_len(n)) {
        if (component[[start]] != 0L) next
        queue <- start
        component[[start]] <- start
        while (length(queue) > 0L) {
            v <- queue[[1L]]
            queue <- queue[-1L]
            for (u in adj.list[[v]]) {
                if (component[[u]] == 0L) {
                    component[[u]] <- start
                    queue <- c(queue, u)
                }
            }
        }
    }
    component
}

.graph.adj.mat <- function(X, E) {
    if (!is.matrix(X) || !is.numeric(X) || any(!is.finite(X))) {
        stop("'X' must be a finite numeric matrix.", call. = FALSE)
    }
    if (!is.matrix(E) || ncol(E) != 2L || !is.numeric(E) ||
        any(!is.finite(E)) || any(E != floor(E))) {
        stop("'E' must be a finite numeric two-column integer matrix.",
             call. = FALSE)
    }
    n <- nrow(X)
    if (nrow(E) > 0L && (any(E < 1L) || any(E > n))) {
        stop("All edge indices in 'E' must be between 1 and nrow(X).",
             call. = FALSE)
    }
    A <- matrix(0, nrow = n, ncol = n)
    for (i in seq_len(nrow(E))) {
        s <- as.integer(E[i, 1L])
        e <- as.integer(E[i, 2L])
        d <- sqrt(sum((X[s, , drop = TRUE] - X[e, , drop = TRUE])^2))
        A[s, e] <- d
        A[e, s] <- d
    }
    if (!is.null(rownames(X))) {
        rownames(A) <- rownames(X)
        colnames(A) <- rownames(X)
    }
    A
}

#' Compute a Weighted Shortest-Path Distance
#'
#' @param graph A `dgraph` with stored lengths.
#' @param stage Stored graph stage.
#' @param i Source vertex.
#' @param j Target vertex.
#'
#' @return Numeric shortest-path distance.
#'
#' @examples
#' graph <- list(2L, c(1L, 3L), 2L)
#' weights <- list(1, c(1, 2), 2)
#' compute.graph.distance(i = 1, j = 3, graph = dgraph(graph, weights))
#'
#' @export
compute.graph.distance <- function(graph, i, j, stage = "final") {
    graph.geodesic.distances(graph, vertices = c(i, j), stage = stage)[1L, 2L]
}

.dgraphs.edge.matrix <- function(adj.list, weight.list = NULL) {
    adj.list <- .dgraphs.validate.adj.list(adj.list)
    if (is.null(weight.list)) {
        weight.list <- lapply(adj.list, function(x) rep(1, length(x)))
    }
    weight.list <- .dgraphs.validate.length.list(adj.list, weight.list)
    edge.list <- list()
    weights <- numeric(0)
    idx <- 0L
    for (i in seq_along(adj.list)) {
        for (k in seq_along(adj.list[[i]])) {
            j <- adj.list[[i]][[k]]
            if (i < j) {
                idx <- idx + 1L
                edge.list[[idx]] <- c(i, j)
                weights[[idx]] <- weight.list[[i]][[k]]
            }
        }
    }
    edge.matrix <- if (length(edge.list)) {
        do.call(rbind, edge.list)
    } else {
        matrix(integer(0), ncol = 2L)
    }
    storage.mode(edge.matrix) <- "integer"
    list(edge.matrix = edge.matrix, weights = weights)
}

#' Convert an Adjacency List to an Edge Matrix
#'
#' @param adj.list A 1-based adjacency list.
#' @param weight.list Optional edge-weight list aligned with `adj.list`.
#'
#' @return A list with `edge.matrix` and `weights`.
#'
#' @examples
#' graph <- list(c(2L, 3L), 1L, 1L)
#' convert.adjacency.to.edge.matrix(graph)
#'
#' @export
convert.adjacency.to.edge.matrix <- function(adj.list, weight.list = NULL) {
    .dgraphs.edge.matrix(adj.list, weight.list)
}

#' Convert a Weighted Adjacency Matrix to Lists
#'
#' @param A Numeric square adjacency matrix.
#'
#' @return A list with `adj.list` and `weight.list`.
#'
#' @examples
#' A <- matrix(c(0, 1, 0, 1, 0, 2, 0, 2, 0), nrow = 3)
#' convert.weighted.adjacency.matrix.to.adjacency.list(A)
#'
#' @export
convert.weighted.adjacency.matrix.to.adjacency.list <- function(A) {
    if (!(is.matrix(A) || inherits(A, "Matrix"))) {
        stop("'A' must be a matrix.", call. = FALSE)
    }
    A <- as.matrix(A)
    if (!is.numeric(A) || nrow(A) != ncol(A)) {
        stop("'A' must be a square numeric matrix.", call. = FALSE)
    }
    n <- nrow(A)
    adj.list <- vector("list", n)
    weight.list <- vector("list", n)
    for (i in seq_len(n)) {
        idx <- which(A[i, ] != 0)
        adj.list[[i]] <- as.integer(idx)
        weight.list[[i]] <- as.numeric(A[i, idx])
    }
    list(adj.list = adj.list, weight.list = weight.list)
}

#' Compute a Weighted Graph Diameter
#'
#' @param graph A `dgraph` with stored lengths.
#' @param stage Stored graph stage.
#'
#' @return A list containing the diameter and the farthest path details.
#'
#' @examples
#' graph <- list(2L, c(1L, 3L), 2L)
#' weights <- list(1, c(1, 2), 2)
#' compute.graph.diameter(dgraph(graph, weights))$diameter
#'
#' @importFrom igraph graph_from_edgelist E diameter farthest_vertices shortest_paths make_empty_graph
#' @export
compute.graph.diameter <- function(graph, stage = "final") {
    if (!requireNamespace("igraph", quietly = TRUE)) {
        stop("Package 'igraph' is required.", call. = FALSE)
    }
    adj.list <- graph.adjacency(graph, stage)
    length.list <- graph.lengths(graph, stage)
    if (is.null(length.list)) stop("Graph diameter requires stored lengths.")
    res <- .dgraphs.edge.matrix(adj.list, length.list)
    if (nrow(res$edge.matrix) == 0L) {
        g <- igraph::make_empty_graph(n = length(adj.list), directed = FALSE)
    } else {
        g <- igraph::graph_from_edgelist(res$edge.matrix, directed = FALSE)
        if (igraph::vcount(g) < graph.order(graph)) g <- igraph::add_vertices(g, graph.order(graph) - igraph::vcount(g))
        igraph::E(g)$weight <- res$weights
    }
    diam <- igraph::diameter(g, weights = igraph::E(g)$weight, directed = FALSE)
    farthest <- igraph::farthest_vertices(g, weights = igraph::E(g)$weight,
                                          directed = FALSE)
    path <- igraph::shortest_paths(
        g,
        from = farthest$vertices[[1L]],
        to = farthest$vertices[[2L]],
        weights = igraph::E(g)$weight,
        output = "both"
    )
    list(
        diameter = diam,
        message = paste("The diameter of the graph is:", diam),
        farthest_vertices = farthest,
        diameter_path = path
    )
}
