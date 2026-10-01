#' Compute Complete or Graph-Restricted Sample Fermat Distances
#'
#' Minimize sums of powered edge lengths. Coordinate input defaults to the
#' complete Euclidean graph, implementing the sample Fermat distance on the
#' observed points. A symmetric kNN restriction or a supplied graph is an
#' explicit alternative, with no automatic guarantee of the same distances.
#'
#' @param graph A `dgraph` with finite nonnegative edge lengths, interpreted
#'   as base lengths before powering. Supply exactly one of `graph` and `points`.
#' @param p Finite numeric scalar at least one; the edge-length exponent.
#' @param rooted Logical scalar. If `TRUE`, return the `1/p` power of the
#'   minimum sum. Defaults to `FALSE`; rooting does not change minimizing paths.
#' @param vertices Optional unique 1-based vertex indices in output order.
#'   Paths may use all vertices. `NULL` selects all; an empty vector selects none.
#' @param stage Stored graph stage, default `"final"`. Coordinate input only
#'   permits `"final"`.
#' @param points Finite numeric matrix or data frame, observations in rows.
#' @param graph.type Coordinate construction: `"complete"` (default) or
#'   `"sknn"` (union-symmetric Euclidean kNN, without pruning or repair).
#'   Cannot accompany `graph`.
#' @param k Required for `graph.type = "sknn"`, with `1 <= k < n`.
#'   Not accepted for complete or supplied graphs.
#'
#' @param backend Complete-graph coordinate backend: `"explicit"` (the
#'   default reference) or `"implicit"` (evaluate edges on demand without
#'   storing adjacency). Explicitly supplied only for complete coordinate input.
#' @param sources Optional unique source indices for rectangular queries with
#'   `backend = "implicit"`. For pivot-to-all distances, supply the pivot ids.
#'   Cannot accompany `vertices`; every point remains a possible transit vertex.
#' @param targets Optional unique target indices with `sources`; defaults to
#'   all observations. Row and column order follow `sources` and `targets`.
#' @param max.workspace.bytes Positive finite workspace allowance for the
#'   implicit backend (default 512 MiB). The estimate includes coordinates,
#'   output and linear native scratch, not total R process memory or R copies.
#'
#' @param return.graph Logical scalar; return distances together with the union
#'   of selected shortest-path edges and coverage metadata. Defaults to `FALSE`.
#'   Complete coordinate input uses the implicit implementation for this option,
#'   even when `backend = "explicit"` is left at its default.
#'
#' @details For base lengths \eqn{l_e}, the unrooted result is
#'   \eqn{\min_\pi \sum_{e\in\pi} l_e^p}. At `p = 1`, complete-graph coordinate
#'   distances are Euclidean; restricted distances are ordinary graph distances.
#'   Restricting edges cannot decrease the result when retained weights agree.
#'   Taking `k = n - 1` recovers the complete graph.
#'
#'   Groisman, Jonckheere and Sapienza define the unrooted complete-graph
#'   estimator and prove consistency after sample-size normalization under
#'   their sampling assumptions. Their Proposition 2.12 establishes a
#'   high-probability equality for a sufficiently large nearest-neighbor
#'   restriction under its stated assumptions. It does not certify arbitrary
#'   fixed `k`, pruned graphs, or arbitrary supplied lengths. This function
#'   applies neither sample-size normalization nor an estimated limit constant.
#'
#'   Both coordinate constructions evaluate all Euclidean pairs. Explicit
#'   complete graphs store quadratic adjacency. The implicit backend uses dense
#'   Dijkstra searches with linear scratch and no graph restriction: with h
#'   sources, n observations and d coordinates its worst-case time is O(h*n^2*d).
#'   A global numeric-range check takes O(n^2*d) time. Pivot-to-all output uses
#'   O(h*n) storage; full all-pairs output is still quadratic. Select pivots
#'   outside this function; no automatic pivot sampling or distance approximation
#'   is performed. Distances are computed in floating-point arithmetic.
#'   Overflow, positive powered lengths underflowing to zero, and a conservative
#'   upper bound on simple-path cost exceeding the numeric range cause errors;
#'   rescale base lengths before retrying. Multiplying lengths by `a > 0`
#'   multiplies unrooted distances by `a^p` (rooted distances by `a`).
#'
#'   With `return.graph = TRUE`, one deterministic shortest-path tree is selected
#'   per source (ties need not include every minimizing path). Only paths to the
#'   requested targets contribute edges. The returned graph retains all input
#'   vertices, including unused isolated vertices. Its edge lengths are powered
#'   base lengths even when the returned distances are rooted. Thus graph
#'   geodesics reproduce the unrooted requested distances. With all sources and
#'   targets it preserves every pair; a subset guarantees only the requested
#'   pairs. The union need not be sparse. The implicit workspace estimate includes
#'   a conservative allowance for the predecessor-edge union when requested.
#'
#' @return Numeric square distance matrix, or a source-by-target matrix when
#'   `sources` is supplied, in requested order. Unreachable
#'   pairs are `Inf`. Zero-length edges are retained; duplicate points have zero
#'   distance. Point row names or graph adjacency names label the matrix.
#'   With `return.graph = TRUE`, return a list containing `distances` (this
#'   matrix), `graph` (a `dgraph` with powered base edge lengths), and `metadata`.
#'   Metadata records `sources`, `targets`, `coverage` (`all_pairs` or
#'   `requested_pairs`), `p`, `rooted`, `edge.weight.type`, and the backend used.
#'   Graph distances are unrooted even when the returned matrix is rooted.
#' @references Groisman, P., Jonckheere, M. and Sapienza, F. (2022).
#'   Nonhomogeneous Euclidean first-passage percolation and distance learning.
#'   Bernoulli, 28(1), 255--276. \doi{10.3150/21-BEJ1341}.
#'   See Definitions 2.1 and 2.11 and Proposition 2.12 in
#'   \url{https://arxiv.org/html/1810.09398v2}.
#' @seealso [graph.geodesic.distances()], [create.sknn.graph()]
#' @examples
#' X <- matrix(c(0, 1, 2), ncol = 1)
#' fermat.distances(points = X, p = 2) # 0 -> 1 -> 2 costs 2, not 4
#' fermat.distances(points = X, p = 2, rooted = TRUE)
#' fermat.distances(points = X, graph.type = "sknn", k = 1)
#' g <- dgraph(list(2L, c(1L, 3L), 2L), list(1, c(1, 1), 1))
#' fermat.distances(g, vertices = c(1, 3))
#' @export
fermat.distances <- function(graph = NULL, p = 2, rooted = FALSE,
                             vertices = NULL, stage = "final", points = NULL,
                             graph.type = NULL, k = NULL,
                             backend = "explicit", sources = NULL, targets = NULL,
                             max.workspace.bytes = 512 * 1024^2,
                             return.graph = FALSE) {
    if (!is.logical(return.graph) || length(return.graph) != 1L || is.na(return.graph))
        stop("return.graph must be TRUE or FALSE.", call. = FALSE)
    backend.supplied <- !missing(backend)
    backend <- .graph.choice(backend, c("explicit", "implicit"), "backend")
    if ((!is.null(sources) || !is.null(targets)) && backend != "implicit")
        stop("sources and targets require backend = 'implicit'.", call. = FALSE)
    if (!is.null(targets) && is.null(sources))
        stop("targets requires sources.", call. = FALSE)
    if (!is.null(vertices) && !is.null(sources))
        stop("sources cannot accompany vertices.", call. = FALSE)
    if (!missing(max.workspace.bytes) && backend != "implicit")
        stop("max.workspace.bytes requires backend = 'implicit'.", call. = FALSE)
    if (!is.numeric(p) || length(p) != 1L || !is.finite(p) || p < 1)
        stop("'p' must be a finite numeric scalar at least one.", call. = FALSE)
    if (!is.logical(rooted) || length(rooted) != 1L || is.na(rooted))
        stop("'rooted' must be TRUE or FALSE.", call. = FALSE)
    if (is.null(graph) == is.null(points))
        stop("Supply exactly one of 'graph' and 'points'.", call. = FALSE)
    labels <- NULL
    if (!is.null(graph)) {
        if (backend.supplied || !is.null(sources))
            stop("backend and sources require complete coordinate input.", call. = FALSE)
        if (!is.null(graph.type) || !is.null(k))
            stop("Construction arguments graph.type and k cannot accompany 'graph'.", call. = FALSE)
        adj <- graph.adjacency(graph, stage)
        lens <- graph.lengths(graph, stage)
        if (is.null(lens)) stop("Graph must have base edge lengths.", call. = FALSE)
        labels <- names(adj)
    } else {
        if (!identical(stage, "final"))
            stop("Coordinate input permits only stage = 'final'.", call. = FALSE)
        if (!is.matrix(points) && !is.data.frame(points))
            stop("'points' must be a numeric matrix or data frame.", call. = FALSE)
        points <- as.matrix(points)
        if (!is.numeric(points) || !nrow(points) || !ncol(points) || any(!is.finite(points)))
            stop("'points' must contain finite numeric values in at least one row and column.", call. = FALSE)
        storage.mode(points) <- "double"
        labels <- rownames(points)
        if (is.null(graph.type)) graph.type <- "complete"
        graph.type <- .graph.choice(graph.type, c("complete", "sknn"), "graph.type")
        n <- nrow(points)
        if (graph.type != "complete" && backend.supplied)
            stop("backend requires complete coordinate input.", call. = FALSE)
        if (graph.type == "complete" && (backend == "implicit" || return.graph)) {
            if (!is.null(k)) stop("'k' is only accepted for graph.type = 'sknn'.", call. = FALSE)
            if (!is.numeric(max.workspace.bytes) || length(max.workspace.bytes) != 1L ||
                !is.finite(max.workspace.bytes) || max.workspace.bytes <= 0)
                stop("max.workspace.bytes must be positive and finite.", call. = FALSE)
            ids <- function(x, name) {
                if (!is.numeric(x) || !is.null(dim(x)) || any(!is.finite(x)) ||
                    any(x != floor(x)) || any(x < 1 | x > n) || anyDuplicated(x))
                    stop(name, " must contain unique, valid 1-based integer indices.", call. = FALSE)
                as.integer(x)
            }
            if (is.null(sources)) {
                sources <- if (is.null(vertices)) seq_len(n) else ids(vertices, "vertices")
                targets <- sources
            } else {
                sources <- ids(sources, "sources")
                targets <- if (is.null(targets)) seq_len(n) else ids(targets, "targets")
            }
            native <- fermat_implicit_cpp(points, p, sources, targets, max.workspace.bytes, return.graph)
            out <- native$distances
            if (rooted) out <- out^(1/p)
            if (!is.null(labels)) dimnames(out) <- list(labels[sources], labels[targets])
            if (return.graph) return(.fermat.graph.result(out, native$edges,
                native$weights, n, labels, sources, targets, p, rooted, "implicit"))
            return(out)
        }
        if (graph.type == "sknn") {
            k <- .graph.integer(k, "k", 1)
            if (k >= n) stop("'k' must be less than the number of points.", call. = FALSE)
            graph <- create.sknn.graph(points, k = k, neighbor.method = "exact",
                                      prune.edges = FALSE, connect.components = FALSE,
                                      graph.detail = "minimal")
            adj <- graph.adjacency(graph)
            lens <- graph.lengths(graph)
        } else {
            if (!is.null(k)) stop("'k' is only accepted for graph.type = 'sknn'.", call. = FALSE)
            adj <- lapply(seq_len(n), function(i) seq_len(n)[-i])
            lens <- lapply(seq_len(n), function(i) {
                if (!length(adj[[i]])) return(numeric())
                delta <- sweep(points[adj[[i]], , drop = FALSE], 2L, points[i, ], "-")
                scale <- apply(abs(delta), 1L, max)
                d <- scale * sqrt(rowSums((delta / ifelse(scale == 0, 1, scale))^2))
                if (any(!is.finite(d))) stop("Euclidean distances overflow; rescale points.", call. = FALSE)
                d
            })
        }
    }
    n <- length(adj)
    if (is.null(vertices)) vertices <- seq_len(n)
    if (!is.numeric(vertices) || !is.null(dim(vertices)) || any(!is.finite(vertices)) ||
        any(vertices != floor(vertices)) || any(vertices < 1 | vertices > n) || anyDuplicated(vertices))
        stop("'vertices' must contain unique, valid 1-based integer indices.", call. = FALSE)
    powered <- lapply(lens, function(x) {
        w <- x^p
        if (any(!is.finite(w))) stop("Powered edge lengths overflow; rescale base lengths.", call. = FALSE)
        if (any(x > 0 & w == 0)) stop("Powered edge lengths underflow to zero; rescale base lengths.", call. = FALSE)
        if (any(w > .Machine$double.xmax / max(1, n - 1)))
            stop("Potential path-cost overflow; rescale base lengths.", call. = FALSE)
        w
    })
    if (return.graph) {
        g <- as_igraph(dgraph(adj, powered))
        edge.ids <- integer()
        for (v in vertices) {
            paths <- suppressWarnings(igraph::shortest_paths(g, from=v, to=vertices,
                weights=igraph::E(g)$length, output="epath", algorithm="dijkstra"))
            edge.ids <- union(edge.ids, unlist(lapply(paths$epath, as.integer), use.names=FALSE))
        }
        all.edges <- igraph::as_edgelist(g, names=FALSE)
        out <- if (length(vertices)) .graph.distance.matrix(adj, powered, vertices) else matrix(numeric(),0,0)
        if (rooted) out <- out^(1/p)
        if (!is.null(labels)) dimnames(out) <- list(labels[vertices], labels[vertices])
        return(.fermat.graph.result(out, all.edges[edge.ids,,drop=FALSE],
            igraph::E(g)$length[edge.ids], n, labels, as.integer(vertices),
            as.integer(vertices), p, rooted, "explicit"))
    }
    if (!length(vertices)) return(matrix(numeric(), 0L, 0L))
    out <- .graph.distance.matrix(adj, powered, vertices)
    if (rooted) out <- out^(1 / p)
    if (!is.null(labels)) dimnames(out) <- list(labels[vertices], labels[vertices])
    out
}

# Construct a dgraph without dropping isolated observations or zero edges.
.fermat.graph.result <- function(distances, edges, weights, n, labels,
                                 sources, targets, p, rooted, backend) {
    adj <- replicate(n, integer(), simplify=FALSE)
    lens <- replicate(n, numeric(), simplify=FALSE)
    if (nrow(edges)) {
        from <- c(edges[,1], edges[,2]); to <- c(edges[,2], edges[,1])
        values <- rep(weights, 2L)
        groups <- split(seq_along(from), factor(from, levels=seq_len(n)))
        for (i in seq_len(n)) {
            ix <- groups[[i]]; ix <- ix[order(to[ix])]
            adj[[i]] <- as.integer(to[ix]); lens[[i]] <- values[ix]
        }
    }
    names(adj) <- labels
    list(distances=distances, graph=dgraph(adj, lens), metadata=list(
        sources=sources, targets=targets,
        coverage=if (length(sources)==n && length(targets)==n) "all_pairs" else "requested_pairs",
        p=p, rooted=rooted, edge.weight.type="powered_base_lengths", backend=backend))
}
