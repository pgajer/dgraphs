#' Find Exact Sample Fermat Nearest Neighbors
#'
#' Find nearest neighbors in the complete-graph sample Fermat distance using
#' Euclidean neighbor pruning and truncated Dijkstra searches.
#'
#' @param points Finite numeric matrix or data frame, observations in rows.
#' @param k Number of other observations to return per row; `1 <= k < n`.
#' @param p Finite edge-length exponent at least one.
#' @param rooted Logical; return the `1/p` power of path costs if `TRUE`.
#' @param algorithm Exact Euclidean search algorithm passed to `FNN::get.knnx()`:
#'   `"kd_tree"` (default) or `"brute"`.
#'
#' @details The unrooted distance is the minimum sum of Euclidean edge lengths
#'   raised to `p`, allowing paths through all observations. Rooting preserves
#'   neighbor rankings. Lemma 5.6 of McKenzie and Damelin justifies pruning to
#'   directed Euclidean neighbor lists for nearest-neighbor queries. This does
#'   not establish equality of all pairwise distances on the sparse graph.
#'   The paper counts the source among its neighbors; here `k` excludes it.
#'
#'   Equal-distance neighbors at the cutoff may be selected arbitrarily;
#'   their identities need not agree across search algorithms or permutations.
#'   Duplicate observations are retained as distinct vertices with zero distance.
#'   Exactness refers to the complete-graph target, subject to floating-point
#'   arithmetic. Extremely disparate coordinate scales should be rescaled.
#'   Nonfinite computed lengths and powered costs, and positive costs that
#'   underflow to zero, cause errors.
#'
#'   Candidate lists and output use O(n*k) storage. After Euclidean search,
#'   binary-heap path searches take O(n*k^2*log(k+1)) time with O(n+k^2)
#'   scratch. Euclidean search may be quadratic in n in high dimensions.
#'   Unlike the implicit distance backend, this function does not scan every
#'   complete-graph edge for numeric-range validation.
#'
#' @return `fermat.knn()` returns a list with n-by-k matrices `index` (1-based
#'   neighbor indices) and `distance` (in nondecreasing order), excluding self.
#'   `create.fermat.knn.graph()` returns a `dgraph` formed by the union of these
#'   directed selections. Its lengths are Fermat distances, not powered direct
#'   Euclidean edges. Vertex degrees can exceed k; components are not repaired.
#'   Use [graph.geodesic.distances()] to sum stored lengths, rather than applying
#'   [fermat.distances()] with `p > 1` and powering them again.
#' @references McKenzie, D. and Damelin, S. (2019).
#'   Power Weighted Shortest Paths for Clustering Euclidean Data.
#'   Section 5, Lemma 5.6 and Algorithm 2. <https://arxiv.org/abs/1905.13345>.
#' @seealso [fermat.distances()], [create.sknn.graph()]
#' @examples
#' X <- cbind(c(0, 1, 2, 4), 0)
#' fermat.knn(X, k = 2, p = 2)
#' graph <- create.fermat.knn.graph(X, k = 2)
#' graph.edges(graph)
#' @export
fermat.knn <- function(points, k, p = 2, rooted = FALSE,
                       algorithm = "kd_tree") {
    if (!is.matrix(points) && !is.data.frame(points))
        stop("points must be a numeric matrix or data frame.", call. = FALSE)
    points <- as.matrix(points)
    if (!is.numeric(points) || nrow(points) < 2L || !ncol(points) || any(!is.finite(points)))
        stop("points must have at least two rows of finite numeric coordinates.", call. = FALSE)
    k <- .graph.integer(k, "k", 1L)
    if (k >= nrow(points)) stop("k must be less than the number of points.", call. = FALSE)
    if (!is.numeric(p) || length(p) != 1L || !is.finite(p) || p < 1)
        stop("p must be a finite numeric scalar at least one.", call. = FALSE)
    if (!is.logical(rooted) || length(rooted) != 1L || is.na(rooted))
        stop("rooted must be TRUE or FALSE.", call. = FALSE)
    algorithm <- .graph.choice(algorithm, c("kd_tree", "brute"), "algorithm")
    storage.mode(points) <- "double"
    neighbors <- .fermat.euclidean.neighbors(points, k, algorithm)
    weights <- neighbors$nn.dist^p
    if (any(!is.finite(weights)) || any(neighbors$nn.dist > 0 & weights == 0))
        stop("Powered costs overflow or underflow; rescale points.", call. = FALSE)
    out <- fermat_knn_cpp(neighbors$nn.index, weights)
    if (rooted) out$distance <- out$distance^(1/p)
    rownames(out$index) <- rownames(out$distance) <- rownames(points)
    out
}

.fermat.euclidean.neighbors <- function(points, k, algorithm) {
    # Uniform scaling avoids squared-distance overflow in the tree search.
    scale <- max(abs(points))
    if (scale == 0) scale <- 1
    normalized <- points / scale
    if (any(points != 0 & normalized == 0))
        stop("Coordinate scaling underflows; rescale points.", call. = FALSE)
    raw <- FNN::get.knnx(normalized, normalized, k = k + 1L, algorithm = algorithm)
    # get.knn drops the first result, which need not be self among duplicates.
    index <- matrix(0L, nrow(points), k)
    distance <- matrix(0, nrow(points), k)
    for (i in seq_len(nrow(points))) {
        take <- which(raw$nn.index[i, ] != i)[seq_len(k)]
        index[i, ] <- raw$nn.index[i, take]
        distance[i, ] <- raw$nn.dist[i, take]
    }
    out <- list(nn.index = index, nn.dist = distance)
    zeros <- which(out$nn.dist == 0, arr.ind = TRUE)
    if (nrow(zeros)) for (a in seq_len(nrow(zeros))) {
        i <- zeros[a, 1L]; j <- out$nn.index[i, zeros[a, 2L]]
        if (any(points[i, ] != points[j, ]))
            stop("Euclidean lengths underflow to zero; rescale points.", call. = FALSE)
    }
    out$nn.dist <- out$nn.dist * scale
    if (any(!is.finite(out$nn.dist)))
        stop("Euclidean lengths overflow; rescale points.", call. = FALSE)
    out
}

#' @rdname fermat.knn
#' @export
create.fermat.knn.graph <- function(points, k, p = 2, rooted = FALSE,
                                   algorithm = "kd_tree") {
    neighbors <- fermat.knn(points, k, p, rooted, algorithm)
    .fermat.knn.graph(neighbors, rownames(as.matrix(points)), k, p, rooted, algorithm)
}

.fermat.knn.graph <- function(neighbors, labels, k, p, rooted, algorithm) {
    n <- nrow(neighbors$index)
    from <- rep(seq_len(n), times = ncol(neighbors$index))
    to <- as.vector(neighbors$index)
    edges <- data.frame(from = pmin(from, to), to = pmax(from, to),
                        length = as.vector(neighbors$distance))
    # Reciprocal searches may differ at rounding scale; choose their minimum.
    edges <- edges[order(edges$from, edges$to, edges$length), ]
    edges <- edges[!duplicated(edges[c("from", "to")]), ]
    adj <- split(c(edges$to, edges$from),
                 factor(c(edges$from, edges$to), levels = seq_len(n)))
    lens <- split(rep(edges$length, 2L),
                  factor(c(edges$from, edges$to), levels = seq_len(n)))
    names(adj) <- names(lens) <- labels
    graph <- dgraph(adj, lens)
    graph$metadata <- list(method = "fermat_knn", k = k, p = p,
                           rooted = rooted, algorithm = algorithm,
                           symmetrization = "union", complete.graph.neighbors = TRUE)
    graph
}
