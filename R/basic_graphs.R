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
        adj.list[[i]] <- unique(nbrs)
    }
    adj.list
}

.dgraphs.validate.weight.list <- function(adj.list, weight.list) {
    if (!is.list(weight.list)) {
        stop("'weight.list' must be a list.", call. = FALSE)
    }
    if (length(weight.list) != length(adj.list)) {
        stop("'weight.list' must have the same length as 'adj.list'.",
             call. = FALSE)
    }
    for (i in seq_along(weight.list)) {
        w <- weight.list[[i]]
        if (is.null(w) || length(w) == 0L) {
            weight.list[[i]] <- numeric(0)
            next
        }
        if (!is.numeric(w) || any(!is.finite(w)) || any(w < 0)) {
            stop("weight.list[[", i, "]] must contain finite non-negative ",
                 "edge lengths.", call. = FALSE)
        }
        if (length(w) != length(adj.list[[i]])) {
            stop("adj.list[[", i, "]] and weight.list[[", i,
                 "]] must have matching lengths.", call. = FALSE)
        }
        weight.list[[i]] <- as.numeric(w)
    }
    weight.list
}

#' Create a Complete Graph
#'
#' @param n Integer number of vertices.
#'
#' @return An adjacency list for the complete graph on `n` vertices.
#'
#' @export
create.complete.graph <- function(n) {
    n <- as.integer(n)
    if (length(n) != 1L || is.na(n) || n < 1L) {
        stop("'n' must be a positive integer.", call. = FALSE)
    }
    lapply(seq_len(n), function(i) as.integer(setdiff(seq_len(n), i)))
}

#' Create an Empty Graph
#'
#' @param n Integer number of vertices.
#'
#' @return An adjacency list for the empty graph on `n` vertices.
#'
#' @export
create.empty.graph <- function(n) {
    n <- as.integer(n)
    if (length(n) != 1L || is.na(n) || n < 1L) {
        stop("'n' must be a positive integer.", call. = FALSE)
    }
    replicate(n, integer(0), simplify = FALSE)
}

