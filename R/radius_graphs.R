.validate.numeric.data.matrix <- function(X) {
    if (!(is.matrix(X) || is.data.frame(X))) {
        stop("'X' must be a matrix or data frame.", call. = FALSE)
    }
    X <- as.matrix(X)
    if (!is.numeric(X)) {
        stop("'X' must contain numeric data.", call. = FALSE)
    }
    if (any(!is.finite(X))) {
        stop("'X' cannot contain NA, NaN, or Inf values.", call. = FALSE)
    }
    if (nrow(X) < 2L) {
        stop("'X' must contain at least two observations.", call. = FALSE)
    }
    if (!is.double(X)) {
        storage.mode(X) <- "double"
    }
    X
}

.pairwise.radius.edges <- function(X, keep.edge) {
    n <- nrow(X)
    rows <- vector("list", n * (n - 1L) / 2L)
    cursor <- 0L
    for (i in seq_len(n - 1L)) {
        for (j in (i + 1L):n) {
            d <- .euclidean.distance(X, i, j)
            if (keep.edge(i, j, d)) {
                cursor <- cursor + 1L
                rows[[cursor]] <- data.frame(from = i, to = j, weight = d)
            }
        }
    }
    if (!cursor) {
        return(data.frame(from = integer(), to = integer(), weight = numeric()))
    }
    do.call(rbind, rows[seq_len(cursor)])
}

.adaptive.radius.edges.ann <- function(X, k.scale, radius.factor, radius.rule) {
    radius.rule.id <- switch(radius.rule,
                             max = 0L,
                             min = 1L,
                             geomean = 2L)
    out <- .Call(
        "S_adaptive_radius_edges_ann",
        X,
        as.integer(k.scale),
        as.double(radius.factor),
        as.integer(radius.rule.id),
        PACKAGE = "dgraphs"
    )
    edges <- out$edges
    if (!nrow(edges)) {
        edges <- data.frame(from = integer(), to = integer(), weight = numeric())
    }
    list(edges = edges, sigma = as.numeric(out$sigma), timing = out$timing)
}

.adaptive.radius.graphs.ann <- function(X, k.values, radius.factor, radius.rule) {
    radius.rule.id <- switch(radius.rule,
                             max = 0L,
                             min = 1L,
                             geomean = 2L)
    out <- .Call(
        "S_adaptive_radius_edges_ann_graphs",
        X,
        as.integer(k.values),
        as.double(radius.factor),
        as.integer(radius.rule.id),
        PACKAGE = "dgraphs"
    )
    for (i in seq_along(out$edges)) {
        if (!nrow(out$edges[[i]])) {
            out$edges[[i]] <- data.frame(
                from = integer(),
                to = integer(),
                weight = numeric()
            )
        }
    }
    out$sigma <- lapply(out$sigma, as.numeric)
    out
}

.radius.graph.timing.frame <- function(named.seconds) {
    data.frame(
        phase = names(named.seconds),
        elapsed.sec = as.numeric(named.seconds),
        stringsAsFactors = FALSE
    )
}

.default.radius.prune.k <- function(adj.list) {
    n <- length(adj.list)
    degree <- lengths(adj.list)
    positive.degree <- degree[degree > 0L]
    if (!length(positive.degree)) {
        return(1L)
    }
    as.integer(min(n - 1L, max(1L, round(stats::median(positive.degree)))))
}

