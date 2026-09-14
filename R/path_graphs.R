.graph.distance.matrix <- function(adj.list, length.list, vertices) {
    adj.list <- .dgraphs.validate.adj.list(adj.list)
    length.list <- .dgraphs.validate.length.list(adj.list, length.list)
    if (!is.numeric(vertices) || length(vertices) == 0L ||
        any(!is.finite(vertices)) || any(vertices != floor(vertices)) ||
        any(vertices < 1L) || any(vertices > length(adj.list))) {
        stop("'vertices' must contain valid 1-based vertex indices.",
             call. = FALSE)
    }
    graph.0based <- lapply(adj.list, function(x) as.integer(x - 1L))
    .Call("S_shortest_path",
          graph.0based,
          length.list,
          as.integer(vertices - 1L),
          PACKAGE = "dgraphs")
}

#' Construct a path.graph object
#'
#' @return A list of class `"path.graph"` containing aligned adjacency,
#'   edge-length, and hop-count lists together with the stored shortest paths.
#'
#' @keywords internal
new.path.graph <- function(adj.list, length.list, hop.list, shortest.paths) {
    structure(list(graph = dgraph(adj.list, length.list,
                                  edge.attributes = list(hops = hop.list)),
                   shortest.paths = shortest.paths), class = "path.graph")
}

#' Get Shortest Path Between Two Vertices
#'
#' @param path.result A `"path.graph"` object.
#' @param from Source vertex.
#' @param to Target vertex.
#'
#' @return A list with `path` (vertex indices in requested direction), `length`
#'   and `hops`, or `NULL` when no stored route exists within this result's
#'   hop limit. A vertex queried against itself has path `from`, length zero
#'   and zero hops. Routes can be retrieved in either direction.
#'
#' @examples
#' graph <- list(2L, c(1L, 3L), 2L)
#' lengths <- list(1, c(1, 2), 2)
#' pg <- create.path.graph(dgraph(graph, lengths), h.values = 2)[[1L]]
#' get.shortest.path(pg, from = 1, to = 3)
#'
#' @export
get.shortest.path <- function(path.result, from, to) {
    if (!inherits(path.result, "path.graph")) {
        stop("'path.result' must be a path.graph object.", call. = FALSE)
    }
    n.vertices <- graph.order(path.result$graph)
    valid <- function(v) is.numeric(v) && length(v) == 1L && is.finite(v) &&
        v == floor(v) && v >= 1 && v <= n.vertices
    if (!valid(from) || !valid(to))
        stop("'from' and 'to' must be valid integer vertex indices.", call. = FALSE)
    from <- as.integer(from); to <- as.integer(to)
    if (from == to) return(list(path = from, length = 0, hops = 0L))
    idx <- which(path.result$shortest.paths$i == min(from, to) &
                 path.result$shortest.paths$j == max(from, to))
    if (length(idx) == 0L) return(NULL)
    path <- path.result$shortest.paths$paths[[idx[[1L]]]]
    if (from > to) path <- rev(path)
    edge.idx <- which(graph.adjacency(path.result$graph)[[from]] == to)
    path.length <- if (length(edge.idx)) {
        graph.lengths(path.result$graph)[[from]][[edge.idx[[1L]]]]
    } else {
        NA_real_
    }
    list(path = path, length = path.length, hops = length(path) - 1L)
}

#' Inspect a Path Graph
#'
#' @param x,object A single `path.graph` member from [create.path.graph()].
#' @param ... Unused.
#' @return `print()` invisibly returns its unchanged input after printing graph
#'   counts. `summary()` prints and invisibly returns a named list containing
#'   `n.vertices`, `n.paths`, `avg.path.length` (number of vertices per stored
#'   path, or `NA` if no paths), and `avg.degree` (mean adjacency-list length).
#' @examples
#' chain <- create.graph("chain", n = 5)
#' paths <- create.path.graph(chain, h.values = 2)[[1L]]
#' print(paths)
#' summary(paths)
#' @name inspect.path.graph
#' @export
print.path.graph <- function(x, ...) {
    cat("Path graph object\n")
    cat("  Number of vertices:", length(graph.adjacency(x$graph)), "\n")
    cat("  Number of stored paths:", length(x$shortest.paths$paths), "\n")
    cat("  Number of edges in path graph:", nrow(graph.edges(x$graph)), "\n")
    invisible(x)
}

