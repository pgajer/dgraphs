## DG6e ikNN graph-selection diagnostics migrated from gflow/R/iknn_graphs.R.

.dgraphs.safe.spline.predict <- function(x, y, xout = NULL, w = NULL, spar = NULL, df = NULL) {
    x <- as.numeric(x)
    y <- as.numeric(y)
    if (is.null(w)) {
        w <- rep(1, length(x))
    } else {
        w <- as.numeric(w)
    }

    keep <- is.finite(x) & is.finite(y) & is.finite(w) & w > 0
    x <- x[keep]
    y <- y[keep]
    w <- w[keep]

    if (length(x) == 0L) {
        return(list(x = x, y = y, fit = NULL, yhat.in = numeric(0),
                    yhat.out = numeric(0), method = "empty"))
    }

    ord <- order(x)
    x <- x[ord]
    y <- y[ord]
    w <- w[ord]
    if (is.null(xout)) xout <- x else xout <- as.numeric(xout)

    if (length(x) == 1L) {
        return(list(x = x, y = y, fit = NULL, yhat.in = y,
                    yhat.out = rep(y[1], length(xout)), method = "constant"))
    }

    if (length(x) < 4L || length(unique(x)) < 4L) {
        return(list(
            x = x,
            y = y,
            fit = NULL,
            yhat.in = stats::approx(x, y, xout = x, rule = 2, ties = "ordered")$y,
            yhat.out = stats::approx(x, y, xout = xout, rule = 2, ties = "ordered")$y,
            method = "approx"
        ))
    }

    fit <- tryCatch(
        stats::smooth.spline(x = x, y = y, w = w, spar = spar, df = df),
        error = function(e) NULL
    )

    if (is.null(fit)) {
        return(list(
            x = x,
            y = y,
            fit = NULL,
            yhat.in = stats::approx(x, y, xout = x, rule = 2, ties = "ordered")$y,
            yhat.out = stats::approx(x, y, xout = xout, rule = 2, ties = "ordered")$y,
            method = "approx"
        ))
    }

    list(
        x = x,
        y = y,
        fit = fit,
        yhat.in = as.numeric(stats::predict(fit, x = x)$y),
        yhat.out = as.numeric(stats::predict(fit, x = xout)$y),
        method = "smooth.spline.gcv",
        selected.spar = if (!is.null(fit$spar)) fit$spar else NA_real_,
        selected.df = if (!is.null(fit$df)) fit$df else NA_real_
    )
}

.dgraphs.fit.iknn.trend <- function(x, y) {
    x <- as.numeric(x)
    y <- as.numeric(y)
    keep <- is.finite(x) & is.finite(y)
    x <- x[keep]
    y <- y[keep]

    if (length(x) < 4L || length(unique(x)) < 4L) {
        return(NULL)
    }

    xout <- sort(unique(x))
    pred <- .dgraphs.safe.spline.predict(x = x, y = y, xout = xout)
    yhat <- pred$yhat.out

    breakpoint <- NA_real_
    if (length(xout) >= 3L) {
        dx <- diff(xout)
        dx[dx <= 0] <- 1
        d1 <- diff(yhat) / dx
        if (length(d1) >= 2L) {
            x.mid <- (xout[-1] + xout[-length(xout)]) / 2
            dmid <- diff(x.mid)
            dmid[dmid <= 0] <- 1
            d2 <- diff(d1) / dmid
            if (length(d2) > 0L && any(is.finite(d2))) {
                breakpoint <- xout[which.max(abs(d2))[1L] + 1L]
            }
        }
    }

    structure(
        list(x = xout, y = yhat, breakpoint = breakpoint, method = pred$method),
        class = c("dgraphs_trend_fit", "list")
    )
}

internal.find.local.minima <- function(x, k.values,
                                       include.boundary = c("both", "none", "left", "right")) {
    if (!is.numeric(x)) stop("x must be a numeric vector")
    if (!is.numeric(k.values)) stop("k.values must be a numeric vector")
    if (length(x) != length(k.values)) stop("x and k.values must have the same length")

    include.boundary <- match.arg(include.boundary)
    n <- length(x)
    if (n < 2L) return(numeric(0))

    is.min <- rep(FALSE, n)
    if (n >= 3L) {
        for (i in 2L:(n - 1L)) {
            is.min[i] <- is.finite(x[i - 1L]) && is.finite(x[i]) && is.finite(x[i + 1L]) &&
                (x[i] < x[i - 1L]) && (x[i] < x[i + 1L])
        }
    }
    if (include.boundary %in% c("both", "left")) {
        is.min[1L] <- is.finite(x[1L]) && is.finite(x[2L]) && (x[1L] < x[2L])
    }
    if (include.boundary %in% c("both", "right")) {
        is.min[n] <- is.finite(x[n]) && is.finite(x[n - 1L]) && (x[n] < x[n - 1L])
    }

    k.values[is.min]
}

.dgraphs.break.composition.ties <- function(rel.abund.mat,
                                            neighborhood.method = c("knn", "radius"),
                                            neighborhood.size = 20,
                                            neighborhood.radius = 0.01,
                                            distance.metric = c("euclidean", "manhattan", "chebyshev", "bray.curtis"),
                                            noise.scale = 1e-10,
                                            min.neighborhood.size = 5,
                                            seed = NULL,
                                            verbose = FALSE) {
    if (!is.null(seed)) set.seed(seed)
    neighborhood.method <- match.arg(neighborhood.method)
    distance.metric <- match.arg(distance.metric)

    rel.abund.mat <- as.matrix(rel.abund.mat)
    n <- nrow(rel.abund.mat)
    p <- ncol(rel.abund.mat)
    dup.rows <- duplicated(rel.abund.mat) | duplicated(rel.abund.mat, fromLast = TRUE)
    if (!any(dup.rows)) return(rel.abund.mat)

    compute.distance <- function(x, y, metric) {
        switch(
            metric,
            euclidean = sqrt(sum((x - y)^2)),
            manhattan = sum(abs(x - y)),
            chebyshev = max(abs(x - y)),
            bray.curtis = sum(abs(x - y)) / sum(x + y)
        )
    }

    result <- rel.abund.mat
    for (i in which(dup.rows)) {
        distances <- apply(rel.abund.mat, 1L, function(x) {
            compute.distance(x, rel.abund.mat[i, ], distance.metric)
        })

        if (neighborhood.method == "knn") {
            nn <- min(neighborhood.size, n - 1L)
            neighbor.idx <- order(distances)[seq.int(2L, nn + 1L)]
        } else {
            neighbor.idx <- which(distances > 0 & distances <= neighborhood.radius)
            if (length(neighbor.idx) < min.neighborhood.size) {
                nn <- min(min.neighborhood.size, n - 1L)
                neighbor.idx <- order(distances)[seq.int(2L, nn + 1L)]
            }
        }

        neighborhood <- rel.abund.mat[neighbor.idx, , drop = FALSE]
        local.sd <- apply(neighborhood, 2L, stats::sd)
        zero.var <- !is.finite(local.sd) | local.sd == 0
        if (any(zero.var)) {
            min.positive.sd <- min(local.sd[!zero.var], na.rm = TRUE)
            if (is.finite(min.positive.sd)) {
                local.sd[zero.var] <- min.positive.sd * 0.1
            } else {
                global.sd <- apply(rel.abund.mat, 2L, stats::sd)
                local.sd[zero.var] <- global.sd[zero.var] * 0.1
                local.sd[!is.finite(local.sd)] <- 1
            }
        }

        perturbed <- rel.abund.mat[i, ] + stats::rnorm(p, mean = 0, sd = local.sd * noise.scale)
        perturbed[perturbed < 0] <- 0
        if (sum(perturbed) > 0) {
            result[i, ] <- perturbed / sum(perturbed)
        } else {
            result[i, ] <- (rel.abund.mat[i, ] + 1e-15) / (1 + p * 1e-15)
        }
    }

    if (isTRUE(verbose)) {
        remaining.dup <- sum(duplicated(result))
        cat("Remaining duplicate samples after perturbation:", remaining.dup, "\n")
    }

    result
}

