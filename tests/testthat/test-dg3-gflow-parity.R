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
        "create.radius.graph",
        X = X,
        radius = 0.45,
        prune.method = "none",
        connect.components = FALSE
    )

    .dg3.expect.gflow.parity(
        "create.adaptive.radius.graph",
        X = X,
        k.scale = 2,
        radius.factor = 1.15,
        radius.rule = "min",
        radius.search = "ann",
        prune.method = "none",
        connect.components = FALSE,
        return.timing = FALSE
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
