#' Compute a graph summary as a probability mass function
#'
#' @description
#' Converts a graph-like object into a named probability mass function (PMF)
#' describing one selected graph summary. This provides a standardized bridge
#' between graph objects and divergence functions such as
#' [jensen.shannon.divergence()].
#'
#' Supported v1 summaries are:
#' - `"degree_distribution"`
#' - `"edge_weight_distribution"`
#' - `"component_size_distribution"`
#' - `"neighborhood_label_distribution"`
#'
#' `"component_size_distribution"` is included primarily as a diagnostic
#' for disconnectedness / fragmentation, not as a general-purpose default
#' stability summary.
#'
#' @param graph Graph-like object. Supported inputs are:
#' - an object with `adj_list` and optional `weight_list`
#' - an object with `pruned_adj_list` and optional `pruned_weight_list`
#' - a plain adjacency list (list of integer vectors)
#' @param summary Summary type to compute.
#' @param labels Optional label vector used for
#'   `"neighborhood_label_distribution"`. Must have length equal to the
#'   number of vertices.
#' @param weight.list Optional edge-weight list used when `graph` is a
#'   plain adjacency list.
#' @param bins Optional numeric vector of histogram breaks used for
#'   `"edge_weight_distribution"`.
#' @param n.bins Integer number of bins used when `bins` is `NULL`
#'   and the summary is `"edge_weight_distribution"`.
#' @param bin.method Character string controlling automatic bin construction for
#'   `"edge_weight_distribution"`.
#' @param normalize Logical; if `TRUE`, convert counts to a PMF.
#' @param support Optional support to align the resulting PMF to.
#' @param zero.pad Logical; if `TRUE` and `support` is provided,
#'   missing support entries are padded with zero mass.
#' @param simplify.multiple Logical; if `TRUE`, duplicate edges are
#'   collapsed before computing summaries.
#' @param directed Logical; if `FALSE` (default), treat edges as
#'   undirected.
#' @param return.details Logical; if `TRUE`, return a structured list.
#'   Otherwise return the named PMF directly.
#'
#' @return If `return.details = TRUE`, a list with fields:
#' - `summary`: summary type used.
#' - `pmf`: named probability mass function.
#' - `support`: support of the PMF.
#' - `counts`: named raw-count vector before normalization.
#' - `metadata`: list of summary-specific metadata.
#'
#' Otherwise, returns the named PMF vector.
#'
#' @export
compute.graph.summary.pmf <- function(
    graph,
    summary = c(
        "degree_distribution",
        "edge_weight_distribution",
        "component_size_distribution",
        "neighborhood_label_distribution"
    ),
    labels = NULL,
    weight.list = NULL,
    bins = NULL,
    n.bins = 20L,
    bin.method = c("auto", "fixed_width", "fixed_quantile", "explicit"),
    normalize = TRUE,
    support = NULL,
    zero.pad = TRUE,
    simplify.multiple = TRUE,
    directed = FALSE,
    return.details = TRUE
) {
    summary <- match.arg(summary)
    bin.method <- match.arg(bin.method)

    graph.info <- .dgraphs.resolve.graph.summary.inputs(graph = graph, weight.list = weight.list)
    adj.list <- graph.info$adj.list
    weight.list <- graph.info$weight.list
    n.vertices <- graph.info$n.vertices

    edge.df <- .dgraphs.as.edge.data.frame(
        adj.list = adj.list,
        weight.list = weight.list,
        simplify.multiple = simplify.multiple,
        directed = directed
    )

    metadata <- list(
        n.vertices = n.vertices,
        n.edges = nrow(edge.df),
        directed = isTRUE(directed),
        simplify.multiple = isTRUE(simplify.multiple)
    )

    if (summary == "degree_distribution") {
        if (nrow(edge.df) == 0L) {
            deg <- rep.int(0L, n.vertices)
        } else if (isTRUE(directed)) {
            deg <- tabulate(edge.df$from, nbins = n.vertices)
        } else {
            deg <- tabulate(c(edge.df$from, edge.df$to), nbins = n.vertices)
        }
        counts.tab <- table(deg)
        counts <- stats::setNames(as.numeric(counts.tab), names(counts.tab))
    } else if (summary == "edge_weight_distribution") {
        if (nrow(edge.df) == 0L) {
            counts <- c("__no_edges__" = 1)
            metadata$bins <- NULL
            metadata$bin.method <- NULL
        } else {
            if (all(is.na(edge.df$weight))) {
                stop("edge_weight_distribution requires edge weights.")
            }
            bins.use <- bins
            bin.method.use <- bin.method
            if (is.null(bins.use)) {
                bins.use <- .dgraphs.compute.weight.breaks(
                    edge.df$weight,
                    n.bins = n.bins,
                    bin.method = bin.method.use
                )
            } else {
                bin.method.use <- "explicit"
            }
            w.cut <- cut(
                edge.df$weight,
                breaks = bins.use,
                include.lowest = TRUE,
                right = TRUE,
                ordered_result = TRUE
            )
            counts.tab <- table(w.cut)
            counts <- stats::setNames(as.numeric(counts.tab), levels(w.cut))
            metadata$bins <- bins.use
            metadata$bin.method <- bin.method.use
        }
    } else if (summary == "component_size_distribution") {
        cc <- .dgraphs.connected.components(adj.list)
        comp.sizes <- as.integer(table(cc))
        size.freq <- table(comp.sizes)
        counts <- stats::setNames(
            as.numeric(size.freq) * as.numeric(names(size.freq)),
            names(size.freq)
        )
        metadata$component_count <- length(comp.sizes)
        metadata$fragmentation_diagnostic <- TRUE
    } else if (summary == "neighborhood_label_distribution") {
        labels <- .dgraphs.validate.summary.labels(labels, n.vertices)
        if (nrow(edge.df) == 0L) {
            counts <- c("__no_edges__" = 1)
            metadata$n.labeled.edges <- 0L
        } else {
            from.lab <- labels[edge.df$from]
            to.lab <- labels[edge.df$to]
            ok <- !is.na(from.lab) & !is.na(to.lab)
            if (!any(ok)) {
                counts <- c("__no_labeled_edges__" = 1)
                metadata$n.labeled.edges <- 0L
            } else {
                from.lab <- as.character(from.lab[ok])
                to.lab <- as.character(to.lab[ok])
                if (!isTRUE(directed)) {
                    pair.mat <- t(vapply(
                        seq_along(from.lab),
                        function(i) sort(c(from.lab[[i]], to.lab[[i]]), method = "shell"),
                        character(2)
                    ))
                    pair.keys <- paste(pair.mat[, 1], pair.mat[, 2], sep = "|")
                } else {
                    pair.keys <- paste(from.lab, to.lab, sep = "|")
                }
                pair.tab <- table(pair.keys)
                counts <- stats::setNames(as.numeric(pair.tab), names(pair.tab))
                metadata$n.labeled.edges <- sum(ok)
            }
        }
    } else {
        stop("Unsupported summary: ", summary)
    }

    pmf <- .dgraphs.finalize.named.pmf(
        counts = counts,
        support = support,
        normalize = normalize,
        zero.pad = zero.pad
    )

    if (!isTRUE(return.details)) {
        return(pmf)
    }

    list(
        summary = summary,
        pmf = pmf,
        support = names(pmf),
        counts = .dgraphs.finalize.named.pmf(
            counts = counts,
            support = support,
            normalize = FALSE,
            zero.pad = zero.pad
        ),
        metadata = metadata
    )
}

