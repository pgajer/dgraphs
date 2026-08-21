.dg6d.ensure.gflow.parity.source <- function() {
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

.dg6d.gflow.function <- function(.fname) {
    .dg6d.ensure.gflow.parity.source()
    ns <- asNamespace("gflow")
    if (exists(.fname, envir = ns, mode = "function", inherits = FALSE)) {
        return(get(.fname, envir = ns, mode = "function", inherits = FALSE))
    }
    getExportedValue("gflow", .fname)
}

.dg6d.projection <- function(x) {
    x %*% t(x)
}

.dg6d.pairwise.distances <- function(x) {
    as.matrix(stats::dist(x))
}

.dg6d.expect.spectrum.parity <- function(graph,
                                         nev = 3,
                                         return.Laplacian = FALSE,
                                         return.dense = FALSE,
                                         tolerance = 1e-8) {
    dgraphs.fun <- getExportedValue("dgraphs", "graph.spectrum")
    gflow.fun <- .dg6d.gflow.function("graph.spectrum")

    d.res <- dgraphs.fun(
        graph,
        nev = nev,
        use.R = FALSE,
        return.Laplacian = return.Laplacian,
        return.dense = return.dense
    )
    g.res <- gflow.fun(
        graph,
        nev = nev,
        use.R = FALSE,
        return.Laplacian = return.Laplacian,
        return.dense = return.dense
    )

    expect_equal(d.res$evalues, g.res$evalues, tolerance = tolerance)
    expect_true(all(diff(d.res$evalues) <= tolerance))
    expect_equal(
        .dg6d.projection(d.res$evectors),
        .dg6d.projection(g.res$evectors),
        tolerance = tolerance,
        ignore_attr = TRUE
    )
    if (return.Laplacian) {
        expect_equal(
            as.matrix(d.res$laplacian),
            as.matrix(g.res$laplacian),
            tolerance = tolerance,
            ignore_attr = TRUE
        )
    }
}

test_that("DG6d graph.spectrum matches gflow on path, cycle, and disconnected graphs", {
    path.graph <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), c(5L))
    cycle.graph <- list(c(2L, 6L), c(1L, 3L), c(2L, 4L),
                        c(3L, 5L), c(4L, 6L), c(5L, 1L))
    disconnected.graph <- list(c(2L), c(1L), c(4L), c(3L))

    .dg6d.expect.spectrum.parity(path.graph, nev = 3)
    .dg6d.expect.spectrum.parity(cycle.graph, nev = 3)
    .dg6d.expect.spectrum.parity(disconnected.graph, nev = 3,
                                 return.Laplacian = TRUE,
                                 return.dense = TRUE)
})

test_that("DG6d graph.spectral.embedding matches gflow up to sign", {
    path.graph <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), c(5L))
    d.spec <- dgraphs::graph.spectrum(path.graph, nev = 4)
    g.spec <- .dg6d.gflow.function("graph.spectrum")(path.graph, nev = 4)

    d.emb <- dgraphs::graph.spectral.embedding(d.spec$evectors, dim = 2,
                                               evalues = d.spec$evalues)
    g.emb <- .dg6d.gflow.function("graph.spectral.embedding")(
        g.spec$evectors,
        dim = 2,
        evalues = g.spec$evalues
    )

    expect_equal(colnames(d.emb), colnames(g.emb))
    expect_equal(
        .dg6d.pairwise.distances(d.emb),
        .dg6d.pairwise.distances(g.emb),
        tolerance = 1e-8,
        ignore_attr = TRUE
    )
})

test_that("DG6d graph.embedding matches gflow layouts with fixed seeds", {
    path.graph <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), c(5L))
    cycle.graph <- list(c(2L, 6L), c(1L, 3L), c(2L, 4L),
                        c(3L, 5L), c(4L, 6L), c(5L, 1L))
    disconnected.graph <- list(c(2L), c(1L), c(4L), c(3L))

    gflow.embedding <- .dg6d.gflow.function("graph.embedding")

    set.seed(101)
    d.path <- dgraphs::graph.embedding(path.graph, dim = 2, method = "fr")
    set.seed(101)
    g.path <- gflow.embedding(path.graph, dim = 2, method = "fr")
    expect_equal(.dg6d.pairwise.distances(d.path),
                 .dg6d.pairwise.distances(g.path),
                 tolerance = 1e-8,
                 ignore_attr = TRUE)

    weights <- lapply(cycle.graph, function(x) seq_along(x) + 1)
    set.seed(202)
    d.cycle <- dgraphs::graph.embedding(cycle.graph, weights, dim = 2, method = "kk")
    set.seed(202)
    g.cycle <- gflow.embedding(cycle.graph, weights, dim = 2, method = "kk")
    expect_equal(.dg6d.pairwise.distances(d.cycle),
                 .dg6d.pairwise.distances(g.cycle),
                 tolerance = 1e-8,
                 ignore_attr = TRUE)

    set.seed(303)
    d.disconnected <- dgraphs::graph.embedding(disconnected.graph, dim = 2, method = "fr")
    set.seed(303)
    g.disconnected <- gflow.embedding(disconnected.graph, dim = 2, method = "fr")
    expect_equal(.dg6d.pairwise.distances(d.disconnected),
                 .dg6d.pairwise.distances(g.disconnected),
                 tolerance = 1e-8,
                 ignore_attr = TRUE)
})

test_that("DG6d plot2D.colored.graph renders without retaining gflow par side effects", {
    embedding <- matrix(c(0, 0, 1, 0, 1, 1, 0, 1), ncol = 2, byrow = TRUE)
    graph <- list(c(2L, 4L), c(1L, 3L), c(2L, 4L), c(1L, 3L))
    colors <- c(-1, 0, 1, 2)

    render.plot <- function(plot.function, file) {
        grDevices::pdf(file)
        on.exit(grDevices::dev.off(), add = TRUE)
        par.before <- graphics::par(no.readonly = TRUE)
        result <- plot.function(
            embedding,
            graph,
            colors,
            add.legend = FALSE
        )
        par.after <- graphics::par(no.readonly = TRUE)
        list(result = result, par.before = par.before, par.after = par.after)
    }

    d.file <- tempfile(fileext = ".pdf")
    d.render <- render.plot(dgraphs::plot2D.colored.graph, d.file)
    g.file <- tempfile(fileext = ".pdf")
    g.render <- render.plot(
        .dg6d.gflow.function("plot2D.colored.graph"),
        g.file
    )

    expect_null(d.render$result)
    expect_equal(
        d.render$par.after[c("mar", "xpd")],
        d.render$par.before[c("mar", "xpd")]
    )

    # The pinned gflow function returns the old xpd value from its final par()
    # call and leaves its changed margins in place. dgraphs intentionally does
    # neither, in accordance with CRAN's graphics-state policy.
    expect_equal(g.render$result, list(xpd = FALSE))
    expect_false(identical(g.render$par.after$mar, g.render$par.before$mar))

    expect_true(file.exists(d.file))
    expect_true(file.exists(g.file))
    expect_gt(file.info(d.file)$size, 0)
    expect_gt(file.info(g.file)$size, 0)
})