#' Compute Stability Metrics Across a Sequence of IkNN Graphs
#'
#' Computes stability diagnostics across the pruned IkNN graphs produced by
#' [create.iknn.graphs()]. Metrics include edit distances between consecutive
#' graphs, graph-summary Jensen-Shannon divergence, edge-count diagnostics,
#' local minima, and smoothed trend fits for plotting.
#'
#' @param graphs An object of class `"iknn_graphs"` returned by
#'   [create.iknn.graphs()].
#' @param graph.type Character string, either `"geom"` or `"isize"`.
#' @param summary Graph-summary family used for the divergence curve.
#' @param divergence Divergence used for consecutive-graph comparison.
#'   Currently only `"js"`.
#' @param labels Optional vertex-label vector used when
#'   `summary = "neighborhood_label_distribution"`.
#' @param summary.args Optional named list forwarded to
#'   [compute.graph.summary.stability()].
#'
#' @return An object of class `"iknn_stability_metrics"`.
#' @export
compute.stability.metrics <- function(
    graphs,
    graph.type = c("geom", "isize"),
    summary = c(
        "degree_distribution",
        "edge_weight_distribution",
        "component_size_distribution",
        "neighborhood_label_distribution"
    ),
    divergence = c("js"),
    labels = NULL,
    summary.args = list()
) {
    graph.type <- match.arg(graph.type)
    summary <- match.arg(summary)
    divergence <- match.arg(divergence)

    if (!inherits(graphs, "iknn_graphs")) {
        stop("graphs must be an object of class 'iknn_graphs' returned by create.iknn.graphs().")
    }

    kmin <- attr(graphs, "kmin")
    kmax <- attr(graphs, "kmax")
    if (!is.numeric(kmin) || !is.numeric(kmax) || length(kmin) != 1L || length(kmax) != 1L) {
        stop("graphs must have numeric scalar attributes 'kmin' and 'kmax'.")
    }

    k.values <- as.integer(kmin:kmax)
    graphs.list <- if (graph.type == "geom") graphs$geom_pruned_graphs else graphs$isize_pruned_graphs
    if (is.null(graphs.list)) {
        if (graph.type == "isize") {
            stop("Requested intersection-size pruned graphs are not available. Recompute with create.iknn.graphs(..., compute.full = TRUE, with.isize.pruning = TRUE).")
        }
        stop("Requested pruned graphs are not available. Recompute create.iknn.graphs(..., compute.full = TRUE).")
    }
    if (length(graphs.list) != length(k.values)) {
        stop("Length mismatch: pruned graph list length does not match kmin:kmax.")
    }

    k.stats <- graphs$k_statistics
    have.k.stats <- !is.null(k.stats) && is.matrix(k.stats) && nrow(k.stats) >= length(k.values)
    n.edges <- rep(NA_real_, length(k.values))
    n.edges.in.pruned.graph <- rep(NA_real_, length(k.values))
    edge.reduction.ratio <- rep(NA_real_, length(k.values))

    if (have.k.stats) {
        row.idx <- if (!is.null(colnames(k.stats)) && "k" %in% colnames(k.stats)) {
            match(k.values, as.integer(k.stats[, "k"]))
        } else {
            seq_along(k.values)
        }
        if (!is.null(colnames(k.stats))) {
            edge.col <- if (graph.type == "geom") {
                "n_edges_in_geom_pruned_graph"
            } else {
                "n_edges_in_isize_pruned_graph"
            }
            ratio.col <- if (graph.type == "geom") {
                "geom_edge_reduction_ratio"
            } else {
                "isize_edge_reduction_ratio"
            }
            if ("n_edges" %in% colnames(k.stats)) n.edges <- as.numeric(k.stats[row.idx, "n_edges"])
            if (edge.col %in% colnames(k.stats)) n.edges.in.pruned.graph <- as.numeric(k.stats[row.idx, edge.col])
            if (ratio.col %in% colnames(k.stats)) edge.reduction.ratio <- as.numeric(k.stats[row.idx, ratio.col])
        }
    }

    if (any(!is.finite(n.edges.in.pruned.graph))) {
        for (i in seq_along(k.values)) {
            g <- graphs.list[[i]]
            if (!is.null(g$adj_list)) {
                n.edges.in.pruned.graph[i] <- sum(vapply(g$adj_list, length, integer(1))) / 2
            }
        }
    }
    if (any(!is.finite(edge.reduction.ratio)) &&
        any(is.finite(n.edges)) &&
        all(is.finite(n.edges.in.pruned.graph))) {
        edge.reduction.ratio <- (n.edges - n.edges.in.pruned.graph) / n.edges
    }

    js.stability <- compute.graph.summary.stability(
        graphs = graphs.list,
        summary = summary,
        divergence = divergence,
        labels = labels,
        summary.args = summary.args,
        k.values = k.values,
        return.details = TRUE
    )
    js.div <- js.stability$values
    edit.distances <- compute.edit.distances(graphs.list)

    edit.distances.lmin <- integer(0)
    edge.lmin <- integer(0)
    js.div.lmin <- integer(0)
    if (length(k.values) >= 2L) {
        edit.distances.lmin <- internal.find.local.minima(edit.distances, k.values[-length(k.values)])
        js.div.lmin <- internal.find.local.minima(js.div, k.values[-length(k.values)])
    }
    edge.lmin <- internal.find.local.minima(n.edges.in.pruned.graph, k.values)

    edit.distances.model <- if (length(k.values) >= 2L) {
        .dgraphs.fit.iknn.trend(k.values[-length(k.values)], edit.distances)
    } else {
        NULL
    }
    js.model <- if (length(k.values) >= 2L) {
        .dgraphs.fit.iknn.trend(k.values[-length(k.values)], js.div)
    } else {
        NULL
    }
    edge.model <- .dgraphs.fit.iknn.trend(k.values, n.edges.in.pruned.graph)

    result <- list(
        k.values = k.values,
        k.tr = k.values[-length(k.values)],
        graph.type = graph.type,
        summary = summary,
        divergence = divergence,
        n.edges = n.edges,
        n.edges.in.pruned.graph = n.edges.in.pruned.graph,
        edge.reduction.ratio = edge.reduction.ratio,
        edit.distances = edit.distances,
        js.div = js.div,
        summary.stability = stats::setNames(list(js.stability), summary),
        edit.distances.lmin = edit.distances.lmin,
        n.edges.lmin = edge.lmin,
        js.div.lmin = js.div.lmin,
        edit.distances.pwlm = if (!is.null(edit.distances.model)) edit.distances.model else NULL,
        edit.distances.breakpoint = if (!is.null(edit.distances.model)) edit.distances.model$breakpoint else NA_real_,
        n.edges.in.pruned.graph.pwlm = if (!is.null(edge.model)) edge.model else NULL,
        n.edges.in.pruned.graph.breakpoint = if (!is.null(edge.model)) edge.model$breakpoint else NA_real_,
        js.div.pwlm = if (!is.null(js.model)) js.model else NULL,
        js.div.breakpoint = if (!is.null(js.model)) js.model$breakpoint else NA_real_
    )

    class(result) <- c("iknn_stability_metrics", "list")
    result
}

compute.degrees.js.divergence <- function(g1, g2) {
    graph.summary.divergence(
        g1 = g1,
        g2 = g2,
        summary = "degree_distribution",
        divergence = "js",
        return.details = FALSE
    )
}

.add.iknn.trend <- function(trend, col = "red") {
    if (is.null(trend)) return(invisible(NULL))
    if (inherits(trend, "pwlm")) {
        plot(trend, add = TRUE, col = col)
        return(invisible(NULL))
    }
    if (is.list(trend) && all(c("x", "y") %in% names(trend))) {
        graphics::lines(trend$x, trend$y, col = col, lwd = 2)
    }
    invisible(NULL)
}

compute.edit.distances <- function(graphs.list) {
    n.graphs <- length(graphs.list)
    if (n.graphs < 2L) return(numeric(0))
    edit.distances <- numeric(n.graphs - 1L)

    edge.keys <- function(adj.list) {
        keys <- character(0)
        for (i in seq_along(adj.list)) {
            nbrs <- adj.list[[i]]
            if (length(nbrs) == 0L) next
            j <- nbrs[nbrs > i]
            if (length(j) > 0L) keys <- c(keys, paste(i, j, sep = "-"))
        }
        unique(keys)
    }

    for (i in seq_len(n.graphs - 1L)) {
        g1 <- graphs.list[[i]]
        g2 <- graphs.list[[i + 1L]]
        if (is.null(g1$adj_list) || is.null(g2$adj_list)) {
            stop("Each graph must contain an 'adj_list'.")
        }
        e1 <- edge.keys(g1$adj_list)
        e2 <- edge.keys(g2$adj_list)
        edit.distances[i] <- length(setdiff(e1, e2)) + length(setdiff(e2, e1))
    }
    edit.distances
}

find.optimal.k <- function(x, ...) {
    if (inherits(x, "iknn_stability_metrics")) {
        return(find.optimal.k.from.stability(x, ...))
    }
    args <- list(...)
    kmin <- args$kmin
    kmax <- args$kmax
    matrix.type <- if (is.null(args$matrix_type)) "geom" else args$matrix_type
    if (is.null(kmin) || is.null(kmax)) {
        stop("For birth-death input, you must supply kmin and kmax (e.g., find.optimal.k(bd, kmin=..., kmax=...)).")
    }
    find.optimal.k.from.birth.death(x, kmin = kmin, kmax = kmax, matrix_type = matrix.type)
}

find.optimal.k.from.stability <- function(x,
                                          weights = c(edist = 1, js = 1, edges = 1),
                                          k.range = NULL) {
    k.values <- x$k.values
    n <- length(k.values)
    if (n < 2L) {
        return(list(
            k.values = k.values,
            stability.scores = numeric(0),
            opt.k = if (n == 1L) k.values[1L] else NA_integer_
        ))
    }

    k.comp <- k.values[-n]
    ed <- x$edit.distances
    js <- x$js.div
    ne <- x$n.edges.in.pruned.graph[-n]

    if (!is.null(k.range)) {
        keep <- (k.comp >= k.range[1L]) & (k.comp <= k.range[2L])
        k.comp <- k.comp[keep]
        ed <- ed[keep]
        js <- js[keep]
        ne <- ne[keep]
    }

    scale01 <- function(v) {
        if (length(v) == 0L) return(v)
        r <- range(v, finite = TRUE)
        if (!is.finite(r[1L]) || !is.finite(r[2L]) || r[1L] == r[2L]) {
            return(rep(0.5, length(v)))
        }
        (v - r[1L]) / (r[2L] - r[1L])
    }

    ed.bad <- scale01(ed)
    js.bad <- scale01(js)
    ne.good <- scale01(ne)
    w <- weights
    score <- (1 - ed.bad)^w["edist"] * (1 - js.bad)^w["js"] * (ne.good)^w["edges"]
    opt.k <- k.comp[which.max(score)]

    list(
        k.values = k.comp,
        stability.scores = score,
        opt.k = as.integer(opt.k),
        components = list(
            edit.distances = ed,
            js.div = js,
            n.edges.in.pruned.graph = ne
        ),
        weights = w
    )
}

find.optimal.k.from.birth.death <- function(birth.death.matrix, kmin, kmax, matrix_type = "geom") {
    if (is.null(birth.death.matrix) || nrow(birth.death.matrix) == 0L) {
        warning(paste("Empty", matrix_type, "birth/death matrix. Returning middle k value."))
        return(list(
            stability.scores = rep(0, kmax - kmin + 1L),
            k.values = kmin:kmax,
            opt.k = floor((kmin + kmax) / 2)
        ))
    }

    persistence <- birth.death.matrix[, "death_time"] - birth.death.matrix[, "birth_time"]
    stability.scores <- numeric(kmax - kmin + 1L)
    for (k in kmin:kmax) {
        edges.at.k <- birth.death.matrix[, "birth_time"] <= k &
            birth.death.matrix[, "death_time"] > k
        if (sum(edges.at.k) > 0L) {
            avg.persistence <- mean(persistence[edges.at.k])
            persistent.ratio <- mean(birth.death.matrix[edges.at.k, "death_time"] == (kmax + 1L))
            edge.stability <- mean(pmin(
                k - birth.death.matrix[edges.at.k, "birth_time"],
                birth.death.matrix[edges.at.k, "death_time"] - k
            ))
            stability.scores[k - kmin + 1L] <- avg.persistence * persistent.ratio * edge.stability
        }
    }

    list(
        stability.scores = stability.scores,
        k.values = kmin:kmax,
        opt.k = kmin - 1L + which.max(stability.scores)
    )
}

