#' Convert a Basin Graph to igraph
#'
#' @param gflow.graph A basin graph list with adjacency, weight, intersection,
#'   and basin metadata fields. The argument name is retained for backward
#'   compatibility.
#' @param include.vertex.attrs Logical; include basin metadata as vertex
#'   attributes.
#' @param include.edge.attrs Logical; include edge weights and intersection
#'   sizes as edge attributes.
#'
#' @return An `igraph` object.
#' @export
as_igraph <- function(gflow.graph,
                      include.vertex.attrs = TRUE,
                      include.edge.attrs = TRUE) {
    n.total <- length(gflow.graph$adjacency.list)

    edge.list <- NULL
    edge.weights <- NULL
    edge.intersections <- NULL

    for (i in seq_len(n.total)) {
        if (length(gflow.graph$adjacency.list[[i]]) == 0) {
            next
        }

        for (k in seq_along(gflow.graph$adjacency.list[[i]])) {
            j <- gflow.graph$adjacency.list[[i]][k]
            if (i < j) {
                edge.list <- rbind(edge.list, c(i, j))
                if (include.edge.attrs) {
                    edge.weights <- c(edge.weights, gflow.graph$weight.list[[i]][k])
                    edge.intersections <- c(edge.intersections,
                                            gflow.graph$intersection.matrix[i, j])
                }
            }
        }
    }

    if (is.null(edge.list)) {
        g <- igraph::make_empty_graph(n = n.total, directed = FALSE)
    } else {
        g <- igraph::graph_from_edgelist(edge.list, directed = FALSE)
    }

    if (include.vertex.attrs) {
        igraph::V(g)$name <- gflow.graph$basin.metadata$label
        igraph::V(g)$type <- gflow.graph$basin.metadata$type
        igraph::V(g)$size <- gflow.graph$basin.metadata$size
        igraph::V(g)$extremum.vertex <- gflow.graph$basin.metadata$extremum.vertex
        igraph::V(g)$extremum.value <- gflow.graph$basin.metadata$extremum.value
    } else {
        igraph::V(g)$name <- gflow.graph$basin.metadata$label
    }

    if (include.edge.attrs && !is.null(edge.weights)) {
        igraph::E(g)$weight <- edge.weights
        igraph::E(g)$intersection.size <- edge.intersections
    }

    g
}
