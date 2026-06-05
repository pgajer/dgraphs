## DG6a generic graph utilities migrated from gflow/R/graph_utils.R.

utils::globalVariables("all.edge.lengths")

#' Compare Two Adjacency Lists
#'
#' @param adj.list1 First adjacency list.
#' @param adj.list2 Second adjacency list.
#'
#' @return `TRUE` when each vertex has the same neighbor set in both lists,
#'   ignoring order; otherwise `FALSE`.
#'
#' @export
compare.adj.lists <- function(adj.list1, adj.list2) {
    if (length(adj.list1) != length(adj.list2)) {
        return(FALSE)
    }

    vertices.with.different.neighbors <- c()
    for (i in seq_along(adj.list1)) {
        if (!setequal(adj.list1[[i]], adj.list2[[i]])) {
            vertices.with.different.neighbors <- c(vertices.with.different.neighbors, i)
        }
    }

    if (length(vertices.with.different.neighbors) == 0) {
        return(TRUE)
    } else {
        cat("FALSE: Vertices with neighbor sets not the same: ")
        cat(vertices.with.different.neighbors)
        cat("\n")
        return(FALSE)
    }
}

#' Convert a Directed Adjacency List to an Undirected Adjacency List
#'
#' @param adj.list Directed adjacency list.
#'
#' @return An adjacency list with reciprocal edges added and duplicate
#'   neighbors removed.
#'
#' @export
convert.to.undirected <- function(adj.list) {
    undirected.adj.list <- list()

    if (is.null(names(adj.list))) {
        names(adj.list) <- as.character(seq_along(adj.list))
    }

    for (vertex in seq_along(adj.list)) {
        vertex.name <- names(adj.list)[vertex]
        for (neighbor in adj.list[[vertex]]) {
            if (!(vertex.name %in% names(undirected.adj.list))) {
                undirected.adj.list[[vertex.name]] <- c()
            }

            neighbor.name <- ifelse(neighbor %in% seq_along(adj.list),
                                    names(adj.list)[neighbor],
                                    as.character(neighbor))
            undirected.adj.list[[vertex.name]] <- c(undirected.adj.list[[vertex.name]],
                                                    neighbor)

            if (!(neighbor.name %in% names(undirected.adj.list))) {
                undirected.adj.list[[neighbor.name]] <- c()
            }
            undirected.adj.list[[neighbor.name]] <- c(undirected.adj.list[[neighbor.name]],
                                                      vertex)
        }
    }

    undirected.adj.list <- lapply(undirected.adj.list, unique)

    return(undirected.adj.list)
}

#' Remove Self-Loops from an Adjacency List
#'
#' @param adj.list Adjacency list.
#'
#' @return The adjacency list with entries equal to their vertex index removed.
#'
#' @export
rm.self.loops <- function(adj.list) {
    for (vertex in seq_along(adj.list)) {
        adj.list[[vertex]] <- adj.list[[vertex]][adj.list[[vertex]] != vertex]
    }

    return(adj.list)
}

#' Weighted Graph Distance Between Graphs with Identical Vertex Sets
#'
#' @param graph1.adj.list First graph adjacency list.
#' @param graph1.weights First graph edge weights.
#' @param graph2.adj.list Second graph adjacency list.
#' @param graph2.weights Second graph edge weights.
#' @param calculate.normalized.deviation Logical; if `TRUE`, normalize the L1
#'   distance-matrix deviation.
#'
#' @return Numeric distance-matrix deviation.
#'
#' @export
identical.vertex.set.weighted.graph.similarity <- function(graph1.adj.list,
                                                           graph1.weights,
                                                           graph2.adj.list,
                                                           graph2.weights,
                                                           calculate.normalized.deviation = FALSE) {

    graph1.obj <- convert.adjacency.to.edge.matrix(graph1.adj.list, graph1.weights)
    graph2.obj <- convert.adjacency.to.edge.matrix(graph2.adj.list, graph2.weights)

    graph1 <- igraph::graph_from_edgelist(graph1.obj$edge.matrix, directed = FALSE)
    graph2 <- igraph::graph_from_edgelist(graph2.obj$edge.matrix, directed = FALSE)

    igraph::E(graph1)$weight <- graph1.obj$weights
    igraph::E(graph2)$weight <- graph2.obj$weights

    D1 <- igraph::distances(graph1, weights = igraph::E(graph1)$weight)
    D2 <- igraph::distances(graph2, weights = igraph::E(graph2)$weight)

    deviation <- sum(abs(D1 - D2))

    if (calculate.normalized.deviation) {
        max.distance.graph1 <- max(D1[is.finite(D1)])
        max.distance.graph2 <- max(D2[is.finite(D2)])

        max.distance <- max(max.distance.graph1, max.distance.graph2)

        n <- igraph::vcount(graph1)
        max.deviation <- n * n * max.distance
        deviation <- deviation / max.deviation
    }

    return(deviation)
}

