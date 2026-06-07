test_that("create.rknn.graphs matches scalar adaptive-radius constructor", {
    X <- matrix(c(
        0.00, 0.00,
        0.40, 0.05,
        0.78, 0.08,
        0.12, 0.58,
        0.48, 0.65,
        0.88, 0.72
    ), ncol = 2, byrow = TRUE)

    graphs <- create.rknn.graphs(
        X,
        kmin = 1,
        kmax = 3,
        radius.factor = 1.15,
        radius.rule = "geomean",
        radius.search = "all.pairs",
        prune.method = "none",
        graph.detail = "minimal",
        connect.components = FALSE
    )

    expect_s3_class(graphs, "rknn_graphs")
    expect_named(graphs$graphs, as.character(1:3))
    expect_equal(attr(graphs, "k.values"), 1:3)
    expect_equal(graphs$k_statistics$k, 1:3)
    expect_equal(graphs$k_statistics$n_edges,
                 unname(vapply(graphs$graphs,
                                function(g) g$n_edges,
                                integer(1))))

    for (k in 1:3) {
        scalar <- create.rknn.graph(
            X,
            type = "adaptive.radius",
            k.scale = k,
            radius.factor = 1.15,
            radius.rule = "geomean",
            radius.search = "all.pairs",
            prune.method = "none",
            graph.detail = "minimal",
            connect.components = FALSE
        )
        expect_equal(graphs$graphs[[as.character(k)]], scalar)
    }
})

test_that("create.rknn.graphs is exported", {
    expect_true("create.rknn.graphs" %in% getNamespaceExports("dgraphs"))
})

test_that("create.rknn.graphs supports explicit k.values order", {
    X <- matrix(c(
        0.00, 0.00,
        0.40, 0.05,
        0.78, 0.08,
        0.12, 0.58,
        0.48, 0.65,
        0.88, 0.72
    ), ncol = 2, byrow = TRUE)

    graphs <- create.rknn.graphs(
        X,
        k.values = c(3, 1),
        radius.factor = 1.1,
        radius.search = "all.pairs",
        prune.method = "none",
        graph.detail = "minimal",
        connect.components = FALSE
    )

    expect_named(graphs$graphs, c("3", "1"))
    expect_equal(graphs$k_statistics$k, c(3L, 1L))
    expect_equal(attr(graphs, "kmin"), 1L)
    expect_equal(attr(graphs, "kmax"), 3L)
})

test_that("create.rknn.graphs aggregates scalar timing rows", {
    X <- matrix(c(
        0.00, 0.00,
        0.40, 0.05,
        0.78, 0.08,
        0.12, 0.58,
        0.48, 0.65,
        0.88, 0.72
    ), ncol = 2, byrow = TRUE)

    graphs <- create.rknn.graphs(
        X,
        kmin = 1,
        kmax = 2,
        radius.search = "all.pairs",
        prune.method = "none",
        graph.detail = "minimal",
        connect.components = FALSE,
        return.timing = TRUE
    )

    expect_s3_class(graphs$timing, "data.frame")
    expect_true(all(c("k", "phase", "elapsed.sec") %in% names(graphs$timing)))
    expect_equal(sort(unique(graphs$timing$k)), c(1L, 2L))
})

test_that("create.rknn.graphs rejects scalar and fixed-radius controls", {
    X <- matrix(seq_len(12), ncol = 2)

    expect_error(
        create.rknn.graphs(X, 1, 2, k.scale = 1),
        "'k.scale' is varied"
    )
    expect_error(
        create.rknn.graphs(X, 1, 2, type = "fixed"),
        "'type' must be omitted"
    )
    expect_error(
        create.rknn.graphs(X, 1, 2, radius = 1),
        "'radius' is for fixed-radius graphs"
    )
    expect_error(
        create.rknn.graphs(X, k.values = c(1, 1)),
        "'k.values' cannot contain duplicate"
    )
})
