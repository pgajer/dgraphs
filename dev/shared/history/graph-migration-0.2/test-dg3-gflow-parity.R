.dg3.strip.provenance <- function(x) {
    if (is.list(x)) {
        x$call <- NULL
        x$timing <- NULL
        x$finalization_timing <- NULL
        x <- lapply(x, .dg3.strip.provenance)
    }
    attributes(x)$call <- NULL
    x
}

.dg3.expect.gflow.parity <- function(name, ...) {
    skip_if_not_installed("gflow")
    dgraphs.fun <- getExportedValue("dgraphs", name)
    gflow.fun <- getExportedValue("gflow", name)
    dgraphs.res <- suppressWarnings(dgraphs.fun(...))
    gflow.res <- suppressWarnings(gflow.fun(...))
    expect_equal(
        .dg3.strip.provenance(dgraphs.res),
        .dg3.strip.provenance(gflow.res),
        tolerance = 1e-12
    )
}

.dg3.expect.adaptive.radius.parity <- function(X,
                                               k.scale,
                                               radius.factor = 1.15,
                                               radius.rule = "geomean",
                                               radius.search = "ann",
                                               graph.detail = "full",
                                               connect.components = FALSE) {
    .dg3.expect.gflow.parity(
        "create.rknn.graph",
        X = X,
        type = "adaptive.radius",
        k.scale = k.scale,
        radius.factor = radius.factor,
        radius.rule = radius.rule,
        radius.search = radius.search,
        graph.detail = graph.detail,
        prune.method = "none",
        connect.components = connect.components,
        connect.method = "component.mst",
        return.timing = FALSE
    )
}

test_that("DG3 MkNN constructors match original gflow outputs", {
    X <- matrix(c(
        0.00, 0.00,
        0.35, 0.08,
        0.78, 0.18,
        0.15, 0.73,
        0.55, 0.62,
        0.96, 0.85,
        0.42, 1.05,
        1.18, 0.34
    ), ncol = 2, byrow = TRUE)

    .dg3.expect.gflow.parity(
        "create.mknn.graph",
        X = X,
        k = 3,
        prune.method = "none",
        connect.components = TRUE,
        connect.method = "component.mst"
    )

    .dg3.expect.gflow.parity(
        "create.mknn.graphs",
        X = X,
        kmin = 2,
        kmax = 4,
        compute.full = TRUE,
        pca.dim = NULL,
        verbose = FALSE
    )
})

test_that("DG3 radius-family constructors match original gflow outputs", {
    X <- matrix(c(
        0.00, 0.00,
        0.40, 0.05,
        0.78, 0.08,
        0.12, 0.58,
        0.48, 0.65,
        0.88, 0.72
    ), ncol = 2, byrow = TRUE)

    .dg3.expect.gflow.parity(
        "create.rknn.graph",
        X = X,
        type = "fixed",
        radius = 0.45,
        prune.method = "none",
        connect.components = TRUE,
        connect.method = "component.mst"
    )

    .dg3.expect.gflow.parity(
        "create.rknn.graph",
        X = X,
        type = "adaptive.radius",
        k.scale = 2,
        radius.factor = 1.15,
        radius.rule = "max",
        radius.search = "ann",
        prune.method = "none",
        connect.components = FALSE,
        return.timing = FALSE
    )

    .dg3.expect.gflow.parity(
        "create.rknn.graph",
        X = X,
        type = "fixed",
        radius = 0.45,
        prune.method = "none",
        connect.components = FALSE
    )

    .dg3.expect.gflow.parity(
        "create.cknn.graph",
        X = X,
        k.scale = 2,
        delta = 1.2,
        radius.search = "ann",
        prune.method = "none",
        connect.components = FALSE,
        return.timing = FALSE
    )
})

test_that("DG3 adaptive-radius constructor has broad gflow parity coverage", {
    X.irregular <- matrix(c(
        0.00, 0.00,
        0.40, 0.05,
        0.78, 0.08,
        0.12, 0.58,
        0.48, 0.65,
        0.88, 0.72,
        1.12, 0.32,
        0.25, 1.02
    ), ncol = 2, byrow = TRUE)

    for (rule in c("max", "min", "geomean")) {
        .dg3.expect.adaptive.radius.parity(
            X = X.irregular,
            k.scale = 3,
            radius.factor = if (identical(rule, "min")) 1.6 else 1.25,
            radius.rule = rule,
            radius.search = "ann"
        )
    }

    .dg3.expect.adaptive.radius.parity(
        X = X.irregular,
        k.scale = 3,
        radius.factor = 1.25,
        radius.rule = "geomean",
        radius.search = "all.pairs"
    )

    X.grid <- as.matrix(expand.grid(
        x = seq(0, 1, length.out = 4),
        y = seq(0, 1, length.out = 4)
    ))
    .dg3.expect.adaptive.radius.parity(
        X = X.grid,
        k.scale = 4,
        radius.factor = 1.25,
        radius.rule = "geomean",
        radius.search = "ann"
    )

    set.seed(303)
    X.high.dim <- matrix(rnorm(40 * 5), nrow = 40, ncol = 5) %*%
        diag(c(1, 0.5, 0.25, 0.1, 0.05))
    .dg3.expect.adaptive.radius.parity(
        X = X.high.dim,
        k.scale = 7,
        radius.factor = 1.25,
        radius.rule = "max",
        radius.search = "ann"
    )

    .dg3.expect.adaptive.radius.parity(
        X = X.irregular,
        k.scale = 3,
        radius.factor = 1.2,
        radius.rule = "geomean",
        radius.search = "ann",
        graph.detail = "minimal"
    )

    X.two.components <- rbind(
        matrix(c(
            0.00, 0.00,
            0.10, 0.02,
            0.18, 0.04,
            0.25, 0.01
        ), ncol = 2, byrow = TRUE),
        matrix(c(
            3.00, 3.00,
            3.08, 3.02,
            3.20, 3.04,
            3.28, 3.01
        ), ncol = 2, byrow = TRUE)
    )
    .dg3.expect.adaptive.radius.parity(
        X = X.two.components,
        k.scale = 1,
        radius.factor = 0.7,
        radius.rule = "geomean",
        radius.search = "ann",
        connect.components = TRUE
    )

    .dg3.expect.adaptive.radius.parity(
        X = X.irregular,
        k.scale = 3,
        radius.factor = 1.25,
        radius.rule = "geomean",
        radius.search = "ann",
        connect.components = FALSE
    )
})

test_that("DG3 SkNN and CMST constructors match original gflow outputs", {
    X <- matrix(c(
        0.00, 0.00,
        0.30, 0.12,
        0.65, 0.05,
        0.08, 0.54,
        0.45, 0.76,
        0.84, 0.68,
        1.10, 0.32
    ), ncol = 2, byrow = TRUE)

    .dg3.expect.gflow.parity(
        "create.sknn.graph",
        X = X,
        k = 2,
        prune.method = "none",
        connect.components = TRUE,
        connect.method = "component.mst",
        neighbor.method = "ann"
    )

    .dg3.expect.gflow.parity(
        "create.cmst.graph",
        X = X,
        q.thld = 0.75,
        pca.dim = NULL,
        variance.explained = NULL,
        verbose = FALSE
    )
})