#' Plot Method for IkNN Stability Metrics
#'
#' @param x An object returned by `compute.stability.metrics()`.
#' @param ... Passed to `plot.IkNNgraphs()`.
#' @export
plot.iknn_stability_metrics <- function(x, ...) {
    plot.IkNNgraphs(x, ...)
}

#' Plot Diagnostics for Intersection k-NN Graph Analysis
#'
#' @param x A list with `k.values`, `edit.distances`,
#'   `n.edges.in.pruned.graph`, and `js.div`.
#' @param type Character string. Only `"diag"` is currently supported.
#' @param diags Diagnostic panels. The supported combination is
#'   `c("edist", "edge", "deg")`.
#' @param with.pwlm Logical. If `TRUE`, overlays smoothed trend fits.
#' @param with.lmin Logical. If `TRUE`, shows local-minimum vertical lines.
#' @param breakpoint.col Color for breakpoint vertical lines.
#' @param lmin.col Color for local-minima vertical lines.
#' @param k Optional k to highlight. Reserved for legacy compatibility.
#' @param mar,mgp,tcl,xline,yline Base graphics controls.
#' @param ... Additional arguments passed to plot.
#'
#' @return Invisibly returns `TRUE`.
#' @export
plot.IkNNgraphs <- function(x,
                            type = "diag",
                            diags = c("edist", "edge", "deg"),
                            with.pwlm = TRUE,
                            with.lmin = FALSE,
                            breakpoint.col = "blue",
                            lmin.col = "gray",
                            k = NA,
                            mar = c(2.5, 2.5, 0.5, 0.5),
                            mgp = c(2.5, 0.5, 0),
                            tcl = -0.3,
                            xline = 2.4,
                            yline = 3.15,
                            ...) {
    type <- match.arg(type, choices = c("diag"))
    if (!"k.values" %in% names(x)) stop("k.values not in x")

    k.edge <- x$k.values
    if (length(k.edge) < 1L) stop("k.values must have positive length.")
    k.tr <- if (length(k.edge) >= 2L) k.edge[-length(k.edge)] else integer(0)

    old.par <- graphics::par(no.readonly = TRUE)
    on.exit(graphics::par(old.par), add = TRUE)

    if (!setequal(diags, c("edist", "edge", "deg"))) {
        stop("Currently supported diags combination is exactly c('edist','edge','deg').")
    }

    graphics::par(mfrow = c(1, 3), mar = mar, mgp = mgp, tcl = tcl)

    if (!"edit.distances" %in% names(x)) stop("edit.distances not in x")
    if (length(x$edit.distances) != length(k.tr)) {
        stop("Length mismatch: edit.distances must have length length(k.values)-1.")
    }
    graphics::plot(k.tr, x$edit.distances, las = 1, type = "b", xlab = "", ylab = "", ...)
    graphics::mtext("Number of Nearest Neighbors (k)", side = 1, line = xline, outer = FALSE)
    graphics::mtext("Edit Distance", side = 2, line = yline, outer = FALSE)
    if (with.pwlm && "edit.distances.pwlm" %in% names(x)) {
        .add.iknn.trend(x$edit.distances.pwlm, col = "red")
        if ("edit.distances.breakpoint" %in% names(x)) {
            graphics::abline(v = x$edit.distances.breakpoint, lty = 2, col = breakpoint.col)
        }
    }
    if (with.lmin && "edit.distances.lmin" %in% names(x)) {
        graphics::abline(v = x$edit.distances.lmin, lty = 2, col = lmin.col)
    }

    if (!"n.edges.in.pruned.graph" %in% names(x)) stop("n.edges.in.pruned.graph not in x")
    if (length(x$n.edges.in.pruned.graph) != length(k.edge)) {
        stop("Length mismatch: n.edges.in.pruned.graph must have length length(k.values).")
    }
    graphics::plot(k.edge, x$n.edges.in.pruned.graph, las = 1, type = "b", xlab = "", ylab = "", ...)
    graphics::mtext("Number of Nearest Neighbors (k)", side = 1, line = xline, outer = FALSE)
    graphics::mtext("Num. Edges in Pruned Graph", side = 2, line = yline, outer = FALSE)
    if (with.pwlm && "n.edges.in.pruned.graph.pwlm" %in% names(x)) {
        .add.iknn.trend(x$n.edges.in.pruned.graph.pwlm, col = "red")
        if ("n.edges.in.pruned.graph.breakpoint" %in% names(x)) {
            graphics::abline(v = x$n.edges.in.pruned.graph.breakpoint, lty = 2, col = breakpoint.col)
        }
    }
    if (with.lmin && "n.edges.in.pruned.graph.lmin" %in% names(x)) {
        graphics::abline(v = x$n.edges.in.pruned.graph.lmin, lty = 2, col = lmin.col)
    }

    if (!"js.div" %in% names(x)) stop("js.div not in x")
    if (length(x$js.div) != length(k.tr)) {
        stop("Length mismatch: js.div must have length length(k.values)-1.")
    }
    summary.key <- if (!is.null(x$summary)) x$summary else "degree_distribution"
    summary.label.pretty <- switch(
        summary.key,
        degree_distribution = "Degrees",
        edge_weight_distribution = "Edge Weights",
        component_size_distribution = "Component Sizes",
        neighborhood_label_distribution = "Neighborhood Labels",
        summary.key
    )
    graphics::plot(k.tr, x$js.div, las = 1, type = "b", xlab = "", ylab = "", ...)
    graphics::mtext("Number of Nearest Neighbors (k)", side = 1, line = xline, outer = FALSE)
    graphics::mtext(paste0("JS Divergence (", summary.label.pretty, ")"), side = 2, line = yline, outer = FALSE)
    if (with.pwlm && "js.div.pwlm" %in% names(x)) {
        .add.iknn.trend(x$js.div.pwlm, col = "red")
        if ("js.div.breakpoint" %in% names(x)) {
            graphics::abline(v = x$js.div.breakpoint, lty = 2, col = breakpoint.col)
        }
    }
    if (with.lmin && "js.div.lmin" %in% names(x)) {
        graphics::abline(v = x$js.div.lmin, lty = 2, col = lmin.col)
    }

    invisible(TRUE)
}

internal.compute.edit.distances <- function(graphs) {
    compute.edit.distances(graphs)
}

trim.X.to.main.cc <- function(X, adj.list, verbose = FALSE) {
    cc <- graph.connected.components(adj.list)
    cc.tbl <- table(cc)
    main.cc <- as.integer(names(sort(cc.tbl, decreasing = TRUE)[1L]))
    in.main <- cc == main.cc
    if (verbose) {
        cat("Trimming to main connected component:\n")
        cat("  vertices before:", nrow(X), "\n")
        cat("  vertices kept  :", sum(in.main), "\n")
    }
    list(X = X[in.main, , drop = FALSE], kept = in.main)
}

pick.k.within.eps.global.max <- function(metric,
                                         k.values = NULL,
                                         eps = 0.05,
                                         direction = c("max", "min"),
                                         idx.ok = NULL,
                                         k.min = -Inf,
                                         k.max = Inf,
                                         require.local.extremum = FALSE,
                                         window = 1L,
                                         return.details = FALSE) {
    if (missing(metric) || is.null(metric)) stop("`metric` must be provided.")
    metric <- as.double(metric)
    n <- length(metric)
    if (n < 1L) stop("`metric` must have length >= 1.")
    if (is.null(k.values)) {
        k.values <- seq_len(n)
    } else if (length(k.values) != n) {
        stop("`k.values` must have the same length as `metric`.")
    }
    k.values <- as.double(k.values)

    direction <- match.arg(direction)
    if (!is.numeric(eps) || length(eps) != 1L || !is.finite(eps) || eps < 0) {
        stop("`eps` must be a single finite number >= 0.")
    }
    window <- as.integer(window)
    if (!is.finite(window) || window < 1L) stop("`window` must be an integer >= 1.")

    keep <- is.finite(metric) & is.finite(k.values) & k.values >= k.min & k.values <= k.max
    if (!is.null(idx.ok)) {
        idx.ok <- as.integer(idx.ok)
        idx.ok <- idx.ok[idx.ok >= 1L & idx.ok <= n]
        keep2 <- rep(FALSE, n)
        keep2[idx.ok] <- TRUE
        keep <- keep & keep2
    }
    idx.keep <- which(keep)
    empty <- function(threshold = NA_real_) {
        if (isTRUE(return.details)) {
            return(list(k.opt = NA_real_, idx.opt = NA_integer_, threshold = threshold,
                        idx.candidates = integer(0), idx.local = integer(0)))
        }
        NA_real_
    }
    if (length(idx.keep) == 0L) return(empty())

    m.keep <- metric[idx.keep]
    if (direction == "max") {
        m.opt <- max(m.keep)
        thr <- (1 - eps) * m.opt
        idx.cand <- idx.keep[metric[idx.keep] >= thr]
    } else {
        m.opt <- min(m.keep)
        thr <- (1 + eps) * m.opt
        idx.cand <- idx.keep[metric[idx.keep] <= thr]
    }
    if (length(idx.cand) == 0L) return(empty(thr))

    if (isTRUE(require.local.extremum)) {
        is.local <- rep(FALSE, n)
        for (ii in idx.cand) {
            lo <- max(1L, ii - window)
            hi <- min(n, ii + window)
            nb <- metric[lo:hi]
            nb <- nb[is.finite(nb)]
            if (!length(nb)) next
            is.local[ii] <- if (direction == "max") {
                isTRUE(all(metric[ii] >= nb))
            } else {
                isTRUE(all(metric[ii] <= nb))
            }
        }
        idx.local <- idx.cand[is.local[idx.cand]]
        if (length(idx.local) == 0L) idx.local <- idx.cand
    } else {
        idx.local <- idx.cand
    }

    k.sub <- k.values[idx.local]
    k.min.val <- min(k.sub, na.rm = TRUE)
    idx.opt <- idx.local[which(k.sub == k.min.val)[1L]]
    k.opt <- k.values[idx.opt]

    if (isTRUE(return.details)) {
        return(list(k.opt = k.opt, idx.opt = idx.opt, threshold = thr,
                    idx.candidates = idx.cand, idx.local = idx.local))
    }
    k.opt
}

