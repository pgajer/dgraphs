.dg12.ensure.gflow.parity.source <- function() {
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

.dg12.strip.provenance <- function(x) {
    if (inherits(x, "igraph")) {
        return(list(
            n_vertices = igraph::vcount(x),
            n_edges = igraph::ecount(x),
            vertex_names = igraph::vertex_attr(x, "name"),
            edge_weights = igraph::edge_attr(x, "weight"),
            edge_intersections = igraph::edge_attr(x, "intersection.size")
        ))
    }
    if (inherits(x, "igraph.vs") || inherits(x, "igraph.es")) {
        return(as.integer(x))
    }
    if (is.list(x)) {
        x$call <- NULL
        x$timing <- NULL
        x$finalization_timing <- NULL
        x <- lapply(x, .dg12.strip.provenance)
    }
    attributes(x)$call <- NULL
    attributes(x)$graph <- NULL
    x
}

.dg12.expect.gflow.parity <- function(.name, ..., seed = NULL, tolerance = 1e-12) {
    .dg12.ensure.gflow.parity.source()
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
        .dg12.strip.provenance(dgraphs.res),
        .dg12.strip.provenance(gflow.res),
        tolerance = tolerance,
        ignore_attr = TRUE
    )
}

test_that("DG1 basic graph generators match original gflow outputs", {
    .dg12.expect.gflow.parity("create.complete.graph", n = 5)
    .dg12.expect.gflow.parity("create.empty.graph", n = 5)
    .dg12.expect.gflow.parity(
        "join.graphs",
        graph1 = list(2L, 1L),
        graph2 = list(2L, 1L),
        i1 = 2,
        i2 = 1
    )
    .dg12.expect.gflow.parity("create.star.graph", sizes = c(2, 3, 1))
})

test_that("DG1 random graph structure matches gflow without legacy RNG reset", {
    .dg12.ensure.gflow.parity.source()

    set.seed(111)
    dgraphs.res <- create.random.graph(
        n_vertices = 8,
        avg_degree = 3,
        connected = TRUE
    )
    set.seed(111)
    gflow.res <- getExportedValue("gflow", "create.random.graph")(
        n_vertices = 8,
        avg_degree = 3,
        connected = TRUE
    )

    expect_equal(dgraphs.res$adj.list, gflow.res$adj.list)
    expect_equal(lengths(dgraphs.res$weight.list), lengths(gflow.res$weight.list))

    set.seed(1001)
    invisible(create.random.graph(n_vertices = 8, avg_degree = 3, connected = TRUE))
    next.after.seed.1001 <- stats::runif(3)

    set.seed(1002)
    invisible(create.random.graph(n_vertices = 8, avg_degree = 3, connected = TRUE))
    next.after.seed.1002 <- stats::runif(3)

    expect_false(isTRUE(all.equal(next.after.seed.1001, next.after.seed.1002)))
})

test_that("DG1 graph utilities match original gflow outputs", {
    adj <- list(c(2L, 3L), c(1L, 3L, 4L), c(1L, 2L, 4L), c(2L, 3L))
    weights <- list(c(1.0, 2.0), c(1.0, 1.2, 2.2), c(2.0, 1.2, 0.7),
                    c(2.2, 0.7))

    .dg12.expect.gflow.parity(
        "graph.connected.components",
        adj.list = list(c(2L, 3L), c(1L), c(1L), integer(0))
    )
    .dg12.expect.gflow.parity(
        "graph.adj.mat",
        X = matrix(c(0, 0, 1, 0, 1, 1), ncol = 2, byrow = TRUE),
        E = matrix(c(1, 2, 2, 3), ncol = 2, byrow = TRUE)
    )
    .dg12.expect.gflow.parity(
        "compute.graph.distance",
        i = 1,
        j = 4,
        adj.list = adj,
        edge.lengths = weights
    )
    .dg12.expect.gflow.parity(
        "compute.graph.diameter",
        adj.list = adj,
        weight.list = weights
    )
    .dg12.expect.gflow.parity("adjlist.to.igraph", adj.list = adj)
})

test_that("DG2 path, grid, and pruning utilities match original gflow outputs", {
    adj <- list(c(2L, 3L), c(1L, 3L, 4L), c(1L, 2L, 4L), c(2L, 3L))
    weights <- list(c(1.0, 2.0), c(1.0, 1.2, 2.2), c(2.0, 1.2, 0.7),
                    c(2.2, 0.7))

    .dg12.expect.gflow.parity(
        "shortest.path",
        graph = adj,
        edge.lengths = weights,
        vertices = 1:4
    )
    .dg12.expect.gflow.parity(
        "create.path.graph",
        graph = adj,
        edge.lengths = weights,
        h = 2
    )
    .dg12.expect.gflow.parity(
        "create.path.graph.series",
        graph = adj,
        edge.lengths = weights,
        h.values = c(1, 2, 3)
    )
    .dg12.expect.gflow.parity(
        "create.grid.graph",
        adj.list = list(c(2L), c(1L, 3L), c(2L)),
        weight.list = list(c(1), c(1, 2), c(2)),
        grid.size = 5
    )
    .dg12.expect.gflow.parity(
        "wgraph.prune.long.edges",
        graph = list(c(2L, 3L), c(1L, 3L), c(1L, 2L)),
        edge.lengths = list(c(1, 2), c(1, 3), c(2, 3)),
        alt.path.len.ratio.thld = 1.1,
        use.total.length.constraint = TRUE,
        verbose = FALSE
    )
})
