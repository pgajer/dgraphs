
#' Select Graph Endpoints by Core-Eccentricity Geometry
#'
#' @param adj.list Graph adjacency list using 1-based vertex indices.
#' @param length.list Edge-length list aligned with `adj.list`.
#' @param core.quantile Numeric in `(0, 1)` defining the low-eccentricity core.
#' @param endpoint.quantile Numeric in `[0, 1]` for endpoint candidate scores.
#' @param use.approx.eccentricity Use landmark-based eccentricity approximation.
#' @param n.landmarks Number of landmarks when approximation is used.
#' @param max.endpoints Optional positive cap on returned endpoints.
#' @param seed Integer seed for landmark initialization.
#' @param verbose Print backend progress.
#'
#' @return A `geodesic_core_endpoints` list of endpoints and diagnostics.
#'
#' @examples
#' graph <- create.graph("chain", n = 8)
#' endpoints <- geodesic.core.endpoints(graph.adjacency(graph), graph.lengths(graph),
#'     use.approx.eccentricity = FALSE)
#' endpoints$endpoints
#'
#' @export
geodesic.core.endpoints <- function(adj.list,
                                    length.list,
                                    core.quantile = 0.10,
                                    endpoint.quantile = 0.90,
                                    use.approx.eccentricity = TRUE,
                                    n.landmarks = 64L,
                                    max.endpoints = NULL,
                                    seed = 1L,
                                    verbose = FALSE) {
    if (!is.list(adj.list)) stop("'adj.list' must be a list.")
    if (!is.list(length.list)) stop("'length.list' must be a list.")
    if (length(adj.list) != length(length.list)) {
        stop("'adj.list' and 'length.list' must have the same length.")
    }
    if (!is.numeric(core.quantile) || length(core.quantile) != 1L ||
        !is.finite(core.quantile) || core.quantile <= 0 || core.quantile >= 1) {
        stop("'core.quantile' must be a finite scalar in (0, 1).")
    }
    if (!is.numeric(endpoint.quantile) || length(endpoint.quantile) != 1L ||
        !is.finite(endpoint.quantile) ||
        endpoint.quantile < 0 || endpoint.quantile > 1) {
        stop("'endpoint.quantile' must be a finite scalar in [0, 1].")
    }
    if (!is.logical(use.approx.eccentricity) ||
        length(use.approx.eccentricity) != 1L) {
        stop("'use.approx.eccentricity' must be a scalar logical.")
    }
    if (!is.numeric(n.landmarks) || length(n.landmarks) != 1L ||
        !is.finite(n.landmarks) || n.landmarks < 1) {
        stop("'n.landmarks' must be a finite scalar >= 1.")
    }
    if (!is.null(max.endpoints)) {
        if (!is.numeric(max.endpoints) || length(max.endpoints) != 1L ||
            !is.finite(max.endpoints) || max.endpoints < 1) {
            stop("'max.endpoints' must be NULL or a finite scalar >= 1.")
        }
    }
    if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed)) {
        stop("'seed' must be a finite scalar.")
    }
    if (!is.logical(verbose) || length(verbose) != 1L) {
        stop("'verbose' must be a scalar logical.")
    }

    adj.list.0 <- lapply(adj.list, function(x) as.integer(x - 1L))
    max.endpoints.int <- if (is.null(max.endpoints)) 0L else as.integer(max.endpoints)

    res <- .Call(
        "S_geodesic_core_endpoints",
        adj.list.0,
        length.list,
        as.double(core.quantile),
        as.double(endpoint.quantile),
        as.logical(use.approx.eccentricity),
        as.integer(n.landmarks),
        as.integer(max.endpoints.int),
        as.integer(seed),
        as.logical(verbose),
        PACKAGE = "dgraphs"
    )

    if (!is.null(res$endpoints)) {
        res$endpoints <- as.integer(res$endpoints) + 1L
    }
    if (!is.null(res$core_vertices)) {
        res$core_vertices <- as.integer(res$core_vertices) + 1L
    }
    if (!is.null(res$landmarks)) {
        res$landmarks <- as.integer(res$landmarks) + 1L
    }
    if (!is.null(res$summary) &&
        is.data.frame(res$summary) &&
        "vertex" %in% names(res$summary)) {
        res$summary$vertex <- as.integer(res$summary$vertex) + 1L
    }

    names(res)[names(res) == "core_vertices"] <- "core.vertices"
    names(res)[names(res) == "distance_to_core"] <- "distance.to.core"
    names(res)[names(res) == "is_core"] <- "is.core"
    names(res)[names(res) == "is_endpoint"] <- "is.endpoint"
    names(res)[names(res) == "is_local_max"] <- "is.local.max"
    names(res)[names(res) == "endpoint_rank"] <- "endpoint.rank"
    names(res)[names(res) == "core_threshold"] <- "core.threshold"
    names(res)[names(res) == "endpoint_threshold"] <- "endpoint.threshold"
    names(res)[names(res) == "used_approx_eccentricity"] <-
        "used.approx.eccentricity"
    names(res)[names(res) == "n_landmarks_used"] <- "n.landmarks.used"

    class(res) <- c("geodesic_core_endpoints", class(res))
    res
}
