#' Compute Graph Endpoint Scores from a 3D Embedding
#'
#' @description
#' Computes endpointness diagnostics for graph vertices by selecting graph-geodesic
#' neighborhoods and evaluating how concentrated the corresponding 3D embedding
#' directions are. This targets terminal arm tips in an embedding rather than
#' graph-theoretic degree-1 vertices.
#'
#' For each vertex \eqn{x}, let \eqn{u_1, \dots, u_m} be unit vectors in the
#' embedding from \eqn{x} to graph-geodesic neighbors of \eqn{x}. The function
#' computes:
#' \deqn{s_{\min}(x) = \min_{i < j} u_i^\top u_j}
#' \deqn{s_q(x) = \mathrm{quantile}\{u_i^\top u_j : i < j\}}
#' \deqn{m(x) = \left\| \frac{1}{\sum_i w_i} \sum_i w_i u_i \right\|}
#' \deqn{\mathrm{score}(x) = m(x)\, \frac{1 + s_q(x)}{2}}
#'
#' Neighborhoods are selected in graph-geodesic space while directions are taken
#' from the supplied 3D embedding.
#'
#' @param adj.list Graph adjacency list (1-based vertex indices).
#' @param weight.list Edge-length list aligned with `adj.list`.
#' @param layout.3d Numeric matrix or data frame with 3 columns giving the 3D
#'   embedding coordinates for graph vertices.
#' @param neighborhood Character string. Either `"geodesic_k"` (default) or
#'   `"geodesic_radius"`.
#' @param k Integer vector of geodesic neighborhood sizes used when
#'   `neighborhood = "geodesic_k"`.
#' @param radius Positive numeric vector of geodesic radii used when
#'   `neighborhood = "geodesic_radius"`.
#' @param q Quantile used for `s.q`. Must lie in `[0, 1]`. Default is `0.1`.
#' @param neighbor.weighting Character string controlling neighbor weights for
#'   `m` and weighted pair quantiles. One of `"uniform"` (default),
#'   `"inverse_distance"`, or `"gaussian"`.
#' @param gaussian.sigma Optional positive numeric scale used when
#'   `neighbor.weighting = "gaussian"`. If `NULL`, the median positive geodesic
#'   neighborhood distance is used per vertex and scale.
#' @param min.neighborhood.size Minimum number of usable neighbors required after
#'   removing zero-length embedding vectors. Must be at least `2`.
#' @param scale.aggregate How to aggregate scores across multiple neighborhood
#'   scales. One of `"mean"` (default), `"median"`, `"min"`, or `"max"`.
#' @param verbose Logical; if `TRUE`, prints progress.
#'
#' @return A list with aggregated per-vertex scores, per-scale score matrices,
#'   and neighborhood diagnostics.
#'
#' @examples
#' chain <- create.chain.graph(n.vertices = 8)
#' layout <- cbind(seq_len(8), 0, 0)
#' scores <- compute.graph.endpoint.scores(
#'   chain$adj.list,
#'   chain$edge.lengths,
#'   layout,
#'   k = c(2, 3),
#'   min.neighborhood.size = 2
#' )
#' head(scores$summary)
#'
#' @export
compute.graph.endpoint.scores <- function(adj.list,
                                          weight.list,
                                          layout.3d,
                                          neighborhood = c("geodesic_k", "geodesic_radius"),
                                          k = c(10L, 20L, 30L),
                                          radius = NULL,
                                          q = 0.10,
                                          neighbor.weighting = c("uniform", "inverse_distance", "gaussian"),
                                          gaussian.sigma = NULL,
                                          min.neighborhood.size = 3L,
                                          scale.aggregate = c("mean", "median", "min", "max"),
                                          verbose = FALSE) {
    neighborhood <- match.arg(neighborhood)
    neighbor.weighting <- match.arg(neighbor.weighting)
    scale.aggregate <- match.arg(scale.aggregate)

    .validate.graph.endpoint.inputs(
        adj.list = adj.list,
        weight.list = weight.list,
        layout.3d = layout.3d,
        q = q,
        gaussian.sigma = gaussian.sigma,
        min.neighborhood.size = min.neighborhood.size,
        verbose = verbose
    )

    layout.3d <- as.matrix(layout.3d)
    storage.mode(layout.3d) <- "double"
    n.vertices <- nrow(layout.3d)

    scales <- .resolve.graph.endpoint.scales(
        neighborhood = neighborhood,
        k = k,
        radius = radius,
        n.vertices = n.vertices
    )
    scale.labels <- names(scales)

    if (verbose) {
        message(
            sprintf(
                "Computing graph endpoint scores for %d vertices across %d scale(s)",
                n.vertices,
                length(scales)
            )
        )
    }

    score.matrices <- .compute.graph.endpoint.scores.reference(
        adj.list = adj.list,
        weight.list = weight.list,
        layout.3d = layout.3d,
        scales = unname(unlist(scales, use.names = FALSE)),
        neighborhood = neighborhood,
        q = q,
        neighbor.weighting = neighbor.weighting,
        gaussian.sigma = gaussian.sigma,
        min.neighborhood.size = min.neighborhood.size,
        verbose = verbose,
        prefer.cpp = TRUE
    )

    s.min.by.scale <- score.matrices$s.min
    s.q.by.scale <- score.matrices$s.q
    m.by.scale <- score.matrices$m
    score.by.scale <- score.matrices$score
    neighborhood.size.by.scale <- score.matrices$neighborhood.size
    distance.scale.by.scale <- score.matrices$distance.scale

    colnames(s.min.by.scale) <- scale.labels
    colnames(s.q.by.scale) <- scale.labels
    colnames(m.by.scale) <- scale.labels
    colnames(score.by.scale) <- scale.labels
    colnames(neighborhood.size.by.scale) <- scale.labels
    colnames(distance.scale.by.scale) <- scale.labels

    aggregate.fn <- .make.graph.endpoint.aggregate(scale.aggregate)

    s.min <- apply(s.min.by.scale, 1L, aggregate.fn)
    s.q <- apply(s.q.by.scale, 1L, aggregate.fn)
    m <- apply(m.by.scale, 1L, aggregate.fn)
    score <- apply(score.by.scale, 1L, aggregate.fn)
    scale.coverage <- rowMeans(is.finite(score.by.scale))

    summary.df <- data.frame(
        vertex = seq_len(n.vertices),
        s.min = s.min,
        s.q = s.q,
        m = m,
        score = score,
        scale.coverage = scale.coverage,
        mean.neighborhood.size = apply(neighborhood.size.by.scale, 1L, function(x) {
            idx <- x > 0L
            if (!any(idx)) return(NA_real_)
            mean(x[idx])
        }),
        stringsAsFactors = FALSE
    )

    res <- list(
        neighborhood = neighborhood,
        scales = unname(scales),
        scale.labels = scale.labels,
        q = q,
        neighbor.weighting = neighbor.weighting,
        gaussian.sigma = gaussian.sigma,
        min.neighborhood.size = as.integer(min.neighborhood.size),
        scale.aggregate = scale.aggregate,
        s.min = as.numeric(s.min),
        s.q = as.numeric(s.q),
        m = as.numeric(m),
        score = as.numeric(score),
        by.scale = list(
            s.min = s.min.by.scale,
            s.q = s.q.by.scale,
            m = m.by.scale,
            score = score.by.scale,
            neighborhood.size = neighborhood.size.by.scale,
            distance.scale = distance.scale.by.scale
        ),
        scale.coverage = as.numeric(scale.coverage),
        summary = summary.df
    )

    class(res) <- c("graph_endpoint_scores", class(res))
    res
}

