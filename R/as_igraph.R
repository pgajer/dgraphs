#' Convert a dgraphs Graph to igraph
#'
#' @param gflow.graph A current `dgraphs` graph object or a legacy basin graph
#'   list. The argument name is retained for backward compatibility.
#' @param include.vertex.attrs Logical; include basin metadata as vertex
#'   attributes when available.
#' @param include.edge.attrs Logical; include edge weights and intersection
#'   sizes when available.
#' @param stage Lifecycle stage used for current `dgraphs` graph objects. See
#'   [graph.geodesic.distances()] for supported values.
#'
#' @return An `igraph` object.
#'
#' @examples
#' X <- matrix(c(0, 0, 1, 0, 2, 0), ncol = 2, byrow = TRUE)
#' graph <- create.mknn.graph(X, k = 2)
#' ig <- as_igraph(graph)
#' igraph::vcount(ig)
#' igraph::ecount(ig)
#'
#' @export
as_igraph <- function(gflow.graph,
                      include.vertex.attrs = TRUE,
                      include.edge.attrs = TRUE,
                      stage = "final") {
    current.classes <- c(
        "IkNN", "sknn_graph", "mknn_graph", "radius_graph",
        "adaptive_radius_graph", "cknn_graph", "geodesic_iknn_graph"
    )
    is.current <- any(vapply(
        current.classes,
        function(class.name) inherits(gflow.graph, class.name),
        logical(1)
    ))

    basin.metadata <- NULL
    intersection.matrix <- NULL
    if (is.current) {
        fields <- .graph.geodesic.fields(gflow.graph, stage = stage)
        adj.list <- gflow.graph[[fields$adj]]
        weight.list <- gflow.graph[[fields$weight]]
    } else {
        adj.list <- gflow.graph$adjacency.list
        weight.list <- gflow.graph$weight.list
        basin.metadata <- gflow.graph$basin.metadata
        intersection.matrix <- gflow.graph$intersection.matrix
    }

    if (is.null(adj.list)) {
        stop(
            "'gflow.graph' must be a supported dgraphs object or contain ",
            "an 'adjacency.list' field.",
            call. = FALSE
        )
    }
    adj.list <- .dgraphs.validate.adj.list(adj.list)
    n.total <- length(adj.list)
    if (!is.null(weight.list)) {
        weight.list <- .dgraphs.validate.weight.list(adj.list, weight.list)
    }

    edges <- .dgraphs.edge.matrix(adj.list, weight.list)
    if (nrow(edges$edge.matrix) == 0L) {
        graph <- igraph::make_empty_graph(n = n.total, directed = FALSE)
    } else {
        graph <- igraph::graph_from_edgelist(
            edges$edge.matrix,
            directed = FALSE
        )
        if (igraph::vcount(graph) < n.total) {
            graph <- igraph::add_vertices(
                graph,
                n.total - igraph::vcount(graph)
            )
        }
    }

    vertex.names <- names(adj.list)
    if (is.null(vertex.names) || any(!nzchar(vertex.names))) {
        vertex.names <- as.character(seq_len(n.total))
    }
    if (!is.null(basin.metadata$label) &&
        length(basin.metadata$label) == n.total) {
        vertex.names <- as.character(basin.metadata$label)
    }
    graph <- igraph::set_vertex_attr(
        graph,
        "name",
        value = vertex.names
    )

    if (include.vertex.attrs && !is.null(basin.metadata)) {
        metadata.fields <- c(
            "type", "size", "extremum.vertex", "extremum.value"
        )
        for (field in metadata.fields) {
            value <- basin.metadata[[field]]
            if (!is.null(value) && length(value) == n.total) {
                graph <- igraph::set_vertex_attr(
                    graph,
                    field,
                    value = value
                )
            }
        }
    }

    if (include.edge.attrs && nrow(edges$edge.matrix) > 0L) {
        if (!is.null(weight.list)) {
            graph <- igraph::set_edge_attr(
                graph,
                "weight",
                value = edges$weights
            )
        }
        if (!is.null(intersection.matrix)) {
            intersection.values <- intersection.matrix[edges$edge.matrix]
            graph <- igraph::set_edge_attr(
                graph,
                "intersection.size",
                value = as.numeric(intersection.values)
            )
        }
    }

    graph
}
