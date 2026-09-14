#' Compute Graph Geodesic Distances
#'
#' @param graph A `dgraph` with finite nonnegative lengths.
#' @param vertices Optional 1-based vertex subset.
#' @param stage Stored graph stage.
#' @param distance `"length"` sums stored lengths (and errors if absent).
#'   `"hop"` explicitly counts edges instead.
#' @return A numeric matrix of shortest-path distances; unreachable pairs
#'   have infinite distance. A zero-length edge remains traversable.
#' @examples
#' graph <- create.graph("chain", 5)
#' graph.geodesic.distances(graph, vertices = c(1, 5))
#' graph.geodesic.distances(create.graph("cycle", 5), distance = "hop")
#' @export
graph.geodesic.distances <- function(graph, vertices = NULL, stage = "final",
                                      distance = c("length", "hop")) {
    distance <- match.arg(distance)
    adj.list <- graph.adjacency(graph, stage)
    length.list <- graph.lengths(graph, stage)
    if (distance == "hop") length.list <- lapply(adj.list, function(x) rep(1, length(x)))
    if (is.null(length.list)) stop("Graph has no lengths; explicitly request distance = 'hop' for hop distances.", call. = FALSE)
    if (is.null(vertices)) vertices <- seq_along(adj.list)
    if (!length(adj.list) && !length(vertices)) return(matrix(numeric(), 0L, 0L))
    shortest.path(adj.list, length.list, vertices)
}