cst.graph.mixing.stats <- function(igraph.obj = NULL,
                                   adj.list = NULL,
                                   weight.list = NULL,
                                   labels,
                                   n.perm = 200L,
                                   perm.blocks = NULL,
                                   use.weights = TRUE,
                                   weights.are.edge.lengths = FALSE,
                                   affinity.method = c("exp", "inv"),
                                   sigma = NULL,
                                   affinity.eps = 1e-8,
                                   simplify.multiple = TRUE,
                                   seed = 1L) {
    affinity.method <- match.arg(affinity.method)

    adjlist.weightlist.to.igraph <- function(adj.list, weight.list = NULL) {
        if (is.null(adj.list) || !is.list(adj.list)) stop("`adj.list` must be a list.")
        n <- length(adj.list)
        if (n < 2L) stop("`adj.list` must have length >= 2.")
        has.w <- !is.null(weight.list)
        if (has.w && (!is.list(weight.list) || length(weight.list) != n)) {
            stop("`weight.list` must be a list of same length as adj.list.")
        }
        e1 <- integer(0)
        e2 <- integer(0)
        ew <- numeric(0)
        for (i in seq_len(n)) {
            nb <- as.integer(adj.list[[i]])
            if (length(nb) == 0L) next
            if (any(nb < 1L | nb > n)) stop("`adj.list` has out-of-range neighbor indices.")
            if (!has.w) {
                jj <- nb[nb > i]
                if (length(jj) > 0L) {
                    e1 <- c(e1, rep.int(i, length(jj)))
                    e2 <- c(e2, jj)
                    ew <- c(ew, rep.int(1.0, length(jj)))
                }
            } else {
                wv <- as.double(weight.list[[i]])
                if (length(wv) != length(nb)) stop("weight.list[[i]] length must match adj.list[[i]].")
                keep <- nb > i
                if (any(keep)) {
                    e1 <- c(e1, rep.int(i, sum(keep)))
                    e2 <- c(e2, nb[keep])
                    ew <- c(ew, wv[keep])
                }
            }
        }
        g <- igraph::make_empty_graph(n = n, directed = FALSE)
        if (length(e1) > 0L) {
            g <- igraph::add_edges(g, as.vector(t(cbind(e1, e2))))
            igraph::E(g)$weight <- ew
        }
        g
    }

    if (!is.null(igraph.obj)) {
        if (!inherits(igraph.obj, "igraph")) stop("`igraph.obj` must be an igraph object.")
        g <- igraph.obj
    } else {
        g <- adjlist.weightlist.to.igraph(adj.list, weight.list)
    }

    n <- igraph::vcount(g)
    m <- igraph::ecount(g)
    if (missing(labels) || is.null(labels)) stop("`labels` must be provided.")
    if (length(labels) != n) stop("`labels` must have length vcount(g).")
    labels <- as.character(labels)

    w.raw <- NULL
    if (isTRUE(use.weights) && "weight" %in% igraph::edge_attr_names(g)) {
        w.raw <- as.double(igraph::E(g)$weight)
        if (length(w.raw) != m) w.raw <- NULL
    }
    if (is.null(w.raw)) w.raw <- rep(1.0, m)

    if (isTRUE(simplify.multiple)) {
        comb.fun <- if (isTRUE(weights.are.edge.lengths)) "min" else "max"
        g <- igraph::simplify(
            g,
            remove.multiple = TRUE,
            remove.loops = TRUE,
            edge.attr.comb = list(weight = comb.fun, "ignore")
        )
        n <- igraph::vcount(g)
        m <- igraph::ecount(g)
        w.raw <- if ("weight" %in% igraph::edge_attr_names(g)) {
            as.double(igraph::E(g)$weight)
        } else {
            rep(1.0, m)
        }
        if (length(w.raw) != m) w.raw <- rep(1.0, m)
    }

    if (isTRUE(use.weights)) {
        if (isTRUE(weights.are.edge.lengths)) {
            d <- w.raw[is.finite(w.raw) & w.raw > 0]
            if (length(d) == 0L) {
                w.used <- rep(1.0, m)
            } else {
                sig <- sigma
                if (is.null(sig)) sig <- stats::median(d)
                if (!is.finite(sig) || sig <= 0) sig <- 1.0
                w.used <- if (affinity.method == "exp") {
                    exp(-(w.raw / sig)^2)
                } else {
                    1 / (w.raw + affinity.eps)
                }
                w.used[!is.finite(w.used)] <- 0
                w.used[w.used < 0] <- 0
            }
        } else {
            w.used <- w.raw
            w.used[!is.finite(w.used)] <- 0
            w.used[w.used < 0] <- 0
        }
    } else {
        w.used <- rep(1.0, m)
    }

    ends <- igraph::ends(g, igraph::E(g), names = FALSE)
    u <- ends[, 1L]
    v <- ends[, 2L]
    lab.u <- labels[u]
    lab.v <- labels[v]
    ok.e <- !is.na(lab.u) & !is.na(lab.v)
    ok.v <- !is.na(labels)
    labels.ok <- labels[ok.v]
    lev <- sort(unique(labels.ok))

    w.ok <- w.used[ok.e]
    same <- lab.u[ok.e] == lab.v[ok.e]
    homophily <- if (sum(w.ok) > 0) sum(w.ok[same]) / sum(w.ok) else NA_real_

    assort <- NA_real_
    mix.mat <- NULL
    if (length(lev) >= 2L && sum(ok.e) > 0L) {
        map <- stats::setNames(seq_along(lev), lev)
        a <- map[lab.u[ok.e]]
        b <- map[lab.v[ok.e]]
        M <- matrix(0, nrow = length(lev), ncol = length(lev), dimnames = list(lev, lev))
        ok.idx <- which(ok.e)
        for (i in seq_along(a)) {
            w0 <- w.used[ok.idx[i]]
            M[a[i], b[i]] <- M[a[i], b[i]] + w0
            M[b[i], a[i]] <- M[b[i], a[i]] + w0
        }
        sM <- sum(M)
        if (sM > 0) {
            e <- M / sM
            aa <- rowSums(e)
            tr <- sum(diag(e))
            denom <- 1 - sum(aa^2)
            assort <- if (denom > 0) (tr - sum(aa^2)) / denom else NA_real_
        }
        mix.mat <- M
    }

    strength <- igraph::strength(g, weights = w.used)
    strength[!is.finite(strength)] <- 0
    strength.ok <- strength[ok.v]
    h.null <- NA_real_
    if (sum(strength.ok) > 0 && length(lev) >= 1L) {
        p.l <- tapply(strength.ok, labels.ok, sum)
        p.l <- p.l / sum(strength.ok)
        h.null <- sum(as.numeric(p.l)^2)
    }
    homophily.adjusted <- if (is.finite(h.null) && h.null < 1 && is.finite(homophily)) {
        (homophily - h.null) / (1 - h.null)
    } else {
        NA_real_
    }

    conductance.by.label <- NULL
    conductance.summary <- NULL
    if (length(lev) >= 2L && sum(ok.e) > 0L) {
        vol.total <- sum(strength.ok)
        vol.l <- tapply(strength.ok, labels.ok, sum)
        vol.l <- vol.l[lev]
        cut.l <- stats::setNames(rep(0, length(lev)), lev)
        for (i in which(ok.e)) {
            a0 <- labels[u[i]]
            b0 <- labels[v[i]]
            if (!is.na(a0) && !is.na(b0) && a0 != b0) {
                cut.l[a0] <- cut.l[a0] + w.used[i]
                cut.l[b0] <- cut.l[b0] + w.used[i]
            }
        }
        cond <- rep(NA_real_, length(lev))
        names(cond) <- lev
        for (l in lev) {
            va <- as.numeric(vol.l[l])
            vb <- vol.total - va
            denom <- min(va, vb)
            cond[l] <- if (is.finite(denom) && denom > 0) as.numeric(cut.l[l]) / denom else NA_real_
        }
        conductance.by.label <- data.frame(
            cst = lev,
            vol = as.numeric(vol.l),
            cut = as.numeric(cut.l[lev]),
            conductance = as.numeric(cond),
            stringsAsFactors = FALSE
        )
        wv <- conductance.by.label$vol
        ok.c <- is.finite(conductance.by.label$conductance) & wv > 0
        conductance.summary <- list(
            conductance.median = stats::median(conductance.by.label$conductance[ok.c], na.rm = TRUE),
            conductance.vol.weighted.mean = sum(conductance.by.label$conductance[ok.c] * wv[ok.c]) / sum(wv[ok.c])
        )
    }

    n.perm <- as.integer(n.perm)
    perm <- NULL
    if (n.perm > 0L && sum(ok.v) >= 10L && sum(ok.e) >= 10L) {
        permute.labels <- function(lbl, blocks = NULL) {
            lbl2 <- lbl
            idx <- which(!is.na(lbl2))
            if (is.null(blocks)) {
                lbl2[idx] <- sample(lbl2[idx], replace = FALSE)
            } else {
                if (length(blocks) != length(lbl2)) stop("perm.blocks must have length vcount(g).")
                for (bb in unique(blocks[idx])) {
                    ii <- idx[blocks[idx] == bb]
                    if (length(ii) >= 2L) lbl2[ii] <- sample(lbl2[ii], replace = FALSE)
                }
            }
            lbl2
        }
        metric.from.labels <- function(lbl) {
            lab.u2 <- lbl[u]
            lab.v2 <- lbl[v]
            ok.e2 <- !is.na(lab.u2) & !is.na(lab.v2)
            if (sum(ok.e2) == 0L) return(c(h = NA_real_, r = NA_real_))
            w.ok2 <- w.used[ok.e2]
            same2 <- lab.u2[ok.e2] == lab.v2[ok.e2]
            h2 <- if (sum(w.ok2) > 0) sum(w.ok2[same2]) / sum(w.ok2) else NA_real_
            r2 <- NA_real_
            lev2 <- sort(unique(lbl[!is.na(lbl)]))
            if (length(lev2) >= 2L) {
                map2 <- stats::setNames(seq_along(lev2), lev2)
                a2 <- map2[lab.u2[ok.e2]]
                b2 <- map2[lab.v2[ok.e2]]
                M2 <- matrix(0, nrow = length(lev2), ncol = length(lev2))
                idx.e2 <- which(ok.e2)
                for (ii in seq_along(a2)) {
                    w0 <- w.used[idx.e2[ii]]
                    M2[a2[ii], b2[ii]] <- M2[a2[ii], b2[ii]] + w0
                    M2[b2[ii], a2[ii]] <- M2[b2[ii], a2[ii]] + w0
                }
                sM2 <- sum(M2)
                if (sM2 > 0) {
                    e2 <- M2 / sM2
                    aa2 <- rowSums(e2)
                    tr2 <- sum(diag(e2))
                    denom2 <- 1 - sum(aa2^2)
                    r2 <- if (denom2 > 0) (tr2 - sum(aa2^2)) / denom2 else NA_real_
                }
            }
            c(h = h2, r = r2)
        }
        set.seed(seed)
        h.null.vec <- rep(NA_real_, n.perm)
        r.null.vec <- rep(NA_real_, n.perm)
        for (b in seq_len(n.perm)) {
            mm <- metric.from.labels(permute.labels(labels, blocks = perm.blocks))
            h.null.vec[b] <- mm["h"]
            r.null.vec[b] <- mm["r"]
        }
        summarize.null <- function(obs, null.vec) {
            mu <- mean(null.vec, na.rm = TRUE)
            sd0 <- stats::sd(null.vec, na.rm = TRUE)
            eff <- obs - mu
            z <- if (is.finite(sd0) && sd0 > 0) eff / sd0 else NA_real_
            null.finite <- null.vec[is.finite(null.vec)]
            p.upper <- if (length(null.finite) >= 10L) {
                (1 + sum(null.finite >= obs)) / (1 + length(null.finite))
            } else {
                NA_real_
            }
            list(obs = obs, mu = mu, sd = sd0, effect = eff, z = z, p = p.upper)
        }
        perm <- list(
            n.perm = n.perm,
            homophily.null = h.null.vec,
            assortativity.null = r.null.vec,
            homophily = summarize.null(homophily, h.null.vec),
            assortativity = summarize.null(assort, r.null.vec)
        )
    }

    out <- list(
        n.vertices = n,
        n.edges = m,
        labels.levels = lev,
        weights.used = isTRUE(use.weights),
        weights.are.edge.lengths = isTRUE(weights.are.edge.lengths),
        affinity.method = affinity.method,
        sigma = sigma,
        homophily = homophily,
        homophily.null = h.null,
        homophily.adjusted = homophily.adjusted,
        assortativity = assort,
        mixing.matrix = mix.mat,
        conductance.by.label = conductance.by.label,
        conductance.summary = conductance.summary,
        permutation = perm
    )
    class(out) <- "cst_graph_mixing_stats"
    out
}