.compute.graph.endpoint.scores.reference <- function(adj.list,
                                                     weight.list,
                                                     layout.3d,
                                                     scales,
                                                     neighborhood,
                                                     q,
                                                     neighbor.weighting,
                                                     gaussian.sigma,
                                                     min.neighborhood.size,
                                                     verbose = FALSE,
                                                     prefer.cpp = FALSE)
{
    rcpp.fn <- get0("rcpp_compute_graph_endpoint_scores", mode = "function")
    if (isTRUE(prefer.cpp) && is.function(rcpp.fn)) {
        return(
            rcpp.fn(
                adj_list = adj.list,
                weight_list = weight.list,
                layout_3d = layout.3d,
                scales = as.numeric(scales),
                neighborhood = neighborhood,
                q = q,
                neighbor_weighting = neighbor.weighting,
                gaussian_sigma = gaussian.sigma,
                min_neighborhood_size = as.integer(min.neighborhood.size)
            )
        )
    }

    graph.obj <- .build.graph.endpoint.igraph(adj.list, weight.list)

    s.min.by.scale <- matrix(NA_real_, nrow = nrow(layout.3d), ncol = length(scales))
    s.q.by.scale <- matrix(NA_real_, nrow = nrow(layout.3d), ncol = length(scales))
    m.by.scale <- matrix(NA_real_, nrow = nrow(layout.3d), ncol = length(scales))
    score.by.scale <- matrix(NA_real_, nrow = nrow(layout.3d), ncol = length(scales))
    neighborhood.size.by.scale <- matrix(0L, nrow = nrow(layout.3d), ncol = length(scales))
    distance.scale.by.scale <- matrix(NA_real_, nrow = nrow(layout.3d), ncol = length(scales))

    for (vertex in seq_len(nrow(layout.3d))) {
        if (verbose && (vertex == 1L || vertex %% 100L == 0L || vertex == nrow(layout.3d))) {
            message(sprintf("  vertex %d / %d", vertex, nrow(layout.3d)))
        }

        graph.dist <- as.numeric(
            igraph::distances(
                graph.obj,
                v = vertex,
                to = seq_len(nrow(layout.3d)),
                weights = igraph::E(graph.obj)$weight
            )
        )

        for (scale.idx in seq_along(scales)) {
            selected <- .select.graph.endpoint.neighborhood(
                graph.dist = graph.dist,
                neighborhood = neighborhood,
                scale = scales[[scale.idx]]
            )

            if (length(selected$vertices) < min.neighborhood.size) next

            metrics <- .compute.graph.endpoint.metrics(
                center = layout.3d[vertex, ],
                neighbors = layout.3d[selected$vertices, , drop = FALSE],
                geodesic.distances = selected$distances,
                q = q,
                neighbor.weighting = neighbor.weighting,
                gaussian.sigma = gaussian.sigma,
                min.neighborhood.size = min.neighborhood.size
            )

            neighborhood.size.by.scale[vertex, scale.idx] <- metrics$neighborhood.size
            if (!metrics$usable) next

            s.min.by.scale[vertex, scale.idx] <- metrics$s.min
            s.q.by.scale[vertex, scale.idx] <- metrics$s.q
            m.by.scale[vertex, scale.idx] <- metrics$m
            score.by.scale[vertex, scale.idx] <- metrics$score
            distance.scale.by.scale[vertex, scale.idx] <- metrics$distance.scale
        }
    }

    list(
        s.min = s.min.by.scale,
        s.q = s.q.by.scale,
        m = m.by.scale,
        score = score.by.scale,
        neighborhood.size = neighborhood.size.by.scale,
        distance.scale = distance.scale.by.scale
    )
}

