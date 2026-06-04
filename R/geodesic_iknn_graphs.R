#' Create a graph-geodesic iKNN graph
#'
#' @description
#' Rebuilds an iKNN graph from an existing weighted graph by using graph
#' geodesic distances in place of Euclidean distances. For every vertex `i`,
#' the graph-metric neighbor set contains the first `k` finite graph-geodesic
#' nearest vertices under the same convention used by `create.iknn.graphs()`.
#' Because self-distance is zero, this includes `i` whenever `i` is finite from
#' itself. Vertices `i` and `j` are connected in the returned graph when those
#' two neighbor sets intersect.
#'
#' @param graph A weighted graph list with entries `adj_list` and `weight_list`,
#'   as returned by `create.iknn.graphs(..., compute.full = TRUE)` in
#'   `geom_pruned_graphs`.
#' @param k Integer number of graph-metric nearest vertices in each neighbor
#'   set, matching the `k` convention used by `create.iknn.graphs()`.
#'
#' @return A list with entries:
#' \describe{
#'   \item{adj_list}{1-based adjacency list for the final graph.}
#'   \item{weight_list}{Final graph-geodesic edge lengths from the input graph.}
#'   \item{raw_adj_list, raw_weight_list}{The native geodesic iKNN graph.}
#'   \item{pruned_adj_list, pruned_weight_list}{Identical to \code{raw_*}
#'     because geodesic iKNN graphs do not currently have a pruning stage.}
#'   \item{raw_repaired_adj_list, raw_repaired_weight_list,
#'     pruned_repaired_adj_list, pruned_repaired_weight_list,
#'     repaired_pruned_adj_list, repaired_pruned_weight_list}{Lifecycle aliases
#'     identical to the final graph because this constructor has no MST repair
#'     or pruning stage.}
#'   \item{isize_list}{Intersection sizes for each edge.}
#'   \item{n_edges}{Number of undirected edges.}
#' }
#'
#' @examples
#' graph <- list(
#'   adj_list = list(2L, c(1L, 3L), 2L),
#'   weight_list = list(1, c(1, 1), 1)
#' )
#' create.geodesic.iknn.graph(graph, k = 1)
#'
#' @export
create.geodesic.iknn.graph <- function(graph, k) {
    .validate.geodesic.iknn.input(graph)

    if (!is.numeric(k) || length(k) != 1 || k != floor(k) || k < 1) {
        stop("k must be a positive integer.")
    }
    if (length(graph$adj_list) <= k) {
        stop("Number of vertices must be greater than k.")
    }

    result <- .Call(
        "S_create_geodesic_iknn_graph",
        graph$adj_list,
        graph$weight_list,
        as.integer(k),
        PACKAGE = "dgraphs"
    )
    result$raw_adj_list <- result$adj_list
    result$raw_weight_list <- result$weight_list
    result$pruned_adj_list <- result$adj_list
    result$pruned_weight_list <- result$weight_list
    result$raw_repaired_adj_list <- result$adj_list
    result$raw_repaired_weight_list <- result$weight_list
    result$pruned_repaired_adj_list <- result$adj_list
    result$pruned_repaired_weight_list <- result$weight_list
    result$repaired_pruned_adj_list <- result$adj_list
    result$repaired_pruned_weight_list <- result$weight_list
    result$n_edges_in_raw_graph <- .edge.count.from.adj.list(result$raw_adj_list)
    result$n_edges_in_raw_repaired_graph <- .edge.count.from.adj.list(result$adj_list)
    result$n_edges_in_pruned_repaired_graph <- .edge.count.from.adj.list(result$adj_list)
    result$n_edges_in_repaired_pruned_graph <- .edge.count.from.adj.list(result$adj_list)
    comps <- .graph.components(result$adj_list)
    result$n_components_raw <- comps$n_components
    result$n_components_raw_repaired <- comps$n_components
    result$n_components_pruned <- comps$n_components
    result$n_components_pruned_repaired <- comps$n_components
    result$n_components_repaired_pruned <- comps$n_components
    attr(result, "k") <- as.integer(k)
    attr(result, "k_internal") <- as.integer(k)
    class(result) <- c("geodesic_iknn_graph", "list")
    result
}

