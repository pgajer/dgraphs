#' Plot a dgraph with Reusable Coordinates
#'
#' Draw each undirected edge once and color vertices by values or explicit
#' colors. Coordinates are computed by [graph.embedding()] only when absent.
#' Layout computation remains available separately in two or three dimensions.
#'
#' @param x A `dgraph`.
#' @param coordinates Optional finite numeric matrix with one row per vertex
#'   and two or three columns. Row order must match graph vertex order.
#' @param vertex.values Optional finite numeric value per vertex, mapped through
#'   `color.palette`. Constant values use the palette midpoint and one legend key.
#' @param vertex.colors Optional explicit color or vector of colors, one per
#'   vertex. Cannot accompany `vertex.values`. Defaults to `"steelblue"`.
#' @param vertex.size Nonnegative point size, one value or one per vertex.
#' @param edge.alpha Edge opacity between zero and one.
#' @param color.palette Color vector for numeric values; defaults to a
#'   blue-white-red palette. Requires `vertex.values` when explicitly supplied.
#' @param main Plot title.
#' @param add.legend Logical; show value/color keys for numeric `vertex.values`.
#'   Explicit colors have no automatically inferred numeric legend.
#' @param stage Stored graph stage, used for both layout and drawn edges.
#' @param method Layout method, `"fr"` or `"kk"`, when coordinates are absent.
#' @param edge.attribute,transform Explicit layout edge quantity and transform;
#'   see [graph.embedding()]. Layout arguments cannot accompany coordinates.
#' @param projection For three-column coordinates, two distinct column indices
#'   to display, for example `c(1, 3)`. Three-dimensional input requires explicit
#'   projection; it is never silently flattened. Not used for two-column input.
#' @param ... Named arguments to [graphics::plot.default()], such as `xlim`,
#'   `ylim`, `axes`, `xlab`, `ylab`, or `asp`. The arguments `x`, `y` and `type`
#'   are controlled by this method and cannot be overridden.
#' @return Invisibly returns the two-column coordinates actually drawn. These
#'   can be supplied to subsequent calls to reuse the layout. Graphics settings
#'   are restored after plotting.
#' @examples
#' graph <- create.graph("cycle", n = 6)
#' xy <- plot(graph, vertex.values = 1:6)
#' plot(graph, coordinates = xy, vertex.values = rep(1, 6))
#' xyz <- graph.embedding(graph, dim = 3)
#' plot(graph, coordinates = xyz, projection = c(1, 3), vertex.colors = "navy")
#' @export
plot.dgraph <- function(x, coordinates = NULL, vertex.values = NULL,
                        vertex.colors = NULL, vertex.size = 1, edge.alpha = 0.2,
                        color.palette = NULL, main = "", add.legend = TRUE,
                        stage = "final", method = c("fr", "kk"),
                        edge.attribute = NULL, transform = c("identity", "reciprocal"),
                        projection = NULL, ...) {
    edges <- graph.edges(x, stage)
    n <- graph.order(x)
    if (!is.logical(add.legend) || length(add.legend) != 1L || is.na(add.legend))
        stop("'add.legend' must be TRUE or FALSE.", call. = FALSE)
    if (!is.numeric(edge.alpha) || length(edge.alpha) != 1L ||
        !is.finite(edge.alpha) || edge.alpha < 0 || edge.alpha > 1)
        stop("'edge.alpha' must be between zero and one.", call. = FALSE)
    if (!is.numeric(vertex.size) || !length(vertex.size) ||
        !length(vertex.size) %in% c(1L, n) || any(!is.finite(vertex.size)) || any(vertex.size < 0))
        stop("'vertex.size' must contain one nonnegative size or one per vertex.", call. = FALSE)
    colors <- .graph.plot.colors(n, vertex.values, vertex.colors, color.palette)
    if (is.null(coordinates)) {
        if (!is.null(projection)) stop("'projection' requires supplied three-column coordinates.", call. = FALSE)
        coordinates <- graph.embedding(x, dim = 2, method = match.arg(method),
            edge.attribute = edge.attribute, transform = match.arg(transform), stage = stage)
    } else {
        if (!missing(method) || !missing(edge.attribute) || !missing(transform))
            stop("Layout arguments cannot accompany supplied coordinates.", call. = FALSE)
        if (!is.matrix(coordinates) || !is.numeric(coordinates) || nrow(coordinates) != n ||
            !ncol(coordinates) %in% c(2L, 3L) || any(!is.finite(coordinates)))
            stop("'coordinates' must be a finite numeric n-by-2 or n-by-3 matrix.", call. = FALSE)
        if (ncol(coordinates) == 3L) {
            if (!is.numeric(projection) || length(projection) != 2L ||
                any(!is.finite(projection)) || any(!projection %in% 1:3) || anyDuplicated(projection))
                stop("Three-dimensional coordinates require two distinct projection indices in 1:3.", call. = FALSE)
            coordinates <- coordinates[, projection, drop = FALSE]
        } else if (!is.null(projection)) stop("'projection' applies only to three-column coordinates.", call. = FALSE)
    }
    extra <- list(...)
    if (length(extra) && (is.null(names(extra)) || any(!nzchar(names(extra))) || anyDuplicated(names(extra))))
        stop("Additional plotting arguments must have unique names.", call. = FALSE)
    if (any(names(extra) %in% c("x", "y", "type")))
        stop("Plot coordinates and type are controlled by plot.dgraph.", call. = FALSE)
    show.legend <- add.legend && length(colors$legend.values) > 0L
    oldpar <- graphics::par(no.readonly = TRUE)
    on.exit(graphics::par(oldpar), add = TRUE)
    graphics::par(mar = c(5, 5, 3, if (show.legend) 7 else 1.5))
    axis.labels <- colnames(coordinates)
    if (is.null(axis.labels)) axis.labels <- c("Coordinate 1", "Coordinate 2")
    args <- list(x = coordinates[, 1L], y = coordinates[, 2L], type = "n",
                 xlab = axis.labels[1L], ylab = axis.labels[2L], main = main, asp = 1)
    if (!n) { args$xlim <- c(-1, 1); args$ylim <- c(-1, 1) }
    do.call(graphics::plot, utils::modifyList(args, extra))
    if (nrow(edges)) graphics::segments(
        coordinates[edges$from, 1L], coordinates[edges$from, 2L],
        coordinates[edges$to, 1L], coordinates[edges$to, 2L],
        col = grDevices::rgb(0, 0, 0, edge.alpha))
    graphics::points(coordinates[, 1L], coordinates[, 2L], pch = 21,
                     cex = vertex.size, bg = colors$points, col = "grey25", lwd = 0.6)
    if (show.legend) graphics::legend(
        x = graphics::par("usr")[2L] + 0.03 * diff(graphics::par("usr")[1:2]),
        y = graphics::par("usr")[4L], xjust = 0, yjust = 1,
        legend = format(signif(colors$legend.values, 3), trim = TRUE),
        fill = colors$legend.colors, border = "grey35", bty = "n", xpd = NA,
        title = "Value", cex = 0.85)
    invisible(coordinates)
}