.finalize.radius.graph <- function(X,
                                   edges,
                                   connect.components,
                                   connect.method,
                                   bridge.k,
                                   bridge.k.max,
                                   bridge.growth,
                                   class,
                                   prune.method = "none",
                                   max.path.edge.ratio.deviation.thld = 0.1,
                                   path.edge.ratio.percentile = 0.5,
                                   prune.tau = 1.05,
                                   prune.local.k = NULL,
                                   prune.k = 1L,
                                   with.pruned.edge.stats = FALSE,
                                   return.timing = FALSE,
                                   graph.detail = "full") {
    return.timing <- isTRUE(return.timing)
    graph.detail <- match.arg(graph.detail, c("full", "minimal"))
    timing.rows <- list()
    timing.phase.start <- proc.time()[["elapsed"]]
    add.timing <- function(phase) {
        if (!return.timing) {
            return(invisible(NULL))
        }
        timing.rows[[phase]] <<- .radius.graph.timing.frame(c(
            stats::setNames(proc.time()[["elapsed"]] - timing.phase.start, phase)
        ))
        timing.phase.start <<- proc.time()[["elapsed"]]
        invisible(NULL)
    }

    n <- nrow(X)
    graph <- .graph.from.edge.table(n, edges)
    raw.adj.list <- graph$adj_list
    raw.weight.list <- graph$weight_list
    add.timing("finalization.edge.table.to.adjacency")

    prune.method <- .normalize.prune.method(prune.method)
    prune.controls <- .normalize.local.prune.controls(
        n, prune.k, prune.tau, prune.local.k, with.pruned.edge.stats
    )
    global.ratio.controls <- .normalize.global.ratio.prune.controls(
        max.path.edge.ratio.deviation.thld,
        path.edge.ratio.percentile
    )
    add.timing("finalization.normalize.controls")

    if (identical(graph.detail, "minimal")) {
        if (!identical(prune.method, "none") || isTRUE(connect.components)) {
            stop("graph.detail = 'minimal' requires prune.method = 'none' and connect.components = FALSE.",
                 call. = FALSE)
        }
        components <- .graph.components(raw.adj.list)
        edge.table <- edges
        if (!nrow(edge.table)) {
            edge.table <- data.frame(from = integer(), to = integer(),
                                     weight = numeric())
        }
        add.timing("finalization.minimal.components")
        out <- list(
            adj_list = raw.adj.list,
            weight_list = raw.weight.list,
            edge_matrix = as.matrix(edge.table[, c("from", "to"), drop = FALSE]),
            edge_weight = as.numeric(edge.table$weight),
            n_vertices = n,
            n_edges = nrow(edge.table),
            raw_adj_list = raw.adj.list,
            raw_weight_list = raw.weight.list,
            pruned_adj_list = raw.adj.list,
            pruned_weight_list = raw.weight.list,
            n_edges_before_mst = nrow(edge.table),
            n_edges_after_mst = nrow(edge.table),
            n_components_before = components$n_components,
            n_components_after = components$n_components,
            component_id_before = components$component_id,
            component_id_after = components$component_id,
            mst_edge_matrix = matrix(integer(), ncol = 2L),
            mst_edge_weight = numeric(),
            n_mst_edges_added = 0L,
            connect_components = FALSE,
            connect_method = connect.method,
            bridge_method = "none",
            bridge_k = NA_integer_,
            bridge_k_max = NA_integer_,
            bridge_growth = if (is.null(bridge.growth)) NA_real_
                            else as.numeric(bridge.growth),
            bridge_k_used = NA_integer_,
            bridge_exact_fallback_used = FALSE,
            n_edges_before_pruning = nrow(edge.table),
            n_edges_after_pruning = nrow(edge.table),
            n_pruned_edges = 0L,
            n_quantile_pruned_edges = 0L,
            pruned_edge_stats = .empty.pruned.edge.stats(),
            prune_method = prune.method,
            prune_tau = prune.controls$prune_tau,
            prune_local_k = prune.controls$prune_local_k,
            with_pruned_edge_stats = prune.controls$with_pruned_edge_stats,
            graph_detail = graph.detail,
            lifecycle_branches = FALSE
        )
        class(out) <- c(class, "list")
        add.timing("finalization.class.assignment")
        if (return.timing) {
            timing <- do.call(rbind, timing.rows)
            rownames(timing) <- NULL
            out$finalization_timing <- timing
        }
        return(out)
    }

    pruning <- .prune.graph.by.method(
        X = X,
        adj.list = raw.adj.list,
        weight.list = raw.weight.list,
        k = prune.k,
        prune.method = prune.method,
        max.path.edge.ratio.deviation.thld =
            global.ratio.controls$max.path.edge.ratio.deviation.thld,
        path.edge.ratio.percentile = global.ratio.controls$path.edge.ratio.percentile,
        prune.tau = prune.controls$prune.tau,
        prune.local.k = prune.controls$prune.local.k,
        with.pruned.edge.stats = prune.controls$with.pruned.edge.stats
    )
    pruned.adj.list <- pruning$adj_list
    pruned.weight.list <- pruning$weight_list
    n.edges.before.mst <- pruning$n_edges_after_pruning
    add.timing("finalization.prune")

    bridge <- .augment.graph.with.component.mst(
        X = X,
        adj.list = pruned.adj.list,
        weight.list = pruned.weight.list,
        k = prune.k,
        connect.components = connect.components,
        connect.method = connect.method,
        bridge.k = bridge.k,
        bridge.k.max = bridge.k.max,
        bridge.growth = bridge.growth
    )
    add.timing("finalization.component.mst")

    edge.table <- .graph.edge.table(bridge$adj_list, bridge$weight_list)
    add.timing("finalization.final.edge.table")

    out <- list(
        adj_list = bridge$adj_list,
        weight_list = bridge$weight_list,
        edge_matrix = as.matrix(edge.table[, c("from", "to"), drop = FALSE]),
        edge_weight = as.numeric(edge.table$weight),
        n_vertices = n,
        n_edges = nrow(edge.table),
        raw_adj_list = raw.adj.list,
        raw_weight_list = raw.weight.list,
        pruned_adj_list = pruned.adj.list,
        pruned_weight_list = pruned.weight.list,
        n_edges_before_mst = n.edges.before.mst,
        n_edges_after_mst = nrow(edge.table),
        n_components_before = bridge$n_components_before,
        n_components_after = bridge$n_components_after,
        component_id_before = bridge$component_id_before,
        component_id_after = bridge$component_id_after,
        mst_edge_matrix = bridge$mst_edge_matrix,
        mst_edge_weight = bridge$mst_edge_weight,
        n_mst_edges_added = bridge$n_mst_edges_added,
        connect_components = bridge$connect_components,
        connect_method = bridge$connect_method,
        bridge_method = bridge$bridge_method,
        bridge_k = bridge$bridge_k,
        bridge_k_max = bridge$bridge_k_max,
        bridge_growth = bridge$bridge_growth,
        bridge_k_used = bridge$bridge_k_used,
        bridge_exact_fallback_used = bridge$bridge_exact_fallback_used,
        n_edges_before_pruning = pruning$n_edges_before_pruning,
        n_edges_after_pruning = pruning$n_edges_after_pruning,
        n_pruned_edges = pruning$n_pruned_edges,
        pruned_edge_stats = pruning$pruned_edge_stats,
        prune_method = prune.method,
        prune_tau = pruning$prune_tau,
        prune_local_k = pruning$prune_local_k,
        with_pruned_edge_stats = pruning$with_pruned_edge_stats,
        graph_detail = graph.detail,
        lifecycle_branches = TRUE
    )
    add.timing("finalization.object.assembly")

    out <- .add.graph.lifecycle.branches(
        result = out,
        X = X,
        k = prune.k,
        raw.adj.list = out$raw_adj_list,
        raw.weight.list = out$raw_weight_list,
        pruned.adj.list = out$pruned_adj_list,
        pruned.weight.list = out$pruned_weight_list,
        connect.method = connect.method,
        bridge.k = bridge$bridge_k,
        bridge.k.max = bridge$bridge_k_max,
        bridge.growth = bridge$bridge_growth,
        prune.method = prune.method,
        max.path.edge.ratio.deviation.thld =
            global.ratio.controls$max.path.edge.ratio.deviation.thld,
        path.edge.ratio.percentile = global.ratio.controls$path.edge.ratio.percentile,
        prune.tau = prune.controls$prune.tau,
        prune.local.k = prune.controls$prune.local.k,
        with.pruned.edge.stats = prune.controls$with.pruned.edge.stats
    )
    add.timing("finalization.lifecycle.branches")

    class(out) <- c(class, "list")
    add.timing("finalization.class.assignment")
    if (return.timing) {
        timing <- do.call(rbind, timing.rows)
        rownames(timing) <- NULL
        out$finalization_timing <- timing
    }
    out
}

