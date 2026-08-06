test_that("DG6d graph.spectrum computes ordered native eigenpairs", {
    path.graph <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), c(5L))

    spec <- dgraphs::graph.spectrum(path.graph, nev = 3)
    full <- dgraphs::graph.spectrum(path.graph, use.R = TRUE)
    expected <- tail(full$evalues, 3)

    expect_equal(spec$evalues, expected, tolerance = 1e-8, ignore_attr = TRUE)
    expect_true(all(diff(spec$evalues) <= 1e-8))
    expect_equal(dim(spec$evectors), c(6L, 3L))
    expect_equal(
        t(spec$evectors) %*% spec$evectors,
        diag(3),
        tolerance = 1e-8,
        ignore_attr = TRUE
    )
})

test_that("DG6d graph.spectrum handles disconnected graphs and Laplacian output", {
    disconnected.graph <- list(c(2L), c(1L), c(4L), c(3L))

    spec <- dgraphs::graph.spectrum(
        disconnected.graph,
        nev = 3,
        return.Laplacian = TRUE,
        return.dense = TRUE
    )

    expect_equal(spec$evalues, c(2, 0, 0), tolerance = 1e-8)
    expect_equal(
        spec$laplacian,
        matrix(c(1, -1, 0, 0,
                 -1, 1, 0, 0,
                 0, 0, 1, -1,
                 0, 0, -1, 1),
               nrow = 4,
               byrow = TRUE),
        ignore_attr = TRUE
    )
})

test_that("DG6d graph.spectral.embedding is sign-invariant at distance level", {
    path.graph <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), c(5L))
    spec <- dgraphs::graph.spectrum(path.graph, nev = 4)

    emb <- dgraphs::graph.spectral.embedding(spec$evectors, dim = 2, evalues = spec$evalues)
    emb.flipped <- dgraphs::graph.spectral.embedding(
        sweep(spec$evectors, 2, c(-1, 1, -1, 1), `*`),
        dim = 2,
        evalues = spec$evalues
    )

    expect_equal(colnames(emb), c("Dim1", "Dim2"))
    expect_equal(dim(emb), c(6L, 2L))
    expect_equal(
        as.matrix(stats::dist(emb)),
        as.matrix(stats::dist(emb.flipped)),
        tolerance = 1e-8,
        ignore_attr = TRUE
    )
})

test_that("DG6d graph.embedding returns stable layout-shaped matrices", {
    path.graph <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L))

    set.seed(123)
    layout <- dgraphs::graph.embedding(path.graph, dim = 2, method = "fr")
    expect_equal(dim(layout), c(4L, 2L))
    expect_true(all(is.finite(layout)))

    empty <- dgraphs::graph.embedding(list(), dim = 3)
    expect_equal(dim(empty), c(0L, 3L))

    set.seed(321)
    no.edges <- dgraphs::graph.embedding(rep(list(integer(0)), 3), dim = 2)
    expect_equal(dim(no.edges), c(3L, 2L))
    expect_true(all(no.edges >= -1 & no.edges <= 1))
})

test_that("DG6d plot2D.colored.graph prepares plotting on an off-screen device", {
    embedding <- matrix(c(0, 0, 1, 0, 1, 1, 0, 1), ncol = 2, byrow = TRUE)
    graph <- list(c(2L, 4L), c(1L, 3L), c(2L, 4L), c(1L, 3L))
    colors <- c(-1, 0, 1, 2)

    out <- tempfile(fileext = ".pdf")
    grDevices::pdf(out)
    res <- tryCatch(
        {
            oldpar <- graphics::par(c("mar", "xpd"))
            value <- dgraphs::plot2D.colored.graph(
                embedding,
                graph,
                colors,
                vertex.size = 1.2,
                edge.alpha = 0.4,
                add.legend = FALSE
            )
            expect_equal(graphics::par(c("mar", "xpd")), oldpar)
            value
        },
        finally = grDevices::dev.off()
    )

    expect_null(res)
    expect_true(file.exists(out))
    expect_gt(file.info(out)$size, 0)
})