#' Join Two Adjacency-List Graphs
#'
#' @param graph1 First adjacency list.
#' @param graph2 Second adjacency list.
#' @param i1 Vertex in `graph1` to connect.
#' @param i2 Vertex in `graph2` to connect.
#'
#' @return A joined adjacency list using 1-based vertex indices.
#'
#' @export
join.graphs <- function(graph1, graph2, i1, i2) {
    graph1 <- .dgraphs.validate.adj.list(graph1)
    graph2 <- .dgraphs.validate.adj.list(graph2)
    i1 <- as.integer(i1)
    i2 <- as.integer(i2)
    if (length(i1) != 1L || is.na(i1) || i1 < 1L || i1 > length(graph1)) {
        stop("'i1' must be a valid vertex of 'graph1'.", call. = FALSE)
    }
    if (length(i2) != 1L || is.na(i2) || i2 < 1L || i2 > length(graph2)) {
        stop("'i2' must be a valid vertex of 'graph2'.", call. = FALSE)
    }

    offset <- length(graph1)
    joined <- c(graph1, lapply(graph2, function(x) as.integer(x + offset)))
    joined[[i1]] <- sort(unique(as.integer(c(joined[[i1]], i2 + offset))))
    joined[[i2 + offset]] <- sort(unique(as.integer(c(joined[[i2 + offset]], i1))))
    joined
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

#' Create a Star Graph by Joining Chains
#'
#' @param sizes Positive integer chain lengths attached to the central vertex.
#'
#' @return An adjacency list for the star graph.
#'
#' @export
create.star.graph <- function(sizes) {
    if (!is.numeric(sizes) || length(sizes) < 2L ||
        any(!is.finite(sizes)) || any(sizes <= 0)) {
        stop("'sizes' must contain at least two positive chain lengths.",
             call. = FALSE)
    }
    sizes <- as.integer(sizes)
    star.graph <- .dgraphs.chain.graph(sizes[[1L]] + 1L)
    for (i in seq.int(2L, length(sizes))) {
        star.graph <- join.graphs(
            star.graph,
            .dgraphs.chain.graph(sizes[[i]] + 1L),
            1L,
            1L
        )
    }
    star.graph
}

#' Create a Random Undirected Graph
#'
#' @param n_vertices Integer number of vertices.
#' @param avg_degree Target average degree.
#' @param connected Logical; if `TRUE`, first build a random spanning tree.
#'
#' @return A list with `adj.list` and `weight.list`.
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
    connected <- isTRUE(connected)

    adj.list <- replicate(n_vertices, integer(0), simplify = FALSE)
    weight.list <- replicate(n_vertices, numeric(0), simplify = FALSE)
    add.edge <- function(v1, v2) {
        if (!(v2 %in% adj.list[[v1]])) {
            adj.list[[v1]] <<- c(adj.list[[v1]], as.integer(v2))
            adj.list[[v2]] <<- c(adj.list[[v2]], as.integer(v1))
            weight.list[[v1]] <<- c(weight.list[[v1]], 1.0)
            weight.list[[v2]] <<- c(weight.list[[v2]], 1.0)
            return(TRUE)
        }
        FALSE
    }

    target.edges <- floor(n_vertices * avg_degree / 2)
    edges.added <- 0L
    if (connected && n_vertices > 1L) {
        connected.vertices <- 1L
        unconnected.vertices <- setdiff(seq_len(n_vertices), connected.vertices)
        while (length(unconnected.vertices) > 0L) {
            v2 <- sample(unconnected.vertices, 1L)
            v1 <- sample(connected.vertices, 1L)
            add.edge(v1, v2)
            edges.added <- edges.added + 1L
            connected.vertices <- c(connected.vertices, v2)
            unconnected.vertices <- setdiff(unconnected.vertices, v2)
        }
    }

    max.edges <- n_vertices * (n_vertices - 1L) / 2L
    target.edges <- min(target.edges, max.edges)
    attempts <- 0L
    max.attempts <- max(1000L, 20L * max.edges)
    while (edges.added < target.edges && attempts < max.attempts) {
        attempts <- attempts + 1L
        vertices <- sample.int(n_vertices, 2L)
        if (add.edge(vertices[[1L]], vertices[[2L]])) {
            edges.added <- edges.added + 1L
        }
    }

    for (i in seq_len(n_vertices)) {
        if (length(weight.list[[i]]) > 0L) {
            weight.list[[i]] <- stats::runif(length(weight.list[[i]]), 0.5, 1.5)
        }
    }
    list(adj.list = adj.list, weight.list = weight.list)
}

#' Assign Vertices to Connected Components
#'
#' @param adj.list A graph adjacency list using 1-based vertex indices.
#'
#' @return Integer vector of component IDs, one per vertex.
#'
#' @export
graph.connected.components <- function(adj.list) {
    adj.list <- .dgraphs.validate.adj.list(adj.list)
    n <- length(adj.list)
    component <- integer(n)
    current <- 0L
    for (start in seq_len(n)) {
        if (component[[start]] != 0L) next
        current <- current + 1L
        queue <- start
        component[[start]] <- current
        while (length(queue) > 0L) {
            v <- queue[[1L]]
            queue <- queue[-1L]
            for (u in adj.list[[v]]) {
                if (component[[u]] == 0L) {
                    component[[u]] <- current
                    queue <- c(queue, u)
                }
            }
        }
    }
    component
}

