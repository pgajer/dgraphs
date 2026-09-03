#' Detect Local Extrema in a Graph
#'
#' @param adj.list Graph adjacency list using 1-based vertex indices.
#' @param weight.list Edge-length list aligned with `adj.list`.
#' @param y Numeric vertex function values.
#' @param max.radius Maximum graph-geodesic radius for neighborhoods.
#' @param min.neighborhood.size Minimum neighborhood size required.
#' @param detect.maxima Logical; if `TRUE`, detect maxima, otherwise minima.
#' @param custom.prefix Optional label prefix.
#'
#' @return A `local_extrema` object. Its scalar logical `detect.maxima` component
#'   records whether maxima or minima were requested, even when no extrema are
#'   found. The per-extremum `is_maxima` and `type` vectors are empty in that case.
#'
#' @details
#' Summaries use the recorded detection setting for empty results. Empty objects
#' saved by older versions lack this setting; their summaries report `NA` for
#' the extrema type because it cannot be recovered from empty vectors.
#'
#' @examples
#' chain <- create.chain.graph(n.vertices = 5)
#' extrema <- detect.local.extrema(
#'   chain$adj.list,
#'   chain$edge.lengths,
#'   y = c(1, 3, 1, 2, 0),
#'   max.radius = 1,
#'   min.neighborhood.size = 2
#' )
#' extrema$vertices
#'
#' @export
detect.local.extrema <- function(adj.list,
                                 weight.list,
                                 y,
                                 max.radius,
                                 min.neighborhood.size,
                                 detect.maxima = TRUE,
                                 custom.prefix = NULL) {
    adj.list <- .dgraphs.validate.adj.list(adj.list)
    weight.list <- .dgraphs.validate.weight.list(adj.list, weight.list)
    n <- length(adj.list)
    if (!is.numeric(y) || length(y) != n) {
        stop("'y' must be a numeric vector with length equal to the graph size.",
             call. = FALSE)
    }
    if (!is.numeric(max.radius) || length(max.radius) != 1L ||
        !is.finite(max.radius) || max.radius <= 0) {
        stop("'max.radius' must be a positive finite scalar.", call. = FALSE)
    }
    min.neighborhood.size <- as.integer(min.neighborhood.size)
    if (length(min.neighborhood.size) != 1L || is.na(min.neighborhood.size) ||
        min.neighborhood.size < 1L) {
        stop("'min.neighborhood.size' must be a positive integer.", call. = FALSE)
    }
    if (!is.logical(detect.maxima) || length(detect.maxima) != 1L ||
        is.na(detect.maxima)) {
        stop("'detect.maxima' must be a scalar logical.", call. = FALSE)
    }
    if (!is.null(custom.prefix) &&
        (!is.character(custom.prefix) || length(custom.prefix) != 1L)) {
        stop("'custom.prefix' must be NULL or a scalar character string.",
             call. = FALSE)
    }

    graph.obj <- .dgraphs.weighted.igraph(adj.list, weight.list)
    vertices <- integer(0)
    values <- numeric(0)
    radii <- numeric(0)
    neighborhood.sizes <- integer(0)
    neighborhood.vertices <- list()

    for (v in seq_len(n)) {
        d <- as.numeric(igraph::distances(
            graph.obj,
            v = v,
            to = seq_len(n),
            weights = igraph::E(graph.obj)$weight
        ))
        neighborhood <- which(is.finite(d) & d <= max.radius)
        if (length(neighborhood) < min.neighborhood.size) {
            next
        }
        yy <- y[neighborhood]
        is.extreme <- if (isTRUE(detect.maxima)) {
            y[[v]] >= max(yy, na.rm = TRUE)
        } else {
            y[[v]] <= min(yy, na.rm = TRUE)
        }
        if (isTRUE(is.extreme)) {
            vertices <- c(vertices, v)
            values <- c(values, y[[v]])
            radii <- c(radii, max(d[neighborhood], na.rm = TRUE))
            neighborhood.sizes <- c(neighborhood.sizes, length(neighborhood))
            neighborhood.vertices[[length(neighborhood.vertices) + 1L]] <- as.integer(neighborhood)
        }
    }

    labels <- character(length(vertices))
    if (length(vertices) > 0L) {
        prefix <- if (!is.null(custom.prefix)) custom.prefix else if (detect.maxima) "M" else "m"
        value.order <- if (detect.maxima) {
            order(values, decreasing = TRUE)
        } else {
            order(values, decreasing = FALSE)
        }
        labels[value.order] <- paste0(prefix, seq_along(value.order))
    }

    result <- list(
        vertices = as.integer(vertices),
        values = as.numeric(values),
        radii = as.numeric(radii),
        neighborhood_sizes = as.integer(neighborhood.sizes),
        is_maxima = rep(isTRUE(detect.maxima), length(vertices)),
        type = rep(if (detect.maxima) "Maximum" else "Minimum", length(vertices)),
        labels = labels,
        neighborhood_vertices = neighborhood.vertices,
        detect.maxima = detect.maxima
    )
    class(result) <- "local_extrema"
    result
}