#' Compute a Radius-kNN Graph
#'
#' @description
#' Creates an undirected Euclidean radius graph from a numeric data matrix.
#' Use `type = "fixed"` for a fixed-radius graph, where vertices `i` and `j`
#' are adjacent exactly when their Euclidean distance is at most `radius`. Use
#' `type = "adaptive.radius"` for an adaptive-radius graph based on
#' observation-specific local scale distances.
#'
#' @param X Numeric matrix or data frame with observations in rows.
#' @param type Character scalar. `"fixed"` builds a fixed-radius graph using
#'   `radius`. `"adaptive.radius"` builds an adaptive-radius graph using
#'   `k.scale`, `radius.factor`, and `radius.rule`.
#' @param radius Positive numeric scalar. Edges are included when
#'   \eqn{\|x_i - x_j\|_2 \le radius}. Required for `type = "fixed"`.
#' @param k.scale Positive integer smaller than `nrow(X)`. Defines local scale
#'   distances \eqn{\sigma_i}. Required for `type = "adaptive.radius"`.
#' @param radius.factor Positive numeric scalar multiplying the adaptive radius.
#' @param radius.rule Character scalar. `"max"` uses
#'   \eqn{d_{ij} \le radius.factor \max(\sigma_i,\sigma_j)}; `"min"` uses
#'   \eqn{d_{ij} \le radius.factor \min(\sigma_i,\sigma_j)}; and
#'   `"geomean"` uses
#'   \eqn{d_{ij} \le radius.factor \sqrt{\sigma_i\sigma_j}}. The
#'   `"geomean"` rule is the continuous-kNN support rule.
#' @param radius.search Character scalar. `"ann"` uses the bundled ANN kd-tree
#'   to perform exact fixed-radius candidate searches before applying the
#'   pair-specific adaptive-radius rule. `"all.pairs"` uses the direct
#'   \eqn{O(n^2)} pair scan and is retained as a reference path. Used only for
#'   `type = "adaptive.radius"`.
#' @param return.timing Logical scalar. If `TRUE`, attach a construction timing
#'   table for adaptive-radius graphs.
#' @param graph.detail Character scalar. `"full"` returns the complete graph
#'   lifecycle object for adaptive-radius graphs. `"minimal"` returns only the
#'   graph fields needed by fitting code and is currently allowed only for
#'   adaptive-radius graphs with `prune.method = "none"` and
#'   `connect.components = FALSE`.
#' @param connect.components Logical scalar. If `TRUE`, add MST bridge edges so
#'   the final graph is connected whenever possible.
#' @param connect.method Character scalar. `"component.mst"` adds exact shortest
#'   inter-component bridges. `"component.mst.ann"` tries sparse ANN bridge
#'   candidates before automatic exact fallback. `"global.mst"` unions the graph
#'   with the full Euclidean MST.
#' @param bridge.k Integer scalar or `NULL`. Initial ANN bridge neighborhood
#'   size for `connect.method = "component.mst.ann"`.
#' @param bridge.k.max Integer scalar or `NULL`. Maximum ANN bridge neighborhood
#'   size before exact fallback.
#' @param bridge.growth Numeric scalar greater than 1. Multiplicative growth
#'   factor for ANN bridge neighborhoods.
#' @param prune.method Character scalar. `"none"` disables geometric pruning.
#'   `"local.geodesic"` applies the experimental local geometric pruning stage
#'   before optional MST connectivity repair. `"global.geodesic.ratio"` applies
#'   whole-graph geodesic-ratio pruning before optional MST connectivity repair.
#' @param max.path.edge.ratio.deviation.thld Numeric scalar in `[0, 0.2)`.
#'   For `prune.method = "global.geodesic.ratio"`, an edge may be removed when
#'   the shortest alternative path is at most
#'   `1 + max.path.edge.ratio.deviation.thld` times the direct edge length.
#' @param path.edge.ratio.percentile Numeric scalar in `[0, 1]`. For
#'   `prune.method = "global.geodesic.ratio"`, only edges at or above this edge
#'   length percentile are considered.
#' @param prune.tau Numeric scalar greater than 1. For local geometric pruning,
#'   an edge may be removed when a retained local alternative path is at most
#'   this multiplicative factor times the direct edge length.
#' @param prune.local.k Integer scalar or `NULL`. Number of nearest neighbors
#'   used to form local neighborhoods for pruning. For fixed-radius graphs,
#'   `NULL` uses the median positive raw graph degree, clipped to `[1, n - 1]`.
#'   For adaptive-radius graphs, `NULL` defaults to `k.scale`.
#' @param with.pruned.edge.stats Logical scalar. If `TRUE`, return a data frame
#'   with one row per locally pruned edge.
#'
#' @return For `type = "fixed"`, a list of class `"radius_graph"`. For
#'   `type = "adaptive.radius"`, a list of class `"adaptive_radius_graph"`.
#'   Both contain adjacency lists, edge weights, edge matrix, and component
#'   diagnostics. The final graph is stored in `adj_list`/`weight_list`; raw
#'   and pruned lifecycle graph stages are stored in corresponding
#'   `raw_*`/`pruned_*` fields when `graph.detail = "full"`.
#'
#' @examples
#' X <- matrix(c(0, 1, 3), ncol = 1)
#' create.rknn.graph(X, type = "fixed", radius = 1.1)$edge_matrix
#' create.rknn.graph(X, type = "adaptive.radius", k.scale = 1)$edge_matrix
#'
#' @export
create.rknn.graph <- function(X,
                              type = c("fixed", "adaptive.radius"),
                              radius = NULL,
                              k.scale = NULL,
                              radius.factor = 1,
                              radius.rule = c("max", "min", "geomean"),
                              radius.search = c("ann", "all.pairs"),
                              return.timing = FALSE,
                              graph.detail = c("full", "minimal"),
                              prune.method = c("none", "local.geodesic", "global.geodesic.ratio"),
                              max.path.edge.ratio.deviation.thld = 0.1,
                              path.edge.ratio.percentile = 0.5,
                              prune.tau = 1.05,
                              prune.local.k = NULL,
                              with.pruned.edge.stats = FALSE,
                              connect.components = FALSE,
                              connect.method = c("component.mst", "component.mst.ann", "global.mst"),
                              bridge.k = NULL,
                              bridge.k.max = NULL,
                              bridge.growth = 2) {
    type <- match.arg(type)
    if (identical(type, "fixed")) {
        if (is.null(radius)) {
            stop("'radius' is required when type = 'fixed'.", call. = FALSE)
        }
        return(.create.radius.graph(
            X = X,
            radius = radius,
            prune.method = prune.method,
            max.path.edge.ratio.deviation.thld = max.path.edge.ratio.deviation.thld,
            path.edge.ratio.percentile = path.edge.ratio.percentile,
            prune.tau = prune.tau,
            prune.local.k = prune.local.k,
            with.pruned.edge.stats = with.pruned.edge.stats,
            connect.components = connect.components,
            connect.method = connect.method,
            bridge.k = bridge.k,
            bridge.k.max = bridge.k.max,
            bridge.growth = bridge.growth
        ))
    }

    if (is.null(k.scale)) {
        stop("'k.scale' is required when type = 'adaptive.radius'.",
             call. = FALSE)
    }
    .create.adaptive.radius.graph(
        X = X,
        k.scale = k.scale,
        radius.factor = radius.factor,
        radius.rule = radius.rule,
        radius.search = radius.search,
        return.timing = return.timing,
        graph.detail = graph.detail,
        prune.method = prune.method,
        max.path.edge.ratio.deviation.thld = max.path.edge.ratio.deviation.thld,
        path.edge.ratio.percentile = path.edge.ratio.percentile,
        prune.tau = prune.tau,
        prune.local.k = prune.local.k,
        with.pruned.edge.stats = with.pruned.edge.stats,
        connect.components = connect.components,
        connect.method = connect.method,
        bridge.k = bridge.k,
        bridge.k.max = bridge.k.max,
        bridge.growth = bridge.growth
    )
}

