#' Prune Long Edges in a Weighted Graph
#'
#' @param adj.list A graph adjacency list.
#' @param length.list Edge-length list matching `adj.list`.
#' @param alt.path.len.ratio.thld Alternative-path threshold.
#' @param use.total.length.constraint If `TRUE`, compare total alternative path
#'   length with the original edge. Otherwise require every edge on the
#'   alternative path to be shorter than the original edge times the threshold.
#' @param verbose Logical progress flag.
#'
#' @return A `dgraph` object. Use [graph.adjacency()], [graph.lengths()],
#'   [graph.edges()] and [graph.stages()] to inspect its stored graph stages.
#'   Construction and diagnostic information is stored in `metadata`.
#'
#' @examples
#' graph <- list(c(2L, 3L), c(1L, 3L), c(1L, 2L))
#' lengths <- list(c(1, 2), c(1, 1), c(2, 1))
#' graph.adjacency(wgraph.prune.long.edges(graph, lengths, alt.path.len.ratio.thld = 1.1))
#'
#' @export
wgraph.prune.long.edges <- function(adj.list,
                                    length.list,
                                    alt.path.len.ratio.thld,
                                    use.total.length.constraint = TRUE,
                                    verbose = FALSE) {
    adj.list <- .dgraphs.validate.adj.list(adj.list)
    length.list <- .dgraphs.validate.length.list(adj.list, length.list)
    if (!is.numeric(alt.path.len.ratio.thld) ||
        length(alt.path.len.ratio.thld) != 1L ||
        !is.finite(alt.path.len.ratio.thld) ||
        alt.path.len.ratio.thld < 0) {
        stop("'alt.path.len.ratio.thld' must be a non-negative scalar.",
             call. = FALSE)
    }
    graph.0based <- lapply(adj.list, function(x) as.integer(x - 1L))
    res <- .Call("S_wgraph_prune_long_edges",
                 graph.0based,
                 length.list,
                 as.numeric(alt.path.len.ratio.thld),
                 as.logical(use.total.length.constraint),
                 as.logical(verbose),
                 PACKAGE = "dgraphs")
    out <- dgraph(res$adj_list, res$edge_lengths_list)
    out$metadata <- res[c("path_lengths", "edge_lengths")]
    out
}