#' Plot method for cst_graph_mixing_stats
#'
#' @param x Object from `cst.graph.mixing.stats()`.
#' @param which Character vector specifying panels to plot.
#' @param ... Base graphics arguments.
#' @export
plot.cst_graph_mixing_stats <- function(x,
                                        which = c("null.homophily", "null.assortativity", "mixing.matrix", "conductance"),
                                        ...) {
    if (!inherits(x, "cst_graph_mixing_stats")) stop("x must be class 'cst_graph_mixing_stats'.")
    which <- unique(which)
    np <- length(which)
    if (np == 0L) return(invisible(NULL))
    nr <- ceiling(np / 2)
    nc <- if (np == 1L) 1 else 2
    op <- graphics::par(mfrow = c(nr, nc), mar = c(3.2, 3.2, 2.0, 0.8), mgp = c(2.0, 0.6, 0))
    on.exit(graphics::par(op), add = TRUE)
    for (w in which) {
        if (w == "mixing.matrix") {
            M <- x$mixing.matrix
            if (is.null(M)) {
                graphics::plot.new()
                graphics::title("mixing.matrix (none)")
            } else {
                z <- log1p(M)
                graphics::image(t(z[nrow(z):1L, , drop = FALSE]), axes = FALSE,
                                main = "log1p(weighted mixing matrix)")
                graphics::axis(1, at = seq(0, 1, length.out = ncol(z)),
                               labels = colnames(z), las = 2, cex.axis = 0.6)
                graphics::axis(2, at = seq(0, 1, length.out = nrow(z)),
                               labels = rev(rownames(z)), las = 2, cex.axis = 0.6)
            }
        } else if (w == "conductance") {
            df <- x$conductance.by.label
            if (is.null(df)) {
                graphics::plot.new()
                graphics::title("conductance (none)")
            } else {
                o <- order(df$conductance, decreasing = FALSE, na.last = NA)
                graphics::barplot(df$conductance[o], names.arg = df$cst[o], las = 2,
                                  ylab = "conductance", main = "Per-CST conductance",
                                  cex.names = 0.6)
            }
        } else if (w == "null.homophily") {
            if (is.null(x$permutation)) {
                graphics::plot.new()
                graphics::title("homophily null (none)")
            } else {
                graphics::hist(x$permutation$homophily.null, breaks = 30, col = "gray",
                               border = "white", main = "Homophily null", xlab = "homophily")
                graphics::abline(v = x$homophily, lwd = 2)
            }
        } else if (w == "null.assortativity") {
            if (is.null(x$permutation)) {
                graphics::plot.new()
                graphics::title("assortativity null (none)")
            } else {
                graphics::hist(x$permutation$assortativity.null, breaks = 30, col = "gray",
                               border = "white", main = "Assortativity null", xlab = "assortativity")
                graphics::abline(v = x$assortativity, lwd = 2)
            }
        } else {
            graphics::plot.new()
            graphics::title(paste0("Unknown panel: ", w))
        }
    }
    invisible(NULL)
}