#' Compute Adaptive Radius-kNN Graphs Across k Values
#'
#' @description
#' Creates a sequence of adaptive-radius graphs by varying the `k.scale`
#' parameter passed to `create.rknn.graph(type = "adaptive.radius")`. This is
#' an R-level convenience constructor: each returned graph is constructed by
#' the scalar adaptive-radius path and is therefore intended to match the
#' corresponding `create.rknn.graph(..., k.scale = k)` result exactly.
#'
#' @param X Numeric matrix or data frame with observations in rows.
#' @param kmin,kmax Optional integer scalars defining the inclusive k range.
#'   Required when `k.values` is `NULL`.
#' @param ... Additional arguments forwarded to `create.rknn.graph()` with
#'   `type = "adaptive.radius"`. The arguments `type`, `k.scale`, and `radius`
#'   are reserved by this plural constructor.
#' @param k.values Optional integer vector of k values to evaluate. When
#'   supplied, `k.values` is used instead of `kmin:kmax`, and the returned
#'   graph order follows the supplied vector.
#'
#' @return A list of class `"rknn_graphs"` with components:
#'   \describe{
#'     \item{graphs}{A named list of adaptive-radius graph objects, one per k.}
#'     \item{k_statistics}{A data frame with one row per k containing edge,
#'       component, and MST-repair counts.}
#'     \item{timing}{Present only when forwarded options request graph timing;
#'       contains per-k timing rows from the scalar constructor.}
#'   }
#'   Attributes include `kmin`, `kmax`, `k.values`, and `n_vertices`.
#'
#' @examples
#' X <- matrix(c(0, 1, 3, 4), ncol = 1)
#' result <- create.rknn.graphs(
#'   X,
#'   kmin = 1,
#'   kmax = 2,
#'   radius.search = "all.pairs",
#'   graph.detail = "minimal",
#'   prune.method = "none"
#' )
#' names(result$graphs)
#' result$k_statistics
#'
#' @seealso [create.rknn.graph()]
#'
#' @export
create.rknn.graphs <- function(X, kmin = NULL, kmax = NULL, ...,
                               k.values = NULL) {
    X <- .validate.numeric.data.matrix(X)
    n <- nrow(X)
    k.values <- .normalize.rknn.graphs.k.values(kmin, kmax, k.values, n)

    args <- list(...)
    if ("k.scale" %in% names(args)) {
        stop("'k.scale' is varied by create.rknn.graphs(); use 'kmin', 'kmax', or 'k.values'.",
             call. = FALSE)
    }
    if ("radius" %in% names(args)) {
        stop("'radius' is for fixed-radius graphs; create.rknn.graphs() varies k.scale for adaptive-radius graphs.",
             call. = FALSE)
    }
    if ("type" %in% names(args)) {
        if (!is.character(args$type) || length(args$type) != 1L ||
            !identical(args$type, "adaptive.radius")) {
            stop("'type' must be omitted or set to 'adaptive.radius' in create.rknn.graphs().",
                 call. = FALSE)
        }
        args$type <- NULL
    }

    graphs <- vector("list", length(k.values))
    names(graphs) <- as.character(k.values)
    for (i in seq_along(k.values)) {
        graphs[[i]] <- do.call(
            create.rknn.graph,
            c(list(
                X = X,
                type = "adaptive.radius",
                k.scale = k.values[[i]]
            ), args)
        )
    }

    out <- list(
        graphs = graphs,
        k_statistics = .rknn.graphs.k.statistics(graphs, k.values)
    )
    timing <- .rknn.graphs.timing(graphs, k.values)
    if (!is.null(timing)) {
        out$timing <- timing
    }

    attr(out, "kmin") <- min(k.values)
    attr(out, "kmax") <- max(k.values)
    attr(out, "k.values") <- k.values
    attr(out, "n_vertices") <- n
    attr(out, "graph_rule") <- "adaptive.radius"
    class(out) <- c("rknn_graphs", "list")
    out
}

#' Compute Adaptive Radius-kNN Graphs With Batched ANN Search
#'
#' @description
#' Tentative C++-backed counterpart to `create.rknn.graphs()`. It builds one
#' ANN kd-tree, computes nearest-neighbor distances through the maximal
#' requested k value once, derives each requested `k.scale` from that shared
#' result, and materializes adaptive-radius edge tables for all k values in
#' C++. The existing R finalization path is then used for pruning, lifecycle
#' branches, and optional component repair.
#'
#' This function is intentionally named `cpp.create.rknn.graphs()` while the
#' native backend is being validated against `create.rknn.graphs()`. For
#' ordinary use, prefer `create.rknn.graphs()` until the backend selection API
#' is finalized.
#'
#' @inheritParams create.rknn.graphs
#'
#' @return A `"rknn_graphs"` object with the same default structure as
#'   `create.rknn.graphs()`. When `return.timing = TRUE`, timing is attached at
#'   the graph-sequence level because the ANN setup and max-k scale search are
#'   shared across k values.
#'
#' @examples
#' X <- matrix(c(0, 1, 3, 4), ncol = 1)
#' result <- cpp.create.rknn.graphs(
#'   X,
#'   k.values = c(1, 2),
#'   graph.detail = "minimal",
#'   prune.method = "none"
#' )
#' names(result$graphs)
#'
#' @seealso [create.rknn.graphs()]
#'
#' @export
cpp.create.rknn.graphs <- function(X, kmin = NULL, kmax = NULL, ...,
                                   k.values = NULL) {
    X <- .validate.numeric.data.matrix(X)
    n <- nrow(X)
    k.values <- .normalize.rknn.graphs.k.values(kmin, kmax, k.values, n)
    controls <- .normalize.cpp.rknn.graphs.controls(list(...))

    ann <- .adaptive.radius.graphs.ann(
        X = X,
        k.values = k.values,
        radius.factor = controls$radius.factor,
        radius.rule = controls$radius.rule
    )

    graphs <- vector("list", length(k.values))
    names(graphs) <- as.character(k.values)
    timing.rows <- list()
    if (controls$return.timing) {
        timing.rows[["ann"]] <- data.frame(
            k = NA_integer_,
            .radius.graph.timing.frame(ann$timing),
            stringsAsFactors = FALSE
        )
    }

    for (i in seq_along(k.values)) {
        k <- as.integer(k.values[[i]])
        graph <- .finalize.radius.graph(
            X, ann$edges[[i]], controls$connect.components,
            controls$connect.method, controls$bridge.k,
            controls$bridge.k.max, controls$bridge.growth,
            "adaptive_radius_graph",
            prune.method = controls$prune.method,
            max.path.edge.ratio.deviation.thld =
                controls$max.path.edge.ratio.deviation.thld,
            path.edge.ratio.percentile = controls$path.edge.ratio.percentile,
            prune.tau = controls$prune.tau,
            prune.local.k = controls$prune.local.k,
            prune.k = k,
            with.pruned.edge.stats = controls$with.pruned.edge.stats,
            return.timing = controls$return.timing,
            graph.detail = controls$graph.detail
        )
        graph$k_scale <- k
        graph$radius_factor <- as.numeric(controls$radius.factor)
        graph$radius_rule <- controls$radius.rule
        graph$radius_search <- "ann"
        graph$sigma <- ann$sigma[[i]]
        graph$graph_rule <- "adaptive.radius"
        graph$graph_detail <- controls$graph.detail

        if (controls$return.timing && !is.null(graph$finalization_timing)) {
            timing.rows[[paste0("finalization.", k)]] <- data.frame(
                k = k,
                graph$finalization_timing,
                stringsAsFactors = FALSE
            )
            graph$finalization_timing <- NULL
        }
        graphs[[i]] <- graph
    }

    out <- list(
        graphs = graphs,
        k_statistics = .rknn.graphs.k.statistics(graphs, k.values)
    )
    if (controls$return.timing && length(timing.rows)) {
        timing <- do.call(rbind, timing.rows)
        rownames(timing) <- NULL
        out$timing <- timing
    }

    attr(out, "kmin") <- min(k.values)
    attr(out, "kmax") <- max(k.values)
    attr(out, "k.values") <- k.values
    attr(out, "n_vertices") <- n
    attr(out, "graph_rule") <- "adaptive.radius"
    class(out) <- c("rknn_graphs", "list")
    out
}