#' Compute divergence between two graphs using a selected graph summary
#'
#' @description
#' Extracts one selected graph summary from two graph-like objects and computes a
#' divergence between the resulting probability mass functions.
#'
#' Currently the supported divergence is Jensen-Shannon divergence, implemented
#' via [jensen.shannon.divergence()].
#'
#' @param g1 First graph-like object.
#' @param g2 Second graph-like object.
#' @param summary Summary type to compare.
#' @param divergence Divergence type. Currently only `"js"`.
#' @param labels Optional shared vertex-label vector used for
#'   `"neighborhood_label_distribution"`.
#' @param summary.args Optional named list forwarded to
#'   [compute.graph.summary.pmf()].
#' @param support Optional common support. If `NULL`, the union of the two
#'   PMF supports is used.
#' @param return.details Logical; if `TRUE`, return a structured list.
#'
#' @return If `return.details = TRUE`, a list with fields:
#' - `summary`: summary type used.
#' - `divergence`: divergence type used.
#' - `value`: scalar divergence value.
#' - `pmf1`: aligned PMF for `g1`.
#' - `pmf2`: aligned PMF for `g2`.
#' - `support`: aligned support.
#' - `metadata`: summary-specific metadata for both graphs.
#'
#' Otherwise, returns the scalar divergence value.
#'
#' @export
graph.summary.divergence <- function(
    g1,
    g2,
    summary = c(
        "degree_distribution",
        "edge_weight_distribution",
        "component_size_distribution",
        "neighborhood_label_distribution"
    ),
    divergence = c("js"),
    labels = NULL,
    summary.args = list(),
    support = NULL,
    return.details = TRUE
) {
    summary <- match.arg(summary)
    divergence <- match.arg(divergence)

    args1 <- summary.args
    args2 <- summary.args
    args1$graph <- g1
    args2$graph <- g2
    args1$summary <- summary
    args2$summary <- summary
    args1$labels <- labels
    args2$labels <- labels
    args1$return.details <- TRUE
    args2$return.details <- TRUE

    if (identical(summary, "edge_weight_distribution") && is.null(args1$bins) && is.null(args2$bins)) {
        pooled.weights <- c(
            .dgraphs.extract.edge.weights(g1),
            .dgraphs.extract.edge.weights(g2)
        )
        if (length(pooled.weights) > 0L) {
            n.bins.use <- args1[["n.bins"]]
            if (is.null(n.bins.use)) {
                n.bins.use <- 20L
            }
            bin.method.use <- args1[["bin.method"]]
            if (is.null(bin.method.use)) {
                bin.method.use <- "auto"
            }
            bins.use <- .dgraphs.compute.weight.breaks(
                pooled.weights,
                n.bins = as.integer(n.bins.use),
                bin.method = as.character(bin.method.use)
            )
            args1$bins <- bins.use
            args2$bins <- bins.use
        }
    }

    pmf1.obj <- do.call(compute.graph.summary.pmf, args1)
    pmf2.obj <- do.call(compute.graph.summary.pmf, args2)

    support.use <- support
    if (is.null(support.use)) {
        support.use <- union(names(pmf1.obj$pmf), names(pmf2.obj$pmf))
        support.use <- support.use[.dgraphs.order.support(support.use)]
    }

    pmf1 <- .dgraphs.align.named.vector(pmf1.obj$pmf, support.use)
    pmf2 <- .dgraphs.align.named.vector(pmf2.obj$pmf, support.use)

    value <- switch(
        divergence,
        js = jensen.shannon.divergence(pmf1, pmf2),
        stop("Unsupported divergence: ", divergence)
    )

    if (!isTRUE(return.details)) {
        return(value)
    }

    list(
        summary = summary,
        divergence = divergence,
        value = as.numeric(value),
        pmf1 = pmf1,
        pmf2 = pmf2,
        support = support.use,
        metadata = list(
            graph1 = pmf1.obj$metadata,
            graph2 = pmf2.obj$metadata
        )
    )
}