#' Compute Edge Difference Between Two Graphs
#'
#' @param graph1 First adjacency list.
#' @param graph2 Second adjacency list.
#'
#' @return A list containing neighbors present in `graph1` but not `graph2` for
#'   each vertex.
#'
#' @export
edge.diff <- function(graph1, graph2) {
    if (!is.list(graph1) || !is.list(graph2)) {
        stop("Both inputs must be lists representing graph adjacency lists.")
    }

    if (length(graph1) != length(graph2)) {
        stop("The two graphs must have the same number of vertices.")
    }

    result <- vector("list", length(graph1))

    for (i in seq_along(graph1)) {
        result[[i]] <- setdiff(graph1[[i]], graph2[[i]])
    }

    return(result)
}

#' Create a Subgraph from a Graph Object
#'
#' @param S.graph List containing `adj_list` and `dist_list`.
#' @param id.indices Optional vertex indices to keep.
#' @param ids Optional vertex IDs to keep.
#' @param S Data frame or matrix whose row names map `ids` to vertex indices.
#' @param use.sequential.indices Logical; if `TRUE`, renumber kept vertices
#'   from 1 to `length(id.indices)`.
#'
#' @return A list with subgraph `adj_list` and `dist_list`.
#'
#' @export
create.subgraph <- function(S.graph,
                            id.indices = NULL,
                            ids = NULL,
                            S = NULL,
                            use.sequential.indices = FALSE) {
    if (!is.list(S.graph) || !all(c("adj_list", "dist_list") %in% names(S.graph))) {
        stop("S.graph must be a list containing 'adj_list' and 'dist_list'")
    }
    if (is.null(id.indices) && is.null(ids)) {
        stop("Either id.indices or ids must be provided")
    }
    if (!is.null(ids) && is.null(S)) {
        stop("If ids are provided, S must also be provided")
    }
    if (!is.null(S) && !is.null(ids)) {
        if (!all(ids %in% rownames(S))) {
            stop("All ids must be present in rownames(S)")
        }
    }
    if (!is.null(id.indices) && !all(id.indices %in% seq_along(S.graph$adj_list))) {
        stop("All id.indices must be valid indices in S.graph")
    }
    if (!is.logical(use.sequential.indices)) {
        stop("use.sequential.indices must be a logical value (TRUE or FALSE)")
    }

    if (!is.null(ids) && !is.null(S)) {
        id.indices <- match(ids, rownames(S))
    }

    S.subgraph <- list(adj_list = list(), dist_list = list())

    if (use.sequential.indices) {
        index.map <- stats::setNames(seq_along(id.indices), id.indices)
    }

    for (i in seq_along(id.indices)) {
        orig.index <- id.indices[i]

        adj.nodes <- S.graph$adj_list[[orig.index]]
        dist.nodes <- S.graph$dist_list[[orig.index]]

        if (is.null(adj.nodes) || length(adj.nodes) == 0) {
            S.subgraph$adj_list[[i]] <- integer(0)
            S.subgraph$dist_list[[i]] <- numeric(0)
            next
        }

        in.subgraph <- adj.nodes %in% id.indices

        if (use.sequential.indices) {
            mapped.indices <- index.map[as.character(adj.nodes[in.subgraph])]
            S.subgraph$adj_list[[i]] <- as.integer(mapped.indices)
        } else {
            S.subgraph$adj_list[[i]] <- adj.nodes[in.subgraph]
        }
        S.subgraph$dist_list[[i]] <- dist.nodes[in.subgraph]
    }

    if (use.sequential.indices) {
        names(S.subgraph$adj_list) <- seq_along(id.indices)
        names(S.subgraph$dist_list) <- seq_along(id.indices)
    } else {
        names(S.subgraph$adj_list) <- id.indices
        names(S.subgraph$dist_list) <- id.indices
    }

    return(S.subgraph)
}