.normalize.cpp.rknn.graphs.controls <- function(args) {
    if (length(args)) {
        arg.names <- names(args)
        if (is.null(arg.names) || any(!nzchar(arg.names))) {
            stop("All arguments in '...' must be named.", call. = FALSE)
        }
    }

    take <- function(name, default) {
        if (name %in% names(args)) {
            value <- args[[name]]
            args[[name]] <<- NULL
            value
        } else {
            default
        }
    }

    type <- take("type", "adaptive.radius")
    if (!is.character(type) || length(type) != 1L ||
        !identical(type, "adaptive.radius")) {
        stop("'type' must be omitted or set to 'adaptive.radius' in cpp.create.rknn.graphs().",
             call. = FALSE)
    }
    if ("k.scale" %in% names(args)) {
        stop("'k.scale' is varied by cpp.create.rknn.graphs(); use 'kmin', 'kmax', or 'k.values'.",
             call. = FALSE)
    }
    if ("radius" %in% names(args)) {
        stop("'radius' is for fixed-radius graphs; cpp.create.rknn.graphs() varies k.scale for adaptive-radius graphs.",
             call. = FALSE)
    }

    radius.factor <- take("radius.factor", 1)
    if (!is.numeric(radius.factor) || length(radius.factor) != 1L ||
        !is.finite(radius.factor) || radius.factor <= 0) {
        stop("'radius.factor' must be a positive finite numeric scalar.",
             call. = FALSE)
    }
    radius.rule <- match.arg(
        take("radius.rule", "max"),
        c("max", "min", "geomean")
    )
    radius.search <- match.arg(
        take("radius.search", "ann"),
        c("ann", "all.pairs")
    )
    if (!identical(radius.search, "ann")) {
        stop("'radius.search' must be omitted or set to 'ann' in cpp.create.rknn.graphs().",
             call. = FALSE)
    }
    return.timing <- isTRUE(take("return.timing", FALSE))
    graph.detail <- match.arg(take("graph.detail", "full"),
                              c("full", "minimal"))
    prune.method <- match.arg(
        take("prune.method", "none"),
        c("none", "local.geodesic", "global.geodesic.ratio")
    )
    connect.components <- take("connect.components", FALSE)
    if (!is.logical(connect.components) || length(connect.components) != 1L ||
        is.na(connect.components)) {
        stop("'connect.components' must be TRUE or FALSE.", call. = FALSE)
    }
    connect.method <- match.arg(
        take("connect.method", "component.mst"),
        c("component.mst", "component.mst.ann", "global.mst")
    )

    controls <- list(
        radius.factor = radius.factor,
        radius.rule = radius.rule,
        return.timing = return.timing,
        graph.detail = graph.detail,
        prune.method = prune.method,
        max.path.edge.ratio.deviation.thld =
            take("max.path.edge.ratio.deviation.thld", 0.1),
        path.edge.ratio.percentile =
            take("path.edge.ratio.percentile", 0.5),
        prune.tau = take("prune.tau", 1.05),
        prune.local.k = take("prune.local.k", NULL),
        with.pruned.edge.stats = take("with.pruned.edge.stats", FALSE),
        connect.components = connect.components,
        connect.method = connect.method,
        bridge.k = take("bridge.k", NULL),
        bridge.k.max = take("bridge.k.max", NULL),
        bridge.growth = take("bridge.growth", 2)
    )

    if (length(args)) {
        stop(sprintf(
            "Unused argument%s in '...': %s",
            if (length(args) == 1L) "" else "s",
            paste(names(args), collapse = ", ")
        ), call. = FALSE)
    }
    controls
}

.normalize.rknn.graphs.k.values <- function(kmin, kmax, k.values, n) {
    if (!is.null(k.values)) {
        if (!is.numeric(k.values) || !length(k.values) ||
            any(!is.finite(k.values)) || any(k.values != floor(k.values))) {
            stop("'k.values' must be a non-empty integer vector.",
                 call. = FALSE)
        }
        k.values <- as.integer(k.values)
        if (any(k.values < 1L) || any(k.values >= n)) {
            stop("'k.values' must contain positive integers smaller than nrow(X).",
                 call. = FALSE)
        }
        if (anyDuplicated(k.values)) {
            stop("'k.values' cannot contain duplicate values.", call. = FALSE)
        }
        return(k.values)
    }

    if (is.null(kmin) || is.null(kmax)) {
        stop("Provide either 'k.values' or both 'kmin' and 'kmax'.",
             call. = FALSE)
    }
    if (!is.numeric(kmin) || length(kmin) != 1L || !is.finite(kmin) ||
        kmin != floor(kmin) || kmin < 1L) {
        stop("'kmin' must be a positive integer scalar.", call. = FALSE)
    }
    if (!is.numeric(kmax) || length(kmax) != 1L || !is.finite(kmax) ||
        kmax != floor(kmax) || kmax < kmin) {
        stop("'kmax' must be an integer scalar greater than or equal to 'kmin'.",
             call. = FALSE)
    }
    if (kmax >= n) {
        stop("'kmax' must be smaller than nrow(X).", call. = FALSE)
    }
    as.integer(kmin):as.integer(kmax)
}

