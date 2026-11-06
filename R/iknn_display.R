
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

#' Plot Method for IkNN Stability Metrics
#'
#' @param x An object returned by `compute.stability.metrics()`.
#' @param ... Passed to `plot.IkNNgraphs()`.
#'
#' @return Invisibly returns `TRUE` after producing the stability diagnostic
#'   plot.
#'
#' @examples
#' set.seed(1)
#' X <- matrix(rnorm(60), ncol = 2)
#' graphs <- create.iknn.graphs(X, k.values = seq.int(2, 4), compute.full = TRUE,
#'     verbose = FALSE)
#' stability <- compute.stability.metrics(graphs)
#' plot(stability, with.pwlm = FALSE)
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
#' @param mar,mgp,tcl,xline,yline Base graphics controls.
#' @param ... Additional arguments passed to plot.
#'
#' @return Invisibly returns `TRUE`.
#' @examples
#' diagnostics <- structure(list(k.values = 2:4, edit.distances = c(0.3, 0.2),
#'   n.edges.in.pruned.graph = c(6, 8, 10), js.div = c(0.1, 0.05)),
#'   class = "IkNNgraphs")
#' plot(diagnostics, with.pwlm = FALSE)
#' @export
plot.IkNNgraphs <- function(x,
                            type = "diag",
                            diags = c("edist", "edge", "deg"),
                            with.pwlm = TRUE,
                            with.lmin = FALSE,
                            breakpoint.col = "blue",
                            lmin.col = "gray",
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

#' Plot method for cst_graph_mixing_stats
#'
#' @param x Object from `cst.graph.mixing.stats()`.
#' @param which Character vector specifying panels to plot.
#' @param ... Base graphics arguments.
#'
#' @return Invisibly returns `NULL` after producing the requested diagnostic
#'   panels.
#'
#' @examples
#' mixing <- structure(list(mixing.matrix = matrix(c(4, 1, 1, 4), 2,
#'   dimnames = list(c("A", "B"), c("A", "B")))),
#'   class = "cst_graph_mixing_stats")
#' plot(mixing, which = "mixing.matrix")
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

#' Print method for build_iknn_graphs_and_selectk
#'
#' @param x Object from `build.iknn.graphs.and.selectk()`.
#' @param ... Unused.
#'
#' @return Invisibly returns `x`, unchanged, after printing its selected
#'   neighborhood sizes and trimming status.
#'
#' @examples
#' set.seed(1)
#' X <- matrix(rnorm(60), ncol = 2)
#' selected <- build.iknn.graphs.and.selectk(X, k.values = seq.int(2, 4),
#'     method = "edit",
#'     verbose = FALSE)
#' print(selected)
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
#'
#' @return Invisibly returns `x`, unchanged, after producing the requested
#'   panels. If `which` is empty, invisibly returns `NULL` without plotting.
#'
#' @examples
#' set.seed(1)
#' X <- matrix(rnorm(60), ncol = 2)
#' selected <- build.iknn.graphs.and.selectk(X, k.values = seq.int(2, 4),
#'     method = "edit",
#'     verbose = FALSE)
#' plot(selected, which = "connect")
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