#' Count Edges in an Undirected Adjacency List
#'
#' @param adj.list Adjacency list for an undirected graph.
#'
#' @return Number of undirected edges.
#'
#' @export
count.edges <- function(adj.list) {
    n.edges <- 0
    for (i in seq_along(adj.list)) {
        nbrs <- adj.list[[i]]
        n.edges <- n.edges + length(nbrs)
    }

    return(n.edges / 2)
}

#' Get Unique Edge Weights from a Weighted Graph
#'
#' @param adj.list Adjacency list.
#' @param weight.list Edge-weight list aligned with `adj.list`.
#' @param n.cores Number of cores used by the optional `foreach` backend.
#'
#' @return Numeric vector of unique undirected edge weights.
#'
#' @export
get.edge.weights <- function(adj.list,
                             weight.list,
                             n.cores = 12) {

    if (!requireNamespace("foreach", quietly = TRUE) ||
        !requireNamespace("doParallel", quietly = TRUE)) {
        stop("Packages 'foreach' and 'doParallel' are required for this function")
    }

    doParallel::registerDoParallel(cores = n.cores)
    on.exit(doParallel::stopImplicitCluster(), add = TRUE)

    n.vertices <- length(adj.list)
    vertices.per.chunk <- ceiling(n.vertices / n.cores)
    vertex.chunks <- split(1:n.vertices,
                           ceiling(seq_along(1:n.vertices) / vertices.per.chunk))

    chunk <- NULL
    dopar <- foreach::`%dopar%`
    results <- dopar(
        foreach::foreach(chunk = vertex.chunks,
                         .combine = "c",
                         .packages = c()),
        {
            chunk.weights <- c()

            for (i in chunk) {
                nbrs <- adj.list[[i]]

                for (j in seq_along(nbrs)) {
                    neighbor <- nbrs[j]

                    if (i < neighbor) {
                        weight <- weight.list[[i]][j]
                        chunk.weights <- c(chunk.weights, weight)
                    }
                }
            }

            return(chunk.weights)
        }
    )

    return(results)
}

#' Extract Unique Edge Lengths from an Undirected Graph
#'
#' @param adj.list Adjacency list.
#' @param edge.length.list Edge-length list aligned with `adj.list`.
#' @param method Extraction method: `"vectorized"`, `"preallocate"`, or
#'   `"parallel"`.
#' @param mc.cores Number of cores for `method = "parallel"`.
#'
#' @return Numeric vector of unique undirected edge lengths.
#'
#' @export
extract.edge.lengths <- function(adj.list,
                                 edge.length.list,
                                 method = c("vectorized", "preallocate", "parallel"),
                                 mc.cores = 2) {

    method <- match.arg(method)

    if (!is.list(adj.list) || !is.list(edge.length.list)) {
        stop("Both adj.list and edge.length.list must be lists")
    }

    if (length(adj.list) != length(edge.length.list)) {
        stop("adj.list and edge.length.list must have the same length")
    }

    if (length(adj.list) == 0) {
        return(numeric(0))
    }

    edge.lengths <- switch(
        method,
        preallocate = {
            total.edges <- sum(lengths(adj.list)) / 2
            edge.lengths <- numeric(total.edges)
            idx <- 1

            for (i in seq_along(adj.list)) {
                neighbors <- adj.list[[i]]
                for (j.idx in seq_along(neighbors)) {
                    j <- neighbors[j.idx]
                    if (i < j) {
                        edge.lengths[idx] <- edge.length.list[[i]][j.idx]
                        idx <- idx + 1
                    }
                }
            }
            edge.lengths
        },

        vectorized = {
            unlist(lapply(seq_along(adj.list), function(i) {
                neighbors <- adj.list[[i]]
                valid.idx <- which(neighbors > i)
                if (length(valid.idx) == 0) {
                    return(numeric(0))
                }
                edge.length.list[[i]][valid.idx]
            }))
        },

        parallel = {
            if (!requireNamespace("parallel", quietly = TRUE)) {
                stop("Package 'parallel' is required for method = 'parallel'")
            }

            if (mc.cores < 1) {
                stop("mc.cores must be at least 1")
            }

            unlist(parallel::mclapply(seq_along(adj.list), function(i) {
                neighbors <- adj.list[[i]]
                valid.idx <- which(neighbors > i)
                if (length(valid.idx) == 0) {
                    return(numeric(0))
                }
                edge.length.list[[i]][valid.idx]
            }, mc.cores = mc.cores))
        }
    )

    return(edge.lengths)
}

