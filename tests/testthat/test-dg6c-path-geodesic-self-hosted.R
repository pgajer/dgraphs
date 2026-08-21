test_that("DG6c path distance helpers run self-hosted", {
    d <- matrix(c(0, 1, 4, 1, 0, 2, 4, 2, 0), nrow = 3, byrow = TRUE)
    knn <- dgraphs:::.dist.to.knn(d, k = 2)
    expect_equal(knn$nn.i, matrix(c(1L, 2L, 2L, 1L, 3L, 2L), nrow = 3, byrow = TRUE))
    expect_equal(knn$nn.d, matrix(c(0, 1, 0, 1, 0, 2), nrow = 3, byrow = TRUE))

    V <- matrix(c(0, 0, 1, 0, 1, 1, 2, 1), ncol = 2, byrow = TRUE)
    expect_equal(dgraphs::path.dist(c(1L, 2L, 3L, 4L), V), c(0, 1 / 3, 2 / 3, 1))
    expect_equal(dgraphs::path.length(V), 3)
    expect_equal(dgraphs:::.point.euclidean.distance(c(0, 0), c(3, 4)), 5)

    subdivided <- dgraphs::subdivide.path(V, n.subdivision.pts = 6)
    expect_equal(dim(subdivided), c(6L, 2L))
    expect_equal(
        subdivided,
        matrix(c(0.6, 0,
                 1, 0.8,
                 2, 1,
                 NA, NA,
                 NA, NA,
                 2, 1),
               ncol = 2,
               byrow = TRUE)
    )
    expect_equal(subdivided[6, ], V[4, ])
})

test_that("DG6c geodesic distance helpers run self-hosted", {
    X <- matrix(
        c(0, 0,
          1, 0,
          2, 0,
          3, 0),
        ncol = 2,
        byrow = TRUE
    )
    D <- dgraphs::estimate.geodesic.distances(X, k = 1, method = "mst")
    expect_equal(
        D,
        matrix(c(0, 1, 2, 3,
                 1, 0, 1, 2,
                 2, 1, 0, 1,
                 3, 2, 1, 0),
               nrow = 4,
               byrow = TRUE),
        ignore_attr = TRUE
    )

    gnn <- dgraphs::geodesic.knn(X, k = 2, K = 1)
    expect_equal(gnn$nn.index[1, ], c(1L, 2L))
    expect_equal(gnn$nn.index[4, ], c(4L, 3L))

    graph <- igraph::graph_from_edgelist(
        matrix(c(1, 2, 3, 4), ncol = 2, byrow = TRUE),
        directed = FALSE
    )
    igraph::E(graph)$weight <- c(1, 1)
    disconnected <- dgraphs::estimate.geodesic.distances(X, k = 1, graph = graph)
    expect_true(is.infinite(disconnected[1, 3]))

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
    gnnx <- dgraphs::geodesic.knnx(X2, grid, k = 2)
    expect_equal(dim(gnnx$V), c(14L, 2L))
    expect_equal(dim(gnnx$nn.index), c(9L, 2L))
    expect_equal(dim(gnnx$nn.dist), c(9L, 2L))
})

test_that("DG6c path graph series helpers run self-hosted", {
    adj <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L))
    weights <- list(c(1), c(1, 2), c(2, 3), c(3))

    series <- dgraphs::create.path.graph.series(adj, weights, c(1, 2, 3))
    cmp <- dgraphs::compare.paths(series, from = 1, to = 4)

    expect_equal(cmp$path_exists, c(FALSE, FALSE, TRUE))
    expect_equal(cmp$path_length, c(NA, NA, 6))
    expect_equal(cmp$n_hops, c(NA_integer_, NA_integer_, 3L))
    expect_equal(cmp$path[[3]], c(1L, 2L, 3L, 4L))
    expect_equal(dgraphs::minh.limit(series, from = 1, to = 4), 3L)
    expect_null(dgraphs::minh.limit(series, from = 4, to = 1))
})

test_that("DG6c native-backed PLM graph helper runs self-hosted", {
    adj <- list(c(2L), c(1L, 3L), c(2L))
    weights <- list(c(1), c(1, 2), c(2))

    plm <- dgraphs::create.plm.graph(adj, weights, h = 3)
    expect_s3_class(plm, "path.graph.plm")
    expect_named(plm, c("adj_list", "edge_length_list", "hop_list",
                        "shortest_paths", "vertex_paths", "h"))
    expect_equal(plm$adj_list[[1]], c(2L, 3L))
    expect_equal(plm$edge_length_list[[1]], c(1, 3))
    expect_equal(plm$hop_list[[1]], c(1L, 2L))
    expect_equal(plm$shortest_paths$paths[[2]], c(1L, 2L, 3L))
    expect_equal(plm$vertex_paths[[2]][, "position"], c(2L, 2L, 1L))

    expect_error(
        dgraphs::create.plm.graph(adj, weights, h = 2),
        "'h' must be odd"
    )
})

test_that("DG6c graph core endpoints run self-hosted", {
    adj <- list(c(2L), c(1L, 3L, 4L), c(2L), c(2L))
    weights <- list(c(1), c(1, 2, 3), c(2), c(3))

    endpoints <- dgraphs::geodesic.core.endpoints(
        adj,
        weights,
        core.quantile = 0.5,
        endpoint.quantile = 0,
        use.approx.eccentricity = FALSE,
        verbose = FALSE
    )

    expect_s3_class(endpoints, "geodesic_core_endpoints")
    expect_equal(endpoints$endpoints, c(4L, 3L, 1L))
    expect_equal(endpoints$core.vertices, c(1L, 2L))
    expect_equal(endpoints$distance.to.core, c(0, 0, 2, 3))
    expect_false(endpoints$used.approx.eccentricity)
})

test_that("DG6c single-vertex geodesic statistics use R vertex indices", {
    graph <- dgraphs::generate.circle.graph(8, type = "uniform")
    result <- dgraphs::compute.vertex.geodesic.stats(
        graph$adj.list,
        graph$weight.list,
        grid.vertex = 1,
        min.radius = 0.3,
        max.radius = 0.5,
        n.steps = 2
    )

    expect_s3_class(result, "vertex_geodesic_stats")
    expect_identical(attr(result, "vertex"), 1L)
    expect_equal(nrow(result), 2L)
})
