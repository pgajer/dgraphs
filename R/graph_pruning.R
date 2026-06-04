#' Prune Long Edges in a Weighted Graph
#'
#' @param graph A graph adjacency list.
#' @param edge.lengths Edge-length list matching `graph`.
#' @param alt.path.len.ratio.thld Alternative-path threshold.
#' @param use.total.length.constraint If `TRUE`, compare total alternative path
#'   length with the original edge. Otherwise require every edge on the
#'   alternative path to be shorter than the original edge times the threshold.
#' @param verbose Logical progress flag.
#'
#' @return A list with pruned adjacency and edge-length lists.
#'
#' @export
wgraph.prune.long.edges <- function(graph,
                                    edge.lengths,
                                    alt.path.len.ratio.thld,
                                    use.total.length.constraint = TRUE,
                                    verbose = FALSE) {
    graph <- .dgraphs.validate.adj.list(graph)
    edge.lengths <- .dgraphs.validate.weight.list(graph, edge.lengths)
    if (!is.numeric(alt.path.len.ratio.thld) ||
        length(alt.path.len.ratio.thld) != 1L ||
        !is.finite(alt.path.len.ratio.thld) ||
        alt.path.len.ratio.thld < 0) {
        stop("'alt.path.len.ratio.thld' must be a non-negative scalar.",
             call. = FALSE)
    }
    graph.0based <- lapply(graph, function(x) as.integer(x - 1L))
    res <- .Call("S_wgraph_prune_long_edges",
                 graph.0based,
                 edge.lengths,
                 as.numeric(alt.path.len.ratio.thld),
                 as.logical(use.total.length.constraint),
                 as.logical(verbose),
                 PACKAGE = "dgraphs")
    res$adj_list <- lapply(res$adj_list, function(x) as.integer(x + 1L))
    res
}
