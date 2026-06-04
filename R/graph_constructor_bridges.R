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
#' These functions expose graph-construction APIs that have not yet been moved
#' into `dgraphs`. ANN-backed MkNN, radius, adaptive-radius, SkNN, and CMST
#' constructors are package-local; the remaining intersection/geodesic kNN and
#' conversion utilities delegate to `gflow` for now.
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
as_igraph <- function(...) .dgraphs_gflow_export("as_igraph")(...)

#' @rdname graph-constructor-bridges
#' @export
remove.knn.outliers <- function(...) .dgraphs_gflow_export("remove.knn.outliers")(...)
