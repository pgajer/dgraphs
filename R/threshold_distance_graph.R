#' Create a Threshold Distance Graph
#'
#' @param dist.matrix Symmetric distance matrix.
#' @param threshold Numeric distance threshold. Vertices with distance less
#'   than this value are connected.
#' @param include.names Logical; if `TRUE`, preserve row names on adjacency and
#'   weight lists.
#'
#' @return A list with `adj_list` and `weight_list`.
#' @export
create.threshold.distance.graph <- function(dist.matrix, threshold, include.names = TRUE) {
    if (!isSymmetric(unname(dist.matrix))) {
        stop("The distance matrix must be symmetric")
    }

    n.vertices <- nrow(dist.matrix)
    vertex.names <- rownames(dist.matrix)
    if (is.null(vertex.names)) {
        vertex.names <- seq_len(n.vertices)
    }

    adj.list <- vector("list", n.vertices)
    weight.list <- vector("list", n.vertices)

    for (i in seq_len(n.vertices)) {
        neighbors <- which(dist.matrix[i, ] < threshold & (seq_len(n.vertices) != i))
        adj.list[[i]] <- neighbors
        weight.list[[i]] <- dist.matrix[i, neighbors]
    }

    if (include.names && !is.null(vertex.names)) {
        names(adj.list) <- vertex.names
        names(weight.list) <- vertex.names
    }

    list(adj_list = adj.list, weight_list = weight.list)
}