#' Extract Edge Lengths Along a Graph Path
#'
#' @param traj Numeric or integer vector of consecutive graph vertices.
#' @param adj.list Adjacency list.
#' @param edge.length.list Edge-length list aligned with `adj.list`.
#' @param add.quantiles Logical; if `TRUE`, add edge-length empirical
#'   quantiles.
#'
#' @return Data frame with consecutive vertex pairs and their edge lengths.
#'
#' @export
extract.trajectory.edge.lengths <- function(traj,
                                            adj.list,
                                            edge.length.list,
                                            add.quantiles = FALSE) {

    if (!is.numeric(traj) && !is.integer(traj)) {
        stop("traj must be a numeric or integer vector")
    }

    if (length(traj) < 2) {
        stop("traj must contain at least 2 vertices to form an edge")
    }

    if (!is.list(adj.list) || !is.list(edge.length.list)) {
        stop("Both adj.list and edge.length.list must be lists")
    }

    if (length(adj.list) != length(edge.length.list)) {
        stop("adj.list and edge.length.list must have the same length")
    }

    n.edges <- length(traj) - 1
    first.vertex <- integer(n.edges)
    second.vertex <- integer(n.edges)
    edge.length <- numeric(n.edges)

    for (i in seq_len(n.edges)) {
        v1 <- traj[i]
        v2 <- traj[i + 1]

        if (v1 < 1 || v1 > length(adj.list)) {
            stop(sprintf("Vertex %d (position %d in trajectory) is out of bounds", v1, i))
        }
        if (v2 < 1 || v2 > length(adj.list)) {
            stop(sprintf("Vertex %d (position %d in trajectory) is out of bounds", v2, i + 1))
        }

        pos <- match(v2, adj.list[[v1]])

        if (!is.na(pos)) {
            edge.length[i] <- edge.length.list[[v1]][pos]
        } else {
            pos <- match(v1, adj.list[[v2]])

            if (!is.na(pos)) {
                edge.length[i] <- edge.length.list[[v2]][pos]
            } else {
                stop(sprintf("Edge (%d, %d) not found in graph at trajectory position %d",
                             v1, v2, i))
            }
        }

        first.vertex[i] <- v1
        second.vertex[i] <- v2
    }

    result <- data.frame(
        first.vertex = first.vertex,
        second.vertex = second.vertex,
        edge.length = edge.length,
        stringsAsFactors = FALSE
    )

    if (add.quantiles) {
        if (is.null(all.edge.lengths)) {
            all.edge.lengths <- extract.edge.lengths(adj.list, edge.length.list)
        }
        result$edge.quantile <- stats::ecdf(all.edge.lengths)(result$edge.length)
    }

    return(result)
}

