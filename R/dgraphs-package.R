#' dgraphs: Data-Derived Graph Construction Utilities
#'
#' Construct and analyze graphs derived from numerical observations.
#'
#' @section Start here:
#' \itemize{
#'   \item \href{../doc/function-guide.html}{Finding your way around dgraphs}:
#'     a task-oriented catalog of public functions and object methods.
#'   \item \href{../doc/synthetic-geometry.html}{Synthetic geometry and point sampling}:
#'     reproducible curves, surfaces, embeddings and graph examples.
#'   \item \href{../doc/data-derived-graph-workflow.html}{Constructing and Diagnosing Data-Derived Graphs}:
#'     graph-family comparisons, connectivity repair and diagnostics.
#' }
#' These links open installed HTML guides. From the console, use
#' \code{vignette("function-guide", package = "dgraphs")} or
#' \code{vignette("synthetic-geometry", package = "dgraphs")}.
#'
#' @seealso [create.graph()], [create.sknn.graph()], [create.rknn.graph()],
#'   [graph.geodesic.distances()], [sample.synthetic.geometry()]
#' @keywords internal
#' @useDynLib dgraphs, .registration = TRUE
#' @importFrom Rcpp evalCpp
#' @importFrom graphics contour grid image legend lines par points rect segments text
#' @importFrom grDevices heat.colors rainbow
#' @importFrom stats median
"_PACKAGE"