#' Detect Graph Endpoints from a 3D Embedding
#'
#' @description
#' Detects terminal arm tips in a graph by:
#' \enumerate{
#'   \item computing graph endpoint scores from the 3D embedding,
#'   \item optionally smoothing those scores on the graph using
#'     `fit.rdgraph.regression()` and `refit.rdgraph.regression()`,
#'   \item finding graph-local maxima with [detect.local.extrema()],
#'   \item retaining only maxima that persist across neighborhood scales.
#' }
#'
#' The function works with terminal regions in an embedding; returned endpoints
#' need not be degree-1 vertices.
#'
#' @param adj.list Graph adjacency list (1-based vertex indices).
#' @param weight.list Edge-length list aligned with `adj.list`.
#' @param layout.3d Numeric matrix or data frame with 3 columns giving the 3D
#'   embedding coordinates for graph vertices.
#' @param neighborhood Character string. Either `"geodesic_k"` (default) or
#'   `"geodesic_radius"`.
#' @param k Integer vector of geodesic neighborhood sizes used when
#'   `neighborhood = "geodesic_k"`.
#' @param radius Positive numeric vector of geodesic radii used when
#'   `neighborhood = "geodesic_radius"`.
#' @param q Quantile used for `s.q`. Must lie in `[0, 1]`. Default is `0.1`.
#' @param neighbor.weighting Character string controlling neighbor weights for
#'   `m` and weighted pair quantiles. One of `"uniform"` (default),
#'   `"inverse_distance"`, or `"gaussian"`.
#' @param gaussian.sigma Optional positive numeric scale used when
#'   `neighbor.weighting = "gaussian"`.
#' @param min.neighborhood.size Minimum number of usable neighbors required after
#'   removing zero-length embedding vectors.
#' @param scale.aggregate How to aggregate scores across multiple neighborhood
#'   scales. One of `"mean"` (default), `"median"`, `"min"`, or `"max"`.
#' @param score.metric Which score to maximize. One of `"score"` (default),
#'   `"m"`, `"s.q"`, or `"s.min"`.
#' @param smooth Logical; if `TRUE`, smooths aggregated scores on the graph
#'   before detecting extrema.
#' @param fitted.model Optional fitted graph smoother from
#'   `fit.rdgraph.regression()`. If supplied, smoothing reuses its spectral
#'   decomposition via `refit.rdgraph.regression()`.
#' @param smooth.fit.args Optional named list of arguments passed to
#'   `fit.rdgraph.regression()` when `smooth = TRUE` and `fitted.model` is
#'   `NULL`. `X`, `y`, `adj.list`, `weight.list`, and `verbose.level` are filled
#'   automatically when not supplied.
#' @param smooth.refit.args Optional named list of arguments passed to
#'   `refit.rdgraph.regression()` when smoothing aggregated score fields.
#' @param detect.max.radius Maximum radius passed to [detect.local.extrema()]
#'   when calling endpoint candidates from the final detection score.
#' @param detect.min.neighborhood.size Minimum neighborhood size passed to
#'   [detect.local.extrema()] when calling endpoint candidates.
#' @param scale.stability.radius Optional non-negative geodesic radius used when
#'   translating per-scale local maxima into multiscale support. If `NULL`
#'   (default), uses `detect.max.radius`. This allows smoothed maxima that shift
#'   slightly inward to remain supported by nearby raw multiscale maxima.
#' @param min.scale.stability Minimum fraction of scales for which a vertex must
#'   be a local maximum of the per-scale detection score to be retained as an
#'   endpoint. Default is `0.5`.
#' @param min.score.quantile Quantile filter applied to the final detection
#'   score before returning endpoints. Default is `0.8`, which suppresses weak
#'   local maxima while keeping high-scoring terminal tips.
#' @param max.endpoints Optional positive integer cap on returned endpoints.
#' @param verbose Logical; if `TRUE`, prints progress.
#'
#' @return A list with endpoint vertices, score diagnostics, optional smoothed
#'   scores, scale stability summaries, and the local-extrema fit used for
#'   endpoint calling.
#'
#' @examples
#' chain <- create.chain.graph(n.vertices = 8)
#' layout <- cbind(seq_len(8), 0, 0)
#' endpoints <- detect.graph.endpoints(
#'   chain$adj.list,
#'   chain$edge.lengths,
#'   layout,
#'   k = c(2, 3),
#'   min.neighborhood.size = 2,
#'   detect.max.radius = 2,
#'   detect.min.neighborhood.size = 2,
#'   min.score.quantile = 0.5
#' )
#' endpoints$endpoints
#'
#' @export
detect.graph.endpoints <- function(adj.list,
                                   weight.list,
                                   layout.3d,
                                   neighborhood = c("geodesic_k", "geodesic_radius"),
                                   k = c(10L, 20L, 30L),
                                   radius = NULL,
                                   q = 0.10,
                                   neighbor.weighting = c("uniform", "inverse_distance", "gaussian"),
                                   gaussian.sigma = NULL,
                                   min.neighborhood.size = 3L,
                                   scale.aggregate = c("mean", "median", "min", "max"),
                                   score.metric = c("score", "m", "s.q", "s.min"),
                                   smooth = FALSE,
                                   fitted.model = NULL,
                                   smooth.fit.args = NULL,
                                   smooth.refit.args = NULL,
                                   detect.max.radius = 2,
                                   detect.min.neighborhood.size = 2L,
                                   scale.stability.radius = NULL,
                                   min.scale.stability = 0.5,
                                   min.score.quantile = 0.8,
                                   max.endpoints = NULL,
                                   verbose = FALSE) {
    neighborhood <- match.arg(neighborhood)
    neighbor.weighting <- match.arg(neighbor.weighting)
    scale.aggregate <- match.arg(scale.aggregate)
    score.metric <- match.arg(score.metric)

    if (!is.logical(smooth) || length(smooth) != 1L) {
        stop("'smooth' must be a scalar logical.")
    }
    if (!is.numeric(detect.max.radius) || length(detect.max.radius) != 1L ||
        !is.finite(detect.max.radius) || detect.max.radius <= 0) {
        stop("'detect.max.radius' must be a finite scalar > 0.")
    }
    if (!is.numeric(detect.min.neighborhood.size) ||
        length(detect.min.neighborhood.size) != 1L ||
        !is.finite(detect.min.neighborhood.size) ||
        detect.min.neighborhood.size < 1 ||
        detect.min.neighborhood.size != floor(detect.min.neighborhood.size)) {
        stop("'detect.min.neighborhood.size' must be a positive integer.")
    }
    if (!is.numeric(min.scale.stability) || length(min.scale.stability) != 1L ||
        !is.finite(min.scale.stability) ||
        min.scale.stability < 0 || min.scale.stability > 1) {
        stop("'min.scale.stability' must be a finite scalar in [0, 1].")
    }
    if (!is.null(scale.stability.radius)) {
        if (!is.numeric(scale.stability.radius) || length(scale.stability.radius) != 1L ||
            !is.finite(scale.stability.radius) || scale.stability.radius < 0) {
            stop("'scale.stability.radius' must be NULL or a finite scalar >= 0.")
        }
    }
    if (!is.null(min.score.quantile)) {
        if (!is.numeric(min.score.quantile) || length(min.score.quantile) != 1L ||
            !is.finite(min.score.quantile) ||
            min.score.quantile < 0 || min.score.quantile > 1) {
                stop("'min.score.quantile' must be NULL or a finite scalar in [0, 1].")
        }
    }
    if (!is.null(max.endpoints)) {
        if (!is.numeric(max.endpoints) || length(max.endpoints) != 1L ||
            !is.finite(max.endpoints) || max.endpoints < 1 ||
            max.endpoints != floor(max.endpoints)) {
            stop("'max.endpoints' must be NULL or a positive integer.")
        }
    }

    scores <- compute.graph.endpoint.scores(
        adj.list = adj.list,
        weight.list = weight.list,
        layout.3d = layout.3d,
        neighborhood = neighborhood,
        k = k,
        radius = radius,
        q = q,
        neighbor.weighting = neighbor.weighting,
        gaussian.sigma = gaussian.sigma,
        min.neighborhood.size = min.neighborhood.size,
        scale.aggregate = scale.aggregate,
        verbose = verbose
    )

    metric.map <- list(
        score = scores$score,
        m = scores$m,
        s.q = scores$s.q,
        s.min = scores$s.min
    )
    detection.score.raw <- as.numeric(metric.map[[score.metric]])

    smoothed.scores <- NULL
    smoothing.model <- fitted.model
    smoothing.refit <- NULL
    detection.score <- detection.score.raw
    stability.score.by.scale <- NULL
    stability.smoothing.refit <- NULL

    if (smooth) {
        fit.fn <- .dgraphs.get.optional.function("fit.rdgraph.regression")
        refit.fn <- .dgraphs.get.optional.function("refit.rdgraph.regression")
        if (verbose) {
            message("Smoothing aggregated endpoint scores on the graph")
        }

        score.matrix <- cbind(
            s.min = scores$s.min,
            s.q = scores$s.q,
            m = scores$m,
            score = scores$score
        )

        if (is.null(smoothing.model)) {
            fit.args <- smooth.fit.args
            if (is.null(fit.args)) fit.args <- list()
            fit.args$X <- NULL
            fit.args$y <- NULL

            if (is.null(fit.args$k)) {
                fit.args$k <- max(
                    2L,
                    min(
                        30L,
                        as.integer(round(stats::median(pmax(lengths(adj.list), 1L))))
                    )
                )
            }
            if (is.null(fit.args$adj.list)) fit.args$adj.list <- adj.list
            if (is.null(fit.args$weight.list)) fit.args$weight.list <- weight.list
            if (is.null(fit.args$verbose.level)) fit.args$verbose.level <- 0L
            if (is.null(fit.args$compute.extremality)) fit.args$compute.extremality <- FALSE

            fit.call <- c(list(
                X = as.matrix(layout.3d),
                y = detection.score.raw
            ), fit.args)
            smoothing.model <- do.call(fit.fn, fit.call)
        }

        refit.args <- smooth.refit.args
        if (is.null(refit.args)) refit.args <- list()
        refit.args$fitted.model <- NULL
        refit.args$y.new <- NULL
        if (is.null(refit.args$per.column.gcv)) refit.args$per.column.gcv <- TRUE
        if (is.null(refit.args$verbose)) refit.args$verbose <- FALSE

        refit.call <- c(list(
            fitted.model = smoothing.model,
            y.new = score.matrix
        ), refit.args)
        smoothing.refit <- do.call(refit.fn, refit.call)

        smoothed.scores <- smoothing.refit$fitted.values
        smoothed.scores <- as.matrix(smoothed.scores)
        colnames(smoothed.scores) <- colnames(score.matrix)
        detection.score <- as.numeric(smoothed.scores[, score.metric])
    }

    by.scale.metric <- scores$by.scale[[score.metric]]
    stability.score.by.scale <- by.scale.metric
    if (smooth) {
        refit.args.scale <- refit.args
        refit.args.scale$fitted.model <- NULL
        refit.args.scale$y.new <- NULL
        refit.call.scale <- c(list(
            fitted.model = smoothing.model,
            y.new = by.scale.metric
        ), refit.args.scale)
        stability.smoothing.refit <- do.call(refit.fn, refit.call.scale)
        stability.score.by.scale <- stability.smoothing.refit$fitted.values
        stability.score.by.scale <- as.matrix(stability.score.by.scale)
        colnames(stability.score.by.scale) <- colnames(by.scale.metric)
    }

    local.max.by.scale <- matrix(FALSE, nrow = nrow(by.scale.metric), ncol = ncol(by.scale.metric))
    local.max.strong.by.scale <- matrix(FALSE, nrow = nrow(by.scale.metric), ncol = ncol(by.scale.metric))
    colnames(local.max.by.scale) <- colnames(by.scale.metric)
    colnames(local.max.strong.by.scale) <- colnames(by.scale.metric)
    scale.max.threshold.prob <- if (is.null(min.score.quantile)) {
        0.90
    } else {
        max(0.90, as.numeric(min.score.quantile))
    }
    scale.max.thresholds <- rep(NA_real_, ncol(by.scale.metric))

    for (scale.idx in seq_len(ncol(by.scale.metric))) {
        y.scale <- stability.score.by.scale[, scale.idx]
        if (!any(is.finite(y.scale))) next

        y.detect <- .replace.nonfinite.endpoint.values(y.scale)
        ext.scale <- detect.local.extrema(
            adj.list = adj.list,
            weight.list = weight.list,
            y = y.detect,
            max.radius = detect.max.radius,
            min.neighborhood.size = detect.min.neighborhood.size,
            detect.maxima = TRUE,
            custom.prefix = "E"
        )
        if (length(ext.scale$vertices) > 0L) {
            local.max.by.scale[ext.scale$vertices, scale.idx] <- TRUE
            scale.max.thresholds[scale.idx] <- stats::quantile(
                y.scale[is.finite(y.scale)],
                probs = scale.max.threshold.prob,
                na.rm = TRUE
            )[[1]]
            strong.vertices <- ext.scale$vertices[
                y.scale[ext.scale$vertices] >= scale.max.thresholds[scale.idx]
            ]
            if (length(strong.vertices) > 0L) {
                local.max.strong.by.scale[strong.vertices, scale.idx] <- TRUE
            }
        }
    }

    stability.radius <- if (is.null(scale.stability.radius)) detect.max.radius else scale.stability.radius
    local.max.filtered.by.scale <- .suppress.graph.endpoint.maxima.by.scale(
        adj.list = adj.list,
        weight.list = weight.list,
        local.max.by.scale = local.max.strong.by.scale,
        score.by.scale = stability.score.by.scale,
        radius = stability.radius,
        prefer.cpp = TRUE
    )
    local.max.support.by.scale <- local.max.filtered.by.scale

    if (stability.radius > 0) {
        local.max.support.by.scale <- .compute.graph.endpoint.support.by.scale(
            adj.list = adj.list,
            weight.list = weight.list,
            local.max.by.scale = local.max.filtered.by.scale,
            radius = stability.radius,
            prefer.cpp = TRUE
        )
    }

    finite.scale.count <- rowSums(is.finite(by.scale.metric))
    scale.stability <- rowSums(local.max.support.by.scale) / pmax(finite.scale.count, 1L)
    scale.stability[finite.scale.count < 1L] <- NA_real_

    y.final <- .replace.nonfinite.endpoint.values(detection.score)
    local.maxima <- detect.local.extrema(
        adj.list = adj.list,
        weight.list = weight.list,
        y = y.final,
        max.radius = detect.max.radius,
        min.neighborhood.size = detect.min.neighborhood.size,
        detect.maxima = TRUE,
        custom.prefix = "E"
    )

    local.max.vertices <- local.maxima$vertices
    final.threshold <- NA_real_
    if (!is.null(min.score.quantile)) {
        final.threshold <- stats::quantile(
            detection.score[is.finite(detection.score)],
            probs = min.score.quantile,
            na.rm = TRUE
        )[[1]]
    }

    endpoint.vertices <- local.max.vertices
    if (length(endpoint.vertices) > 0L) {
        keep <- rep(TRUE, length(endpoint.vertices))
        if (!is.null(min.score.quantile) && is.finite(final.threshold)) {
            keep <- keep & (detection.score[endpoint.vertices] >= final.threshold)
        }
        keep <- keep & !is.na(scale.stability[endpoint.vertices]) &
            (scale.stability[endpoint.vertices] >= min.scale.stability)
        endpoint.vertices <- endpoint.vertices[keep]
    }

    if (!is.null(max.endpoints) && length(endpoint.vertices) > max.endpoints) {
        ord <- order(detection.score[endpoint.vertices], decreasing = TRUE)
        endpoint.vertices <- endpoint.vertices[ord[seq_len(max.endpoints)]]
    }

    summary.df <- data.frame(
        vertex = seq_along(detection.score),
        s.min = scores$s.min,
        s.q = scores$s.q,
        m = scores$m,
        score = scores$score,
        detection.score.raw = detection.score.raw,
        detection.score = detection.score,
        scale.coverage = scores$scale.coverage,
        scale.stability = scale.stability,
        is.local.max = seq_along(detection.score) %in% local.max.vertices,
        is.endpoint = seq_along(detection.score) %in% endpoint.vertices,
        stringsAsFactors = FALSE
    )

    if (!is.null(smoothed.scores)) {
        summary.df$s.min.smooth <- smoothed.scores[, "s.min"]
        summary.df$s.q.smooth <- smoothed.scores[, "s.q"]
        summary.df$m.smooth <- smoothed.scores[, "m"]
        summary.df$score.smooth <- smoothed.scores[, "score"]
    }

    res <- list(
        endpoints = as.integer(endpoint.vertices),
        score.metric = score.metric,
        scores = scores,
        smooth = smooth,
        smoothing.model = smoothing.model,
        smoothing.refit = smoothing.refit,
        smoothed.scores = smoothed.scores,
        detection.score.raw = as.numeric(detection.score.raw),
        detection.score = as.numeric(detection.score),
        local.maxima = local.maxima,
        local.max.by.scale = local.max.by.scale,
        local.max.strong.by.scale = local.max.strong.by.scale,
        local.max.filtered.by.scale = local.max.filtered.by.scale,
        local.max.support.by.scale = local.max.support.by.scale,
        stability.score.by.scale = stability.score.by.scale,
        stability.smoothing.refit = stability.smoothing.refit,
        scale.stability = as.numeric(scale.stability),
        finite.scale.count = as.integer(finite.scale.count),
        scale.stability.radius = stability.radius,
        scale.max.threshold.prob = scale.max.threshold.prob,
        scale.max.thresholds = as.numeric(scale.max.thresholds),
        min.scale.stability = min.scale.stability,
        score.threshold = final.threshold,
        summary = summary.df
    )

    class(res) <- c("graph_endpoints", class(res))
    res
}