#' Build iKNN Graphs and Select a Neighborhood Size
#'
#' Builds an iKNN graph sequence and selects `k` from structural edit-distance
#' stability, label-mixing stability, or both.
#'
#' @param X Numeric observation-by-feature matrix.
#' @param kmin,kmax Minimum and maximum neighborhood sizes.
#' @param method Selection criterion.
#' @param pca.dim,variance.explained PCA controls forwarded to
#'   [create.iknn.graphs()].
#' @param trim.disconnected Logical; trim to a largest connected component when
#'   the requested connectivity tail is absent.
#' @param edit.min.lcc.frac,edit.eps Connectivity and tolerance controls for
#'   edit-distance selection.
#' @param labels,perm.blocks Optional labels and permutation blocks for mixing
#'   selection.
#' @param mixing.metric,mixing.min.lcc.frac,mixing.eps Mixing criterion,
#'   connectivity threshold, and tolerance.
#' @param mixing.require.local.extremum,mixing.window Local-extremum controls
#'   for the mixing curve.
#' @param n.perm Number of label permutations.
#' @param use.edge.weights,weights.are.edge.lengths Edge-weight interpretation.
#' @param affinity.method,affinity.sigma,affinity.sigma.from,affinity.eps
#'   Controls for converting edge lengths to affinities.
#' @param simplify.multiple Logical; simplify loops and multiple edges.
#' @param seed Random seed.
#' @param n.cores Number of worker processes.
#' @param verbose Logical; report progress.
#' @param ... Additional arguments forwarded to [create.iknn.graphs()].
#'
#' @return An object of class `"build_iknn_graphs_and_selectk"` containing the
#'   graph sequence, connectivity diagnostics, selection curves, selected
#'   neighborhood sizes, trimming metadata, and call parameters.
#' @export
build.iknn.graphs.and.selectk <- function(X,
                                          kmin,
                                          kmax,
                                          method = c("both", "edit", "mixing", "none"),
                                          pca.dim = 100,
                                          variance.explained = 0.99,
                                          trim.disconnected = TRUE,
                                          edit.min.lcc.frac = 1.0,
                                          edit.eps = 0.05,
                                          labels = NULL,
                                          perm.blocks = NULL,
                                          mixing.metric = c("homophily.effect",
                                                           "homophily.z",
                                                           "homophily.adjusted",
                                                           "assortativity.effect",
                                                           "assortativity.z",
                                                           "homophily",
                                                           "assortativity",
                                                           "conductance.median",
                                                           "conductance.wmean"),
                                          mixing.min.lcc.frac = 0.98,
                                          mixing.eps = 0.05,
                                          mixing.require.local.extremum = TRUE,
                                          mixing.window = 1L,
                                          n.perm = 200L,
                                          use.edge.weights = TRUE,
                                          weights.are.edge.lengths = FALSE,
                                          affinity.method = c("exp", "inv"),
                                          affinity.sigma = NULL,
                                          affinity.sigma.from = c("k.cc.mixing", "k.max.lcc", "k.trim"),
                                          affinity.eps = 1e-8,
                                          simplify.multiple = TRUE,
                                          seed = 1L,
                                          n.cores = 1L,
                                          verbose = TRUE,
                                          ...) {
    if (missing(X) || is.null(X)) stop("`X` must be provided.")
    X <- tryCatch(as.matrix(X), error = function(e) NULL)
    if (is.null(X)) stop("`X` must be coercible to a matrix via as.matrix().")
    suppressWarnings(storage.mode(X) <- "double")
    if (!is.numeric(X)) stop("`X` must be numeric (or coercible to numeric).")
    if (nrow(X) < 5L) stop("`X` must have at least 5 rows.")
    if (ncol(X) < 1L) stop("`X` must have at least 1 column.")

    sample.ids <- rownames(X)
    if (is.null(sample.ids)) sample.ids <- as.character(seq_len(nrow(X)))
    kmin <- as.integer(kmin)
    kmax <- as.integer(kmax)
    if (!is.finite(kmin) || !is.finite(kmax) || kmin < 1L) stop("`kmin` must be an integer >= 1.")
    if (kmax < kmin) stop("`kmax` must be >= kmin.")
    if (kmax >= nrow(X)) {
        kmax <- nrow(X) - 1L
        if (isTRUE(verbose)) cat("NOTE: reducing kmax to nrow(X)-1 =", kmax, "\n")
    }

    method <- match.arg(method)
    mixing.metric <- match.arg(mixing.metric)
    affinity.method <- match.arg(affinity.method)
    affinity.sigma.from <- match.arg(affinity.sigma.from)
    n.cores <- as.integer(n.cores)
    if (!is.finite(n.cores) || n.cores < 1L) stop("`n.cores` must be an integer >= 1.")
    if (!is.numeric(edit.min.lcc.frac) || length(edit.min.lcc.frac) != 1L ||
        !is.finite(edit.min.lcc.frac) || edit.min.lcc.frac <= 0 || edit.min.lcc.frac > 1) {
        stop("`edit.min.lcc.frac` must be in (0,1].")
    }
    if (!is.numeric(mixing.min.lcc.frac) || length(mixing.min.lcc.frac) != 1L ||
        !is.finite(mixing.min.lcc.frac) || mixing.min.lcc.frac <= 0 || mixing.min.lcc.frac > 1) {
        stop("`mixing.min.lcc.frac` must be in (0,1].")
    }

    if (sum(duplicated(X))) {
        X <- .dgraphs.break.composition.ties(
            rel.abund.mat = X,
            neighborhood.method = "knn",
            neighborhood.size = 20,
            distance.metric = "euclidean",
            noise.scale = 1e-10,
            seed = 123,
            verbose = verbose
        )
        X <- as.matrix(X)
    }

    align.labels.to.sample.ids <- function(labels, sample.ids, min.match = 10L) {
        if (is.null(names(labels))) stop("`labels` must be named (or length nrow(X) without names).")
        min.match <- as.integer(min.match)
        lab0 <- labels[sample.ids]
        n.match0 <- sum(!is.na(lab0))
        if (n.match0 >= min.match) {
            return(list(labels.aligned = as.character(lab0), used.make.names = FALSE))
        }
        nm.sample <- make.names(sample.ids, unique = FALSE)
        labels.mn <- labels
        names(labels.mn) <- make.names(names(labels), unique = FALSE)
        lab1 <- labels.mn[nm.sample]
        n.match1 <- sum(!is.na(lab1))
        if (n.match1 >= min.match) {
            warning("Label alignment succeeded only after make.names() normalization. ",
                    "Consider normalizing rownames(X) and names(labels) consistently upstream.")
            return(list(labels.aligned = as.character(lab1), used.make.names = TRUE))
        }
        stop(
            "Label alignment failed: too few matches between rownames(X) and names(labels).\n",
            "  matches strict: ", n.match0, " / ", length(sample.ids), "\n",
            "  matches make.names: ", n.match1, " / ", length(sample.ids), "\n",
            "  head(sample.ids): ", paste(utils::head(sample.ids, 5L), collapse = ", "), "\n",
            "  head(names(labels)): ", paste(utils::head(names(labels), 5L), collapse = ", "), "\n",
            "Fix: ensure rownames(X) equals names(labels) (or pass labels as an unnamed vector in row order)."
        )
    }

    need.mixing <- method %in% c("mixing", "both")
    labels.aligned <- NULL
    blocks.aligned <- NULL
    if (need.mixing) {
        if (is.null(labels)) stop("`labels` must be provided when method includes 'mixing'.")
        if (!is.null(names(labels))) {
            if (is.null(rownames(X)) && length(labels) == nrow(X) && length(unique(names(labels))) == nrow(X)) {
                rownames(X) <- names(labels)
                sample.ids <- rownames(X)
            }
            labels.aligned <- align.labels.to.sample.ids(labels, sample.ids, min.match = 10L)$labels.aligned
        } else {
            if (length(labels) != nrow(X)) stop("`labels` must have length nrow(X) or be named by rownames(X).")
            labels.aligned <- as.character(labels)
            names(labels.aligned) <- sample.ids
        }
        if (sum(!is.na(labels.aligned)) < 10L) {
            stop("Too few non-NA labels after alignment (n=", sum(!is.na(labels.aligned)), ").")
        }
        if (!is.null(perm.blocks)) {
            if (!is.null(names(perm.blocks))) {
                blocks.aligned <- perm.blocks[sample.ids]
            } else {
                if (length(perm.blocks) != nrow(X)) stop("`perm.blocks` must have length nrow(X) or be named.")
                blocks.aligned <- perm.blocks
                names(blocks.aligned) <- sample.ids
            }
        }
    }

    adjlist.to.edge.mat <- function(adj.list, weight.list = NULL, n) {
        has.w <- !is.null(weight.list)
        e1 <- integer(0)
        e2 <- integer(0)
        ew <- numeric(0)
        for (i in seq_len(n)) {
            nb <- as.integer(adj.list[[i]])
            if (length(nb) == 0L) next
            if (!has.w) {
                jj <- nb[nb > i]
                if (length(jj) > 0L) {
                    e1 <- c(e1, rep.int(i, length(jj)))
                    e2 <- c(e2, jj)
                    ew <- c(ew, rep.int(1.0, length(jj)))
                }
            } else {
                wv <- as.double(weight.list[[i]])
                if (length(wv) != length(nb)) stop("weight.list[[i]] length must match adj.list[[i]].")
                keep <- nb > i
                if (any(keep)) {
                    e1 <- c(e1, rep.int(i, sum(keep)))
                    e2 <- c(e2, nb[keep])
                    ew <- c(ew, wv[keep])
                }
            }
        }
        if (length(e1) == 0L) {
            return(list(edge.mat = matrix(integer(0), ncol = 2L), weights = numeric(0)))
        }
        edge.mat <- cbind(e1, e2)
        code <- (edge.mat[, 1L] - 1L) * n + edge.mat[, 2L]
        if (length(code) != length(unique(code))) {
            comb <- if (isTRUE(weights.are.edge.lengths)) min else max
            w.by.code <- tapply(ew, code, comb)
            code.u <- as.integer(names(w.by.code))
            edge.mat <- cbind(
                as.integer((code.u - 1L) %/% n + 1L),
                as.integer((code.u - 1L) %% n + 1L)
            )
            ew <- as.double(w.by.code)
        }
        list(edge.mat = edge.mat, weights = ew)
    }

    edge.codes.from.graph <- function(g.obj, n) {
        el <- adjlist.to.edge.mat(g.obj$adj_list, g.obj$weight_list, n = n)
        if (nrow(el$edge.mat) == 0L) return(integer(0))
        sort(unique(as.integer((el$edge.mat[, 1L] - 1L) * n + el$edge.mat[, 2L])))
    }

    jaccard.distance.codes <- function(a, b) {
        a <- as.integer(a)
        b <- as.integer(b)
        if (length(a) == 0L && length(b) == 0L) return(0)
        if (length(a) == 0L || length(b) == 0L) return(1)
        inter <- sum(!is.na(match(a, b)))
        uni <- length(a) + length(b) - inter
        if (uni <= 0L) return(0)
        1 - inter / uni
    }

    estimate.sigma.from.lengths <- function(d) {
        d <- as.double(d)
        d <- d[is.finite(d) & d > 0]
        if (length(d) == 0L) return(1.0)
        stats::median(d)
    }

    lengths.to.affinity <- function(d, sigma, method = "exp") {
        d <- as.double(d)
        if (!is.finite(sigma) || sigma <= 0) sigma <- estimate.sigma.from.lengths(d)
        if (!is.finite(sigma) || sigma <= 0) sigma <- 1.0
        w <- if (method == "exp") exp(-(d / sigma)^2) else 1 / (d + affinity.eps)
        w[!is.finite(w)] <- 0
        w[w < 0] <- 0
        w
    }

    call.mixing.stats <- function(igraph.obj, labels.vec, blocks.vec = NULL, w.vec = NULL, seed = 1L) {
        args <- list(igraph.obj = igraph.obj, labels = labels.vec, n.perm = as.integer(n.perm), seed = as.integer(seed))
        args$perm.blocks <- blocks.vec
        if (!is.null(w.vec)) args$edge.weights <- w.vec
        do.call(cst.graph.mixing.stats, args[names(args) %in% names(formals(cst.graph.mixing.stats))])
    }

    extract.metric <- function(ms, metric.name, igraph.obj = NULL, labels.vec = NULL) {
        get1 <- function(x, path) {
            cur <- x
            for (nm in path) {
                if (is.null(cur) || is.null(cur[[nm]])) return(NULL)
                cur <- cur[[nm]]
            }
            cur
        }
        if (metric.name == "homophily") return(ms$homophily)
        if (metric.name == "homophily.z") {
            z <- get1(ms, c("permutation", "homophily", "z"))
            if (is.null(z)) z <- get1(ms, c("permutation", "homophily.z", "z"))
            if (is.null(z)) return(NA_real_)
            return(as.double(z))
        }
        if (metric.name == "homophily.effect") {
            eff <- get1(ms, c("permutation", "homophily", "effect"))
            if (!is.null(eff)) return(eff)
            mu <- get1(ms, c("permutation", "homophily.z", "mu"))
            if (!is.null(mu) && is.finite(ms$homophily)) return(ms$homophily - mu)
            return(NA_real_)
        }
        if (metric.name == "homophily.adjusted") {
            adj <- ms$homophily.adjusted
            if (!is.null(adj)) return(adj)
            if (!is.null(igraph.obj) && !is.null(labels.vec)) {
                w <- if ("weight" %in% igraph::edge_attr_names(igraph.obj)) igraph::E(igraph.obj)$weight else NULL
                s <- igraph::strength(igraph.obj, weights = w)
                ok <- !is.na(labels.vec)
                if (sum(s[ok]) > 0) {
                    p <- tapply(s[ok], labels.vec[ok], sum)
                    p <- p / sum(s[ok])
                    h0 <- sum(as.numeric(p)^2)
                    if (is.finite(h0) && h0 < 1 && is.finite(ms$homophily)) {
                        return((ms$homophily - h0) / (1 - h0))
                    }
                }
            }
            return(NA_real_)
        }
        if (metric.name == "assortativity") return(ms$assortativity)
        if (metric.name == "assortativity.z") {
            z <- get1(ms, c("permutation", "assortativity", "z"))
            if (is.null(z)) z <- get1(ms, c("permutation", "assortativity.z", "z"))
            if (is.null(z)) return(NA_real_)
            return(as.double(z))
        }
        if (metric.name == "assortativity.effect") {
            eff <- get1(ms, c("permutation", "assortativity", "effect"))
            if (!is.null(eff)) return(eff)
            mu <- get1(ms, c("permutation", "assortativity.z", "mu"))
            if (!is.null(mu) && is.finite(ms$assortativity)) return(ms$assortativity - mu)
            return(NA_real_)
        }
        if (metric.name == "conductance.median") {
            v <- get1(ms, c("conductance.summary", "conductance.median"))
            if (is.null(v)) return(NA_real_)
            return(as.double(v))
        }
        if (metric.name == "conductance.wmean") {
            v <- get1(ms, c("conductance.summary", "conductance.vol.weighted.mean"))
            if (is.null(v)) return(NA_real_)
            return(as.double(v))
        }
        NA_real_
    }

    metric.direction.default <- function(metric.name) {
        if (metric.name %in% c("conductance.median", "conductance.wmean")) "min" else "max"
    }

    X.graphs <- create.iknn.graphs(
        X,
        kmin = kmin,
        kmax = kmax,
        pca.dim = pca.dim,
        variance.explained = variance.explained,
        compute.full = TRUE,
        n.cores = n.cores,
        verbose = verbose,
        ...
    )

    k.values <- NULL
    if (!is.null(X.graphs[["k_statistics"]]) &&
        is.matrix(X.graphs[["k_statistics"]]) &&
        "k" %in% colnames(X.graphs[["k_statistics"]])) {
        k.values <- X.graphs[["k_statistics"]][, "k"]
    }
    if (!is.null(X.graphs[["k.values"]])) {
        k.values <- X.graphs[["k.values"]]
    }
    if (is.null(k.values) && !is.null(X.graphs[["k"]])) {
        k.values <- X.graphs[["k"]]
    }
    if (is.null(k.values)) k.values <- seq.int(kmin, kmax)
    g.list <- X.graphs$geom_pruned_graphs
    if (is.null(g.list)) stop("X.graphs$geom_pruned_graphs not found; cannot proceed.")
    if (length(g.list) != length(k.values)) stop("Length mismatch: geom_pruned_graphs and k.values.")

    compute.connectivity <- function(g.list, k.values, n) {
        n.comp <- integer(length(k.values))
        lcc.size <- integer(length(k.values))
        lcc.frac <- numeric(length(k.values))
        n.edges <- integer(length(k.values))
        for (i in seq_along(k.values)) {
            el <- adjlist.to.edge.mat(g.list[[i]]$adj_list, g.list[[i]]$weight_list, n = n)
            n.edges[i] <- nrow(el$edge.mat)
            gi <- igraph::make_empty_graph(n = n, directed = FALSE)
            if (nrow(el$edge.mat) > 0L) gi <- igraph::add_edges(gi, as.vector(t(el$edge.mat)))
            comp <- igraph::components(gi)
            n.comp[i] <- comp$no
            lcc.size[i] <- max(comp$csize)
            lcc.frac[i] <- lcc.size[i] / n
        }
        data.frame(
            k = as.integer(k.values),
            n.edges = n.edges,
            n.components = n.comp,
            lcc.size = lcc.size,
            lcc.frac = lcc.frac
        )
    }

    find.k.cc <- function(conn.df, min.lcc.frac) {
        bad <- which(conn.df$lcc.frac < min.lcc.frac)
        if (length(bad) == 0L) return(conn.df$k[1L])
        last.bad <- max(bad)
        if (last.bad >= nrow(conn.df)) return(NA_integer_)
        k.cc <- conn.df$k[last.bad + 1L]
        ok.tail <- which(conn.df$k >= k.cc)
        if (!all(conn.df$lcc.frac[ok.tail] >= min.lcc.frac)) return(NA_integer_)
        k.cc
    }

    conn <- compute.connectivity(g.list, k.values, n = nrow(X))
    k.cc.edit <- find.k.cc(conn, min.lcc.frac = edit.min.lcc.frac)
    trim.info <- list(trimmed = FALSE, keep.idx = seq_len(nrow(X)), dropped.idx = integer(0), k.trim = NA_integer_)

    if (isTRUE(trim.disconnected) && (is.na(k.cc.edit) && method %in% c("edit", "both"))) {
        best.idx <- which(conn$lcc.size == max(conn$lcc.size))
        best.idx <- best.idx[which.min(conn$k[best.idx])]
        k.trim <- conn$k[best.idx]
        trim.info$k.trim <- k.trim
        el <- adjlist.to.edge.mat(g.list[[best.idx]]$adj_list, g.list[[best.idx]]$weight_list, n = nrow(X))
        gi <- igraph::make_empty_graph(n = nrow(X), directed = FALSE)
        if (nrow(el$edge.mat) > 0L) gi <- igraph::add_edges(gi, as.vector(t(el$edge.mat)))
        comp <- igraph::components(gi)
        keep <- which(comp$membership == which.max(comp$csize))
        if (length(keep) < 5L) stop("Trimming would leave too few vertices; aborting.")
        if (isTRUE(verbose)) {
            cat("Trimming to largest CC at k =", k.trim, " (n=", length(keep), " of ", nrow(X), ")\n", sep = "")
        }
        old.n <- nrow(X)
        X <- X[keep, , drop = FALSE]
        sample.ids <- sample.ids[keep]
        if (need.mixing) {
            labels.aligned <- labels.aligned[sample.ids]
            if (!is.null(blocks.aligned)) blocks.aligned <- blocks.aligned[sample.ids]
        }
        trim.info$trimmed <- TRUE
        trim.info$keep.idx <- keep
        trim.info$dropped.idx <- setdiff(seq_len(old.n), keep)
        if (kmax >= nrow(X)) kmax <- nrow(X) - 1L
        X.graphs <- create.iknn.graphs(
            X,
            kmin = kmin,
            kmax = kmax,
            pca.dim = pca.dim,
            variance.explained = variance.explained,
            compute.full = TRUE,
            n.cores = n.cores,
            verbose = verbose,
            ...
        )
        k.values <- NULL
        if (!is.null(X.graphs[["k_statistics"]]) &&
            is.matrix(X.graphs[["k_statistics"]]) &&
            "k" %in% colnames(X.graphs[["k_statistics"]])) {
            k.values <- X.graphs[["k_statistics"]][, "k"]
        }
        if (!is.null(X.graphs[["k.values"]])) {
            k.values <- X.graphs[["k.values"]]
        }
        if (is.null(k.values) && !is.null(X.graphs[["k"]])) {
            k.values <- X.graphs[["k"]]
        }
        if (is.null(k.values)) k.values <- seq.int(kmin, kmax)
        g.list <- X.graphs$geom_pruned_graphs
        if (is.null(g.list)) stop("Rebuilt X.graphs missing geom_pruned_graphs.")
        conn <- compute.connectivity(g.list, k.values, n = nrow(X))
        k.cc.edit <- find.k.cc(conn, min.lcc.frac = edit.min.lcc.frac)
    }

    k.cc.mixing <- find.k.cc(conn, min.lcc.frac = mixing.min.lcc.frac)
    edit.df <- NULL
    k.opt.edit <- NA_integer_
    pick.k.within.eps.global.min.internal <- function(metric, k.values, eps = 0.05, idx.ok = NULL) {
        pick.k.within.eps.global.max(
            metric = metric,
            k.values = k.values,
            eps = eps,
            direction = "min",
            idx.ok = idx.ok,
            require.local.extremum = FALSE,
            window = 1L,
            return.details = FALSE
        )
    }

    if (method %in% c("edit", "both")) {
        if (is.na(k.cc.edit)) {
            stop("No connected tail found for edit selection; consider trim.disconnected=TRUE or relax edit.min.lcc.frac.")
        }
        edge.codes <- vector("list", length(k.values))
        for (i in seq_along(k.values)) {
            edge.codes[[i]] <- edge.codes.from.graph(g.list[[i]], n = nrow(X))
        }
        edit.dist <- rep(NA_real_, length(k.values))
        for (i in seq_len(length(k.values) - 1L)) {
            edit.dist[i] <- jaccard.distance.codes(edge.codes[[i]], edge.codes[[i + 1L]])
        }
        edit.df <- data.frame(k = as.integer(k.values), edit.dist.to.next = edit.dist)
        idx.ok <- which(edit.df$k >= k.cc.edit & is.finite(edit.df$edit.dist.to.next))
        if (length(idx.ok) > 0L) {
            k.opt.edit <- as.integer(
                pick.k.within.eps.global.min.internal(
                    edit.df$edit.dist.to.next,
                    edit.df$k,
                    eps = edit.eps,
                    idx.ok = idx.ok
                )
            )
        }
    }

    mixing.df <- NULL
    k.opt.mixing <- NA_integer_
    sigma.used <- affinity.sigma
    if (need.mixing) {
        dir0 <- metric.direction.default(mixing.metric)
        idx.mix <- which(conn$lcc.frac >= mixing.min.lcc.frac)
        if (!is.na(k.cc.mixing)) idx.mix <- idx.mix[conn$k[idx.mix] >= k.cc.mixing]
        if (length(idx.mix) == 0L) {
            stop("No k values satisfy mixing connectivity constraint; relax mixing.min.lcc.frac or trim.disconnected.")
        }
        if (isTRUE(use.edge.weights) && isTRUE(weights.are.edge.lengths) && is.null(affinity.sigma)) {
            idx.ref <- idx.mix[1L]
            if (affinity.sigma.from == "k.max.lcc") {
                idx.ref <- which(conn$lcc.size == max(conn$lcc.size))[1L]
            } else if (affinity.sigma.from == "k.trim" && isTRUE(trim.info$trimmed)) {
                idx.ref <- which(conn$k == trim.info$k.trim)
                if (length(idx.ref) == 0L) idx.ref <- idx.mix[1L]
            }
            el.ref <- adjlist.to.edge.mat(g.list[[idx.ref]]$adj_list, g.list[[idx.ref]]$weight_list, n = nrow(X))
            sigma.used <- estimate.sigma.from.lengths(el.ref$weights)
            if (isTRUE(verbose)) {
                cat("Estimated affinity.sigma =", signif(sigma.used, 5), "from k =", conn$k[idx.ref], "\n")
            }
        }

        k.out <- conn$k[idx.mix]
        val <- rep(NA_real_, length(idx.mix))
        val.z <- rep(NA_real_, length(idx.mix))
        val.effect <- rep(NA_real_, length(idx.mix))
        val.adj <- rep(NA_real_, length(idx.mix))
        assort <- rep(NA_real_, length(idx.mix))
        cond.med <- rep(NA_real_, length(idx.mix))
        cond.wm <- rep(NA_real_, length(idx.mix))

        for (jj in seq_along(idx.mix)) {
            if (isTRUE(verbose)) cat("\r", jj, "/", length(idx.mix), "\n")
            ii <- idx.mix[jj]
            g.obj <- g.list[[ii]]
            n0 <- nrow(X)
            el <- adjlist.to.edge.mat(g.obj$adj_list, g.obj$weight_list, n = n0)
            if (nrow(el$edge.mat) == 0L) next
            w.use <- NULL
            if (isTRUE(use.edge.weights)) {
                if (isTRUE(weights.are.edge.lengths)) {
                    w.use <- lengths.to.affinity(el$weights, sigma = sigma.used, method = affinity.method)
                } else {
                    w.use <- el$weights
                    w.use[!is.finite(w.use)] <- 0
                    w.use[w.use < 0] <- 0
                }
            }
            ig <- igraph::make_empty_graph(n = n0, directed = FALSE)
            ig <- igraph::add_edges(ig, as.vector(t(el$edge.mat)))
            igraph::E(ig)$weight <- el$weights
            if (!is.null(w.use) && length(w.use) == nrow(el$edge.mat)) igraph::E(ig)$weight <- w.use
            if (isTRUE(simplify.multiple)) {
                ig <- igraph::simplify(
                    ig,
                    remove.multiple = TRUE,
                    remove.loops = TRUE,
                    edge.attr.comb = list(weight = "max", "ignore")
                )
            }
            ms <- call.mixing.stats(
                ig,
                labels.vec = labels.aligned,
                blocks.vec = blocks.aligned,
                w.vec = NULL,
                seed = seed
            )
            val[jj] <- extract.metric(ms, mixing.metric, igraph.obj = ig, labels.vec = labels.aligned)
            val.z[jj] <- extract.metric(ms, "homophily.z", igraph.obj = ig, labels.vec = labels.aligned)
            val.effect[jj] <- extract.metric(ms, "homophily.effect", igraph.obj = ig, labels.vec = labels.aligned)
            val.adj[jj] <- extract.metric(ms, "homophily.adjusted", igraph.obj = ig, labels.vec = labels.aligned)
            assort[jj] <- extract.metric(ms, "assortativity", igraph.obj = ig, labels.vec = labels.aligned)
            cond.med[jj] <- extract.metric(ms, "conductance.median", igraph.obj = ig, labels.vec = labels.aligned)
            cond.wm[jj] <- extract.metric(ms, "conductance.wmean", igraph.obj = ig, labels.vec = labels.aligned)
        }
        mixing.df <- data.frame(
            k = as.integer(k.out),
            metric = as.double(val),
            homophily.z = as.double(val.z),
            homophily.effect = as.double(val.effect),
            homophily.adjusted = as.double(val.adj),
            assortativity = as.double(assort),
            conductance.median = as.double(cond.med),
            conductance.wmean = as.double(cond.wm)
        )
        mixing.df <- mixing.df[order(mixing.df$k), , drop = FALSE]
        metric.vec <- mixing.df$metric
        k.vec <- mixing.df$k
        idx.ok <- which(is.finite(metric.vec))
        if (length(idx.ok) > 0L) {
            k.opt.mixing <- as.integer(
                pick.k.within.eps.global.max(
                    metric = metric.vec,
                    k.values = k.vec,
                    eps = mixing.eps,
                    direction = dir0,
                    idx.ok = idx.ok,
                    require.local.extremum = isTRUE(mixing.require.local.extremum),
                    window = mixing.window,
                    return.details = FALSE
                )
            )
        }
    }

    out <- list(
        X.graphs = X.graphs,
        k.values = as.integer(k.values),
        connectivity = conn,
        edit = edit.df,
        mixing = mixing.df,
        k.cc.edit = as.integer(k.cc.edit),
        k.opt.edit = as.integer(k.opt.edit),
        k.cc.mixing = as.integer(k.cc.mixing),
        k.opt.mixing = as.integer(k.opt.mixing),
        trim = trim.info,
        params = list(
            method = method,
            kmin = kmin,
            kmax = kmax,
            pca.dim = pca.dim,
            variance.explained = variance.explained,
            n.cores = n.cores,
            edit.min.lcc.frac = edit.min.lcc.frac,
            edit.eps = edit.eps,
            mixing.metric = mixing.metric,
            mixing.min.lcc.frac = mixing.min.lcc.frac,
            mixing.eps = mixing.eps,
            mixing.require.local.extremum = mixing.require.local.extremum,
            mixing.window = mixing.window,
            n.perm = n.perm,
            use.edge.weights = use.edge.weights,
            weights.are.edge.lengths = weights.are.edge.lengths,
            affinity.method = affinity.method,
            affinity.sigma = sigma.used,
            affinity.eps = affinity.eps,
            simplify.multiple = simplify.multiple
        )
    )
    class(out) <- "build_iknn_graphs_and_selectk"
    out
}