#' @rdname inspect.path.graph
#' @export
summary.path.graph <- function(object, ...) {
    n.paths <- length(object$shortest.paths$paths)
    stats <- list(
        n.vertices = length(graph.adjacency(object$graph)),
        n.paths = n.paths,
        avg.path.length = if (n.paths > 0L) {
            mean(vapply(object$shortest.paths$paths, length, integer(1)))
        } else {
            NA_real_
        },
        avg.degree = mean(vapply(graph.adjacency(object$graph), length, integer(1)))
    )
    print(stats)
    invisible(stats)
}


#' Construct Path Graphs Across Hop Limits
#'
#' Find minimum-length routes using at most each requested number of edges.
#' Equal-length routes prefer fewer hops. One route is stored per unordered
#' pair and can be retrieved in either direction with [get.shortest.path()].
#'
#' @param graph A `dgraph` with finite nonnegative stored lengths.
#' @param h.values One or more strictly increasing positive integer hop limits.
#'   A hop counts one traversed edge. Invalid, duplicate or unordered values
#'   error; values are never silently rounded or reordered.
#' @param stage Stored graph stage; defaults to `"final"`.
#' @return A named `path.graph.series` collection, even for one limit. Names
#'   are `h_2`, `h_4`, etc. Each member is a `path.graph` with a `graph` of
#'   reachable pairs, stored `shortest.paths`, and an `h` attribute recording
#'   the requested limit. Its graph stores route lengths and a `hops` edge
#'   attribute. Routes use the input graph's vertex indices. Empty graphs and
#'   isolated vertices are preserved.
#' @details Hop-constrained search retains a separate distance for each hop
#'   count, then selects the best route for each pair. With nonnegative lengths,
#'   limits above `n - 1` need no additional search. For each source, auxiliary
#'   storage is proportional to `n * min(h, n - 1)`; storing routes for all
#'   reachable pairs can require cubic space. Use small hop limits when possible.
#' @examples
#' graph <- create.graph("chain", n = 5)
#' paths <- create.path.graph(graph, h.values = c(2, 4))
#' get.shortest.path(paths[["h_4"]], from = 1, to = 5)
#' get.shortest.path(paths[["h_4"]], from = 5, to = 1)
#' compare.paths(paths, from = 1, to = 5)
#' @export
create.path.graph <- function(graph, h.values, stage = "final") {
    adj.list <- graph.adjacency(graph, stage)
    length.list <- graph.lengths(graph, stage)
    if (is.null(length.list)) stop("Path construction requires stored lengths.", call. = FALSE)
    if (!is.numeric(h.values) || !is.null(dim(h.values)) || !length(h.values) ||
        any(!is.finite(h.values)) || any(h.values < 1) ||
        any(h.values != floor(h.values)) || any(h.values > .Machine$integer.max) ||
        any(diff(h.values) <= 0))
        stop("'h.values' must contain strictly increasing positive integers.", call. = FALSE)
    graph.0based <- lapply(adj.list, function(x) as.integer(x - 1L))
    res <- .Call("S_create_path_graph_series", graph.0based, length.list,
                 as.integer(h.values), PACKAGE = "dgraphs")
    out <- Map(function(pg, h) {
        result <- new.path.graph(pg$adj_list, pg$edge_length_list,
                                 pg$hop_list, pg$shortest_paths)
        attr(result, "h") <- as.integer(h)
        result$graph$metadata <- list(h = as.integer(h), source.stage = stage)
        if (!is.null(names(adj.list))) {
            names(result$graph$stages$final$adj.list) <- names(adj.list)
            names(result$graph$stages$final$length.list) <- names(adj.list)
        }
        result
    }, res, h.values)
    names(out) <- paste0("h_", h.values)
    class(out) <- "path.graph.series"
    out
}
