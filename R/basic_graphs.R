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