#' Compute graph-summary stability across a graph sequence
#'
#' @description
#' Computes a divergence-based stability curve across consecutive graphs in a
#' sequence. This function provides a generalized sequence-level analogue of the
#' degree-profile Jensen-Shannon calculation currently used in
#' `compute.stability.metrics()`.
#'
#' @param graphs Either a list of graph-like objects or an object of class
#'   `"iknn_graphs"`.
#' @param summary Summary type to compare across consecutive graph pairs.
#' @param divergence Divergence type. Currently only `"js"`.
#' @param labels Optional shared vertex-label vector used for
#'   `"neighborhood_label_distribution"`.
#' @param summary.args Optional named list forwarded to
#'   [graph.summary.divergence()].
#' @param k.values Optional integer vector of k values. If `graphs` is an
#'   `"iknn_graphs"` object and `k.values` is `NULL`, the values
#'   are derived from its `kmin` and `kmax` attributes.
#' @param graph.type If `graphs` is an `"iknn_graphs"` object, choose
#'   either `"geom"` or `"isize"`.
#' @param return.details Logical; if `TRUE`, return a structured list.
#'
#' @return If `return.details = TRUE`, a list with fields:
#' - `summary`: summary type used.
#' - `divergence`: divergence type used.
#' - `k.values`: full `k` sequence.
#' - `k.transition.values`: `k` values corresponding to consecutive-graph
#'   transitions.
#' - `values`: vector of divergence values of length `length(k.values) - 1`.
#' - `details`: optional pairwise details for each transition.
#'
#' Otherwise, returns only the divergence vector.
#'
#' @export
compute.graph.summary.stability <- function(
    graphs,
    summary = c(
        "degree_distribution",
        "edge_weight_distribution",
        "component_size_distribution",
        "neighborhood_label_distribution"
    ),
    divergence = c("js"),
    labels = NULL,
    summary.args = list(),
    k.values = NULL,
    graph.type = c("geom", "isize"),
    return.details = TRUE
) {
    summary <- match.arg(summary)
    divergence <- match.arg(divergence)

    graph.seq <- graphs
    if (inherits(graphs, "iknn_graphs")) {
        graph.type <- match.arg(graph.type)
        graph.seq <- if (graph.type == "geom") graphs$geom_pruned_graphs else graphs$isize_pruned_graphs
        if (is.null(graph.seq)) {
            stop("Requested graph sequence is unavailable in `graphs`.")
        }
        if (is.null(k.values)) {
            kmin <- attr(graphs, "kmin")
            kmax <- attr(graphs, "kmax")
            if (!is.numeric(kmin) || !is.numeric(kmax) || length(kmin) != 1L || length(kmax) != 1L) {
                stop("`graphs` must provide scalar numeric `kmin` and `kmax` attributes when `k.values` is NULL.")
            }
            k.values <- as.integer(kmin:kmax)
        }
    }

    if (!is.list(graph.seq) || length(graph.seq) < 1L) {
        stop("`graphs` must be a non-empty graph sequence or an `iknn_graphs` object.")
    }

    if (is.null(k.values)) {
        k.values <- seq_along(graph.seq)
    }
    k.values <- as.integer(k.values)
    if (length(k.values) != length(graph.seq)) {
        stop("`k.values` must have the same length as the graph sequence.")
    }

    if (length(graph.seq) < 2L) {
        out <- list(
            summary = summary,
            divergence = divergence,
            k.values = k.values,
            k.transition.values = integer(0),
            values = numeric(0),
            details = list(pairwise = list())
        )
        class(out) <- c("graph_summary_stability", "list")
        if (!isTRUE(return.details)) {
            return(out$values)
        }
        return(out)
    }

    values <- numeric(length(graph.seq) - 1L)
    pairwise <- vector("list", length(graph.seq) - 1L)

    for (i in seq_len(length(graph.seq) - 1L)) {
        pair.res <- graph.summary.divergence(
            g1 = graph.seq[[i]],
            g2 = graph.seq[[i + 1L]],
            summary = summary,
            divergence = divergence,
            labels = labels,
            summary.args = summary.args,
            return.details = TRUE
        )
        values[[i]] <- pair.res$value
        pairwise[[i]] <- pair.res
    }

    out <- list(
        summary = summary,
        divergence = divergence,
        k.values = k.values,
        k.transition.values = k.values[-length(k.values)],
        values = values,
        details = list(pairwise = pairwise)
    )
    class(out) <- c("graph_summary_stability", "list")

    if (!isTRUE(return.details)) {
        return(out$values)
    }
    out
}