.rknn.graphs.k.statistics <- function(graphs, k.values) {
    data.frame(
        idx = seq_along(k.values),
        k = as.integer(k.values),
        n_edges = vapply(graphs, function(g) g$n_edges, integer(1)),
        n_edges_before_pruning = vapply(
            graphs, function(g) g$n_edges_before_pruning, integer(1)
        ),
        n_edges_after_pruning = vapply(
            graphs, function(g) g$n_edges_after_pruning, integer(1)
        ),
        n_components_before = vapply(
            graphs, function(g) g$n_components_before, integer(1)
        ),
        n_components_after = vapply(
            graphs, function(g) g$n_components_after, integer(1)
        ),
        n_mst_edges_added = vapply(
            graphs, function(g) g$n_mst_edges_added, integer(1)
        ),
        stringsAsFactors = FALSE
    )
}

.rknn.graphs.timing <- function(graphs, k.values) {
    rows <- vector("list", length(graphs))
    for (i in seq_along(graphs)) {
        timing <- graphs[[i]]$timing
        if (is.null(timing)) {
            next
        }
        rows[[i]] <- data.frame(
            k = as.integer(k.values[[i]]),
            timing,
            stringsAsFactors = FALSE
        )
    }
    rows <- rows[!vapply(rows, is.null, logical(1))]
    if (!length(rows)) {
        return(NULL)
    }
    timing <- do.call(rbind, rows)
    rownames(timing) <- NULL
    timing
}

.create.radius.graph <- function(X,
                                 radius,
                                 prune.method = c("none", "local.geodesic", "global.geodesic.ratio"),
                                 max.path.edge.ratio.deviation.thld = 0.1,
                                 path.edge.ratio.percentile = 0.5,
                                 prune.tau = 1.05,
                                 prune.local.k = NULL,
                                 with.pruned.edge.stats = FALSE,
                                 connect.components = FALSE,
                                 connect.method = c("component.mst", "component.mst.ann", "global.mst"),
                                 bridge.k = NULL,
                                 bridge.k.max = NULL,
                                 bridge.growth = 2) {
    X <- .validate.numeric.data.matrix(X)
    if (!is.numeric(radius) || length(radius) != 1L || !is.finite(radius) ||
        radius <= 0) {
        stop("'radius' must be a positive finite numeric scalar.", call. = FALSE)
    }
    if (!is.logical(connect.components) || length(connect.components) != 1L ||
        is.na(connect.components)) {
        stop("'connect.components' must be TRUE or FALSE.", call. = FALSE)
    }
    connect.method <- match.arg(connect.method)
    edges <- .pairwise.radius.edges(
        X,
        keep.edge = function(i, j, d) d <= radius
    )
    graph <- .graph.from.edge.table(nrow(X), edges)
    prune.k <- .default.radius.prune.k(graph$adj_list)
    out <- .finalize.radius.graph(
        X, edges, connect.components, connect.method,
        bridge.k, bridge.k.max, bridge.growth, "radius_graph",
        prune.method = prune.method,
        max.path.edge.ratio.deviation.thld = max.path.edge.ratio.deviation.thld,
        path.edge.ratio.percentile = path.edge.ratio.percentile,
        prune.tau = prune.tau,
        prune.local.k = prune.local.k,
        prune.k = prune.k,
        with.pruned.edge.stats = with.pruned.edge.stats,
        return.timing = FALSE
    )
    out$radius <- as.numeric(radius)
    out$graph_rule <- "fixed.radius"
    out
}

#' Deprecated Radius Graph Constructors
#'
#' @description
#' `create.radius.graph()` and `create.adaptive.radius.graph()` are deprecated
#' compatibility wrappers. Use `create.rknn.graph()` with `type = "fixed"` or
#' `type = "adaptive.radius"` instead.
#'
#' @param X Numeric matrix or data frame with observations in rows.
#' @param radius Fixed radius passed to `create.rknn.graph(type = "fixed")`.
#' @param k.scale,radius.factor,radius.rule,radius.search Adaptive-radius
#'   parameters passed to `create.rknn.graph(type = "adaptive.radius")`.
#' @param return.timing,graph.detail Adaptive-radius output controls passed to
#'   `create.rknn.graph()`.
#' @param prune.method,max.path.edge.ratio.deviation.thld,path.edge.ratio.percentile,prune.tau,prune.local.k,with.pruned.edge.stats Geometric
#'   pruning controls passed to `create.rknn.graph()`.
#' @param connect.components,connect.method,bridge.k,bridge.k.max,bridge.growth Component
#'   repair controls passed to `create.rknn.graph()`.
#'
#' @examples
#' X <- matrix(c(0, 1, 3), ncol = 1)
#' create.rknn.graph(X, type = "fixed", radius = 1.1)$edge_matrix
#' create.rknn.graph(X, type = "adaptive.radius", k.scale = 1)$edge_matrix
#'
#' @name deprecated-radius-graph-constructors
NULL

#' @rdname deprecated-radius-graph-constructors
#' @export
create.radius.graph <- function(X,
                                radius,
                                prune.method = c("none", "local.geodesic", "global.geodesic.ratio"),
                                max.path.edge.ratio.deviation.thld = 0.1,
                                path.edge.ratio.percentile = 0.5,
                                prune.tau = 1.05,
                                prune.local.k = NULL,
                                with.pruned.edge.stats = FALSE,
                                connect.components = FALSE,
                                connect.method = c("component.mst", "component.mst.ann", "global.mst"),
                                bridge.k = NULL,
                                bridge.k.max = NULL,
                                bridge.growth = 2) {
    .Deprecated("create.rknn.graph")
    create.rknn.graph(
        X = X,
        type = "fixed",
        radius = radius,
        prune.method = prune.method,
        max.path.edge.ratio.deviation.thld = max.path.edge.ratio.deviation.thld,
        path.edge.ratio.percentile = path.edge.ratio.percentile,
        prune.tau = prune.tau,
        prune.local.k = prune.local.k,
        with.pruned.edge.stats = with.pruned.edge.stats,
        connect.components = connect.components,
        connect.method = connect.method,
        bridge.k = bridge.k,
        bridge.k.max = bridge.k.max,
        bridge.growth = bridge.growth
    )
}