#' Convert Coordinates and Edges to a Weighted Adjacency Matrix
#'
#' @param X Numeric coordinate matrix.
#' @param E Two-column matrix of 1-based edge endpoints.
#'
#' @return Symmetric weighted adjacency matrix with Euclidean edge lengths.
#'
#' @export
graph.adj.mat <- function(X, E) {
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
#' @param star.obj Optional object containing `adj.list` and `edge.lengths`.
#' @param i Source vertex.
#' @param j Target vertex.
#' @param adj.list Adjacency list.
#' @param edge.lengths Edge-length list matching `adj.list`.
#'
#' @return Numeric shortest-path distance.
#'
#' @export
compute.graph.distance <- function(star.obj = NULL,
                                   i,
                                   j,
                                   adj.list = NULL,
                                   edge.lengths = NULL) {
    if (!is.null(star.obj)) {
        adj.list <- star.obj$adj.list
        edge.lengths <- star.obj$edge.lengths
    }
    adj.list <- .dgraphs.validate.adj.list(adj.list)
    edge.lengths <- .dgraphs.validate.weight.list(adj.list, edge.lengths)
    n <- length(adj.list)
    i <- as.integer(i)
    j <- as.integer(j)
    if (length(i) != 1L || length(j) != 1L || is.na(i) || is.na(j) ||
        i < 1L || i > n || j < 1L || j > n) {
        stop("'i' and 'j' must be valid vertex indices.", call. = FALSE)
    }
    if (i == j) return(0)

    distances <- rep(Inf, n)
    distances[[i]] <- 0
    visited <- rep(FALSE, n)
    while (!visited[[j]] && any(!visited)) {
        current.distances <- ifelse(visited, Inf, distances)
        v <- which.min(current.distances)
        if (!is.finite(current.distances[[v]])) break
        visited[[v]] <- TRUE
        for (k in seq_along(adj.list[[v]])) {
            u <- adj.list[[v]][[k]]
            if (!visited[[u]]) {
                distances[[u]] <- min(distances[[u]],
                                      distances[[v]] + edge.lengths[[v]][[k]])
            }
        }
    }
    distances[[j]]
}

.dgraphs.edge.matrix <- function(adj.list, weight.list = NULL) {
    adj.list <- .dgraphs.validate.adj.list(adj.list)
    if (is.null(weight.list)) {
        weight.list <- lapply(adj.list, function(x) rep(1, length(x)))
    }
    weight.list <- .dgraphs.validate.weight.list(adj.list, weight.list)
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

#' Compute a Weighted Graph Diameter
#'
#' @param adj.list Adjacency list.
#' @param weight.list Edge-length list matching `adj.list`.
#'
#' @return A list containing the diameter and the farthest path details.
#'
#' @importFrom igraph graph_from_edgelist E diameter farthest_vertices shortest_paths make_empty_graph
#' @export
compute.graph.diameter <- function(adj.list, weight.list) {
    if (!requireNamespace("igraph", quietly = TRUE)) {
        stop("Package 'igraph' is required.", call. = FALSE)
    }
    res <- .dgraphs.edge.matrix(adj.list, weight.list)
    if (nrow(res$edge.matrix) == 0L) {
        g <- igraph::make_empty_graph(n = length(adj.list), directed = FALSE)
    } else {
        g <- igraph::graph_from_edgelist(res$edge.matrix, directed = FALSE)
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

#' Convert an Adjacency List to igraph
#'
#' @param adj.list A 1-based adjacency list.
#'
#' @return An undirected `igraph` graph.
#'
#' @importFrom igraph graph_from_edgelist make_empty_graph add_vertices
#' @export
adjlist.to.igraph <- function(adj.list) {
    if (!requireNamespace("igraph", quietly = TRUE)) {
        stop("Package 'igraph' is required.", call. = FALSE)
    }
    adj.list <- .dgraphs.validate.adj.list(adj.list)
    n <- length(adj.list)
    edges <- vector("list", n)
    for (v in seq_len(n)) {
        w <- adj.list[[v]]
        w <- w[w > v]
        if (length(w) > 0L) {
            edges[[v]] <- cbind(v, w)
        }
    }
    ed <- do.call(rbind, edges)
    if (is.null(ed) || nrow(ed) == 0L) {
        g <- igraph::make_empty_graph(n = n, directed = FALSE)
    } else {
        storage.mode(ed) <- "integer"
        g <- igraph::graph_from_edgelist(ed, directed = FALSE)
        if (igraph::vcount(g) < n) {
            g <- igraph::add_vertices(g, n - igraph::vcount(g))
        }
    }
    g
}
