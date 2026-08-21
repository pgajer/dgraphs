.normalize.graph.geodesic.stage <- function(stage) {
    match.arg(
        stage,
        c("final", "raw", "raw.repaired", "pruned", "pruned.repaired",
          "repaired.pruned")
    )
}

.graph.geodesic.fields <- function(graph, stage = "final") {
    if (inherits(graph, "IkNN") ||
        inherits(graph, "sknn_graph") ||
        inherits(graph, "mknn_graph") ||
        inherits(graph, "radius_graph") ||
        inherits(graph, "adaptive_radius_graph") ||
        inherits(graph, "cknn_graph") ||
        inherits(graph, "geodesic_iknn_graph")) {
        stage <- .normalize.graph.geodesic.stage(stage)
        fields <- switch(
            stage,
            final = c("adj_list", "weight_list"),
            raw = c("raw_adj_list", "raw_weight_list"),
            raw.repaired = c("raw_repaired_adj_list", "raw_repaired_weight_list"),
            pruned = c("pruned_adj_list", "pruned_weight_list"),
            pruned.repaired = c("pruned_repaired_adj_list", "pruned_repaired_weight_list"),
            repaired.pruned = c("repaired_pruned_adj_list", "repaired_pruned_weight_list")
        )
        return(list(adj = fields[[1L]], weight = fields[[2L]], stage = stage))
    }
    stop(
        "'graph' must inherit from one of: IkNN, sknn_graph, mknn_graph, ",
        "radius_graph, adaptive_radius_graph, cknn_graph, or ",
        "geodesic_iknn_graph.",
        call. = FALSE
    )
}

#' Compute Graph Geodesic Distances from a Graph Object
#'
#' @param graph A supported graph object.
#' @param vertices Optional 1-based vertex subset.
#' @param stage Graph lifecycle stage.
#'
#' @return A numeric matrix of shortest-path distances.
#'
#' @examples
#' X <- cbind(seq(0, 1, length.out = 6), 0)
#' graph <- create.mknn.graph(X, k = 2, connect.components = TRUE)
#' graph.geodesic.distances(graph, vertices = c(1, 6))
#'
#' @export
graph.geodesic.distances <- function(graph, vertices = NULL, stage = "final") {
    fields <- .graph.geodesic.fields(graph, stage = stage)
    adj.list <- graph[[fields$adj]]
    weight.list <- graph[[fields$weight]]
    adj.list <- .dgraphs.validate.adj.list(adj.list)
    weight.list <- .dgraphs.validate.weight.list(adj.list, weight.list)
    if (is.null(vertices)) {
        vertices <- seq_along(adj.list)
    }
    shortest.path(adj.list, weight.list, as.integer(vertices))
}
