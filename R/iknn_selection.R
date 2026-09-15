
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

find.optimal.k <- function(x, ...) {
    if (inherits(x, "iknn_stability_metrics")) return(find.optimal.k.from.stability(x, ...))
    find.optimal.k.from.birth.death(x, ...)
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

find.optimal.k.from.birth.death <- function(birth.death.matrix, k.values, matrix_type = "geom") {
    k.values <- .validate.k.values(k.values, Inf)
    kmax <- max(k.values)
    if (is.null(birth.death.matrix) || nrow(birth.death.matrix) == 0L) {
        warning(paste("Empty", matrix_type, "birth/death matrix. Returning middle k value."))
        return(list(
            stability.scores = rep(0, length(k.values)),
            k.values = k.values,
            opt.k = k.values[ceiling(length(k.values) / 2)]
        ))
    }

    persistence <- birth.death.matrix[, "death_time"] - birth.death.matrix[, "birth_time"]
    stability.scores <- numeric(length(k.values))
    for (k in k.values) {
        edges.at.k <- birth.death.matrix[, "birth_time"] <= k &
            birth.death.matrix[, "death_time"] > k
        if (sum(edges.at.k) > 0L) {
            avg.persistence <- mean(persistence[edges.at.k])
            persistent.ratio <- mean(birth.death.matrix[edges.at.k, "death_time"] == (kmax + 1L))
            edge.stability <- mean(pmin(
                k - birth.death.matrix[edges.at.k, "birth_time"],
                birth.death.matrix[edges.at.k, "death_time"] - k
            ))
            stability.scores[match(k, k.values)] <- avg.persistence * persistent.ratio * edge.stability
        }
    }

    list(
        stability.scores = stability.scores,
        k.values = k.values,
        opt.k = k.values[which.max(stability.scores)]
    )
}

trim.X.to.main.cc <- function(X, adj.list, verbose = FALSE) {
    cc <- .graph.components(adj.list)$component_id
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

#' Build iKNN Graphs and Select a Neighborhood Size
#'
#' Builds an iKNN graph sequence and selects `k` from structural edit-distance
#' stability, label-mixing stability, or both.
#'
#' @param X Numeric observation-by-feature matrix.
#' @param k.values Strictly increasing integer vector of neighborhood sizes, each between 1 and n - 1.
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
#' @param verbose Logical; report progress.
#' @param ... Additional arguments forwarded to [create.iknn.graphs()].
#'
#' @return An object of class `"build_iknn_graphs_and_selectk"` containing the
#'   graph sequence, connectivity diagnostics, selection curves, selected
#'   neighborhood sizes, trimming metadata, and call parameters.
#' @examples
#' set.seed(1)
#' x <- matrix(rnorm(60), ncol = 2)
#' selected <- build.iknn.graphs.and.selectk(x, k.values = seq.int(2, 4),
#'     method = "edit",
#'     verbose = FALSE)
#' selected$k.opt.edit
#' @export
build.iknn.graphs.and.selectk <- function(X,
                                          k.values,
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
    k.values <- .validate.k.values(k.values, nrow(X))
    kmin <- min(k.values); kmax <- max(k.values)

    method <- match.arg(method)
    mixing.metric <- match.arg(mixing.metric)
    affinity.method <- match.arg(affinity.method)
    affinity.sigma.from <- match.arg(affinity.sigma.from)
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
        el <- adjlist.to.edge.mat(graph.adjacency(g.obj), graph.lengths(g.obj), n = n)
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
        k.values = k.values,
        pca.dim = pca.dim,
        variance.explained = variance.explained,
        compute.full = TRUE,
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
            el <- adjlist.to.edge.mat(graph.adjacency(g.list[[i]]), graph.lengths(g.list[[i]]), n = n)
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
        el <- adjlist.to.edge.mat(graph.adjacency(g.list[[best.idx]]), graph.lengths(g.list[[best.idx]]), n = nrow(X))
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
        if (any(k.values >= nrow(X))) stop("Requested k.values do not fit the trimmed sample; choose smaller values.")
        X.graphs <- create.iknn.graphs(
            X,
            k.values = k.values,
            pca.dim = pca.dim,
            variance.explained = variance.explained,
            compute.full = TRUE,
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
            el.ref <- adjlist.to.edge.mat(graph.adjacency(g.list[[idx.ref]]), graph.lengths(g.list[[idx.ref]]), n = nrow(X))
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
            el <- adjlist.to.edge.mat(graph.adjacency(g.obj), graph.lengths(g.obj), n = n0)
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
            k.values = k.values,
            pca.dim = pca.dim,
            variance.explained = variance.explained,
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