#' @rdname deprecated-radius-graph-constructors
#' @export
create.adaptive.radius.graph <- function(X,
                                         k.scale,
                                         radius.factor = 1,
                                         radius.rule = c("max", "min", "geomean"),
                                         radius.search = c("ann", "all.pairs"),
                                         return.timing = FALSE,
                                         graph.detail = c("full", "minimal"),
                                         prune.method = c("none", "local.geodesic", "global.geodesic.ratio"),
                                         max.path.edge.ratio.deviation.thld = 0.1,
                                         path.edge.ratio.percentile = 0.5,
                                         prune.tau = 1.05,
                                         prune.local.k = NULL,
                                         with.pruned.edge.stats = FALSE,
                                         connect.components = FALSE,
                                         connect.method = c("component.mst", "component.mst.ann", "global.mst"),
                                         bridge.k = NULL,
                                         bridge.k.max = NULL,
                                         bridge.growth = 2) {
    .Deprecated("create.rknn.graph")
    create.rknn.graph(
        X = X,
        type = "adaptive.radius",
        k.scale = k.scale,
        radius.factor = radius.factor,
        radius.rule = radius.rule,
        radius.search = radius.search,
        return.timing = return.timing,
        graph.detail = graph.detail,
        prune.method = prune.method,
        max.path.edge.ratio.deviation.thld = max.path.edge.ratio.deviation.thld,
        path.edge.ratio.percentile = path.edge.ratio.percentile,
        prune.tau = prune.tau,
        prune.local.k = prune.local.k,
        with.pruned.edge.stats = with.pruned.edge.stats,
        connect.components = connect.components,
        connect.method = connect.method,
        bridge.k = bridge.k,
        bridge.k.max = bridge.k.max,
        bridge.growth = bridge.growth
    )
}

.create.adaptive.radius.graph <- function(X,
                                          k.scale,
                                          radius.factor = 1,
                                          radius.rule = c("max", "min", "geomean"),
                                          radius.search = c("ann", "all.pairs"),
                                          return.timing = FALSE,
                                          graph.detail = c("full", "minimal"),
                                          prune.method = c("none", "local.geodesic", "global.geodesic.ratio"),
                                          max.path.edge.ratio.deviation.thld = 0.1,
                                          path.edge.ratio.percentile = 0.5,
                                          prune.tau = 1.05,
                                          prune.local.k = NULL,
                                          with.pruned.edge.stats = FALSE,
                                          connect.components = FALSE,
                                          connect.method = c("component.mst", "component.mst.ann", "global.mst"),
                                          bridge.k = NULL,
                                          bridge.k.max = NULL,
                                          bridge.growth = 2) {
    X <- .validate.numeric.data.matrix(X)
    n <- nrow(X)
    if (!is.numeric(k.scale) || length(k.scale) != 1L || !is.finite(k.scale) ||
        k.scale != floor(k.scale) || k.scale < 1L || k.scale >= n) {
        stop("'k.scale' must be a positive integer smaller than nrow(X).",
             call. = FALSE)
    }
    if (!is.numeric(radius.factor) || length(radius.factor) != 1L ||
        !is.finite(radius.factor) || radius.factor <= 0) {
        stop("'radius.factor' must be a positive finite numeric scalar.",
             call. = FALSE)
    }
    if (!is.logical(connect.components) || length(connect.components) != 1L ||
        is.na(connect.components)) {
        stop("'connect.components' must be TRUE or FALSE.", call. = FALSE)
    }
    radius.rule <- match.arg(radius.rule)
    radius.search <- match.arg(radius.search)
    return.timing <- isTRUE(return.timing)
    graph.detail <- match.arg(graph.detail)
    connect.method <- match.arg(connect.method)
    timing.rows <- list()

    if (identical(radius.search, "ann")) {
        ann <- .adaptive.radius.edges.ann(
            X = X,
            k.scale = as.integer(k.scale),
            radius.factor = radius.factor,
            radius.rule = radius.rule
        )
        edges <- ann$edges
        sigma <- ann$sigma
        if (return.timing) {
            timing.rows[["ann"]] <- .radius.graph.timing.frame(ann$timing)
        }
    } else {
        scale.start <- proc.time()[["elapsed"]]
        knn.index <- .exact.knn.index(X, as.integer(k.scale))
        sigma <- numeric(n)
        for (i in seq_len(n)) {
            j <- knn.index[i, as.integer(k.scale)]
            sigma[[i]] <- .euclidean.distance(X, i, j)
        }
        scale.elapsed <- proc.time()[["elapsed"]] - scale.start
        radius.fun <- switch(radius.rule,
                             max = function(a, b) max(a, b),
                             min = function(a, b) min(a, b),
                             geomean = function(a, b) sqrt(a * b))
        radius.start <- proc.time()[["elapsed"]]
        edges <- .pairwise.radius.edges(
            X,
            keep.edge = function(i, j, d) {
                d <= radius.factor * radius.fun(sigma[[i]], sigma[[j]])
            }
        )
        radius.elapsed <- proc.time()[["elapsed"]] - radius.start
        if (return.timing) {
            timing.rows[["all.pairs"]] <- .radius.graph.timing.frame(c(
                "all.pairs.scale.search" = scale.elapsed,
                "all.pairs.fixed.radius.search" = radius.elapsed,
                "all.pairs.edge.materialization" = 0
            ))
        }
    }
    finalization.start <- proc.time()[["elapsed"]]
    out <- .finalize.radius.graph(
        X, edges, connect.components, connect.method,
        bridge.k, bridge.k.max, bridge.growth, "adaptive_radius_graph",
        prune.method = prune.method,
        max.path.edge.ratio.deviation.thld = max.path.edge.ratio.deviation.thld,
        path.edge.ratio.percentile = path.edge.ratio.percentile,
        prune.tau = prune.tau,
        prune.local.k = prune.local.k,
        prune.k = as.integer(k.scale),
        with.pruned.edge.stats = with.pruned.edge.stats,
        return.timing = return.timing,
        graph.detail = graph.detail
    )
    out$k_scale <- as.integer(k.scale)
    out$radius_factor <- as.numeric(radius.factor)
    out$radius_rule <- radius.rule
    out$radius_search <- radius.search
    out$sigma <- sigma
    out$graph_rule <- "adaptive.radius"
    out$graph_detail <- graph.detail
    if (return.timing) {
        finalization.elapsed <- proc.time()[["elapsed"]] - finalization.start
        if (!is.null(out$finalization_timing)) {
            timing.rows[["graph.finalization"]] <- out$finalization_timing
            out$finalization_timing <- NULL
        } else {
            timing.rows[["graph.finalization"]] <- .radius.graph.timing.frame(c(
                "graph.finalization" = finalization.elapsed
            ))
        }
        timing <- do.call(rbind, timing.rows)
        rownames(timing) <- NULL
        out$timing <- timing
    }
    out
}

