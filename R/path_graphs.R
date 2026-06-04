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
    vertices <- as.integer(vertices)
    out <- matrix(Inf, nrow = length(vertices), ncol = length(vertices))
    for (a in seq_along(vertices)) {
        d <- .dgraphs.dijkstra(graph, edge.lengths, vertices[[a]])
        out[a, ] <- d[vertices]
    }
    out
}

.dgraphs.dijkstra <- function(graph, edge.lengths, start, banned.edge = NULL) {
    n <- length(graph)
    dist <- rep(Inf, n)
    visited <- rep(FALSE, n)
    dist[[start]] <- 0
    repeat {
        available <- which(!visited)
        if (length(available) == 0L) break
        v <- available[which.min(dist[available])]
        if (!is.finite(dist[[v]])) break
        visited[[v]] <- TRUE
        for (k in seq_along(graph[[v]])) {
            u <- graph[[v]][[k]]
            if (!is.null(banned.edge) &&
                ((v == banned.edge[[1L]] && u == banned.edge[[2L]]) ||
                 (v == banned.edge[[2L]] && u == banned.edge[[1L]]))) {
                next
            }
            if (!visited[[u]]) {
                dist[[u]] <- min(dist[[u]], dist[[v]] + edge.lengths[[v]][[k]])
            }
        }
    }
    dist
}

.dgraphs.shortest.path.with.hops <- function(graph, edge.lengths, start, h) {
    n <- length(graph)
    dist <- rep(Inf, n)
    hops <- rep(.Machine$integer.max, n)
    parent <- rep(NA_integer_, n)
    dist[[start]] <- 0
    hops[[start]] <- 0L
    queue <- start
    while (length(queue) > 0L) {
        v <- queue[[1L]]
        queue <- queue[-1L]
        if (hops[[v]] >= h) next
        for (k in seq_along(graph[[v]])) {
            u <- graph[[v]][[k]]
            proposed.dist <- dist[[v]] + edge.lengths[[v]][[k]]
            proposed.hops <- hops[[v]] + 1L
            if (proposed.hops <= h &&
                (proposed.dist < dist[[u]] ||
                 (isTRUE(all.equal(proposed.dist, dist[[u]])) &&
                  proposed.hops < hops[[u]]))) {
                dist[[u]] <- proposed.dist
                hops[[u]] <- proposed.hops
                parent[[u]] <- v
                queue <- unique(c(queue, u))
            }
        }
    }
    list(dist = dist, hops = hops, parent = parent)
}

.dgraphs.reconstruct.path <- function(parent, start, target) {
    path <- target
    current <- target
    while (!is.na(parent[[current]]) && current != start) {
        current <- parent[[current]]
        path <- c(current, path)
    }
    if (path[[1L]] != start) return(integer(0))
    as.integer(path)
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
    n <- length(graph)
    adj.list <- vector("list", n)
    edge.length.list <- vector("list", n)
    hop.list <- vector("list", n)
    sp.i <- integer(0)
    sp.j <- integer(0)
    sp.paths <- list()

    for (start in seq_len(n)) {
        res <- .dgraphs.shortest.path.with.hops(graph, edge.lengths, start, h)
        reachable <- which(seq_len(n) != start & res$hops <= h)
        adj.list[[start]] <- as.integer(reachable)
        edge.length.list[[start]] <- as.numeric(res$dist[reachable])
        hop.list[[start]] <- as.integer(res$hops[reachable])
        for (target in reachable[reachable > start]) {
            sp.i <- c(sp.i, start)
            sp.j <- c(sp.j, target)
            sp.paths[[length(sp.paths) + 1L]] <-
                .dgraphs.reconstruct.path(res$parent, start, target)
        }
    }

    new.path.graph(
        adj.list = adj.list,
        edge.length.list = edge.length.list,
        hop.list = hop.list,
        shortest.paths = list(i = sp.i, j = sp.j, paths = sp.paths)
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
    path.length <- if (length(edge.idx)) pg$edge.length.list[[from]][[edge.idx[[1L]]]] else NA_real_
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
    if (!is.numeric(h.values) || length(h.values) == 0L || any(h.values < 1)) {
        stop("'h.values' must contain positive hop limits.", call. = FALSE)
    }
    h.values <- sort(unique(as.integer(h.values)))
    out <- lapply(h.values, function(h) {
        pg <- create.path.graph(graph, edge.lengths, h)
        attr(pg, "h") <- h
        pg
    })
    names(out) <- paste0("h_", h.values)
    class(out) <- "path.graph.series"
    out
}
