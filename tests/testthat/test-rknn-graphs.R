.dg7.rknn.expect.cpp.ann.parity <- function(X, ..., tolerance = 1e-12) {
    r.graphs <- create.rknn.graphs(X, radius.search = "ann", ...)
    cpp.graphs <- cpp.create.rknn.graphs(X, ...)
    expect_equal(cpp.graphs, r.graphs, tolerance = tolerance)
    invisible(cpp.graphs)
}

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

test_that("cpp.create.rknn.graphs is exported", {
    expect_true("cpp.create.rknn.graphs" %in% getNamespaceExports("dgraphs"))
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

test_that("cpp.create.rknn.graphs matches R-level ANN backend", {
    X <- matrix(c(
        0.00, 0.00,
        0.41, 0.07,
        0.82, 0.13,
        0.09, 0.61,
        0.52, 0.68,
        0.91, 0.79,
        1.17, 0.33
    ), ncol = 2, byrow = TRUE)

    for (rule in c("max", "min", "geomean")) {
        r.graphs <- create.rknn.graphs(
            X,
            k.values = c(3, 1, 2),
            radius.factor = 1.13,
            radius.rule = rule,
            radius.search = "ann",
            prune.method = "none",
            graph.detail = "minimal",
            connect.components = FALSE
        )
        cpp.graphs <- cpp.create.rknn.graphs(
            X,
            k.values = c(3, 1, 2),
            radius.factor = 1.13,
            radius.rule = rule,
            prune.method = "none",
            graph.detail = "minimal",
            connect.components = FALSE
        )

        expect_equal(cpp.graphs, r.graphs, tolerance = 1e-12)
    }
})

test_that("cpp.create.rknn.graphs matches ANN backend for near-duplicate and tie cases", {
    cases <- list(
        near.duplicates = list(
            X = matrix(c(
                0, 0,
                1e-12, 0,
                2e-12, 0,
                1, 0,
                2, 0,
                3, 0
            ), ncol = 2, byrow = TRUE),
            k.values = c(1, 2, 4)
        ),
        jittered.cluster.line = list(
            X = matrix(c(
                0,      0,
                1e-12,  0,
                1,      0,
                2,      0,
                3,      0,
                4,      0
            ), ncol = 2, byrow = TRUE),
            k.values = c(3, 1, 2)
        ),
        square.center.ties = list(
            X = matrix(c(
                 0,  0,
                 1,  0,
                -1,  0,
                 0,  1,
                 0, -1,
                 2,  0
            ), ncol = 2, byrow = TRUE),
            k.values = c(1, 2, 3)
        ),
        symmetric.hexagon = list(
            X = cbind(
                cos(2 * pi * (0:5) / 6),
                sin(2 * pi * (0:5) / 6)
            ),
            k.values = c(2, 1, 3)
        )
    )

    for (case in cases) {
        for (rule in c("max", "min", "geomean")) {
            .dg7.rknn.expect.cpp.ann.parity(
                case$X,
                k.values = case$k.values,
                radius.factor = 1,
                radius.rule = rule,
                prune.method = "none",
                graph.detail = "minimal",
                connect.components = FALSE
            )
        }
    }
})

test_that("cpp.create.rknn.graphs forwards finalization controls", {
    X <- rbind(
        c(0, 0), c(0.07, 0), c(0, 0.07),
        c(10, 10), c(10.07, 10), c(10, 10.07)
    )

    r.graphs <- create.rknn.graphs(
        X,
        kmin = 1,
        kmax = 2,
        radius.factor = 1.05,
        radius.rule = "max",
        radius.search = "ann",
        prune.method = "none",
        connect.components = TRUE,
        connect.method = "component.mst"
    )
    cpp.graphs <- cpp.create.rknn.graphs(
        X,
        kmin = 1,
        kmax = 2,
        radius.factor = 1.05,
        radius.rule = "max",
        prune.method = "none",
        connect.components = TRUE,
        connect.method = "component.mst"
    )

    expect_equal(cpp.graphs, r.graphs, tolerance = 1e-12)
})

test_that("cpp.create.rknn.graphs matches ANN backend for pruning finalization", {
    X <- matrix(c(
        0.00, 0.00,
        0.35, 0.00,
        0.70, 0.00,
        0.20, 0.35,
        0.55, 0.38,
        0.90, 0.30,
        1.20, 0.00
    ), ncol = 2, byrow = TRUE)

    .dg7.rknn.expect.cpp.ann.parity(
        X,
        k.values = c(2, 3),
        radius.factor = 1.4,
        radius.rule = "max",
        prune.method = "local.geodesic",
        prune.local.k = 3,
        with.pruned.edge.stats = TRUE,
        connect.components = FALSE
    )

    .dg7.rknn.expect.cpp.ann.parity(
        X,
        k.values = c(2, 3),
        radius.factor = 1.4,
        radius.rule = "max",
        prune.method = "global.geodesic.ratio",
        max.path.edge.ratio.deviation.thld = 0.12,
        path.edge.ratio.percentile = 0.25,
        with.pruned.edge.stats = TRUE,
        connect.components = FALSE
    )
})

test_that("cpp.create.rknn.graphs matches ANN backend for component repair methods", {
    X <- rbind(
        c(0, 0), c(0.07, 0), c(0, 0.07),
        c(10, 10), c(10.07, 10), c(10, 10.07)
    )

    cpp.graphs <- .dg7.rknn.expect.cpp.ann.parity(
        X,
        k.values = c(1, 2),
        radius.factor = 1.05,
        radius.rule = "max",
        prune.method = "none",
        connect.components = TRUE,
        connect.method = "component.mst.ann",
        bridge.k = 1,
        bridge.k.max = 1
    )
    expect_true(all(vapply(cpp.graphs$graphs,
                           function(g) isTRUE(g$bridge_exact_fallback_used),
                           logical(1))))

    .dg7.rknn.expect.cpp.ann.parity(
        X,
        k.values = c(1, 2),
        radius.factor = 1.05,
        radius.rule = "max",
        prune.method = "none",
        connect.components = TRUE,
        connect.method = "global.mst"
    )
})

test_that("cpp.create.rknn.graphs matches ANN backend for full lifecycle repair", {
    X <- rbind(
        c(0, 0), c(0.07, 0), c(0, 0.07),
        c(10, 10), c(10.07, 10), c(10, 10.07)
    )

    .dg7.rknn.expect.cpp.ann.parity(
        X,
        k.values = c(1, 2),
        radius.factor = 1.05,
        radius.rule = "max",
        prune.method = "local.geodesic",
        prune.local.k = 2,
        with.pruned.edge.stats = TRUE,
        connect.components = TRUE,
        connect.method = "component.mst"
    )
})

test_that("cpp.create.rknn.graphs reports shared native timing", {
    X <- matrix(c(
        0.00, 0.00,
        0.40, 0.05,
        0.78, 0.08,
        0.12, 0.58,
        0.48, 0.65,
        0.88, 0.72
    ), ncol = 2, byrow = TRUE)

    graphs <- cpp.create.rknn.graphs(
        X,
        kmin = 1,
        kmax = 2,
        prune.method = "none",
        graph.detail = "minimal",
        connect.components = FALSE,
        return.timing = TRUE
    )

    expect_s3_class(graphs$timing, "data.frame")
    expect_true(all(c("k", "phase", "elapsed.sec") %in% names(graphs$timing)))
    expect_true(any(is.na(graphs$timing$k)))
    expect_true("ann.max.scale.search" %in% graphs$timing$phase)
    expect_true(all(c(1L, 2L) %in% graphs$timing$k))
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

test_that("cpp.create.rknn.graphs rejects non-ANN and unsupported controls", {
    X <- matrix(seq_len(12), ncol = 2)

    expect_error(
        cpp.create.rknn.graphs(X, 1, 2, radius.search = "all.pairs"),
        "'radius.search' must be omitted"
    )
    expect_error(
        cpp.create.rknn.graphs(X, 1, 2, k.scale = 1),
        "'k.scale' is varied"
    )
    expect_error(
        cpp.create.rknn.graphs(X, 1, 2, type = "fixed"),
        "'type' must be omitted"
    )
    expect_error(
        cpp.create.rknn.graphs(X, 1, 2, unknown.control = TRUE),
        "Unused argument"
    )
})

test_that("radius graph constructors reject duplicate rows", {
    X <- matrix(c(
        0.00, 0.00,
        0.25, 0.25,
        0.25, 0.25,
        0.75, 0.75
    ), ncol = 2, byrow = TRUE)

    expect_error(
        create.rknn.graph(
            X,
            type = "adaptive.radius",
            k.scale = 1,
            radius.search = "all.pairs",
            prune.method = "none",
            graph.detail = "minimal"
        ),
        "duplicate rows"
    )
    expect_error(
        create.rknn.graph(
            X,
            type = "fixed",
            radius = 0.5,
            prune.method = "none"
        ),
        "duplicate rows"
    )
    expect_error(
        create.rknn.graphs(
            X,
            kmin = 1,
            kmax = 2,
            prune.method = "none",
            graph.detail = "minimal"
        ),
        "duplicate rows"
    )
    expect_error(
        cpp.create.rknn.graphs(
            X,
            kmin = 1,
            kmax = 2,
            prune.method = "none",
            graph.detail = "minimal"
        ),
        "duplicate rows"
    )
    expect_error(
        create.cknn.graph(
            X,
            k.scale = 1,
            radius.search = "all.pairs",
            prune.method = "none",
            graph.detail = "minimal"
        ),
        "duplicate rows"
    )
})