.compute.graph.endpoint.support.by.scale <- function(adj.list,
                                                     weight.list,
                                                     local.max.by.scale,
                                                     radius,
                                                     prefer.cpp = TRUE)
{
    local.max.by.scale <- as.matrix(local.max.by.scale)
    local.max.by.scale <- matrix(
        as.logical(local.max.by.scale),
        nrow = nrow(local.max.by.scale),
        ncol = ncol(local.max.by.scale),
        dimnames = dimnames(local.max.by.scale)
    )

    rcpp.fn <- get0("rcpp_graph_multi_source_support_by_scale", mode = "function")
    if (isTRUE(prefer.cpp) && is.function(rcpp.fn)) {
        support <- rcpp.fn(
            adj_list = adj.list,
            weight_list = weight.list,
            local_max_by_scale = local.max.by.scale,
            radius = as.numeric(radius)
        )
        support <- as.matrix(support)
        dimnames(support) <- dimnames(local.max.by.scale)
        return(support)
    }

    graph.obj <- .build.graph.endpoint.igraph(adj.list, weight.list)
    support <- matrix(
        FALSE,
        nrow = nrow(local.max.by.scale),
        ncol = ncol(local.max.by.scale),
        dimnames = dimnames(local.max.by.scale)
    )

    for (scale.idx in seq_len(ncol(local.max.by.scale))) {
        maxima.idx <- which(local.max.by.scale[, scale.idx])
        if (length(maxima.idx) < 1L) next

        d.to.max <- igraph::distances(
            graph.obj,
            v = maxima.idx,
            to = seq_len(nrow(local.max.by.scale)),
            weights = igraph::E(graph.obj)$weight
        )
        if (is.null(dim(d.to.max))) {
            d.to.max <- matrix(d.to.max, nrow = 1L)
        }
        support[, scale.idx] <- apply(d.to.max, 2L, min) <= radius
    }

    support
}