#' Print method for build_iknn_graphs_and_selectk
#'
#' @param x Object from `build.iknn.graphs.and.selectk()`.
#' @param ... Unused.
#' @export
print.build_iknn_graphs_and_selectk <- function(x, ...) {
    if (!inherits(x, "build_iknn_graphs_and_selectk")) stop("x must be class 'build_iknn_graphs_and_selectk'.")
    cat("build.iknn.graphs.and.selectk result\n")
    cat("  k range: ", min(x$k.values), " .. ", max(x$k.values), "\n", sep = "")
    cat("  trimmed: ", isTRUE(x$trim$trimmed), "\n", sep = "")
    if (isTRUE(x$trim$trimmed)) cat("  trim k:  ", x$trim$k.trim, "\n", sep = "")
    cat("  k.cc.edit:    ", x$k.cc.edit, "\n", sep = "")
    cat("  k.opt.edit:   ", x$k.opt.edit, "\n", sep = "")
    cat("  k.cc.mixing:  ", x$k.cc.mixing, "\n", sep = "")
    cat("  k.opt.mixing: ", x$k.opt.mixing, "\n", sep = "")
    invisible(x)
}

#' Plot method for build_iknn_graphs_and_selectk
#'
#' @param x Object from `build.iknn.graphs.and.selectk()`.
#' @param which Character vector selecting panels among `"connect"`, `"edit"`,
#'   and `"mixing"`.
#' @param connect.args,edit.args,mixing.args Named lists forwarded to panel plots.
#' @param par.args Named list forwarded to [graphics::par()].
#' @param ... Additional arguments, currently ignored.
#' @export
plot.build_iknn_graphs_and_selectk <- function(x,
                                               which = c("connect", "edit", "mixing"),
                                               connect.args = list(),
                                               edit.args = list(),
                                               mixing.args = list(),
                                               par.args = list(),
                                               ...) {
    if (!inherits(x, "build_iknn_graphs_and_selectk")) stop("x must be class 'build_iknn_graphs_and_selectk'.")
    which <- unique(which)
    np <- length(which)
    if (np < 1L) return(invisible(NULL))
    par.default <- list(mfrow = c(np, 1), mar = c(3.2, 3.2, 1.5, 0.8), mgp = c(2.0, 0.6, 0), tcl = -0.3)
    par.use <- utils::modifyList(par.default, par.args)
    op <- do.call(graphics::par, par.use)
    on.exit(graphics::par(op), add = TRUE)

    if ("connect" %in% which) {
        df <- x$connectivity
        args <- list(df$k, df$lcc.frac, type = "l", las = 1,
                     xlab = "k", ylab = "LCC fraction",
                     main = "Connectivity (LCC fraction)")
        args <- utils::modifyList(args, connect.args)
        do.call(graphics::plot, args)
        if (is.finite(x$k.cc.edit)) graphics::abline(v = x$k.cc.edit, lty = 2)
        if (is.finite(x$k.cc.mixing)) graphics::abline(v = x$k.cc.mixing, lty = 3)
    }
    if ("edit" %in% which) {
        if (is.null(x$edit)) {
            graphics::plot.new()
            graphics::title("Edit curve (not computed)")
        } else {
            df <- x$edit
            args <- list(df$k, df$edit.dist.to.next, type = "l", las = 1,
                         xlab = "k", ylab = "edit dist to next",
                         main = "Edit distance between consecutive graphs")
            args <- utils::modifyList(args, edit.args)
            do.call(graphics::plot, args)
            if (is.finite(x$k.cc.edit)) graphics::abline(v = x$k.cc.edit, lty = 2)
            if (is.finite(x$k.opt.edit)) graphics::abline(v = x$k.opt.edit, lty = 3)
        }
    }
    if ("mixing" %in% which) {
        if (is.null(x$mixing)) {
            graphics::plot.new()
            graphics::title("Mixing curve (not computed)")
        } else {
            df <- x$mixing
            args <- list(df$k, df$metric, type = "l", las = 1,
                         xlab = "k", ylab = "mixing metric",
                         main = paste0("Mixing metric: ", x$params$mixing.metric))
            args <- utils::modifyList(args, mixing.args)
            do.call(graphics::plot, args)
            if (is.finite(x$k.cc.mixing)) graphics::abline(v = x$k.cc.mixing, lty = 2)
            if (is.finite(x$k.opt.mixing)) graphics::abline(v = x$k.opt.mixing, lty = 3)
        }
    }
    invisible(x)
}