.graph.plot.colors <- function(n, values, colors, palette) {
    if (!is.null(values) && !is.null(colors))
        stop("Supply only one of vertex.values and vertex.colors.", call. = FALSE)
    valid.colors <- function(x) {
        if (!(is.character(x) || is.numeric(x)) || !length(x) || anyNA(x)) return(FALSE)
        !inherits(try(grDevices::col2rgb(x), silent = TRUE), "try-error")
    }
    if (is.null(values)) {
        if (!is.null(palette)) stop("'color.palette' requires vertex.values.", call. = FALSE)
        if (is.null(colors)) colors <- "steelblue"
        if (!length(colors) %in% c(1L, n) || !valid.colors(colors))
            stop("'vertex.colors' must contain one valid color or one per vertex.", call. = FALSE)
        return(list(points = rep(colors, length.out = n)))
    }
    if (!is.numeric(values) || !is.null(dim(values)) || length(values) != n || any(!is.finite(values)))
        stop("'vertex.values' must contain one finite numeric value per vertex.", call. = FALSE)
    if (is.null(palette)) palette <- grDevices::colorRampPalette(c("blue", "white", "red"))(101)
    if (!valid.colors(palette)) stop("'color.palette' must contain valid colors.", call. = FALSE)
    if (!n) return(list(points = character()))
    span <- range(values)
    if (span[1L] == span[2L]) {
        middle <- palette[ceiling(length(palette) / 2)]
        return(list(points = rep(middle, n), legend.values = span[1L], legend.colors = middle))
    }
    scale <- max(abs(span))
    normalized <- values / scale
    limits <- span / scale
    fraction <- (normalized - limits[1L]) / (limits[2L] - limits[1L])
    indices <- 1L + round(pmin(1, pmax(0, fraction)) * (length(palette) - 1L))
    ticks <- seq(0, 1, length.out = 5L)
    list(points = palette[indices], legend.values = (1 - ticks) * span[1L] + ticks * span[2L],
         legend.colors = palette[1L + round(ticks * (length(palette) - 1L))])
}