.dgraphs.resolve.graph.summary.inputs <- function(graph, weight.list = NULL) {
    if (is.list(graph) && !is.null(graph$adj_list)) {
        adj.list <- graph$adj_list
        if (is.null(weight.list) && !is.null(graph$weight_list)) {
            weight.list <- graph$weight_list
        }
    } else if (is.list(graph) && !is.null(graph$pruned_adj_list)) {
        adj.list <- graph$pruned_adj_list
        if (is.null(weight.list) && !is.null(graph$pruned_weight_list)) {
            weight.list <- graph$pruned_weight_list
        }
    } else if (is.list(graph) && .dgraphs.looks.like.adj.list(graph)) {
        adj.list <- graph
    } else {
        stop("Unsupported graph input. Expected adj_list/pruned_adj_list or a plain adjacency list.")
    }

    if (!is.list(adj.list)) {
        stop("Resolved adjacency structure must be a list.")
    }

    n.vertices <- length(adj.list)
    if (!is.null(weight.list)) {
        if (!is.list(weight.list) || length(weight.list) != n.vertices) {
            stop("`weight.list` must be a list with the same length as the adjacency list.")
        }
    }

    list(
        adj.list = lapply(adj.list, function(x) as.integer(x)),
        weight.list = weight.list,
        n.vertices = n.vertices
    )
}