.suppress.graph.endpoint.maxima.by.scale <- function(adj.list,
                                                     weight.list,
                                                     local.max.by.scale,
                                                     score.by.scale,
                                                     radius,
                                                     prefer.cpp = TRUE)
{
    local.max.by.scale <- as.matrix(local.max.by.scale)
    local.max.by.scale <- matrix(
        as.logical(local.max.by.scale),
        nrow = nrow(local.max.by.scale),
        ncol = ncol(local.max.by.scale),
        dimnames = dimnames(local.max.by.scale)
    )
    score.by.scale <- as.matrix(score.by.scale)

    if (!all(dim(local.max.by.scale) == dim(score.by.scale))) {
        stop("'local.max.by.scale' and 'score.by.scale' must have the same dimensions.")
    }

    rcpp.fn <- get0("rcpp_graph_greedy_maxima_suppression_by_scale", mode = "function")
    if (isTRUE(prefer.cpp) && is.function(rcpp.fn)) {
        keep <- rcpp.fn(
            adj_list = adj.list,
            weight_list = weight.list,
            local_max_by_scale = local.max.by.scale,
            score_by_scale = score.by.scale,
            radius = as.numeric(radius)
        )
        keep <- as.matrix(keep)
        dimnames(keep) <- dimnames(local.max.by.scale)
        return(keep)
    }

    graph.obj <- .build.graph.endpoint.igraph(adj.list, weight.list)
    keep <- matrix(
        FALSE,
        nrow = nrow(local.max.by.scale),
        ncol = ncol(local.max.by.scale),
        dimnames = dimnames(local.max.by.scale)
    )

    for (scale.idx in seq_len(ncol(local.max.by.scale))) {
        cand <- which(local.max.by.scale[, scale.idx])
        if (length(cand) < 1L) next
        ord <- order(score.by.scale[cand, scale.idx], cand, decreasing = TRUE, na.last = NA)
        cand <- cand[ord]
        suppressed <- rep(FALSE, nrow(local.max.by.scale))
        for (vertex in cand) {
            if (suppressed[vertex]) next
            keep[vertex, scale.idx] <- TRUE
            if (radius <= 0) next
            d <- as.numeric(
                igraph::distances(
                    graph.obj,
                    v = vertex,
                    to = cand,
                    weights = igraph::E(graph.obj)$weight
                )
            )
            suppressed[cand[is.finite(d) & d <= radius]] <- TRUE
        }
    }

    keep
}

