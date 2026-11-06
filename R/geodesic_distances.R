#' Compute Graph Geodesic Distances
#'
#' Compute exact shortest-path distances on a supplied graph, or on a graph
#' constructed from coordinates. These graph distances may approximate a
#' continuous geometric distance; construction alone does not make them exact
#' manifold geodesics. Supply exactly one of `graph` and `points`.
#'
#' @param graph A `dgraph`. Construction arguments cannot accompany a graph.
#' @param vertices Optional unique 1-based vertex indices, in output order.
#'   `NULL` selects all vertices; an empty vector returns a zero-by-zero matrix.
#'   Paths may traverse vertices outside the selected subset.
#' @param stage Stored graph stage; defaults to `"final"`. Coordinate input
#'   permits only `"final"`.
#' @param distance `"length"` sums stored lengths (and errors if absent).
#'   `"hop"` explicitly counts edges instead.
#' @param points Finite numeric matrix or data frame, with one point per row
#'   and at least one row and column. Cannot accompany `graph`.
#' @param graph.type Construction for coordinate input: `"sknn"` (default when
#'   omitted) or `"mst"`. Symmetric kNN links a pair if either endpoint selects
#'   the other, without pruning or connectivity repair. MST builds a Euclidean
#'   minimum spanning tree, retaining zero-length edges for coincident points.
#' @param k Required number of other neighbors for `"sknn"`, with `1 <= k < n`.
#'   Not accepted for `"mst"`. In particular, `k = 1` still constructs a
#'   symmetric kNN graph; it never switches to an MST.
#'
#' @details For repeated calculations or more construction options, build a
#'   graph separately and supply it via `graph`. Coordinate construction uses
#'   untransformed Euclidean distances. The exact symmetric-neighbor search
#'   evaluates all pairs; MST construction uses a dense Prim search with
#'   quadratic time and linear auxiliary storage. Selected-vertex output has
#'   `length(vertices)^2` entries; all-pairs output has `n^2` entries.
#' @return A numeric square matrix in the requested vertex order; unreachable
#'   pairs have infinite distance. Zero-length edges remain traversable. Row
#'   names from `points`, or adjacency labels from `graph`, label the matrix
#'   when present.
#' @examples
#' graph <- create.graph("chain", 5)
#' graph.geodesic.distances(graph, vertices = c(1, 5))
#' graph.geodesic.distances(create.graph("cycle", 5), distance = "hop")
#' X <- matrix(c(0, 0, 1, 10), ncol = 1)
#' graph.geodesic.distances(points = X, graph.type = "mst")
#' graph.geodesic.distances(points = X, graph.type = "sknn", k = 1)
#' @export
graph.geodesic.distances <- function(graph = NULL, vertices = NULL, stage = "final",
                                      distance = c("length", "hop"), points = NULL,
                                      graph.type = NULL, k = NULL) {
    distance <- match.arg(distance)
    if (is.null(graph) == is.null(points))
        stop("Supply exactly one of 'graph' and 'points'.", call. = FALSE)
    labels <- NULL
    if (!is.null(graph)) {
        if (!is.null(graph.type) || !is.null(k))
            stop("Construction arguments graph.type and k cannot accompany 'graph'.", call. = FALSE)
    } else {
        if (!identical(stage, "final")) stop("Coordinate input permits only stage = 'final'.", call. = FALSE)
        if (!is.matrix(points) && !is.data.frame(points))
            stop("'points' must be a numeric matrix or data frame.", call. = FALSE)
        points <- as.matrix(points)
        if (!is.numeric(points) || !nrow(points) || !ncol(points) || any(!is.finite(points)))
            stop("'points' must contain finite numeric values in at least one row and column.", call. = FALSE)
        storage.mode(points) <- "double"
        labels <- rownames(points)
        if (is.null(graph.type)) graph.type <- "sknn"
        graph.type <- .graph.choice(graph.type, c("sknn", "mst"), "graph.type")
        if (graph.type == "mst") {
            if (!is.null(k)) stop("'k' is not accepted for graph.type = 'mst'.", call. = FALSE)
            graph <- .graph.euclidean.mst(points)
        } else {
            k <- .graph.integer(k, "k", 1)
            if (k >= nrow(points)) stop("'k' must be less than the number of points.", call. = FALSE)
            graph <- create.sknn.graph(points, k = k, neighbor.method = "exact",
                                      prune.edges = FALSE, connect.components = FALSE,
                                      graph.detail = "minimal")
        }
    }
    adj.list <- graph.adjacency(graph, stage)
    length.list <- graph.lengths(graph, stage)
    if (is.null(labels)) labels <- names(adj.list)
    if (distance == "hop") length.list <- lapply(adj.list, function(x) rep(1, length(x)))
    if (is.null(length.list)) stop("Graph has no lengths; explicitly request distance = 'hop' for hop distances.", call. = FALSE)
    if (is.null(vertices)) vertices <- seq_along(adj.list)
    if (!is.numeric(vertices) || !is.null(dim(vertices)) || any(!is.finite(vertices)) ||
        any(vertices != floor(vertices)) || any(vertices < 1 | vertices > length(adj.list)) ||
        anyDuplicated(vertices))
        stop("'vertices' must contain unique, valid 1-based integer indices.", call. = FALSE)
    if (!length(vertices)) return(matrix(numeric(), 0L, 0L))
    out <- .graph.distance.matrix(adj.list, length.list, vertices)
    if (!is.null(labels)) dimnames(out) <- list(labels[vertices], labels[vertices])
    out
}

.graph.euclidean.mst <- function(points) {
    n <- nrow(points)
    adj <- rep(list(integer()), n); lens <- rep(list(numeric()), n)
    taken <- rep(FALSE, n); cost <- rep(Inf, n); parent <- integer(n)
    cost[1L] <- 0
    for (step in seq_len(n)) {
        v <- which.min(replace(cost, taken, Inf))
        taken[v] <- TRUE
        if (parent[v]) {
            u <- parent[v]
            adj[[u]] <- c(adj[[u]], v); adj[[v]] <- c(adj[[v]], u)
            lens[[u]] <- c(lens[[u]], cost[v]); lens[[v]] <- c(lens[[v]], cost[v])
        }
        remaining <- which(!taken)
        if (length(remaining)) {
            delta <- sweep(points[remaining, , drop = FALSE], 2L, points[v, ], "-")
            # Scale each row before squaring to avoid avoidable overflow.
            scale <- apply(abs(delta), 1L, max)
            d <- scale * sqrt(rowSums((delta / ifelse(scale == 0, 1, scale))^2))
            if (any(!is.finite(d))) stop("Euclidean distances overflow for these coordinates.", call. = FALSE)
            better <- remaining[d < cost[remaining]]
            cost[better] <- d[match(better, remaining)]; parent[better] <- v
        }
    }
    dgraph(adj, lens)
}
