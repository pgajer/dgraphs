.dg6a.ensure.gflow.parity.source <- function() {
    gflow.path <- Sys.getenv(
        "DGRAPHS_GFLOW_PARITY_SOURCE",
        file.path("..", "gflow")
    )
    if (file.exists(file.path(gflow.path, "DESCRIPTION")) &&
        requireNamespace("pkgload", quietly = TRUE)) {
        pkgload::load_all(gflow.path, quiet = TRUE)
    } else {
        skip_if_not_installed("gflow")
    }
}

.dg6a.strip <- function(x) {
    if (inherits(x, "igraph")) {
        return(list(
            n_vertices = igraph::vcount(x),
            n_edges = igraph::ecount(x),
            vertex_names = igraph::vertex_attr(x, "name"),
            edge_weights = igraph::edge_attr(x, "weight")
        ))
    }
    if (is.list(x)) {
        x$call <- NULL
        x$timing <- NULL
        x$finalization_timing <- NULL
        x <- lapply(x, .dg6a.strip)
    }
    attributes(x)$call <- NULL
    attributes(x)$graph <- NULL
    x
}

.dg6a.expect.gflow.parity <- function(.name, ..., seed = NULL, tolerance = 1e-12) {
    .dg6a.ensure.gflow.parity.source()
    dgraphs.fun <- getExportedValue("dgraphs", .name)
    gflow.fun <- getExportedValue("gflow", .name)
    if (!is.null(seed)) {
        set.seed(seed)
    }
    dgraphs.res <- suppressWarnings(dgraphs.fun(...))
    if (!is.null(seed)) {
        set.seed(seed)
    }
    gflow.res <- suppressWarnings(gflow.fun(...))
    expect_equal(
        .dg6a.strip(dgraphs.res),
        .dg6a.strip(gflow.res),
        tolerance = tolerance,
        ignore_attr = TRUE
    )
}

test_that("DG6a adjacency-list utilities match original gflow outputs", {
    adj <- list(c(2L, 3L), c(1L, 3L, 4L), c(1L, 2L), c(2L))
    adj.same <- list(c(3L, 2L), c(4L, 3L, 1L), c(2L, 1L), c(2L))
    directed <- list(c(2L, 3L), c(3L), c(4L), integer(0))
    loops <- list(c(1L, 2L), c(1L, 2L, 3L), c(2L, 3L))

    .dg6a.expect.gflow.parity("compare.adj.lists", adj.list1 = adj,
                              adj.list2 = adj.same)
    .dg6a.expect.gflow.parity("convert.to.undirected", adj.list = directed)
    .dg6a.expect.gflow.parity("rm.self.loops", adj.list = loops)
    .dg6a.expect.gflow.parity("count.edges", adj.list = adj)
    .dg6a.expect.gflow.parity(
        "edge.diff",
        graph1 = adj,
        graph2 = list(c(2L), c(1L, 4L), integer(0), c(2L))
    )
})

test_that("DG6a weighted graph utilities match original gflow outputs", {
    adj <- list(c(2L, 3L), c(1L, 3L, 4L), c(1L, 2L, 4L), c(2L, 3L))
    weights <- list(c(1.0, 2.0), c(1.0, 1.2, 2.2), c(2.0, 1.2, 0.7),
                    c(2.2, 0.7))
    alt.weights <- list(c(1.0, 2.5), c(1.0, 1.4, 2.2), c(2.5, 1.4, 0.9),
                        c(2.2, 0.9))

    .dg6a.expect.gflow.parity(
        "convert.adjacency.list.to.adjacency.matrix",
        adj.list = adj,
        weight.list = weights,
        mode = "undirected"
    )
    .dg6a.expect.gflow.parity(
        "convert.adjacency.list.to.adjacency.matrix",
        adj.list = adj,
        weight.list = weights,
        mode = "directed",
        remove.self.loops = FALSE
    )
    .dg6a.expect.gflow.parity(
        "extract.edge.lengths",
        adj.list = adj,
        edge.length.list = weights,
        method = "vectorized"
    )
    .dg6a.expect.gflow.parity(
        "extract.trajectory.edge.lengths",
        traj = c(1L, 2L, 4L, 3L),
        adj.list = adj,
        edge.length.list = weights
    )
    .dg6a.expect.gflow.parity(
        "get.edge.weights",
        adj.list = adj,
        weight.list = weights,
        n.cores = 1
    )
    .dg6a.expect.gflow.parity(
        "identical.vertex.set.weighted.graph.similarity",
        graph1.adj.list = adj,
        graph1.weights = weights,
        graph2.adj.list = adj,
        graph2.weights = alt.weights,
        calculate.normalized.deviation = TRUE
    )
})

test_that("DG6a graph extraction and disk utilities match original gflow outputs", {
    S.graph <- list(
        adj_list = list(c(2L, 3L), c(1L, 4L), c(1L, 4L), c(2L, 3L, 5L), c(4L)),
        dist_list = list(c(1.0, 1.5), c(1.0, 2.0), c(1.5, 1.2),
                         c(2.0, 1.2, 0.8), c(0.8))
    )
    S <- matrix(seq_len(10), nrow = 5)
    rownames(S) <- paste0("id", seq_len(5))

    .dg6a.expect.gflow.parity(
        "create.subgraph",
        S.graph = S.graph,
        ids = c("id1", "id3", "id4"),
        S = S,
        use.sequential.indices = TRUE
    )

    dist.mat <- matrix(c(
        0.00, 0.10, 0.35, 0.60,
        0.10, 0.00, 0.20, 0.55,
        0.35, 0.20, 0.00, 0.25,
        0.60, 0.55, 0.25, 0.00
    ), nrow = 4, byrow = TRUE)
    rownames(dist.mat) <- colnames(dist.mat) <- paste0("v", seq_len(4))

    .dg6a.expect.gflow.parity(
        "create.threshold.distance.graph",
        dist.matrix = dist.mat,
        threshold = 0.3,
        include.names = TRUE
    )

    .dg6a.expect.gflow.parity(
        "geodesic.disk",
        adj.list = S.graph$adj_list,
        weight.list = S.graph$dist_list,
        center.vertex = 1L,
        radius = 2.5
    )
    .dg6a.expect.gflow.parity(
        "geodesic.disk",
        adj.list = S.graph$adj_list,
        weight.list = S.graph$dist_list,
        center.vertex = 1L,
        n = 4L
    )
})