.validate.graph.endpoint.inputs <- function(adj.list,
                                            weight.list,
                                            layout.3d,
                                            q,
                                            gaussian.sigma,
                                            min.neighborhood.size,
                                            verbose) {
    if (!is.list(adj.list)) stop("'adj.list' must be a list.")
    if (!is.list(weight.list)) stop("'weight.list' must be a list.")
    if (length(adj.list) != length(weight.list)) {
        stop("'adj.list' and 'weight.list' must have the same length.")
    }

    n.vertices <- length(adj.list)
    for (i in seq_len(n.vertices)) {
        if (!is.numeric(adj.list[[i]])) {
            stop(sprintf("'adj.list[[%d]]' must be numeric.", i))
        }
        if (!is.numeric(weight.list[[i]])) {
            stop(sprintf("'weight.list[[%d]]' must be numeric.", i))
        }
        if (length(adj.list[[i]]) != length(weight.list[[i]])) {
            stop(sprintf(
                "'adj.list[[%d]]' and 'weight.list[[%d]]' must have the same length.",
                i,
                i
            ))
        }
        if (length(weight.list[[i]]) > 0L &&
            (any(!is.finite(weight.list[[i]])) || any(weight.list[[i]] <= 0))) {
            stop("All edge lengths must be finite and > 0.")
        }
    }

    if (!is.matrix(layout.3d) && !is.data.frame(layout.3d)) {
        stop("'layout.3d' must be a matrix or data.frame.")
    }
    layout.3d <- as.matrix(layout.3d)
    if (!is.numeric(layout.3d)) stop("'layout.3d' must be numeric.")
    if (nrow(layout.3d) != n.vertices) {
        stop("nrow('layout.3d') must equal length('adj.list').")
    }
    if (ncol(layout.3d) != 3L) {
        stop("'layout.3d' must have exactly 3 columns.")
    }
    if (anyNA(layout.3d) || any(!is.finite(layout.3d))) {
        stop("'layout.3d' must contain only finite values.")
    }
    if (!is.numeric(q) || length(q) != 1L || !is.finite(q) || q < 0 || q > 1) {
        stop("'q' must be a finite scalar in [0, 1].")
    }
    if (!is.null(gaussian.sigma)) {
        if (!is.numeric(gaussian.sigma) || length(gaussian.sigma) != 1L ||
            !is.finite(gaussian.sigma) || gaussian.sigma <= 0) {
            stop("'gaussian.sigma' must be NULL or a finite scalar > 0.")
        }
    }
    if (!is.numeric(min.neighborhood.size) || length(min.neighborhood.size) != 1L ||
        !is.finite(min.neighborhood.size) || min.neighborhood.size < 2 ||
        min.neighborhood.size != floor(min.neighborhood.size)) {
        stop("'min.neighborhood.size' must be an integer >= 2.")
    }
    if (!is.logical(verbose) || length(verbose) != 1L) {
        stop("'verbose' must be a scalar logical.")
    }
}