.dgraphs.looks.like.adj.list <- function(x) {
    if (!is.list(x)) {
        return(FALSE)
    }
    all(vapply(x, function(el) is.null(el) || is.atomic(el), logical(1)))
}

.dgraphs.as.edge.data.frame <- function(adj.list,
                                      weight.list = NULL,
                                      simplify.multiple = TRUE,
                                      directed = FALSE) {
    n <- length(adj.list)
    if (n == 0L) {
        return(data.frame(from = integer(0), to = integer(0), weight = numeric(0)))
    }

    from <- rep.int(seq_len(n), lengths(adj.list))
    to <- unlist(adj.list, use.names = FALSE)
    if (length(to) == 0L) {
        return(data.frame(from = integer(0), to = integer(0), weight = numeric(0)))
    }

    if (is.null(weight.list)) {
        weight <- rep(NA_real_, length(to))
    } else {
        weight <- unlist(weight.list, use.names = FALSE)
        if (length(weight) != length(to)) {
            stop("Flattened `weight.list` length must match flattened adjacency length.")
        }
        weight <- as.double(weight)
    }

    to <- as.integer(to)
    ok <- is.finite(to) & to >= 1L & to <= n
    from <- from[ok]
    to <- to[ok]
    weight <- weight[ok]

    if (!isTRUE(directed)) {
        ii <- pmin(from, to)
        jj <- pmax(from, to)
        keep <- ii != jj
        from <- ii[keep]
        to <- jj[keep]
        weight <- weight[keep]
    }

    if (length(from) == 0L) {
        return(data.frame(from = integer(0), to = integer(0), weight = numeric(0)))
    }

    edge.df <- data.frame(
        from = as.integer(from),
        to = as.integer(to),
        weight = as.double(weight),
        stringsAsFactors = FALSE
    )

    if (isTRUE(simplify.multiple)) {
        key <- paste(edge.df$from, edge.df$to, sep = "|")
        split.idx <- split(seq_len(nrow(edge.df)), key)
        edge.df <- do.call(
            rbind,
            lapply(split.idx, function(idx) {
                w <- edge.df$weight[idx]
                if (all(is.na(w))) {
                    w.use <- NA_real_
                } else {
                    w.use <- mean(w, na.rm = TRUE)
                }
                data.frame(
                    from = edge.df$from[idx[1L]],
                    to = edge.df$to[idx[1L]],
                    weight = w.use,
                    stringsAsFactors = FALSE
                )
            })
        )
        rownames(edge.df) <- NULL
    }

    edge.df
}

