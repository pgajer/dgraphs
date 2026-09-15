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
#' @examples
#' set.seed(1)
#' x <- matrix(rnorm(60), ncol = 2)
#' graphs <- create.iknn.graphs(x, k.values = seq.int(2, 4), compute.full = TRUE,
#'     verbose = FALSE)
#' stability <- compute.stability.metrics(graphs)
#' stability$edit.distances
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

    k.values <- .validate.k.values(attr(graphs, "k.values"), Inf)
    graphs.list <- if (graph.type == "geom") graphs$geom_pruned_graphs else graphs$isize_pruned_graphs
    if (is.null(graphs.list)) {
        if (graph.type == "isize") {
            stop("Requested intersection-size pruned graphs are not available. Recompute with create.iknn.graphs(..., compute.full = TRUE, with.isize.pruning = TRUE).")
        }
        stop("Requested pruned graphs are not available. Recompute create.iknn.graphs(..., compute.full = TRUE).")
    }
    if (length(graphs.list) != length(k.values)) {
        stop("Length mismatch: pruned graph list length does not match k.values.")
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
            if (!is.null(graph.adjacency(g))) {
                n.edges.in.pruned.graph[i] <- sum(vapply(graph.adjacency(g), length, integer(1))) / 2
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

compute.degrees.js.divergence <- function(graph1, graph2) {
    graph.summary.divergence(
        graph1 = graph1,
        graph2 = graph2,
        summary = "degree_distribution",
        divergence = "js",
        return.details = FALSE
    )
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
        if (is.null(graph.adjacency(g1)) || is.null(graph.adjacency(g2))) {
            stop("Each graph must contain an 'adj_list'.")
        }
        e1 <- edge.keys(graph.adjacency(g1))
        e2 <- edge.keys(graph.adjacency(g2))
        edit.distances[i] <- length(setdiff(e1, e2)) + length(setdiff(e2, e1))
    }
    edit.distances
}

internal.compute.edit.distances <- function(graphs) {
    compute.edit.distances(graphs)
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
