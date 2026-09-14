.dg6c.ensure.gflow.parity.source <- function() {
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

.dg6c.gflow.function <- function(.fname) {
    .dg6c.ensure.gflow.parity.source()
    ns <- asNamespace("gflow")
    if (exists(.fname, envir = ns, mode = "function", inherits = FALSE)) {
        return(get(.fname, envir = ns, mode = "function", inherits = FALSE))
    }
    getExportedValue("gflow", .fname)
}

.dg6c.strip <- function(x) {
    if (is.data.frame(x)) {
        attributes(x)$call <- NULL
        return(x)
    }
    if (is.list(x)) {
        x <- lapply(x, .dg6c.strip)
    }
    attributes(x)$call <- NULL
    x
}

.dg6c.expect.gflow.parity <- function(.fname, ..., seed = NULL, tolerance = 1e-12) {
    dgraphs.fun <- get(.fname, envir = asNamespace("dgraphs"), mode = "function",
                       inherits = FALSE)
    gflow.fun <- .dg6c.gflow.function(.fname)
    if (!is.null(seed)) set.seed(seed)
    dgraphs.res <- suppressWarnings(dgraphs.fun(...))
    if (!is.null(seed)) set.seed(seed)
    gflow.res <- suppressWarnings(gflow.fun(...))
    expect_equal(
        .dg6c.strip(dgraphs.res),
        .dg6c.strip(gflow.res),
        tolerance = tolerance,
        ignore_attr = TRUE
    )
}

test_that("DG6c generic path distance helpers match original gflow outputs", {
    V <- matrix(c(0, 0, 1, 0, 1, 1, 2, 1), ncol = 2, byrow = TRUE)
    .dg6c.expect.gflow.parity("path.dist", s = c(1L, 2L, 3L, 4L), V = V)
    .dg6c.expect.gflow.parity("path.length", X = V)
    .dg6c.expect.gflow.parity("subdivide.path", path = V, n.subdivision.pts = 6)
})

test_that("DG6c geodesic distance and nearest-neighbor helpers match gflow", {
    X <- matrix(
        c(0, 0,
          1, 0,
          2, 0,
          3, 0,
          4, 0),
        ncol = 2,
        byrow = TRUE
    )
    rownames(X) <- paste0("p", seq_len(nrow(X)))

    .dg6c.expect.gflow.parity(
        "estimate.geodesic.distances",
        points = X,
        k = 1,
        method = "mst"
    )
    .dg6c.expect.gflow.parity("geodesic.knn", X = X, k = 2, K = 1)

    grid <- as.matrix(expand.grid(seq(0, 1, length.out = 3),
                                  seq(0, 1, length.out = 3)))
    X2 <- matrix(
        c(0, 0,
          1, 0,
          0, 1,
          1, 1,
          0.5, 0.5),
        ncol = 2,
        byrow = TRUE
    )
    .dg6c.expect.gflow.parity("geodesic.knnx", X = X2, X.grid = grid, k = 2)
})

test_that("DG6c disconnected geodesic behavior matches gflow", {
    points <- matrix(
        c(0, 0,
          1, 0,
          10, 0,
          11, 0),
        ncol = 2,
        byrow = TRUE
    )
    graph <- igraph::graph_from_edgelist(
        matrix(c(1, 2, 3, 4), ncol = 2, byrow = TRUE),
        directed = FALSE
    )
    igraph::E(graph)$weight <- c(1, 1)

    .dg6c.expect.gflow.parity(
        "estimate.geodesic.distances",
        points = points,
        k = 1,
        graph = graph
    )
})

test_that("DG6c path graph series helpers match original gflow outputs", {
    adj <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L))
    weights <- list(c(1), c(1, 2), c(2, 3), c(3))

    .dg6c.ensure.gflow.parity.source()
    dgraphs.series <- dgraphs::create.path.graph.series(adj, weights, c(1, 2, 3))
    gflow.series <- getExportedValue("gflow", "create.path.graph.series")(
        adj,
        weights,
        c(1, 2, 3)
    )

    expect_equal(
        .dg6c.strip(dgraphs::compare.paths(dgraphs.series, 1, 4)),
        .dg6c.strip(getExportedValue("gflow", "compare.paths")(gflow.series, 1, 4)),
        ignore_attr = TRUE
    )
    expect_equal(
        dgraphs::minh.limit(dgraphs.series, 1, 4),
        getExportedValue("gflow", "minh.limit")(gflow.series, 1, 4)
    )
})

test_that("DG6c native-backed path and endpoint helpers match gflow", {
    adj <- list(c(2L), c(1L, 3L, 4L), c(2L), c(2L))
    weights <- list(c(1), c(1, 2, 3), c(2), c(3))

    .dg6c.expect.gflow.parity("create.plm.graph", graph = adj, edge.lengths = weights, h = 3)
    .dg6c.expect.gflow.parity(
        "geodesic.core.endpoints",
        adj.list = adj,
        weight.list = weights,
        core.quantile = 0.5,
        endpoint.quantile = 0,
        use.approx.eccentricity = FALSE,
        verbose = FALSE
    )
})