.dgraphs.compute.weight.breaks <- function(weights,
                                        n.bins = 20L,
                                        bin.method = c("auto", "fixed_width", "fixed_quantile", "explicit")) {
    bin.method <- match.arg(bin.method)
    w <- as.double(weights)
    w <- w[is.finite(w)]
    if (length(w) == 0L) {
        return(c(0, 1))
    }

    n.bins <- as.integer(n.bins)
    if (!is.finite(n.bins) || n.bins < 1L) {
        stop("`n.bins` must be an integer >= 1.")
    }

    if (bin.method == "auto") {
        bin.method <- "fixed_width"
    }

    if (bin.method == "fixed_quantile") {
        probs <- seq(0, 1, length.out = n.bins + 1L)
        br <- unique(as.numeric(stats::quantile(w, probs = probs, na.rm = TRUE, names = FALSE, type = 8)))
    } else {
        br <- pretty(range(w), n = n.bins)
    }

    if (length(br) < 2L || diff(range(br)) == 0) {
        center <- w[1L]
        delta <- max(abs(center) * 1e-6, 1e-6)
        br <- c(center - delta, center + delta)
    }

    br
}

.dgraphs.validate.summary.labels <- function(labels, n.vertices) {
    if (is.null(labels)) {
        stop("`labels` must be provided for neighborhood_label_distribution.")
    }
    if (length(labels) != n.vertices) {
        stop("`labels` must have length equal to the number of vertices.")
    }
    labels
}

.dgraphs.finalize.named.pmf <- function(counts,
                                      support = NULL,
                                      normalize = TRUE,
                                      zero.pad = TRUE) {
    nm <- names(counts)
    counts <- stats::setNames(as.double(counts), nm)
    if (is.null(names(counts))) {
        stop("`counts` must be a named numeric vector.")
    }

    if (!is.null(support)) {
        counts <- .dgraphs.align.named.vector(counts, support)
    } else {
        counts <- counts[.dgraphs.order.support(names(counts))]
    }

    if (!isTRUE(normalize)) {
        return(counts)
    }

    total <- sum(counts)
    if (!is.finite(total) || total <= 0) {
        stop("Cannot normalize a summary with non-positive total mass.")
    }

    counts / total
}

.dgraphs.align.named.vector <- function(x, support) {
    support <- as.character(support)
    out <- rep(0, length(support))
    names(out) <- support
    idx <- match(names(x), support)
    idx.ok <- !is.na(idx)
    out[idx[idx.ok]] <- as.double(x[idx.ok])
    out
}

.dgraphs.order.support <- function(support) {
    support <- as.character(support)
    num <- suppressWarnings(as.numeric(support))
    if (all(!is.na(num))) {
        return(order(num))
    }
    order(support)
}

.dgraphs.connected.components <- function(adj.list) {
    if (exists("graph.connected.components", mode = "function")) {
        return(graph.connected.components(adj.list))
    }

    n <- length(adj.list)
    comp <- rep.int(NA_integer_, n)
    current <- 0L

    for (start in seq_len(n)) {
        if (!is.na(comp[start])) next
        current <- current + 1L
        queue <- start
        comp[start] <- current
        head <- 1L
        while (head <= length(queue)) {
            v <- queue[[head]]
            head <- head + 1L
            nbrs <- adj.list[[v]]
            nbrs <- nbrs[is.finite(nbrs) & nbrs >= 1L & nbrs <= n]
            new <- nbrs[is.na(comp[nbrs])]
            if (length(new) > 0L) {
                comp[new] <- current
                queue <- c(queue, new)
            }
        }
    }

    comp
}

.dgraphs.extract.edge.weights <- function(graph) {
    info <- .dgraphs.resolve.graph.summary.inputs(graph)
    edge.df <- .dgraphs.as.edge.data.frame(
        adj.list = info$adj.list,
        weight.list = info$weight.list,
        simplify.multiple = TRUE,
        directed = FALSE
    )
    w <- edge.df$weight
    w[is.finite(w)]
}
