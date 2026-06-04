#' Computes Shortest Path Distances for Selected Vertices
#'
#' @param graph A graph adjacency list using 1-based vertex indices.
#' @param edge.lengths Edge-length list matching `graph`.
#' @param vertices Integer vector of vertices for which to compute distances.
#'
#' @return A numeric matrix of shortest-path distances.
#'
#' @export
shortest.path <- function(graph, edge.lengths, vertices) {
    graph <- .dgraphs.validate.adj.list(graph)
    edge.lengths <- .dgraphs.validate.weight.list(graph, edge.lengths)
    if (!is.numeric(vertices) || length(vertices) == 0L ||
        any(!is.finite(vertices)) || any(vertices != floor(vertices)) ||
        any(vertices < 1L) || any(vertices > length(graph))) {
        stop("'vertices' must contain valid 1-based vertex indices.",
             call. = FALSE)
    }
    graph.0based <- lapply(graph, function(x) as.integer(x - 1L))
    .Call("S_shortest_path",
          graph.0based,
          edge.lengths,
          as.integer(vertices - 1L),
          PACKAGE = "dgraphs")
}

#' Create a Path Graph with Limited Hop Distance
#'
#' @param graph A graph adjacency list using 1-based vertex indices.
#' @param edge.lengths Edge-length list matching `graph`.
#' @param h Integer maximum hop count.
#'
#' @return An object of class `"path.graph"`.
#'
#' @export
create.path.graph <- function(graph, edge.lengths, h) {
    graph <- .dgraphs.validate.adj.list(graph)
    edge.lengths <- .dgraphs.validate.weight.list(graph, edge.lengths)
    h <- as.integer(h)
    if (length(h) != 1L || is.na(h) || h < 1L) {
        stop("'h' must be a positive integer.", call. = FALSE)
    }
    graph.0based <- lapply(graph, function(x) as.integer(x - 1L))
    res <- .Call("S_create_path_graph_plus",
                 graph.0based,
                 edge.lengths,
                 h,
                 PACKAGE = "dgraphs")
    new.path.graph(
        adj.list = res$adj_list,
        edge.length.list = res$edge_length_list,
        hop.list = res$hop_list,
        shortest.paths = res$shortest_paths
    )
}

#' Construct a path.graph object
#'
#' @keywords internal
new.path.graph <- function(adj.list, edge.length.list, hop.list, shortest.paths) {
    structure(
        list(
            adj.list = adj.list,
            edge.length.list = edge.length.list,
            hop.list = hop.list,
            shortest.paths = shortest.paths
        ),
        class = "path.graph"
    )
}

#' Get Shortest Path Between Two Vertices
#'
#' @param pg A `"path.graph"` object.
#' @param from Source vertex.
#' @param to Target vertex.
#'
#' @return Path information, or `NULL` when no stored path exists.
#'
#' @export
get.shortest.path <- function(pg, from, to) {
    if (!inherits(pg, "path.graph")) {
        stop("'pg' must be a path.graph object.", call. = FALSE)
    }
    from <- as.integer(from)
    to <- as.integer(to)
    n.vertices <- length(pg$adj.list)
    if (length(from) != 1L || is.na(from) || from < 1L || from > n.vertices ||
        length(to) != 1L || is.na(to) || to < 1L || to > n.vertices) {
        stop("'from' and 'to' must be valid vertex indices.", call. = FALSE)
    }
    idx <- which(pg$shortest.paths$i == from & pg$shortest.paths$j == to)
    if (length(idx) == 0L) return(NULL)
    path <- pg$shortest.paths$paths[[idx[[1L]]]]
    edge.idx <- which(pg$adj.list[[from]] == to)
    path.length <- if (length(edge.idx)) {
        pg$edge.length.list[[from]][[edge.idx[[1L]]]]
    } else {
        NA_real_
    }
    list(path = path, length = path.length, hops = length(path) - 1L)
}

#' @export
print.path.graph <- function(x, ...) {
    cat("Path graph object\n")
    cat("  Number of vertices:", length(x$adj.list), "\n")
    cat("  Number of stored paths:", length(x$shortest.paths$paths), "\n")
    cat("  Number of edges in path graph:", sum(vapply(x$adj.list, length, integer(1))), "\n")
    invisible(x)
}

#' @export
summary.path.graph <- function(object, ...) {
    n.paths <- length(object$shortest.paths$paths)
    stats <- list(
        n.vertices = length(object$adj.list),
        n.paths = n.paths,
        avg.path.length = if (n.paths > 0L) {
            mean(vapply(object$shortest.paths$paths, length, integer(1)))
        } else {
            NA_real_
        },
        avg.degree = mean(vapply(object$adj.list, length, integer(1)))
    )
    print(stats)
    invisible(stats)
}

#' Create a Series of Path Graphs
#'
#' @param graph A graph adjacency list.
#' @param edge.lengths Edge-length list.
#' @param h.values Positive integer hop limits.
#'
#' @return A list of `"path.graph"` objects.
#'
#' @export
create.path.graph.series <- function(graph, edge.lengths, h.values) {
    graph <- .dgraphs.validate.adj.list(graph)
    edge.lengths <- .dgraphs.validate.weight.list(graph, edge.lengths)
    if (!is.numeric(h.values) || length(h.values) == 0L || any(h.values < 1)) {
        stop("'h.values' must contain positive hop limits.", call. = FALSE)
    }
    h.values <- sort(unique(as.integer(h.values)))
    graph.0based <- lapply(graph, function(x) as.integer(x - 1L))
    res <- .Call("S_create_path_graph_series",
                 graph.0based,
                 edge.lengths,
                 as.integer(h.values),
                 PACKAGE = "dgraphs")
    out <- mapply(function(pg, h) {
        pg.obj <- new.path.graph(
            adj.list = pg$adj_list,
            edge.length.list = pg$edge_length_list,
            hop.list = pg$hop_list,
            shortest.paths = pg$shortest_paths
        )
        attr(pg.obj, "h") <- h
        pg.obj
    }, res, h.values, SIMPLIFY = FALSE)
    names(out) <- paste0("h_", h.values)
    class(out) <- "path.graph.series"
    out
}