#' Create iterated graph-geodesic iKNN graphs
#'
#' @description
#' Constructs `G0` with `create.iknn.graphs()`, then constructs `G1`, `G2`, ...,
#' `Gm` by repeatedly applying `create.geodesic.iknn.graph()` to each graph in
#' the `kmin:kmax` sequence. This implements the iterated nerve rule
#'
#' \deqn{\{i,j\} \in E(G_{t+1}) \iff
#'       kNN_{G_t}(i) \cap kNN_{G_t}(j) \ne \emptyset,}
#'
#' with edge length
#'
#' \deqn{\ell_{t+1}(i,j) = d_{G_t}(i,j).}
#'
#' @param X Numeric matrix with rows as observations and columns as features.
#' @param kmin Integer minimum `k`.
#' @param kmax Integer maximum `k`.
#' @param n.iterations Non-negative integer number of geodesic rebuilds after
#'   `G0`. The default `3` returns `G0`, `G1`, `G2`, and `G3`.
#' @param max.path.edge.ratio.deviation.thld,path.edge.ratio.percentile,threshold.percentile
#'   Initial `G0` pruning arguments forwarded to `create.iknn.graphs()`. The
#'   default deviation and quantile thresholds are zero so that `G0` is the
#'   unpruned iKNN 1-skeleton.
#' @param pca.dim,variance.explained,n.cores,parallel.mode,hybrid.batch.size,verbose,knn.cache.path,knn.cache.mode
#'   Additional arguments forwarded to `create.iknn.graphs()` for the initial
#'   `G0` construction.
#'
#' @return A list of class `"iterated_iknn_graphs"` with entries:
#' \describe{
#'   \item{k_values}{Integer vector of requested `k` values.}
#'   \item{n_iterations}{Number of geodesic rebuilds after `G0`.}
#'   \item{initial_graphs}{The `"iknn_graphs"` object returned by
#'     `create.iknn.graphs()` for `G0`.}
#'   \item{graphs}{Nested list named `G0`, `G1`, ...; each entry is a named list
#'     of graph objects for `kmin:kmax`.}
#'   \item{summary}{Data frame with one row per iteration and `k`.}
#' }
#'
#' @examples
#' set.seed(1)
#' X <- matrix(rnorm(30), ncol = 2)
#' out <- create.iterated.iknn.graphs(X, kmin = 2, kmax = 3, n.iterations = 1,
#'                                    verbose = FALSE)
#' out$summary
#'
#' @export
create.iterated.iknn.graphs <- function(X,
                                        kmin,
                                        kmax,
                                        n.iterations = 3L,
                                        max.path.edge.ratio.deviation.thld = 0,
                                        path.edge.ratio.percentile = 0.5,
                                        threshold.percentile = 0,
                                        pca.dim = 100,
                                        variance.explained = 0.99,
                                        n.cores = NULL,
                                        parallel.mode = c("auto", "k", "bucket", "hybrid", "bucket.prune"),
                                        hybrid.batch.size = 2L,
                                        verbose = TRUE,
                                        knn.cache.path = NULL,
                                        knn.cache.mode = c("none", "read", "write", "readwrite")) {
    if (!is.numeric(n.iterations) ||
        length(n.iterations) != 1 ||
        n.iterations != floor(n.iterations) ||
        n.iterations < 0) {
        stop("n.iterations must be a non-negative integer.")
    }

    k.values <- seq.int(as.integer(kmin), as.integer(kmax))
    parallel.mode <- match.arg(parallel.mode)
    knn.cache.mode <- match.arg(knn.cache.mode)

    initial.graphs <- create.iknn.graphs(
        X = X,
        kmin = kmin,
        kmax = kmax,
        max.path.edge.ratio.deviation.thld = max.path.edge.ratio.deviation.thld,
        path.edge.ratio.percentile = path.edge.ratio.percentile,
        threshold.percentile = threshold.percentile,
        compute.full = TRUE,
        with.isize.pruning = FALSE,
        with.edge.pruning.stats = FALSE,
        pca.dim = pca.dim,
        variance.explained = variance.explained,
        n.cores = n.cores,
        parallel.mode = parallel.mode,
        hybrid.batch.size = hybrid.batch.size,
        verbose = verbose,
        knn.cache.path = knn.cache.path,
        knn.cache.mode = knn.cache.mode
    )

    g0 <- initial.graphs$geom_pruned_graphs
    if (is.null(g0) || length(g0) != length(k.values)) {
        stop("create.iknn.graphs() did not return the expected G0 graph list.")
    }
    names(g0) <- as.character(k.values)

    graphs <- vector("list", length = as.integer(n.iterations) + 1L)
    names(graphs) <- paste0("G", seq.int(0L, as.integer(n.iterations)))
    graphs[[1L]] <- g0

    if (n.iterations > 0) {
        for (iteration in seq_len(as.integer(n.iterations))) {
            previous <- graphs[[iteration]]
            current <- vector("list", length(k.values))
            names(current) <- as.character(k.values)
            for (idx in seq_along(k.values)) {
                current[[idx]] <- create.geodesic.iknn.graph(
                    previous[[idx]],
                    k = k.values[[idx]]
                )
            }
            graphs[[iteration + 1L]] <- current
        }
    }

    result <- list(
        k_values = k.values,
        n_iterations = as.integer(n.iterations),
        initial_graphs = initial.graphs,
        graphs = graphs,
        summary = .summarize.iterated.iknn.graphs(graphs, k.values),
        call = match.call()
    )

    attr(result, "kmin") <- as.integer(kmin)
    attr(result, "kmax") <- as.integer(kmax)
    attr(result, "n.iterations") <- as.integer(n.iterations)
    class(result) <- c("iterated_iknn_graphs", "list")
    result
}

