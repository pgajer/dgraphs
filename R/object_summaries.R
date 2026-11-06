#' Inspect a Synthetic Geometry Sample
#' @param x,object A sample returned by [sample.synthetic.geometry()].
#' @param ... Reserved for generic method arguments.
#' @return `print()` returns its input invisibly. `summary()` returns a
#'   `summary.synthetic_geometry_sample` with dimensions, geometry/sampling
#'   families, coordinate ranges, observed region counts and RNG mode. State
#'   vectors remain available in the sample's `$rng` without being printed.
#' @examples
#' x <- sample.synthetic.geometry(synthetic.circle(),
#'   synthetic.sampling.uniform.interval(0, 2*pi), n = 5, seed = 17)
#' print(x)
#' summary(x)
#' @name inspect.synthetic_geometry_sample
#' @export
print.synthetic_geometry_sample <- function(x, ...) {
    cat("Synthetic geometry sample:", x$geometry.spec$family, "\n")
    cat("Points:", x$n, "| Intrinsic dimension:", if (is.na(x$intrinsic.dim)) "varies by region" else x$intrinsic.dim,
        "| Ambient dimension:", x$ambient.dim, "\n")
    cat("Sampler:", x$sampling.spec$family, "| Frame:", x$geometry.spec$parameters$frame, "\n")
    cat("RNG:", if (identical(x$rng$plan, "current")) "current stream" else "isolated seed/state plan", "\n")
    cat("Coordinates: $predictors (ambient), $latent (parameters). Details: summary(x), $rng.\n")
    invisible(x)
}
#' @rdname inspect.synthetic_geometry_sample
#' @export
summary.synthetic_geometry_sample <- function(object, ...) {
    X <- object$predictors
    ranges <- t(vapply(seq_len(ncol(X)), function(j) range(X[, j]), numeric(2)))
    colnames(ranges) <- c("minimum", "maximum")
    rownames(ranges) <- if (is.null(colnames(X))) paste0("coordinate", seq_len(ncol(X))) else colnames(X)
    structure(list(family = object$geometry.spec$family, sampling = object$sampling.spec$family,
        n = object$n, intrinsic.dim = object$intrinsic.dim, ambient.dim = object$ambient.dim,
        intrinsic.dim.by.region = object$intrinsic.dim.by.region,
        ranges = ranges, regions = table(object$region),
        rng.mode = if (identical(object$rng$plan, "current")) "current stream" else "isolated seed/state plan"),
        class = "summary.synthetic_geometry_sample")
}
#' @rdname inspect.synthetic_geometry_sample
#' @export
print.summary.synthetic_geometry_sample <- function(x, ...) {
    cat(x$family, "sample:", x$n, "points;", x$ambient.dim, "ambient dimensions\n")
    if (is.na(x$intrinsic.dim)) { cat("Intrinsic dimensions by region:\n"); print(x$intrinsic.dim.by.region) }
    else cat("Intrinsic dimension:", x$intrinsic.dim, "\n")
    cat("Sampler:", x$sampling, "| RNG:", x$rng.mode, "\n")
    print(utils::head(x$ranges, 10))
    if (nrow(x$ranges) > 10) cat("More coordinate ranges in summary(x)$ranges.\n")
    if (length(x$regions)) { cat("Observed region counts:\n"); print(x$regions) }
    invisible(x)
}

#' Inspect a Collection of Hop-Constrained Path Graphs
#' @param x,object A collection returned by [create.path.graph()].
#' @param ... Reserved for generic method arguments.
#' @return `summary()` returns a data frame of hop limits, vertex counts,
#'   edge counts and stored route counts. `print()` displays up to ten rows
#'   and returns the original collection invisibly. No paths are recomputed.
#' @examples
#' paths <- create.path.graph(create.graph("chain", 6), h.values = c(1, 2, 4))
#' print(paths)
#' summary(paths)
#' @name inspect.path.graph.series
#' @export
summary.path.graph.series <- function(object, ...) {
    data.frame(h = vapply(object, function(x) attr(x, "h"), integer(1)),
        vertices = vapply(object, function(x) graph.order(x$graph), numeric(1)),
        edges = vapply(object, function(x) sum(lengths(graph.adjacency(x$graph))) / 2, numeric(1)),
        routes = vapply(object, function(x) length(x$shortest.paths$paths), integer(1)),
        row.names = NULL)
}
#' @rdname inspect.path.graph.series
#' @export
print.path.graph.series <- function(x, ...) {
    cat("Path graph collection:", length(x), "hop limits\n")
    print(utils::head(summary(x), 10), row.names = FALSE)
    if (length(x) > 10) cat("...", length(x) - 10, "more rows; use summary(x) for the full table.\n")
    invisible(x)
}
