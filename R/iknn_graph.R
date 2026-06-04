#' Create a Single Intersection-weighted k-Nearest Neighbors Graph
#'
#' @description
#' Creates and prunes an intersection-weighted k-nearest neighbors (IWD-kNN) graph from
#' input data. The graph is constructed based on feature space distances and intersection
#' sizes between neighbor sets.
#'
#' @param X A numeric matrix where rows represent data points and columns represent features.
#'        Data frames will be coerced to matrices.
#'
#' @param k Integer scalar. The number of nearest neighbors to consider for each point.
#'        Must be positive and less than the number of data points.
#'
#' @param max.path.edge.ratio.deviation.thld Numeric in \eqn{[0, 0.2)}.
#'     Geometric pruning removes an edge \eqn{(i,j)} when there exists an
#'     alternative path between \eqn{i} and \eqn{j} whose path/edge length ratio
#'     minus 1.0 is \emph{less than} this threshold. This is a deviation
#'     threshold \eqn{\delta} in \eqn{[0, 0.2)}. Internally we compare the
#'     path-to-edge ratio R to \eqn{1 + \delta}.
#'     Used when `prune.method` is `"global.geodesic"` or
#'     `"global.geodesic.ratio"`.
#'
#' @param prune.method Character scalar. `"global.geodesic"` preserves the
#'     historical whole-graph geometric pruning behavior controlled by
#'     `max.path.edge.ratio.deviation.thld` and
#'     `path.edge.ratio.percentile`. `"global.geodesic.ratio"` is a separately
#'     named alias for that whole-graph geodesic-ratio behavior.
#'     `"local.geodesic"` applies the same experimental local geometric pruning
#'     stage used by sKNN/mKNN. `"none"` disables geometric pruning; quantile
#'     pruning controlled by `threshold.percentile` is still honored.
#'
#' @param prune.tau Numeric scalar greater than 1, or `NULL`. Multiplicative
#'     threshold for local geometric pruning. If `NULL`, defaults to
#'     `max(1 + max.path.edge.ratio.deviation.thld, 1.05)`.
#'
#' @param prune.local.k Integer scalar or `NULL`. Number of nearest neighbors
#'     used to form local neighborhoods for local geometric pruning. Defaults
#'     to `k`.
#'
#' @param path.edge.ratio.percentile Numeric in \eqn{[0,1]}. Only edges with
#'     length above this percentile are considered for geometric pruning.
#'
#' @param threshold.percentile Numeric in \eqn{[0, 0.5]}. Percentile threshold for
#'     quantile-based edge length pruning. Default is 0 (no quantile pruning).
#'     When greater than 0, edges in the top (1 - threshold.percentile) quantile
#'     by length are removed if their removal preserves graph connectivity.
#'     For example, threshold.percentile = 0.9 removes edges in the top 10\% by length.
#'     This pruning is applied after geometric pruning and targets unusually long edges
#'     based on absolute edge lengths rather than path-to-edge ratios.
#'
#' @param compute.full Logical scalar controlling additional full-payload outputs.
#'        If TRUE, keeps legacy original-graph components `isize_list` and
#'        `conn_comps`. Lifecycle graph payloads are always returned:
#'        `raw_adj_list`/`raw_weight_list`, `pruned_adj_list`/`pruned_weight_list`,
#'        and final `adj_list`/`weight_list`.
#'
#' @param with.isize.pruning Logical scalar. If TRUE, compute intersection-size pruning
#'        outputs and related statistics. Default is FALSE.
#'
#' @param with.edge.pruning.stats Logical scalar. If TRUE, compute edge-level pruning
#'        statistics. Default is FALSE.
#'
#' @param pca.dim Maximum number of principal components to use if dimensionality reduction
#'        is applied (default: 100). Set to NULL to skip dimensionality reduction.
#'
#' @param variance.explained Percentage of variance to be explained by the principal components
#'        (default: 0.99). If this threshold can be met with fewer components than pca.dim,
#'        the smaller number will be used. Set to NULL to use exactly pca.dim components.
#'
#' @param knn.metric Character scalar specifying the geometry used for kNN search.
#'        \code{"euclidean"} uses ordinary ambient Euclidean distance.
#'        \code{"linf.simplex"} uses the unfolded intrinsic metric on the
#'        \eqn{L^\infty}-simplex and requires rows of \code{X} to be
#'        \eqn{L^\infty}-normalized.
#'
#' @param linf.tol Positive numeric tolerance used only when
#'        \code{knn.metric = "linf.simplex"} to identify active simplex faces
#'        and validate that \code{max(row) = 1}.
#'
#' @param connect.components Logical scalar. If TRUE, add MST bridge edges to
#'        the final pruned graph so it is connected whenever possible. Currently
#'        supported only with \code{knn.metric = "euclidean"}.
#'
#' @param connect.method Character scalar. \code{"component.mst"} adds exact
#'        shortest inter-component bridges. \code{"component.mst.ann"} tries
#'        sparse ANN bridge candidates before automatic exact fallback.
#'        \code{"global.mst"} unions the graph with the full Euclidean MST.
#'
#' @param bridge.k Integer scalar or NULL. Initial ANN bridge neighborhood size
#'        for \code{connect.method = "component.mst.ann"}.
#'
#' @param bridge.k.max Integer scalar or NULL. Maximum ANN bridge neighborhood
#'        size before exact fallback.
#'
#' @param bridge.growth Numeric scalar greater than 1. Multiplicative growth
#'        factor for ANN bridge neighborhoods.
#'
#' @param with.lifecycle.branches Logical scalar. If TRUE, compute the
#'        additional repaired lifecycle branches
#'        \code{raw_repaired_*}, \code{pruned_repaired_*}, and
#'        \code{repaired_pruned_*}. This is useful for graph-geodesic
#'        reconstruction experiments but can be expensive for the historical
#'        global iKNN pruning path, so the default is FALSE.
#'
#' @param knn.cache.path Optional character scalar path to a binary kNN cache file.
#'        Used only when `knn.cache.mode != "none"`.
#'
#' @param knn.cache.mode Character cache mode:
#'   \itemize{
#'     \item \code{"none"}: always compute kNN; do not read/write cache.
#'     \item \code{"read"}: read kNN from cache only; if cache is missing/invalid, error.
#'     \item \code{"write"}: always compute kNN and atomically write/overwrite cache.
#'     \item \code{"readwrite"}: read valid cache when available; if cache file is missing,
#'       compute and write cache; if cache exists but is invalid, error.
#'   }
#'
#' @param verbose Logical. If TRUE, print progress messages. Default is TRUE.
#'
#' @return An object of class "IkNN" (inheriting from "list") containing:
#' \describe{
#'   \item{adj_list}{Adjacency lists for the final graph after optional MST repair}
#'   \item{weight_list}{Edge weights for the final graph}
#'   \item{raw_adj_list}{Adjacency lists for the native graph before pruning}
#'   \item{raw_weight_list}{Edge weights for the native graph before pruning}
#'   \item{pruned_adj_list}{Adjacency lists after pruning and before MST repair}
#'   \item{pruned_weight_list}{Edge weights after pruning and before MST repair}
#'   \item{raw_repaired_adj_list, raw_repaired_weight_list}{The native graph
#'     after MST component repair.}
#'   \item{pruned_repaired_adj_list, pruned_repaired_weight_list}{The
#'     prune-first branch after MST component repair.}
#'   \item{repaired_pruned_adj_list, repaired_pruned_weight_list}{The
#'     repair-first branch after applying the selected pruning method to the
#'     repaired raw graph.}
#'   \item{n_edges}{Total number of edges in original graph}
#'   \item{n_edges_in_pruned_graph}{Number of edges after pruning}
#'   \item{n_removed_edges}{Number of edges removed by pruning}
#'   \item{edge_reduction_ratio}{Proportion of edges removed}
#'   \item{call}{The matched function call}
#'   \item{k}{Number of nearest neighbors used}
#'   \item{n}{Number of data points}
#'   \item{d}{Number of features}
#' }
#'
#' If compute.full = TRUE, additional components include:
#' \describe{
#'   \item{isize_list}{Intersection sizes for original edges}
#'   \item{conn_comps}{Connected components identification}
#'   \item{connected_components}{Alternative format of connected components}
#' }
#'
#' @details
#' `adj_list` and `weight_list` always contain the final graph used by downstream
#' algorithms. `raw_*` fields contain the native graph before pruning, and
#' `pruned_*` fields contain the graph after pruning but before optional MST
#' component repair. If pruning is disabled, `pruned_*` is identical to `raw_*`.
#' The repaired lifecycle branches allow direct comparison of raw, prune-first,
#' and repair-first graph geodesic distances from a single constructor call.
#'
#' @examples
#' # Create sample data
#' set.seed(123)
#' X <- matrix(rnorm(100), ncol = 2)
#' result <- create.single.iknn.graph(X, k = 3)
#' summary(result)
#' @export
create.single.iknn.graph <- function(X,
                                     k,
                                     max.path.edge.ratio.deviation.thld = 0.1,
                                     prune.method = c("global.geodesic", "none", "local.geodesic",
                                                      "global.geodesic.ratio"),
                                     prune.tau = NULL,
                                     prune.local.k = NULL,
                                     path.edge.ratio.percentile = 0.5,
                                     threshold.percentile = 0,
                                     compute.full = FALSE,
                                     with.isize.pruning = FALSE,
                                     with.edge.pruning.stats = FALSE,
                                     pca.dim = 100,
                                     variance.explained = 0.99,
                                     knn.metric = c("euclidean", "linf.simplex"),
                                     linf.tol = sqrt(.Machine$double.eps),
                                     connect.components = FALSE,
                                     connect.method = c("component.mst", "component.mst.ann", "global.mst"),
                                     bridge.k = NULL,
                                     bridge.k.max = NULL,
                                     bridge.growth = 2,
                                     with.lifecycle.branches = FALSE,
                                     verbose = TRUE,
                                     knn.cache.path = NULL,
                                     knn.cache.mode = c("none", "read", "write", "readwrite")) {
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

    n <- nrow(X)
    if (n < 2) {
        stop("X must contain at least 2 data points")
    }

    if (!is.double(X)) {
        storage.mode(X) <- "double"
    }

    knn.metric <- .normalize.knn.metric(knn.metric)
    linf.tol <- .normalize.linf.tol(linf.tol)
    if (!is.logical(connect.components) || length(connect.components) != 1L ||
        is.na(connect.components)) {
        stop("'connect.components' must be TRUE or FALSE.", call. = FALSE)
    }
    connect.method <- match.arg(connect.method)

    if (!is.numeric(k) || length(k) != 1 || k != round(k) || k < 1 || k >= n) {
        stop("k must be a positive integer less than the number of data points")
    }

    if (!is.numeric(max.path.edge.ratio.deviation.thld) || length(max.path.edge.ratio.deviation.thld) != 1)
        stop("max.path.edge.ratio.deviation.thld must be numeric.")
    if (max.path.edge.ratio.deviation.thld < 0 || max.path.edge.ratio.deviation.thld >= 0.2)
        stop("max.path.edge.ratio.deviation.thld must be in [0, 0.2).")
    prune.method <- match.arg(prune.method)

    if (!is.numeric(path.edge.ratio.percentile) || length(path.edge.ratio.percentile) != 1 ||
        path.edge.ratio.percentile < 0 || path.edge.ratio.percentile > 1)
        stop("path.edge.ratio.percentile must be in [0, 1].")

    if (!is.logical(compute.full) || length(compute.full) != 1) {
        stop("compute.full must be a single logical value")
    }
    if (!is.logical(with.isize.pruning) || length(with.isize.pruning) != 1) {
        stop("with.isize.pruning must be a single logical value")
    }
    if (!is.logical(with.edge.pruning.stats) || length(with.edge.pruning.stats) != 1) {
        stop("with.edge.pruning.stats must be a single logical value")
    }
    if (!is.logical(with.lifecycle.branches) || length(with.lifecycle.branches) != 1 ||
        is.na(with.lifecycle.branches)) {
        stop("with.lifecycle.branches must be a single logical value")
    }
    local.prune.tau <- if (is.null(prune.tau)) {
        max(1 + max.path.edge.ratio.deviation.thld, 1.05)
    } else {
        prune.tau
    }
    local.prune.controls <- .normalize.local.prune.controls(
        nrow(X),
        k,
        local.prune.tau,
        prune.local.k,
        with.edge.pruning.stats
    )

    ## Validate threshold.percentile parameter
    if (!is.numeric(threshold.percentile) || length(threshold.percentile) != 1)
        stop("threshold.percentile must be numeric.")
    if (threshold.percentile < 0 || threshold.percentile > 0.5)
        stop("threshold.percentile must be in [0, 0.5].")

    if (!is.logical(compute.full) || length(compute.full) != 1) {
        stop("compute.full must be a single logical value")
    }

    ## Check pca.dim
    if (!is.null(pca.dim)) {
        if (!is.numeric(pca.dim) || length(pca.dim) != 1 || pca.dim < 1 || pca.dim != floor(pca.dim)) {
            stop("pca.dim must be a positive integer or NULL")
        }
    }
    if (identical(knn.metric, "linf.simplex")) {
        if (isTRUE(connect.components)) {
            stop("connect.components is currently supported only when knn.metric = 'euclidean'.",
                 call. = FALSE)
        }
        if (!is.null(pca.dim)) {
            stop("pca.dim must be NULL when knn.metric = 'linf.simplex'.")
        }
        .validate.linf.simplex.input(X, linf.tol)
    }

    ## Check variance.explained
    if (!is.null(variance.explained)) {
        if (!is.numeric(variance.explained) || length(variance.explained) != 1 ||
            variance.explained <= 0 || variance.explained > 1) {
            stop("variance.explained must be a numeric value between 0 and 1, or NULL")
        }
    }

    knn.cache.mode <- match.arg(knn.cache.mode)
    knn.cache.path <- .normalize.knn.cache.path(knn.cache.path, knn.cache.mode)
    knn.metric.id <- .knn.metric.id(knn.metric)
    knn.cache.mode.id <- switch(knn.cache.mode,
                                none = 0L,
                                read = 1L,
                                write = 2L,
                                readwrite = 3L)

    ## PCA (optional)
    pca_info <- NULL
    if (!is.null(pca.dim) && ncol(X) > pca.dim) {
        if (verbose) {
            message("High-dimensional data detected. Performing dimensionality reduction.")
        }

        ## Store original dimensions for reporting
        original_dim <- ncol(X)

        ## If variance.explained is specified, analyze variance
        if (!is.null(variance.explained)) {
            pca_analysis <- pca.optimal.components(X,
                                                   variance.threshold = variance.explained,
                                                   max.components = pca.dim)

            ## Number of components to use (based on variance or pca.dim)
            n_components <- pca_analysis$n.components

            if (verbose) {
                message(sprintf("Using %d principal components (explains %.2f%% of variance)",
                                n_components, pca_analysis$variance.explained * 100))
            }

            ## Project data onto selected components
            X <- pca.project(X, pca_analysis$pca.result, n_components)

            ## Store PCA information
            pca_info <- list(
                original_dim = original_dim,
                n_components = n_components,
                variance_explained = pca_analysis$variance.explained,
                cumulative_variance = pca_analysis$cumulative.variance,
                pca_projected_X = X
            )
        } else {
            ## Use fixed number of components (pca.dim)
            if (verbose) {
                message(sprintf("Projecting data onto first %d principal components", pca.dim))
            }

            ## Perform PCA and projection
            pca_result <- stats::prcomp(X)
            X <- pca.project(X, pca_result, pca.dim)

            ## Calculate variance explained by pca.dim components
            variance_explained <- sum(pca_result$sdev[1:pca.dim]^2) / sum(pca_result$sdev^2)

            ## Store PCA information
            pca_info <- list(
                original_dim = original_dim,
                n_components = pca.dim,
                variance_explained = variance_explained,
                pca_projected_X = X
            )
        }
    }

    if (verbose && !compute.full) {
        message("compute.full=FALSE: legacy isize_list/conn_comps may be omitted; lifecycle graph payloads are still returned.")
    }
    if (verbose && identical(prune.method, "none") && threshold.percentile == 0) {
        message("No geometric/quantile pruning requested: pruned_adj_list/pruned_weight_list will match the unpruned graph.")
    }
    bridge.controls <- .normalize.bridge.controls(nrow(X), k, bridge.k, bridge.k.max, bridge.growth)
    cxx.edge.ratio.threshold <- if (prune.method %in% c("global.geodesic",
                                                        "global.geodesic.ratio")) {
        max.path.edge.ratio.deviation.thld + 1.0
    } else {
        1.0
    }

    result <- .Call("S_create_single_iknn_graph",
                    X,
                    as.integer(k + 1L),
                    as.double(cxx.edge.ratio.threshold),
                    as.double(path.edge.ratio.percentile),
                    as.double(threshold.percentile),
                    TRUE,
                    as.logical(with.isize.pruning),
                    as.logical(with.edge.pruning.stats),
                    if (is.null(knn.cache.path)) NULL else as.character(knn.cache.path),
                    as.integer(knn.cache.mode.id),
                    as.integer(knn.metric.id),
                    as.double(linf.tol),
                    as.logical(verbose),
                    PACKAGE = "dgraphs")
    raw.adj.list <- result$adj_list
    raw.weight.list <- result$weight_list
    raw.isize.list <- result$isize_list
    raw.conn.comps <- result$conn_comps
    if (!isTRUE(compute.full)) {
        result$isize_list <- NULL
        result$conn_comps <- NULL
    }

    if (identical(prune.method, "local.geodesic")) {
        pruning <- .prune.graph.local.geodesic(
            X = X,
            adj.list = result$pruned_adj_list,
            weight.list = result$pruned_weight_list,
            k = k,
            prune.tau = local.prune.controls$prune.tau,
            prune.local.k = local.prune.controls$prune.local.k,
            with.pruned.edge.stats = local.prune.controls$with.pruned.edge.stats
        )
        result$pruned_adj_list <- pruning$adj_list
        result$pruned_weight_list <- pruning$weight_list
        result$n_edges_in_pruned_graph <- pruning$n_edges_after_pruning
        result$n_removed_edges <- result$n_edges - result$n_edges_in_pruned_graph
        result$edge_reduction_ratio <- if (result$n_edges > 0) {
            result$n_removed_edges / result$n_edges
        } else {
            0
        }
    } else {
        pruning <- list(
            n_edges_before_pruning = result$n_edges,
            n_edges_after_pruning = result$n_edges_in_pruned_graph,
            n_pruned_edges = result$n_edges - result$n_edges_in_pruned_graph,
            pruned_edge_stats = .empty.pruned.edge.stats(),
            prune_tau = local.prune.controls$prune.tau,
            prune_local_k = local.prune.controls$prune.local.k,
            with_pruned_edge_stats = local.prune.controls$with.pruned.edge.stats
        )
    }
    result$prune_method <- prune.method
    result$prune_tau <- pruning$prune_tau
    result$prune_local_k <- pruning$prune_local_k
    result$with_pruned_edge_stats <- pruning$with_pruned_edge_stats
    result$n_edges_before_pruning <- pruning$n_edges_before_pruning
    result$n_edges_after_pruning <- pruning$n_edges_after_pruning
    result$n_pruned_edges <- pruning$n_pruned_edges
    result$pruned_edge_stats <- pruning$pruned_edge_stats

    n.edges.before.mst <- result$n_edges_in_pruned_graph
    n.removed.by.pruning <- result$n_removed_edges
    pruning.reduction.ratio <- result$edge_reduction_ratio
    pruned.adj.list <- result$pruned_adj_list
    pruned.weight.list <- result$pruned_weight_list
    bridge <- .augment.graph.with.component.mst(
        X = X,
        adj.list = result$pruned_adj_list,
        weight.list = result$pruned_weight_list,
        k = k,
        connect.components = connect.components,
        connect.method = connect.method,
        bridge.k = bridge.controls$bridge.k,
        bridge.k.max = bridge.controls$bridge.k.max,
        bridge.growth = bridge.controls$bridge.growth
    )
    result$raw_adj_list <- raw.adj.list
    result$raw_weight_list <- raw.weight.list
    result$raw_isize_list <- raw.isize.list
    result$raw_conn_comps <- raw.conn.comps
    result$pruned_adj_list <- pruned.adj.list
    result$pruned_weight_list <- pruned.weight.list
    result$adj_list <- bridge$adj_list
    result$weight_list <- bridge$weight_list
    if (isTRUE(with.lifecycle.branches)) {
        result <- .add.graph.lifecycle.branches(
            result = result,
            X = X,
            k = k,
            raw.adj.list = result$raw_adj_list,
            raw.weight.list = result$raw_weight_list,
            pruned.adj.list = result$pruned_adj_list,
            pruned.weight.list = result$pruned_weight_list,
            connect.method = connect.method,
            bridge.k = bridge.controls$bridge.k,
            bridge.k.max = bridge.controls$bridge.k.max,
            bridge.growth = bridge.controls$bridge.growth,
            prune.method = prune.method,
            max.path.edge.ratio.deviation.thld = max.path.edge.ratio.deviation.thld,
            path.edge.ratio.percentile = path.edge.ratio.percentile,
            threshold.percentile = threshold.percentile,
            prune.tau = local.prune.controls$prune.tau,
            prune.local.k = local.prune.controls$prune.local.k,
            with.pruned.edge.stats = local.prune.controls$with.pruned.edge.stats
        )
    } else {
        result["raw_repaired_adj_list"] <- list(NULL)
        result["raw_repaired_weight_list"] <- list(NULL)
        result["pruned_repaired_adj_list"] <- list(NULL)
        result["pruned_repaired_weight_list"] <- list(NULL)
        result["repaired_pruned_adj_list"] <- list(NULL)
        result["repaired_pruned_weight_list"] <- list(NULL)
    }
    result$n_edges_in_pruned_graph <- sum(lengths(result$pruned_adj_list)) / 2
    result$n_removed_edges <- n.removed.by.pruning
    result$edge_reduction_ratio <- pruning.reduction.ratio
    result$n_edges_before_mst <- n.edges.before.mst
    result$n_edges_after_mst <- sum(lengths(result$adj_list)) / 2
    result$n_components_before_mst <- bridge$n_components_before
    result$n_components_after_mst <- bridge$n_components_after
    result$component_id_before_mst <- bridge$component_id_before
    result$component_id_after_mst <- bridge$component_id_after
    result$mst_edge_matrix <- bridge$mst_edge_matrix
    result$mst_edge_weight <- bridge$mst_edge_weight
    result$n_mst_edges_added <- bridge$n_mst_edges_added
    result$connect_components <- bridge$connect_components
    result$connect_method <- bridge$connect_method
    result$bridge_method <- bridge$bridge_method
    result$bridge_k <- bridge$bridge_k
    result$bridge_k_max <- bridge$bridge_k_max
    result$bridge_growth <- bridge$bridge_growth
    result$bridge_k_used <- bridge$bridge_k_used
    result$bridge_exact_fallback_used <- bridge$bridge_exact_fallback_used

    attr(result, "k") <- k
    attr(result, "max.path.edge.ratio.deviation.thld") <- max.path.edge.ratio.deviation.thld
    attr(result, "path.edge.ratio.percentile") <- path.edge.ratio.percentile
    attr(result, "with.isize.pruning") <- with.isize.pruning
    attr(result, "with.edge.pruning.stats") <- with.edge.pruning.stats
    attr(result, "with.lifecycle.branches") <- with.lifecycle.branches
    attr(result, "knn.metric") <- knn.metric
    attr(result, "linf.tol") <- linf.tol
    attr(result, "call") <- match.call()

    ## Add PCA-related attributes if PCA was performed
    if (!is.null(pca_info)) {
        attr(result, "pca") <- pca_info
    }

    class(result) <- c("IkNN", "list")

    return(result)
}