.resolve.graph.endpoint.scales <- function(neighborhood, k, radius, n.vertices) {
    if (neighborhood == "geodesic_k") {
        if (is.null(k) || length(k) < 1L) {
            stop("'k' must contain at least one value when neighborhood = 'geodesic_k'.")
        }
        if (any(!is.finite(k)) || any(k < 1) || any(k != floor(k))) {
            stop("'k' must contain positive integers.")
        }
        k <- sort(unique(as.integer(k)))
        k <- pmin(k, max(n.vertices - 1L, 1L))
        names(k) <- paste0("k_", k)
        return(as.list(k))
    }

    if (is.null(radius) || length(radius) < 1L) {
        stop("'radius' must contain at least one value when neighborhood = 'geodesic_radius'.")
    }
    if (any(!is.finite(radius)) || any(radius <= 0)) {
        stop("'radius' must contain positive finite values.")
    }
    radius <- sort(unique(as.numeric(radius)))
    names(radius) <- paste0("r_", format(radius, trim = TRUE, scientific = FALSE))
    as.list(radius)
}

.build.graph.endpoint.igraph <- function(adj.list, weight.list) {
    graph.obj <- convert.adjacency.to.edge.matrix(adj.list, weight.list)
    edge.matrix <- graph.obj$edge.matrix
    weights <- graph.obj$weights

    n.vertices <- length(adj.list)
    if (nrow(edge.matrix) < 1L) {
        g <- igraph::make_empty_graph(n = n.vertices, directed = FALSE)
        return(g)
    }

    g <- igraph::graph_from_edgelist(edge.matrix, directed = FALSE)
    if (igraph::vcount(g) < n.vertices) {
        g <- igraph::add_vertices(g, n = n.vertices - igraph::vcount(g))
    }
    g <- igraph::set_edge_attr(g, "weight", value = weights)
    g
}