#' @export
summary.iterated_iknn_graphs <- function(object, ...) {
    if (!inherits(object, "iterated_iknn_graphs")) {
        stop("object must inherit from class 'iterated_iknn_graphs'.")
    }
    object$summary
}

.validate.geodesic.iknn.input <- function(graph) {
    if (!is.list(graph) || is.null(graph$adj_list) || is.null(graph$weight_list)) {
        stop("graph must be a list with entries adj_list and weight_list.")
    }
    if (!is.list(graph$adj_list) || !is.list(graph$weight_list)) {
        stop("graph$adj_list and graph$weight_list must both be lists.")
    }
    if (length(graph$adj_list) != length(graph$weight_list)) {
        stop("graph$adj_list and graph$weight_list must have the same length.")
    }
    invisible(TRUE)
}

.summarize.iterated.iknn.graphs <- function(graphs, k.values) {
    rows <- list()
    for (iteration.idx in seq_along(graphs)) {
        iteration <- iteration.idx - 1L
        iteration.name <- names(graphs)[[iteration.idx]]
        for (k.idx in seq_along(k.values)) {
            graph <- graphs[[iteration.idx]][[k.idx]]
            graph.summary <- .summarize.geodesic.graph(graph)
            rows[[length(rows) + 1L]] <- data.frame(
                iteration = iteration,
                graph = iteration.name,
                k = k.values[[k.idx]],
                n_vertices = graph.summary$n_vertices,
                n_edges = graph.summary$n_edges,
                n_ccomp = graph.summary$n_ccomp,
                mean_degree = graph.summary$mean_degree,
                min_degree = graph.summary$min_degree,
                max_degree = graph.summary$max_degree
            )
        }
    }
    do.call(rbind, rows)
}

.summarize.geodesic.graph <- function(graph) {
    .validate.geodesic.iknn.input(graph)
    degrees <- lengths(graph$adj_list)
    n.vertices <- length(graph$adj_list)
    data.frame(
        n_vertices = n.vertices,
        n_edges = as.integer(sum(degrees) / 2L),
        n_ccomp = .graph.component.count(graph$adj_list),
        mean_degree = if (n.vertices > 0L) mean(degrees) else NA_real_,
        min_degree = if (n.vertices > 0L) min(degrees) else NA_integer_,
        max_degree = if (n.vertices > 0L) max(degrees) else NA_integer_
    )
}

.graph.component.count <- function(adj.list) {
    n <- length(adj.list)
    if (n == 0L) {
        return(0L)
    }

    visited <- rep(FALSE, n)
    n.components <- 0L
    for (start in seq_len(n)) {
        if (visited[[start]]) {
            next
        }
        n.components <- n.components + 1L
        queue <- start
        visited[[start]] <- TRUE
        head <- 1L
        while (head <= length(queue)) {
            vertex <- queue[[head]]
            head <- head + 1L
            neighbors <- as.integer(adj.list[[vertex]])
            neighbors <- neighbors[neighbors >= 1L & neighbors <= n]
            unvisited <- neighbors[!visited[neighbors]]
            if (length(unvisited) > 0L) {
                visited[unvisited] <- TRUE
                queue <- c(queue, unvisited)
            }
        }
    }
    n.components
}
