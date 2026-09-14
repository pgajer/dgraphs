#' Create a Chain Graph with Offset Vertex Labels
#'
#' @param n The number of vertices in the graph.
#' @param offset An offset in indexing the vertices of the graph.
#'
#' @return A `dgraph` object. Use [graph.adjacency()], [graph.lengths()],
#'   [graph.edges()] and [graph.stages()] to inspect its stored graph stages.
#'   Construction and diagnostic information is stored in `metadata`.
#'
#' @examples
#' create.chain.graph.with.offset(4, offset = 0)
#'
#' @export
create.chain.graph.with.offset <- function(n, offset = 0) {
    if (length(n) != 1L || !is.finite(n) || n < 2 || n != floor(n))
        stop("A chain has to have at least two vertices.")
    if (length(offset) != 1L || !is.finite(offset) || offset < 0 || offset != floor(offset))
        stop("offset must be a nonnegative integer.")
    adj <- .dgraphs.chain.graph(n)
    names(adj) <- as.character(seq_len(n) + offset)
    out <- dgraph(adj)
    out$metadata$original.vertices <- seq_len(n) + offset
    out
}
