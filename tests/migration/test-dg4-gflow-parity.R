.dg4.strip.provenance <- function(x) {
    if (inherits(x, "igraph")) {
        return(list(
            n_vertices = igraph::vcount(x),
            n_edges = igraph::ecount(x),
            vertex_names = igraph::vertex_attr(x, "name"),
            edge_weights = igraph::edge_attr(x, "weight"),
            edge_intersections = igraph::edge_attr(x, "intersection.size")
        ))
    }
    if (is.list(x)) {
        x$call <- NULL
        x$timing <- NULL
        x$finalization_timing <- NULL
        x <- lapply(x, .dg4.strip.provenance)
    }
    attributes(x)$call <- NULL
    x
}

.dg4.expect.gflow.parity <- function(name, ..., tolerance = 1e-12) {
    skip_if_not_installed("gflow")
    dgraphs.fun <- getExportedValue("dgraphs", name)
    gflow.fun <- getExportedValue("gflow", name)
    dgraphs.res <- suppressWarnings(dgraphs.fun(...))
    gflow.res <- suppressWarnings(gflow.fun(...))
    expect_equal(
        .dg4.strip.provenance(dgraphs.res),
        .dg4.strip.provenance(gflow.res),
        tolerance = tolerance
    )
}

test_that("DG4 iKNN constructors match original gflow outputs", {
    X <- matrix(c(
        0.00, 0.00,
        0.32, 0.06,
        0.76, 0.10,
        0.12, 0.52,
        0.50, 0.70,
        0.88, 0.63,
        1.05, 0.24
    ), ncol = 2, byrow = TRUE)

    .dg4.expect.gflow.parity(
        "create.single.iknn.graph",
        X = X,
        k = 2,
        prune.method = "none",
        threshold.percentile = 0,
        compute.full = TRUE,
        with.isize.pruning = TRUE,
        pca.dim = NULL,
        connect.components = TRUE,
        connect.method = "component.mst",
        verbose = FALSE
    )

    .dg4.expect.gflow.parity(
        "create.iknn.graphs",
        X = X,
        kmin = 2,
        kmax = 3,
        max.path.edge.ratio.deviation.thld = 0,
        threshold.percentile = 0,
        compute.full = TRUE,
        with.isize.pruning = TRUE,
        pca.dim = NULL,
        n.cores = 1,
        parallel.mode = "k",
        verbose = FALSE
    )
})

test_that("DG4 geodesic and iterated iKNN constructors match gflow", {
    graph <- list(
        adj_list = list(c(2L, 3L), c(1L, 3L, 4L), c(1L, 2L, 4L), c(2L, 3L)),
        weight_list = list(c(1.0, 2.0), c(1.0, 1.2, 2.2), c(2.0, 1.2, 0.7),
                           c(2.2, 0.7))
    )

    .dg4.expect.gflow.parity(
        "create.geodesic.iknn.graph",
        graph = graph,
        k = 2
    )

    X <- matrix(c(
        0.00, 0.00,
        0.25, 0.08,
        0.52, 0.02,
        0.10, 0.42,
        0.42, 0.54,
        0.72, 0.40
    ), ncol = 2, byrow = TRUE)

    .dg4.expect.gflow.parity(
        "create.iterated.iknn.graphs",
        X = X,
        kmin = 2,
        kmax = 3,
        n.iterations = 1,
        pca.dim = NULL,
        n.cores = 1,
        parallel.mode = "k",
        verbose = FALSE
    )
})

test_that("DG4 R-level graph utilities match gflow", {
    dist.mat <- matrix(c(
        0.00, 0.10, 0.35, 0.60,
        0.10, 0.00, 0.20, 0.55,
        0.35, 0.20, 0.00, 0.25,
        0.60, 0.55, 0.25, 0.00
    ), nrow = 4, byrow = TRUE)
    rownames(dist.mat) <- colnames(dist.mat) <- paste0("v", seq_len(4))

    .dg4.expect.gflow.parity(
        "create.threshold.distance.graph",
        dist.matrix = dist.mat,
        threshold = 0.3,
        include.names = TRUE
    )

    gflow.graph <- list(
        adjacency.list = list(c(2L, 3L), c(1L), c(1L)),
        weight.list = list(c(1.5, 2.5), c(1.5), c(2.5)),
        intersection.matrix = matrix(c(0, 4, 2, 4, 0, 0, 2, 0, 0),
                                     nrow = 3, byrow = TRUE),
        basin.metadata = data.frame(
            label = c("a", "b", "c"),
            type = c("ascending", "descending", "ascending"),
            size = c(10, 20, 15),
            extremum.vertex = c(1L, 2L, 3L),
            extremum.value = c(0.1, 0.4, 0.7)
        )
    )
    .dg4.expect.gflow.parity(
        "as_igraph",
        gflow.graph = gflow.graph
    )
})

test_that("DG4 KNN outlier removal matches gflow", {
    skip_if_not_installed("FNN")
    S <- matrix(c(
        0.00, 0.00,
        0.10, 0.02,
        0.18, 0.04,
        0.25, 0.01,
        0.32, 0.05,
        4.00, 4.00
    ), ncol = 2, byrow = TRUE)
    y <- seq_len(nrow(S))

    .dg4.expect.gflow.parity(
        "remove.knn.outliers",
        S = S,
        y = y,
        p = 0.8,
        dist.factor = 10,
        K = 2,
        method = "diff.dist.factor"
    )
})