#' Convert an Adjacency List to an Adjacency Matrix
#'
#' @param adj.list Adjacency list.
#' @param weight.list Optional edge-weight list aligned with `adj.list`.
#' @param mode Either `"undirected"` or `"directed"`.
#' @param remove.self.loops Logical; if `TRUE`, remove diagonal entries.
#'
#' @return Numeric adjacency matrix.
#'
#' @export
convert.adjacency.list.to.adjacency.matrix <- function(adj.list,
                                                       weight.list = NULL,
                                                       mode = "undirected",
                                                       remove.self.loops = TRUE) {

    if (!is.list(adj.list)) {
        stop("adj.list must be a list")
    }

    n <- length(adj.list)

    if (n == 0) {
        stop("adj.list cannot be empty")
    }

    if (!is.null(weight.list)) {
        if (!is.list(weight.list)) {
            stop("weight.list must be a list")
        }

        if (length(weight.list) != n) {
            stop("weight.list must have the same length as adj.list")
        }

        for (i in seq_len(n)) {
            if (length(adj.list[[i]]) != length(weight.list[[i]])) {
                stop(sprintf(
                    "Length mismatch at vertex %d: adj.list has %d neighbors but weight.list has %d weights",
                    i, length(adj.list[[i]]), length(weight.list[[i]])
                ))
            }
        }
    }

    mode <- match.arg(mode, choices = c("undirected", "directed"))

    adj.matrix <- matrix(0, nrow = n, ncol = n)

    if (mode == "undirected" && !is.null(weight.list)) {
        edge.count <- matrix(0, nrow = n, ncol = n)
    }

    for (i in seq_len(n)) {
        neighbors <- adj.list[[i]]

        if (length(neighbors) == 0) {
            next
        }

        if (any(neighbors < 1) || any(neighbors > n)) {
            invalid.idx <- neighbors[neighbors < 1 | neighbors > n]
            stop(sprintf(
                "Invalid vertex indices in adj.list[[%d]]: %s (valid range is 1 to %d)",
                i, paste(invalid.idx, collapse = ", "), n
            ))
        }

        if (remove.self.loops) {
            keep.idx <- neighbors != i
            neighbors <- neighbors[keep.idx]

            if (!is.null(weight.list)) {
                weight.list[[i]] <- weight.list[[i]][keep.idx]
            }
        }

        if (length(neighbors) == 0) {
            next
        }

        if (is.null(weight.list)) {
            adj.matrix[i, neighbors] <- 1

            if (mode == "undirected") {
                adj.matrix[neighbors, i] <- 1
            }
        } else {
            weights <- weight.list[[i]]

            if (mode == "directed") {
                adj.matrix[i, neighbors] <- weights
            } else {
                adj.matrix[i, neighbors] <- adj.matrix[i, neighbors] + weights
                edge.count[i, neighbors] <- edge.count[i, neighbors] + 1

                for (j in seq_along(neighbors)) {
                    neighbor <- neighbors[j]
                    weight <- weights[j]
                    adj.matrix[neighbor, i] <- adj.matrix[neighbor, i] + weight
                    edge.count[neighbor, i] <- edge.count[neighbor, i] + 1
                }
            }
        }
    }

    if (mode == "undirected" && !is.null(weight.list)) {
        edge.count[edge.count == 0] <- 1
        adj.matrix <- adj.matrix / edge.count
    }

    if (remove.self.loops) {
        diag(adj.matrix) <- 0
    }

    return(adj.matrix)
}