.dgraphs.weighted.igraph <- function(adj.list, weight.list) {
    edge.obj <- convert.adjacency.to.edge.matrix(adj.list, weight.list)
    if (nrow(edge.obj$edge.matrix) == 0L) {
        return(igraph::make_empty_graph(n = length(adj.list), directed = FALSE))
    }
    g <- igraph::graph_from_edgelist(edge.obj$edge.matrix, directed = FALSE)
    if (igraph::vcount(g) < length(adj.list)) {
        g <- igraph::add_vertices(g, length(adj.list) - igraph::vcount(g))
    }
    igraph::E(g)$weight <- edge.obj$weights
    g
}

#' @export
summary.local_extrema <- function(object, ...) {
    if (!inherits(object, "local_extrema")) {
        stop("Object must be of class 'local_extrema'.", call. = FALSE)
    }
    n.extrema <- length(object$vertices)
    if (n.extrema == 0L) {
        extrema.type <- if (isTRUE(object$detect.maxima)) {
            "Maximum"
        } else if (isFALSE(object$detect.maxima)) {
            "Minimum"
        } else {
            NA_character_
        }
        result <- list(
            n_extrema = 0L,
            extrema_type = extrema.type,
            fn_values_summary = NA,
            neighborhood_sizes_summary = NA,
            radius_summary = NA,
            extrema_details = data.frame()
        )
        class(result) <- "summary.local_extrema"
        return(result)
    }
    details <- data.frame(
        label = object$labels,
        vertex_index = object$vertices,
        fn_value = object$values,
        radius = object$radii,
        neighborhood_size = object$neighborhood_sizes,
        stringsAsFactors = FALSE
    )
    if (all(object$is_maxima)) {
        details <- details[order(details$fn_value, decreasing = TRUE), ]
    } else {
        details <- details[order(details$fn_value), ]
    }
    result <- list(
        n_extrema = n.extrema,
        extrema_type = unique(object$type)[[1L]],
        fn_values_summary = summary(object$values),
        neighborhood_sizes_summary = summary(object$neighborhood_sizes),
        radius_summary = summary(object$radii),
        extrema_details = details
    )
    class(result) <- "summary.local_extrema"
    result
}

#' @export
print.summary.local_extrema <- function(x, ...) {
    cat("Local Extrema Detection Summary\n")
    cat("==============================\n\n")
    cat("Extrema type:", x$extrema_type, "\n")
    cat("Number of extrema found:", x$n_extrema, "\n")
    if (x$n_extrema > 0L) {
        cat("\nTop extrema by function value:\n")
        print(utils::head(x$extrema_details, 10L))
    }
    invisible(x)
}

#' Extract Vertices from a Graph Result
#'
#' @param object Object from which vertices should be extracted.
#' @param ... Additional arguments passed to methods.
#'
#' @return Object-specific vertex indices.
#'
#' @examples
#' chain <- create.chain.graph(n.vertices = 5)
#' extrema <- detect.local.extrema(
#'   chain$adj.list,
#'   chain$edge.lengths,
#'   y = c(1, 3, 1, 2, 0),
#'   max.radius = 1,
#'   min.neighborhood.size = 2
#' )
#' vertices(extrema, extrema$labels[[1]])
#'
#' @export
vertices <- function(object, ...) {
    UseMethod("vertices")
}

#' @export
vertices.local_extrema <- function(object, label, include.center = TRUE, ...) {
    if (!inherits(object, "local_extrema")) {
        stop("Object must be of class 'local_extrema'.", call. = FALSE)
    }
    if (missing(label) || !is.character(label) || length(label) != 1L) {
        stop("'label' must be a scalar character string.", call. = FALSE)
    }
    idx <- which(object$labels == label)
    if (length(idx) == 0L) {
        stop("Label '", label, "' not found.", call. = FALSE)
    }
    v <- object$neighborhood_vertices[[idx[[1L]]]]
    if (!isTRUE(include.center)) {
        v <- v[v != object$vertices[[idx[[1L]]]]]
    }
    v
}
