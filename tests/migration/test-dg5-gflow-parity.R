.dg5.ensure.gflow.parity.source <- function() {
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

.dg5.gflow.function <- function(.fname) {
    .dg5.ensure.gflow.parity.source()
    ns <- asNamespace("gflow")
    if (exists(.fname, envir = ns, mode = "function", inherits = FALSE)) {
        return(get(.fname, envir = ns, mode = "function", inherits = FALSE))
    }
    getExportedValue("gflow", .fname)
}

.dg5.strip <- function(x) {
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
        x <- lapply(x, .dg5.strip)
    }
    attributes(x)$call <- NULL
    attributes(x)$graph <- NULL
    x
}

.dg5.expect.gflow.parity <- function(.fname, ..., seed = NULL, tolerance = 1e-12) {
    dgraphs.fun <- get(.fname, envir = asNamespace("dgraphs"), mode = "function",
                       inherits = FALSE)
    gflow.fun <- .dg5.gflow.function(.fname)
    if (!is.null(seed)) set.seed(seed)
    dgraphs.res <- suppressWarnings(dgraphs.fun(...))
    if (!is.null(seed)) set.seed(seed)
    gflow.res <- suppressWarnings(gflow.fun(...))
    expect_equal(
        .dg5.strip(dgraphs.res),
        .dg5.strip(gflow.res),
        tolerance = tolerance,
        ignore_attr = TRUE
    )
}

test_that("DG5 graph generator utilities match original gflow outputs", {
    cover <- list(c(1L, 2L, 4L), c(2L, 3L), c(5L), c(1L, 5L))
    .dg5.expect.gflow.parity("nerve.graph", covering.list = cover, n.cores = 1)

    .dg5.expect.gflow.parity("create.bipartite.graph", n1 = 3, n2 = 2)
    .dg5.expect.gflow.parity("create.bi.kNN.chain.graph", n.vertices = 6, k = 2)
    .dg5.expect.gflow.parity(
        "create.chain.graph",
        x = c(0.7, 0.2, 0.5, 0.9),
        y = c(7, 2, 5, 9)
    )
    .dg5.expect.gflow.parity("create.circular.graph", n = 5)
    .dg5.expect.gflow.parity(
        "generate.circle.graph",
        n = 6,
        type = "random",
        seed = 404
    )
})

test_that("DG5 graph edit and summary diagnostics match original gflow outputs", {
    g1.adj <- list(c(2L, 3L), c(1L, 3L), c(1L, 2L))
    g1.w <- list(c(1, 2), c(1, 3), c(2, 3))
    g2.adj <- list(c(2L), c(1L, 3L), c(2L))
    g2.w <- list(1.5, c(1.5, 2.5), 2.5)

    .dg5.expect.gflow.parity(
        "graph.edit.distance",
        graph1.adj.list = g1.adj,
        graph1.weights = g1.w,
        graph2.adj.list = g2.adj,
        graph2.weights = g2.w,
        edge.cost = 1,
        weight.cost.factor = 0.1
    )
    .dg5.expect.gflow.parity(
        "compute.graph.summary.pmf",
        graph = g1.adj,
        weight.list = g1.w,
        summary = "degree_distribution"
    )
    .dg5.expect.gflow.parity(
        "graph.summary.divergence",
        g1 = g1.adj,
        g2 = g2.adj,
        summary = "degree_distribution"
    )
    .dg5.expect.gflow.parity(
        "compute.graph.summary.stability",
        graphs = list(g2.adj, g1.adj),
        summary = "degree_distribution"
    )
})

test_that("DG5 isometry diagnostics match original gflow outputs", {
    D.true <- as.matrix(stats::dist(matrix(c(0, 0, 1, 0, 1, 1, 0, 1),
                                           ncol = 2, byrow = TRUE)))
    D.est <- 1.15 * D.true
    .dg5.expect.gflow.parity("isometry.scale", D.estimated = D.est, D.true = D.true)
    .dg5.expect.gflow.parity("isometry.rel.rms.error", D.estimated = D.est, D.true = D.true)
    .dg5.expect.gflow.parity("isometry.rel.abs.error", D.estimated = D.est, D.true = D.true)
    .dg5.expect.gflow.parity("isometry.distortion.quantiles", D.estimated = D.est, D.true = D.true)
    .dg5.expect.gflow.parity("isometry.distance.correlations", D.estimated = D.est, D.true = D.true)
    .dg5.expect.gflow.parity("isometry.geodesic.diagnostics", D.estimated = D.est, D.true = D.true)
    .dg5.expect.gflow.parity("summarize.isometry.deviation", D.estimated = D.est, D.true = D.true)
})

