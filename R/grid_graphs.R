.dgraphs.add.undirected.edge <- function(adj, weights, i, j, w) {
    adj[[i]] <- c(adj[[i]], as.integer(j))
    weights[[i]] <- c(weights[[i]], as.numeric(w))
    adj[[j]] <- c(adj[[j]], as.integer(i))
    weights[[j]] <- c(weights[[j]], as.numeric(w))
    list(adj = adj, weights = weights)
}

#' Create a Refined Graph with Approximately Uniform Edge Spacing
#'
#' @param adj.list Input graph adjacency list.
#' @param weight.list Edge-length list matching `adj.list`.
#' @param grid.size Target number of added grid vertices.
#' @param start.vertex Retained for compatibility.
#' @param snap.tolerance Retained for compatibility.
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

    edges <- data.frame(i = integer(0), j = integer(0), w = numeric(0))
    for (i in seq_along(adj.list)) {
        for (k in seq_along(adj.list[[i]])) {
            j <- adj.list[[i]][[k]]
            if (i < j) {
                edges <- rbind(edges, data.frame(i = i, j = j,
                                                 w = weight.list[[i]][[k]]))
            }
        }
    }
    if (nrow(edges) == 0L) {
        return(list(adj_list = adj.list, weight_list = weight.list,
                    grid_vertices = integer(0)))
    }

    total.length <- sum(edges$w)
    spacing <- total.length / (grid.size + 1L)
    added.per.edge <- pmax(0L, round(edges$w / spacing) - 1L)
    while (sum(added.per.edge) < grid.size) {
        idx <- which.max(edges$w / (added.per.edge + 1L))
        added.per.edge[[idx]] <- added.per.edge[[idx]] + 1L
    }
    while (sum(added.per.edge) > grid.size) {
        idx <- which.max(added.per.edge)
        added.per.edge[[idx]] <- added.per.edge[[idx]] - 1L
    }

    n0 <- length(adj.list)
    new.adj <- replicate(n0 + sum(added.per.edge), integer(0), simplify = FALSE)
    new.weights <- replicate(n0 + sum(added.per.edge), numeric(0), simplify = FALSE)
    grid.vertices <- integer(0)
    next.vertex <- n0 + 1L
    for (row in seq_len(nrow(edges))) {
        chain <- c(edges$i[[row]])
        n.add <- added.per.edge[[row]]
        if (n.add > 0L) {
            verts <- seq.int(next.vertex, length.out = n.add)
            grid.vertices <- c(grid.vertices, verts)
            next.vertex <- next.vertex + n.add
            chain <- c(chain, verts)
        }
        chain <- c(chain, edges$j[[row]])
        segment.length <- edges$w[[row]] / (length(chain) - 1L)
        for (k in seq_len(length(chain) - 1L)) {
            added <- .dgraphs.add.undirected.edge(
                new.adj, new.weights, chain[[k]], chain[[k + 1L]],
                segment.length
            )
            new.adj <- added$adj
            new.weights <- added$weights
        }
    }
    list(adj_list = new.adj, weight_list = new.weights,
         grid_vertices = as.integer(grid.vertices))
}
