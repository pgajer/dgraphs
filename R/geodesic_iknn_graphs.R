#' Create a graph-geodesic iKNN graph
#'
#' @description
#' Each cover contains its source vertex plus its `k` nearest other vertices.
#' Equal distances are resolved by ascending vertex index. Intersecting covers
#' create edges whose lengths are shortest-path distances in the input graph.
#'
#' @param graph A `dgraph` with stored finite, nonnegative lengths.
#' @param k Number of nearest other vertices; integer `1 <= k < n`.
#' @param small.component Default `"error"` requires at least `k + 1` vertices
#'   in every component. `"truncate"` uses all reachable other vertices in
#'   smaller components, recording per-vertex `effective.k` in neighborhood metadata.
#' @return A `dgraph` with a final stage, lengths and an `overlap` edge attribute.
#'   `metadata$neighborhood` records requested and effective sizes and the tie rule.
#'
#' @examples
#' graph <- create.chain.graph(3)
#' create.geodesic.iknn.graph(graph, k = 1)
#' @export
create.geodesic.iknn.graph <- function(graph, k,
                                         small.component = c("error", "truncate")) {
    small.component <- match.arg(small.component)
    n <- graph.order(graph)
    k <- .validate.k.values(k, n)
    if (length(k) != 1L) stop("k must be a single integer.")
    adj.list <- graph.adjacency(graph)
    length.list <- graph.lengths(graph)
    if (is.null(length.list)) stop("Graph-geodesic neighborhoods require stored lengths.")
    components <- graph.connected.components(graph)
    sizes <- tabulate(match(components, unique(components)))
    if (small.component == "error" && any(sizes <= k))
        stop("Components must contain at least k + 1 vertices. Undersized component sizes: ",
             paste(sizes[sizes <= k], collapse = ", "), ". Use small.component = 'truncate' explicitly.")
    effective.k <- pmin(k, sizes[match(components, unique(components))] - 1L)
    result <- .Call("S_create_geodesic_iknn_graph", adj.list, length.list, k,
                    PACKAGE = "dgraphs")
    out <- .dgraph.from.native(result, "geodesic_iknn_graph")
    out$metadata$neighborhood <- .neighborhood.metadata(k, effective.k, "graph.geodesic")
    out$metadata$small.component <- small.component
    out
}

#' Create iterated graph-geodesic iKNN graphs
#'
#' @description
#' Constructs `G0` with `create.iknn.graphs()`, then constructs `G1`, `G2`, ...,
#' `Gm` by repeatedly applying `create.geodesic.iknn.graph()` to each graph in
#' the `k.values` sequence. This implements the iterated nerve rule
#'
#' \deqn{\{i,j\} \in E(G_{t+1}) \iff
#'       kNN_{G_t}(i) \cap kNN_{G_t}(j) \ne \emptyset,}
#'
#' with edge length
#'
#' \deqn{\ell_{t+1}(i,j) = d_{G_t}(i,j).}
#'
#' @param X Numeric matrix with rows as observations and columns as features.
#' @param k.values Strictly increasing integer vector of neighborhood sizes, each between 1 and n - 1.
#' @param small.component Component-size policy forwarded to every geodesic rebuild.
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
#'   \item{k.values}{Integer vector of requested `k` values.}
#'   \item{n_iterations}{Number of geodesic rebuilds after `G0`.}
#'   \item{initial_graphs}{The `"iknn_graphs"` object returned by
#'     `create.iknn.graphs()` for `G0`.}
#'   \item{graphs}{Nested list named `G0`, `G1`, ...; each entry is a named list
#'     of graph objects for `k.values`.}
#'   \item{summary}{Data frame with one row per iteration and `k`.}
#' }
#'
#' @examples
#' set.seed(1)
#' X <- matrix(rnorm(30), ncol = 2)
#' out <- create.iterated.iknn.graphs(X, k.values = seq.int(2, 3), n.iterations = 1,
#'     verbose = FALSE)
#' out$summary
#'
#' @export
create.iterated.iknn.graphs <- function(X,
                                        k.values,
                                        n.iterations = 3L,
                                        small.component = c("error", "truncate"),
                                        max.path.edge.ratio.deviation.thld = 0,
                                        path.edge.ratio.percentile = 0.5,
                                        threshold.percentile = 0,
                                        pca.dim = 100,
                                        variance.explained = 0.99,
                                        n.cores = 1L,
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

    k.values <- .validate.k.values(k.values, nrow(as.matrix(X)))
    small.component <- match.arg(small.component)
    parallel.mode <- match.arg(parallel.mode)
    knn.cache.mode <- match.arg(knn.cache.mode)

    initial.graphs <- create.iknn.graphs(
        X = X,
        k.values = k.values,
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
                    k = k.values[[idx]], small.component = small.component
                )
            }
            graphs[[iteration + 1L]] <- current
        }
    }

    result <- list(
        k.values = k.values,
        n_iterations = as.integer(n.iterations),
        initial_graphs = initial.graphs,
        graphs = graphs,
        summary = .summarize.iterated.iknn.graphs(graphs, k.values),
        call = match.call()
    )

    attr(result, "k.values") <- k.values
    attr(result, "n.iterations") <- as.integer(n.iterations)
    class(result) <- c("iterated_iknn_graphs", "list")
    result
}

#' Summarize Iterated Intersection k-NN Graphs
#'
#' @param object An object from [create.iterated.iknn.graphs()].
#' @param ... Unused.
#' @return A data frame with one row per iteration and neighborhood size,
#'   reporting vertex, edge and connected-component counts and mean, minimum
#'   and maximum degree. This is the object's stored `summary` component.
#' @examples
#' set.seed(1)
#' X <- matrix(rnorm(30), ncol = 2)
#' out <- create.iterated.iknn.graphs(X, k.values = seq.int(2, 3), n.iterations = 1,
#'     verbose = FALSE)
#' summary(out)
#' @export
summary.iterated_iknn_graphs <- function(object, ...) {
    if (!inherits(object, "iterated_iknn_graphs")) {
        stop("object must inherit from class 'iterated_iknn_graphs'.")
    }
    object$summary
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
    degrees <- lengths(graph.adjacency(graph))
    n.vertices <- length(graph.adjacency(graph))
    data.frame(
        n_vertices = n.vertices,
        n_edges = as.integer(sum(degrees) / 2L),
        n_ccomp = .graph.component.count(graph.adjacency(graph)),
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