.select.graph.endpoint.neighborhood <- function(graph.dist, neighborhood, scale) {
    idx <- which(is.finite(graph.dist) & graph.dist > 0)
    if (length(idx) < 1L) {
        return(list(vertices = integer(0), distances = numeric(0)))
    }

    ord <- order(graph.dist[idx], idx)
    idx <- idx[ord]
    d <- graph.dist[idx]

    if (neighborhood == "geodesic_k") {
        keep <- seq_len(min(length(idx), as.integer(scale)))
        return(list(vertices = idx[keep], distances = d[keep]))
    }

    keep <- which(d <= as.double(scale))
    list(vertices = idx[keep], distances = d[keep])
}

.compute.graph.endpoint.metrics <- function(center,
                                            neighbors,
                                            geodesic.distances,
                                            q,
                                            neighbor.weighting,
                                            gaussian.sigma,
                                            min.neighborhood.size) {
    vectors <- sweep(neighbors, 2L, center, FUN = "-")
    lengths <- sqrt(rowSums(vectors^2))
    keep <- is.finite(lengths) & lengths > 0

    if (!any(keep)) {
        return(list(
            usable = FALSE,
            s.min = NA_real_,
            s.q = NA_real_,
            m = NA_real_,
            score = NA_real_,
            neighborhood.size = 0L,
            distance.scale = NA_real_
        ))
    }

    vectors <- vectors[keep, , drop = FALSE]
    geodesic.distances <- geodesic.distances[keep]
    lengths <- lengths[keep]

    if (nrow(vectors) < min.neighborhood.size) {
        return(list(
            usable = FALSE,
            s.min = NA_real_,
            s.q = NA_real_,
            m = NA_real_,
            score = NA_real_,
            neighborhood.size = nrow(vectors),
            distance.scale = NA_real_
        ))
    }

    unit.vectors <- vectors / lengths
    weights <- .graph.endpoint.neighbor.weights(
        geodesic.distances = geodesic.distances,
        weighting = neighbor.weighting,
        gaussian.sigma = gaussian.sigma
    )

    cross <- tcrossprod(unit.vectors)
    cross[] <- pmin(1, pmax(-1, cross))
    pair.idx <- upper.tri(cross)
    dots <- as.numeric(cross[pair.idx])
    pair.weights <- as.numeric((weights %o% weights)[pair.idx])

    s.min <- min(dots)
    s.q <- .weighted.quantile.endpoint(dots, pair.weights, q)

    mean.dir <- colSums(unit.vectors * weights) / sum(weights)
    m <- sqrt(sum(mean.dir^2))
    score <- m * (1 + s.q) / 2

    list(
        usable = TRUE,
        s.min = as.numeric(s.min),
        s.q = as.numeric(s.q),
        m = as.numeric(m),
        score = as.numeric(score),
        neighborhood.size = nrow(unit.vectors),
        distance.scale = stats::weighted.mean(geodesic.distances, w = weights)
    )
}

.graph.endpoint.neighbor.weights <- function(geodesic.distances,
                                             weighting,
                                             gaussian.sigma) {
    d <- as.numeric(geodesic.distances)
    if (length(d) < 1L) return(numeric(0))

    weights <- switch(
        weighting,
        uniform = rep(1, length(d)),
        inverse_distance = 1 / pmax(d, sqrt(.Machine$double.eps)),
        gaussian = {
            sigma <- gaussian.sigma
            if (is.null(sigma)) {
                pos <- d[d > 0]
                sigma <- if (length(pos) > 0L) stats::median(pos) else 1
            }
            exp(-0.5 * (d / sigma)^2)
        }
    )

    weights <- pmax(weights, 0)
    if (!any(weights > 0)) {
        weights <- rep(1, length(d))
    }
    weights / sum(weights)
}

.weighted.quantile.endpoint <- function(x, w, q) {
    x <- as.numeric(x)
    w <- as.numeric(w)

    keep <- is.finite(x) & is.finite(w) & w >= 0
    x <- x[keep]
    w <- w[keep]

    if (length(x) < 1L) return(NA_real_)
    if (length(x) == 1L) return(x[[1]])
    if (!any(w > 0)) w <- rep(1, length(x))

    ord <- order(x)
    x <- x[ord]
    w <- w[ord]

    cw <- cumsum(w) / sum(w)
    idx <- which(cw >= q)[1]
    if (is.na(idx)) idx <- length(x)
    x[[idx]]
}

.make.graph.endpoint.aggregate <- function(method) {
    switch(
        method,
        mean = function(x) {
            if (!any(is.finite(x))) return(NA_real_)
            mean(x, na.rm = TRUE)
        },
        median = function(x) {
            if (!any(is.finite(x))) return(NA_real_)
            stats::median(x, na.rm = TRUE)
        },
        min = function(x) {
            if (!any(is.finite(x))) return(NA_real_)
            min(x, na.rm = TRUE)
        },
        max = function(x) {
            if (!any(is.finite(x))) return(NA_real_)
            max(x, na.rm = TRUE)
        }
    )
}

.replace.nonfinite.endpoint.values <- function(y) {
    y <- as.numeric(y)
    if (all(is.finite(y))) return(y)

    finite.y <- y[is.finite(y)]
    if (length(finite.y) < 1L) {
        return(rep(-1, length(y)))
    }

    range.y <- range(finite.y)
    gap <- max(diff(range.y), 1)
    floor.value <- range.y[[1]] - gap - 1
    y[!is.finite(y)] <- floor.value
    y
}

.dgraphs.get.optional.function <- function(name) {
    if (!exists(name, mode = "function")) {
        stop(
            "The endpoint smoothing branch requires a compatible `", name,
            "()` function on the search path. Use smooth = FALSE or attach ",
            "the package that provides this legacy smoother.",
            call. = FALSE
        )
    }
    get(name, mode = "function")
}
