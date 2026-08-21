#' Convert a dgraphs Graph to igraph
#'
#' @param gflow.graph A current `dgraphs` graph object, a legacy basin graph
#'   list, or a bare 1-based adjacency list. The argument name is retained for
#'   backward compatibility.
#' @param include.vertex.attrs Logical; include basin metadata as vertex
#'   attributes when available.
#' @param include.edge.attrs Logical; include edge weights and intersection
#'   sizes when available.
#' @param stage Lifecycle stage used for current `dgraphs` graph objects. See
#'   [graph.geodesic.distances()] for supported values.
#' @param weight.list Optional list of edge weights aligned with a bare
#'   adjacency list supplied as `gflow.graph`. It must be `NULL` for graph
#'   objects that already contain weights.
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
#' adjacency <- list(c(2L, 3L), 1L, 1L, integer(0))
#' weights <- list(c(1, 2), 1, 2, numeric(0))
#' bare.ig <- as_igraph(adjacency, weight.list = weights)
#' c(vertices = igraph::vcount(bare.ig), edges = igraph::ecount(bare.ig))
#'
#' @export
as_igraph <- function(gflow.graph,
                      include.vertex.attrs = TRUE,
                      include.edge.attrs = TRUE,
                      stage = "final",
                      weight.list = NULL) {
    current.classes <- c(
        "IkNN", "sknn_graph", "mknn_graph", "radius_graph",
        "adaptive_radius_graph", "cknn_graph", "geodesic_iknn_graph"
    )
    is.current <- any(vapply(
        current.classes,
        function(class.name) inherits(gflow.graph, class.name),
        logical(1)
    ))

    supplied.weight.list <- weight.list
    basin.metadata <- NULL
    intersection.matrix <- NULL
    if (is.current) {
        if (!is.null(supplied.weight.list)) {
            stop(
                "'weight.list' can only accompany a bare adjacency list.",
                call. = FALSE
            )
        }
        fields <- .graph.geodesic.fields(gflow.graph, stage = stage)
        adj.list <- gflow.graph[[fields$adj]]
        weight.list <- gflow.graph[[fields$weight]]
    } else {
        bare.adj.list <- if (is.list(gflow.graph) &&
                             is.null(gflow.graph$adjacency.list)) {
            try(.dgraphs.validate.adj.list(gflow.graph), silent = TRUE)
        } else {
            structure("not a bare adjacency list", class = "try-error")
        }
        if (!inherits(bare.adj.list, "try-error")) {
            adj.list <- bare.adj.list
            weight.list <- supplied.weight.list
        } else {
            if (!is.list(gflow.graph)) {
                stop(
                    "'gflow.graph' must be a supported dgraphs object, a ",
                    "legacy basin graph, or a bare adjacency list.",
                    call. = FALSE
                )
            }
            if (!is.null(supplied.weight.list)) {
                stop(
                    "'weight.list' can only accompany a bare adjacency list.",
                    call. = FALSE
                )
            }
            adj.list <- gflow.graph$adjacency.list
            weight.list <- gflow.graph$weight.list
            basin.metadata <- gflow.graph$basin.metadata
            intersection.matrix <- gflow.graph$intersection.matrix
        }
    }

    if (is.null(adj.list)) {
        stop(
            "'gflow.graph' must be a supported dgraphs object, a legacy ",
            "basin graph, or a bare adjacency list.",
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
