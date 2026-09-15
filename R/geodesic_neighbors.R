.distance.neighbors <- function(d, k, self = NULL, small.component = c("error", "truncate")) {
    small.component <- match.arg(small.component)
    limit <- ncol(d) - !is.null(self)
    if (!is.numeric(k) || is.complex(k) || length(k) != 1L ||
        !is.finite(k) || k != floor(k) || k < 1 || k > limit)
        stop("k must be an integer between 1 and ", limit, ".", call. = FALSE)
    index <- matrix(NA_integer_, nrow(d), k)
    distance <- matrix(NA_real_, nrow(d), k)
    counts <- integer(nrow(d))
    for (i in seq_len(nrow(d))) {
        candidates <- which(is.finite(d[i, ]))
        if (!is.null(self)) candidates <- setdiff(candidates, self[i])
        candidates <- candidates[order(d[i, candidates], candidates)]
        counts[i] <- min(k, length(candidates))
        if (counts[i] < k && small.component == "error")
            stop("Fewer than k reachable neighbors for query ", i,
                 "; use small.component = 'truncate' explicitly.", call. = FALSE)
        if (counts[i]) {
            cols <- seq_len(counts[i])
            index[i, cols] <- candidates[cols]
            distance[i, cols] <- d[i, candidates[cols]]
        }
    }
    list(nn.index = index, nn.dist = distance, effective.k = counts)
}

#' Find Geodesic Neighbors Within a Point Cloud
#'
#' @param X Finite numeric matrix of observations, one per row.
#' @param k Number of other vertices to return, an integer in `1:(nrow(X)-1)`.
#'   Self is excluded by vertex index; coincident other observations remain
#'   valid zero-distance neighbors. Ties are ordered by vertex index.
#' @param k.graph Number of other neighbors used to construct the auxiliary
#'   symmetric kNN graph. Components are not automatically connected.
#'   Ignored when `graph` is supplied.
#' @param graph Optional `dgraph` containing stored edge lengths, in X row order.
#' @param small.component Error if fewer than `k` other vertices are reachable
#'   (`"error"`, default), or return the available neighbors (`"truncate"`).
#' @return A list with `nn.index` and `nn.dist` matrices with `k` columns and
#'   `effective.k`, the number returned per row. Under explicit truncation,
#'   absent indices and distances are `NA`; unreachable vertices are never
#'   reported as neighbors.
#' @seealso [geodesic.knnx()], [graph.geodesic.distances()]
#' @examples
#' X <- cbind(0:3, 0)
#' geodesic.knn(X, k = 1, k.graph = 1) # one other vertex per row
#' @export
geodesic.knn <- function(X, k, k.graph = 5, graph = NULL,
                         small.component = c("error", "truncate")) {
    X <- .path.coordinates(X, "X")
    small.component <- match.arg(small.component)
    if (!is.null(graph) && graph.order(graph) != nrow(X))
        stop("graph and X must have the same vertex count.")
    d <- if (is.null(graph)) graph.geodesic.distances(points = X, k = k.graph) else
        graph.geodesic.distances(graph = graph)
    .distance.neighbors(d, k, self = seq_len(nrow(X)), small.component = small.component)
}

#' Find Geodesic Neighbors from Grid Queries to Observations
#'
#' @param X Finite numeric matrix of data observations.
#' @param X.grid Finite numeric matrix of grid query points, with the same
#'   number of coordinate columns as `X`.
#' @param k Number of data observations returned per grid query, in `1:nrow(X)`.
#'   Grid and data rows have distinct identities: a coincident observation is
#'   a valid zero-distance neighbor. Ties are ordered by data row index.
#' @param k.graph Number of grid vertices attached to each observation, in
#'   `1:nrow(X.grid)`. Grid vertices connect to up to twice the coordinate
#'   dimension other grid vertices. No components are automatically bridged.
#' @param small.component Error on insufficient reachable observations, or
#'   explicitly `"truncate"` and pad absent indices and distances with `NA`.
#' @return A list with combined coordinates `V` (grid rows first), edge pairs
#'   `E` in V row indices, `nn.index` (indices into X), `nn.dist` and
#'   `effective.k` (the number returned per grid query).
#' @seealso [geodesic.knn()]
#' @examples
#' X.grid <- as.matrix(expand.grid(x = 0:2, y = 0:2))
#' X <- rbind(c(0, 0), c(1.2, 0.8), c(1.8, 1.7))
#' geodesic.knnx(X, X.grid, k = 2)
#' @export
geodesic.knnx <- function(X, X.grid, k, k.graph = 5,
                          small.component = c("error", "truncate")) {
    X <- .path.coordinates(X, "X")
    X.grid <- .path.coordinates(X.grid, "X.grid")
    small.component <- match.arg(small.component)
    if (ncol(X) != ncol(X.grid)) stop("X and X.grid must have the same coordinate dimension.")
    n <- nrow(X); N <- nrow(X.grid)
    if (!is.numeric(k.graph) || is.complex(k.graph) || length(k.graph) != 1L ||
        !is.finite(k.graph) || k.graph != floor(k.graph) || k.graph < 1 || k.graph > N)
        stop("k.graph must be an integer between 1 and nrow(X.grid).")
    dimK <- min(2L * ncol(X), N - 1L)
    E.grid <- matrix(integer(), 0, 2)
    if (dimK) {
        nn <- FNN::get.knn(X.grid, k = dimK)
        E.grid <- cbind(rep(seq_len(N), dimK), as.vector(nn$nn.index))
    }
    nn <- FNN::get.knnx(X.grid, X, k = k.graph)
    E <- rbind(E.grid, cbind(rep(seq_len(n) + N, k.graph), as.vector(nn$nn.index)))
    V <- rbind(X.grid, X)
    G <- igraph::make_empty_graph(n + N, directed = FALSE)
    G <- igraph::add_edges(G, as.vector(t(E)))
    weights <- sqrt(rowSums((V[E[, 1], , drop = FALSE] - V[E[, 2], , drop = FALSE])^2))
    # Explicit edge weights preserve zero-length edges between coincident rows.
    d <- igraph::distances(G, v = seq_len(N), to = N + seq_len(n), weights = weights)
    c(list(V = V, E = E), .distance.neighbors(d, k, small.component = small.component))
}