test_that("DG5 maximal packing and geodesic statistics match original gflow outputs", {
    adj <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L))
    w <- list(1, c(1, 1), c(1, 1), c(1, 1), 1)

    .dg5.expect.gflow.parity(
        "create.maximal.packing",
        adj.list = adj,
        weight.list = w,
        grid.size = 2,
        max.iterations = 5,
        precision = 0.1
    )
    .dg5.expect.gflow.parity(
        "validate.maximal.packing",
        adj.list = adj,
        weight.list = w,
        packing.vertices = c(1L, 3L, 5L),
        max.packing.radius = 2
    )
    packing <- create.maximal.packing(adj, w, grid.size = 2, max.iterations = 5)
    expect_true(verify.maximal.packing(packing, verbose = FALSE))

    .dg5.expect.gflow.parity(
        "compute.geodesic.stats",
        adj.list = adj,
        weight.list = w,
        min.radius = 0.2,
        max.radius = 0.5,
        n.steps = 2,
        n.packing.vertices = 3,
        max.packing.iterations = 5,
        packing.precision = 0.01,
        verbose = FALSE
    )
    .dg5.expect.gflow.parity(
        "compute.vertex.geodesic.stats",
        adj.list = adj,
        weight.list = w,
        grid.vertex = 3,
        min.radius = 0.2,
        max.radius = 0.5,
        n.steps = 2,
        n.packing.vertices = 3,
        packing.precision = 0.01
    )
})

test_that("DG5 endpoint utilities run self-hosted", {
    adj <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L))
    w <- list(1, c(1, 1), c(1, 1), c(1, 1), 1)
    layout <- cbind(seq_len(5), 0, 0)

    scores <- compute.graph.endpoint.scores(
        adj.list = adj,
        weight.list = w,
        layout.3d = layout,
        k = c(2L, 3L),
        min.neighborhood.size = 2L
    )
    expect_s3_class(scores, "graph_endpoint_scores")
    expect_equal(nrow(scores$summary), 5L)

    endpoints <- detect.graph.endpoints(
        adj.list = adj,
        weight.list = w,
        layout.3d = layout,
        k = c(2L, 3L),
        min.neighborhood.size = 2L,
        detect.max.radius = 2,
        detect.min.neighborhood.size = 2L,
        smooth = FALSE
    )
    expect_s3_class(endpoints, "graph_endpoints")
    expect_true(all(endpoints$endpoints %in% seq_along(adj)))
})

test_that("DG5 endpoint utilities use package-local native acceleration", {
    adj <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L))
    w <- list(1, c(1, 1), c(1, 1), c(1, 1), 1)
    layout <- cbind(seq_len(5), 0, 0)
    local.max <- matrix(
        c(
            TRUE, FALSE,
            FALSE, TRUE,
            TRUE, FALSE,
            FALSE, TRUE,
            TRUE, FALSE
        ),
        nrow = 5,
        ncol = 2
    )
    score.by.scale <- matrix(
        c(
            0.9, 0.1,
            0.7, 0.8,
            0.5, 0.4,
            0.3, 0.6,
            0.1, 0.2
        ),
        nrow = 5,
        ncol = 2
    )

    expect_true(is.function(get("rcpp_compute_graph_endpoint_scores",
                                envir = asNamespace("dgraphs"))))
    expect_true(is.function(get("rcpp_graph_multi_source_support_by_scale",
                                envir = asNamespace("dgraphs"))))
    expect_true(is.function(get("rcpp_graph_greedy_maxima_suppression_by_scale",
                                envir = asNamespace("dgraphs"))))

    native.scores <- dgraphs:::.compute.graph.endpoint.scores.reference(
        adj.list = adj,
        weight.list = w,
        layout.3d = layout,
        scales = c(2, 3),
        neighborhood = "geodesic_k",
        q = 0.1,
        neighbor.weighting = "uniform",
        gaussian.sigma = NULL,
        min.neighborhood.size = 2L,
        prefer.cpp = TRUE
    )
    reference.scores <- dgraphs:::.compute.graph.endpoint.scores.reference(
        adj.list = adj,
        weight.list = w,
        layout.3d = layout,
        scales = c(2, 3),
        neighborhood = "geodesic_k",
        q = 0.1,
        neighbor.weighting = "uniform",
        gaussian.sigma = NULL,
        min.neighborhood.size = 2L,
        prefer.cpp = FALSE
    )
    expect_equal(native.scores, reference.scores, tolerance = 1e-12)

    native.support <- dgraphs:::.compute.graph.endpoint.support.by.scale(
        adj.list = adj,
        weight.list = w,
        local.max.by.scale = local.max,
        radius = 1,
        prefer.cpp = TRUE
    )
    reference.support <- dgraphs:::.compute.graph.endpoint.support.by.scale(
        adj.list = adj,
        weight.list = w,
        local.max.by.scale = local.max,
        radius = 1,
        prefer.cpp = FALSE
    )
    expect_equal(native.support, reference.support)

    native.keep <- dgraphs:::.suppress.graph.endpoint.maxima.by.scale(
        adj.list = adj,
        weight.list = w,
        local.max.by.scale = local.max,
        score.by.scale = score.by.scale,
        radius = 1,
        prefer.cpp = TRUE
    )
    reference.keep <- dgraphs:::.suppress.graph.endpoint.maxima.by.scale(
        adj.list = adj,
        weight.list = w,
        local.max.by.scale = local.max,
        score.by.scale = score.by.scale,
        radius = 1,
        prefer.cpp = FALSE
    )
    expect_equal(native.keep, reference.keep)
})