#' Summarize IkNN Graph Object
#'
#' @description
#' Prints a summary of an IkNN graph object, including the number of vertices,
#' edges, and pruning statistics.
#'
#' @param object An object of class "IkNN", typically output from create.single.iknn.graph()
#' @param ... Additional arguments passed to summary().
#'
#' @return Invisibly returns NULL while printing summary information to the console
#'
#' @examples
#' graph <- list(
#'   pruned_adj_list = list(c(2L, 3L), c(1L, 3L), c(1L, 2L)),
#'   n_edges = 3L,
#'   n_pruned_edges = 2L,
#'   n_removed_edges = 1L,
#'   edge_reduction_ratio = 1 / 3
#' )
#' class(graph) <- c("IkNN", "list")
#'
#' summary(graph)
#'
#' @method summary IkNN
#' @export
summary.IkNN <- function(object, ...) {
    adj.list <- object$adj_list
    if (is.null(adj.list)) {
        adj.list <- object$pruned_adj_list
    }
    final.edges <- if (is.null(adj.list)) NA_real_ else sum(lengths(adj.list)) / 2
    cat("Graph Summary:\n")
    cat("Number of vertices:", length(adj.list), "\n")
    cat("Number of edges:", object$n_edges, "\n")                  # Total number of edges in the original graph
    cat("Number of edges after pruning:", object$n_pruned_edges, "\n")    # Number of edges after pruning
    cat("Number of edges in final graph:", final.edges, "\n")      # Number of edges after optional MST repair
    cat("Number of removed edges:", object$n_removed_edges, "\n")  # Number of edges removed during pruning
    cat("Proportion of edges removed:", object$edge_reduction_ratio,"\n") # Proportion of edges removed (n_removed_edges / n_edges)
}
