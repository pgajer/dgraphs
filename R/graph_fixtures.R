#' Create a Chain Graph with Offset Vertex Labels
#'
#' @param n The number of vertices in the graph.
#' @param offset An offset in indexing the vertices of the graph.
#'
#' @return A chain graph adjacency list.
#'
#' @export
create.chain.graph.with.offset <- function(n, offset = 0) {

    if (n < 2) {
        stop("A chain has to have at least two vertices.")
    }

    graph <- list()
    for (i in seq(n - 1)) {
        graph[[i + offset]] <- c(i + 1 + offset)
    }
    graph[[n + offset]] <- c()

    convert.to.undirected(graph)
}
