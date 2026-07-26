#' Create a Refined Graph with Approximately Uniform Edge Spacing
#'
#' @param adj.list Input graph adjacency list.
#' @param weight.list Edge-length list matching `adj.list`.
#' @param grid.size Target grid size parameter.
#' @param start.vertex Starting vertex used for breadth-first grid placement.
#' @param snap.tolerance Grid snapping tolerance.
#'
#' @return A list with `adj_list`, `weight_list`, and `grid_vertices`.
#'
#' @export
create.grid.graph <- function(adj.list,
                              weight.list,
                              grid.size,
                              start.vertex = 1L,
                              snap.tolerance = 0.1) {
    adj.list <- .dgraphs.validate.adj.list(adj.list)
    weight.list <- .dgraphs.validate.weight.list(adj.list, weight.list)
    grid.size <- as.integer(grid.size)
    if (length(grid.size) != 1L || is.na(grid.size) || grid.size < 2L) {
        stop("'grid.size' must be an integer >= 2.", call. = FALSE)
    }
    start.vertex <- as.integer(start.vertex)
    if (length(start.vertex) != 1L || is.na(start.vertex) ||
        start.vertex < 1L || start.vertex > length(adj.list)) {
        stop("'start.vertex' must be a valid vertex.", call. = FALSE)
    }
    if (!is.numeric(snap.tolerance) || length(snap.tolerance) != 1L ||
        !is.finite(snap.tolerance) || snap.tolerance < 0 ||
        snap.tolerance > 0.5) {
        stop("'snap.tolerance' must be between 0 and 0.5.", call. = FALSE)
    }
    adj.list.0based <- lapply(adj.list, function(x) as.integer(x - 1L))
    .Call("S_create_uniform_grid_graph",
          adj.list.0based,
          weight.list,
          as.integer(grid.size),
          as.integer(start.vertex - 1L),
          as.numeric(snap.tolerance),
          PACKAGE = "dgraphs")
}