#' Geodesic Disk in a Weighted Graph
#'
#' @param adj.list Adjacency list.
#' @param weight.list Edge-length list aligned with `adj.list`.
#' @param center.vertex Center vertex.
#' @param radius Optional geodesic radius.
#' @param n Optional target number of reachable vertices.
#'
#' @return List with `vertices`, effective `radius`, and aligned `dists`.
#'
#' @export
geodesic.disk <- function(adj.list,
                          weight.list,
                          center.vertex,
                          radius = NULL,
                          n = NULL) {

    if (!is.list(adj.list) || !is.list(weight.list)) {
        stop("adj.list and weight.list must be lists.")
    }
    if (length(adj.list) != length(weight.list)) {
        stop("adj.list and weight.list must have the same length.")
    }

    n.vertices <- length(adj.list)

    if (!is.numeric(center.vertex) || length(center.vertex) != 1L || is.na(center.vertex)) {
        stop("center.vertex must be a single non-NA integer (1-based).")
    }
    center.vertex <- as.integer(center.vertex)
    if (center.vertex < 1L || center.vertex > n.vertices) {
        stop(sprintf("center.vertex must be in [1, %d].", n.vertices))
    }

    if (is.null(radius) && is.null(n)) {
        stop("Exactly one of radius or n must be provided (cannot both be NULL).")
    }
    if (!is.null(radius) && !is.null(n)) {
        stop("Exactly one of radius or n must be provided (cannot both be non-NULL).")
    }

    if (!is.null(radius)) {
        if (!is.numeric(radius) || length(radius) != 1L || is.na(radius)) {
            stop("radius must be a single non-NA numeric value.")
        }
        radius <- as.numeric(radius)
        if (radius < 0) stop("radius must be nonnegative.")
    }

    if (!is.null(n)) {
        if (!is.numeric(n) || length(n) != 1L || is.na(n)) {
            stop("n must be a single non-NA integer value.")
        }
        n <- as.integer(n)
        if (n < 1L) stop("n must be >= 1.")
    }

    for (v in seq_len(n.vertices)) {
        if (length(adj.list[[v]]) != length(weight.list[[v]])) {
            stop(sprintf("Mismatch at vertex %d: adj.list[[%d]] and weight.list[[%d]] differ in length.",
                         v, v, v))
        }
        if (length(adj.list[[v]]) > 0L) {
            nbrs <- as.integer(adj.list[[v]])
            if (any(nbrs < 1L | nbrs > n.vertices)) {
                stop(sprintf("adj.list[[%d]] contains out-of-range vertex indices.", v))
            }
        }
        if (length(weight.list[[v]]) > 0L) {
            ww <- as.numeric(weight.list[[v]])
            if (any(!is.finite(ww))) stop(sprintf("Non-finite edge weight at vertex %d.", v))
            if (any(ww < 0)) stop(sprintf("Negative edge weight at vertex %d (unsupported).", v))
        }
    }

    from <- integer(0L)
    to <- integer(0L)
    wts <- numeric(0L)

    for (v in seq_len(n.vertices)) {
        nbrs <- as.integer(adj.list[[v]])
        if (length(nbrs) == 0L) next
        ww <- as.numeric(weight.list[[v]])

        keep <- which(nbrs > v)
        if (length(keep) > 0L) {
            from <- c(from, rep.int(v, length(keep)))
            to <- c(to, nbrs[keep])
            wts <- c(wts, ww[keep])
        }
    }

    edge.df <- data.frame(from = from, to = to, weight = wts)

    g <- igraph::graph_from_data_frame(edge.df, directed = FALSE,
                                       vertices = seq_len(n.vertices))
    if (nrow(edge.df) > 0L) {
        igraph::E(g)$weight <- edge.df$weight
        d <- as.numeric(igraph::distances(g,
                                          v = center.vertex,
                                          to = igraph::V(g),
                                          weights = igraph::E(g)$weight)[1, ])
    } else {
        d <- rep.int(Inf, n.vertices)
        d[center.vertex] <- 0
    }

    d.ok <- is.finite(d)

    build.out <- function(idx, radius.used) {
        in.disk <- which(idx)
        dists <- as.numeric(d[idx])
        o <- order(dists)
        in.disk <- in.disk[o]
        dists <- dists[o]
        names(dists) <- as.character(in.disk)

        list(vertices = as.integer(in.disk),
             radius = as.numeric(radius.used),
             dists = dists)
    }

    if (!is.null(radius)) {
        radius.used <- radius
        idx <- d.ok & (d <= radius.used)
        return(build.out(idx, radius.used))
    }

    d.reach <- d[d.ok]
    if (length(d.reach) == 0L) {
        dists <- 0
        names(dists) <- as.character(center.vertex)
        return(list(vertices = as.integer(center.vertex),
                    radius = 0,
                    dists = dists))
    }

    d.sorted <- sort(d.reach)

    if (n > length(d.sorted)) {
        radius.used <- max(d.sorted)
        idx <- d.ok
        return(build.out(idx, radius.used))
    }

    radius.used <- d.sorted[n]
    idx <- d.ok & (d <= radius.used)
    build.out(idx, radius.used)
}
