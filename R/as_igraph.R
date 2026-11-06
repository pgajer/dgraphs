#' Convert a dgraph to igraph
#'
#' @param graph A `dgraph` object, including isolates.
#' @param stage Stored graph stage.
#' @return An undirected `igraph`. Edge lengths are named `length`; other
#'   attributes retain their names. No implicit `weight` or unit lengths are
#'   added. For metric paths pass `weights = igraph::E(g)$length` explicitly;
#'   for hop distance pass `weights = NA`.
#' @examples
#' graph <- dgraph(list(2L, 1L, integer()), list(0, 0, numeric()))
#' ig <- as_igraph(graph)
#' igraph::vcount(ig)
#' igraph::E(ig)$length
#' @export
as_igraph <- function(graph, stage = "final") {
    edges <- graph.edges(graph, stage)
    out <- igraph::make_empty_graph(n = graph.order(graph), directed = FALSE)
    if (nrow(edges)) out <- igraph::add_edges(out, as.vector(t(as.matrix(edges[, c("from", "to")]))))
    for (name in setdiff(names(edges), c("from", "to")))
        out <- igraph::set_edge_attr(out, name, value = edges[[name]])
    labels <- names(graph.adjacency(graph, stage))
    if (is.null(labels)) labels <- as.character(seq_len(graph.order(graph)))
    igraph::set_vertex_attr(out, "name", value = labels)
}
