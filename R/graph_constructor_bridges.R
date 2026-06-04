.dgraphs_gflow_export <- function(name) {
    getExportedValue("gflow", name)
}

#' Bridge exports for data-derived graph construction
#'
#' These functions are the first `dgraphs` landing surface for graph
#' construction APIs that currently live in `gflow`. They delegate to `gflow`
#' for now. The package vendors ANN under `inst/include/ANN` so native
#' kNN/radius graph code can be migrated here in smaller audited slices.
#'
#' @param ... Arguments forwarded unchanged to the corresponding `gflow`
#'   function.
#'
#' @return The object returned by the delegated `gflow` implementation.
#'
#' @name graph-constructor-bridges
NULL

#' @rdname graph-constructor-bridges
#' @export
create.mknn.graph <- function(...) .dgraphs_gflow_export("create.mknn.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.mknn.graphs <- function(...) .dgraphs_gflow_export("create.mknn.graphs")(...)

#' @rdname graph-constructor-bridges
#' @export
create.rknn.graph <- function(...) .dgraphs_gflow_export("create.rknn.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.sknn.graph <- function(...) .dgraphs_gflow_export("create.sknn.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.cknn.graph <- function(...) .dgraphs_gflow_export("create.cknn.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.radius.graph <- function(...) .dgraphs_gflow_export("create.radius.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.adaptive.radius.graph <- function(...) .dgraphs_gflow_export("create.adaptive.radius.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.cmst.graph <- function(...) .dgraphs_gflow_export("create.cmst.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.iknn.graphs <- function(...) .dgraphs_gflow_export("create.iknn.graphs")(...)

#' @rdname graph-constructor-bridges
#' @export
create.single.iknn.graph <- function(...) .dgraphs_gflow_export("create.single.iknn.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.iterated.iknn.graphs <- function(...) .dgraphs_gflow_export("create.iterated.iknn.graphs")(...)

#' @rdname graph-constructor-bridges
#' @export
create.geodesic.iknn.graph <- function(...) .dgraphs_gflow_export("create.geodesic.iknn.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.threshold.distance.graph <- function(...) .dgraphs_gflow_export("create.threshold.distance.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.random.graph <- function(...) .dgraphs_gflow_export("create.random.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.complete.graph <- function(...) .dgraphs_gflow_export("create.complete.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.empty.graph <- function(...) .dgraphs_gflow_export("create.empty.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.star.graph <- function(...) .dgraphs_gflow_export("create.star.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.grid.graph <- function(...) .dgraphs_gflow_export("create.grid.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.path.graph <- function(...) .dgraphs_gflow_export("create.path.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
join.graphs <- function(...) .dgraphs_gflow_export("join.graphs")(...)

#' @rdname graph-constructor-bridges
#' @export
graph.connected.components <- function(...) .dgraphs_gflow_export("graph.connected.components")(...)

#' @rdname graph-constructor-bridges
#' @export
graph.adj.mat <- function(...) .dgraphs_gflow_export("graph.adj.mat")(...)

#' @rdname graph-constructor-bridges
#' @export
graph.geodesic.distances <- function(...) .dgraphs_gflow_export("graph.geodesic.distances")(...)

#' @rdname graph-constructor-bridges
#' @export
compute.graph.distance <- function(...) .dgraphs_gflow_export("compute.graph.distance")(...)

#' @rdname graph-constructor-bridges
#' @export
compute.graph.diameter <- function(...) .dgraphs_gflow_export("compute.graph.diameter")(...)

#' @rdname graph-constructor-bridges
#' @export
adjlist.to.igraph <- function(...) .dgraphs_gflow_export("adjlist.to.igraph")(...)

#' @rdname graph-constructor-bridges
#' @export
as_igraph <- function(...) .dgraphs_gflow_export("as_igraph")(...)

#' @rdname graph-constructor-bridges
#' @export
remove.knn.outliers <- function(...) .dgraphs_gflow_export("remove.knn.outliers")(...)

#' @rdname graph-constructor-bridges
#' @export
wgraph.prune.long.edges <- function(...) .dgraphs_gflow_export("wgraph.prune.long.edges")(...)