#' Compute a Continuous-kNN Graph
#'
#' @description
#' Creates an undirected continuous-kNN graph using local scale distances.
#' Let \eqn{\sigma_i} be the distance from observation \eqn{i} to its
#' `k.scale`-th non-self nearest neighbor. Vertices are adjacent when
#' \deqn{\|x_i - x_j\|_2 \le \delta \sqrt{\sigma_i\sigma_j}.}
#'
#' This is a convenience wrapper around `create.rknn.graph()` with
#' `type = "adaptive.radius"` and `radius.rule = "geomean"`. It is useful as
#' a named data-derived graph construction in geodesic reconstruction
#' benchmarks.
#'
#' @param X Numeric matrix or data frame with observations in rows.
#' @param k.scale Positive integer smaller than `nrow(X)`. Defines local scale
#'   distances \eqn{\sigma_i}.
#' @param delta Positive numeric scalar multiplying the geometric-mean adaptive
#'   radius.
#' @param radius.search Character scalar. `"ann"` uses the bundled ANN kd-tree
#'   exact radius-search backend inherited from `create.rknn.graph()`.
#'   `"all.pairs"` uses the direct \eqn{O(n^2)} reference path.
#' @param return.timing Logical scalar. If `TRUE`, attach the same construction
#'   timing table returned by `create.rknn.graph()`, including ANN
#'   setup, local-scale search, fixed-radius candidate search, edge
#'   materialization, and graph finalization when `radius.search = "ann"`.
#' @param graph.detail Character scalar. `"full"` returns the complete graph
#'   lifecycle object. `"minimal"` returns only core graph fields and is allowed
#'   only with `prune.method = "none"` and `connect.components = FALSE`.
#' @inheritParams create.rknn.graph
#'
#' @return A list inheriting from `"cknn_graph"` and `"adaptive_radius_graph"`.
#'   It contains the same lifecycle fields as `create.rknn.graph()` with
#'   `type = "adaptive.radius"`, `radius_rule = "geomean"`,
#'   `radius_factor = delta`, and `graph_rule = "continuous.knn"`.
#'
#' @examples
#' X <- matrix(c(0, 1, 3), ncol = 1)
#' create.cknn.graph(X, k.scale = 1, delta = 1)$edge_matrix
#'
#' @export
create.cknn.graph <- function(X,
                              k.scale,
                              delta = 1,
                              radius.search = c("ann", "all.pairs"),
                              return.timing = FALSE,
                              graph.detail = c("full", "minimal"),
                              prune.method = c("none", "local.geodesic", "global.geodesic.ratio"),
                              max.path.edge.ratio.deviation.thld = 0.1,
                              path.edge.ratio.percentile = 0.5,
                              prune.tau = 1.05,
                              prune.local.k = NULL,
                              with.pruned.edge.stats = FALSE,
                              connect.components = FALSE,
                              connect.method = c("component.mst", "component.mst.ann", "global.mst"),
                              bridge.k = NULL,
                              bridge.k.max = NULL,
                              bridge.growth = 2) {
    if (!is.numeric(delta) || length(delta) != 1L ||
        !is.finite(delta) || delta <= 0) {
        stop("'delta' must be a positive finite numeric scalar.",
             call. = FALSE)
    }
    radius.search <- match.arg(radius.search)
    graph.detail <- match.arg(graph.detail)
    g <- .create.adaptive.radius.graph(
        X = X,
        k.scale = k.scale,
        radius.factor = delta,
        radius.rule = "geomean",
        radius.search = radius.search,
        return.timing = return.timing,
        graph.detail = graph.detail,
        prune.method = prune.method,
        max.path.edge.ratio.deviation.thld = max.path.edge.ratio.deviation.thld,
        path.edge.ratio.percentile = path.edge.ratio.percentile,
        prune.tau = prune.tau,
        prune.local.k = prune.local.k,
        with.pruned.edge.stats = with.pruned.edge.stats,
        connect.components = connect.components,
        connect.method = connect.method,
        bridge.k = bridge.k,
        bridge.k.max = bridge.k.max,
        bridge.growth = bridge.growth
    )
    g$delta <- as.numeric(g$radius_factor)
    g$graph_rule <- "continuous.knn"
    class(g) <- c("cknn_graph", class(g))
    g
}

#' @export
print.radius_graph <- function(x, ...) {
    cat("Fixed-radius graph\n")
    cat("Number of vertices:", x$n_vertices, "\n")
    cat("Number of edges:", x$n_edges, "\n")
    cat("Radius:", x$radius, "\n")
    cat("Connected components before MST augmentation:", x$n_components_before, "\n")
    cat("Connected components after MST augmentation:", x$n_components_after, "\n")
    invisible(x)
}

#' @export
print.cknn_graph <- function(x, ...) {
    cat("Continuous-kNN graph\n")
    cat("Number of vertices:", x$n_vertices, "\n")
    cat("Number of edges:", x$n_edges, "\n")
    cat("k.scale:", x$k_scale, "\n")
    cat("Delta:", x$delta, "\n")
    cat("Connected components before MST augmentation:", x$n_components_before, "\n")
    cat("Connected components after MST augmentation:", x$n_components_after, "\n")
    invisible(x)
}

#' @export
print.rknn_graphs <- function(x, ...) {
    cat("Adaptive-radius graph sequence\n")
    cat("Number of vertices:", attr(x, "n_vertices"), "\n")
    cat("Number of graphs:", length(x$graphs), "\n")
    cat("k values:", paste(attr(x, "k.values"), collapse = ", "), "\n")
    invisible(x)
}

#' @export
print.adaptive_radius_graph <- function(x, ...) {
    cat("Adaptive-radius graph\n")
    cat("Number of vertices:", x$n_vertices, "\n")
    cat("Number of edges:", x$n_edges, "\n")
    cat("k.scale:", x$k_scale, "\n")
    cat("Radius factor:", x$radius_factor, "\n")
    cat("Radius rule:", x$radius_rule, "\n")
    cat("Radius search:", x$radius_search %||% "all.pairs", "\n")
    cat("Connected components before MST augmentation:", x$n_components_before, "\n")
    cat("Connected components after MST augmentation:", x$n_components_after, "\n")
    invisible(x)
}
