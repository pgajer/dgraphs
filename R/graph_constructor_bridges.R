.dgraphs_gflow_export <- function(name) {
    if (!requireNamespace("gflow", quietly = TRUE)) {
        stop("The bridge function '", name, "' requires the gflow package ",
             "until its implementation is migrated into dgraphs.",
             call. = FALSE)
    }
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
create.grid.graph <- function(...) .dgraphs_gflow_export("create.grid.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
create.path.graph <- function(...) .dgraphs_gflow_export("create.path.graph")(...)

#' @rdname graph-constructor-bridges
#' @export
graph.geodesic.distances <- function(...) .dgraphs_gflow_export("graph.geodesic.distances")(...)

#' @rdname graph-constructor-bridges
#' @export
as_igraph <- function(...) .dgraphs_gflow_export("as_igraph")(...)

#' @rdname graph-constructor-bridges
#' @export
remove.knn.outliers <- function(...) .dgraphs_gflow_export("remove.knn.outliers")(...)

#' @rdname graph-constructor-bridges
#' @export
wgraph.prune.long.edges <- function(...) .dgraphs_gflow_export("wgraph.prune.long.edges")(...)
