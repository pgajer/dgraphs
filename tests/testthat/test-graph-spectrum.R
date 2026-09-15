test_that("both backends return the requested smallest positive chain modes", {
    graph <- create.graph("chain", 8)
    expected <- 2 - 2 * cos(pi * (1:7) / 8)
    for (use.R in c(FALSE, TRUE)) for (nev in c(1L, 3L, 7L)) {
        spectrum <- graph.spectrum(graph, nev, use.R = use.R,
                                   return.Laplacian = TRUE, return.dense = TRUE)
        expect_s3_class(spectrum, "graph_spectrum")
        expect_equal(spectrum$evalues, expected[seq_len(nev)], tolerance = 1e-9)
        expect_equal(dim(spectrum$evectors), c(8L, nev))
        expect_identical(spectrum$nullity, 1L)
        expect_equal(length(unique(spectrum$components)), 1L)
        expect_equal(spectrum$tolerance, 100 * .Machine$double.eps * 4)
        expect_true(is.matrix(spectrum$laplacian))
        V <- spectrum$evectors
        expect_equal(t(V) %*% V, diag(nev), tolerance = 1e-9)
        expect_equal(spectrum$laplacian %*% V,
                     sweep(V, 2, spectrum$evalues, "*"), tolerance = 1e-9)
        expect_equal(colSums(V), rep(0, nev), tolerance = 1e-9)
    }
    expect_equal(graph.spectrum(graph)$evalues, expected, tolerance = 1e-9)
})

test_that("component nullity excludes every zero mode including isolates", {
    graph <- dgraph(list(2L, 1L, 4L, 3L, integer()))
    L <- matrix(0, 5, 5)
    L[1:2, 1:2] <- L[3:4, 3:4] <- matrix(c(1, -1, -1, 1), 2)
    for (use.R in c(FALSE, TRUE)) {
        spectrum <- graph.spectrum(graph, use.R = use.R,
                                   return.Laplacian = TRUE, return.dense = TRUE)
        expect_equal(spectrum$evalues, c(2, 2), tolerance = 1e-9)
        expect_equal(dim(spectrum$evectors), c(5L, 2L))
        expect_equal(spectrum$components, c(1L, 1L, 3L, 3L, 5L))
        expect_identical(spectrum$nullity, 3L)
        expect_equal(spectrum$laplacian, L)
        expect_equal(spectrum$evectors[5, ], c(0, 0), tolerance = 1e-9)
        expect_error(graph.spectrum(graph, nev = 3, use.R = use.R), "n - nullity")
        expect_error(graph.spectral.embedding(spectrum, 1), "component by component")
        first <- create.subgraph(graph, which(spectrum$components == 1))
        embedded <- graph.spectral.embedding(graph.spectrum(first), 1)
        expect_equal(dim(embedded), c(2L, 1L))
    }
})

test_that("edgeless, singleton, empty and zero-count spectra retain dimensions", {
    for (use.R in c(FALSE, TRUE)) for (n in c(0L, 1L, 4L)) {
        graph <- create.graph("empty", n)
        s <- graph.spectrum(graph, use.R = use.R,
                            return.Laplacian = TRUE, return.dense = TRUE)
        expect_identical(s$evalues, numeric())
        expect_equal(dim(s$evectors), c(n, 0L))
        expect_identical(s$nullity, n)
        expect_equal(s$laplacian, matrix(0, n, n))
        expect_error(graph.spectrum(graph, 1, use.R = use.R), "n - nullity")
        expect_error(graph.spectral.embedding(s, 1),
                     "positive eigenpairs|component by component")
    }
    for (use.R in c(FALSE, TRUE)) {
        s <- graph.spectrum(create.graph("chain", 5), 0, use.R = use.R)
        expect_identical(s$evalues, numeric())
        expect_equal(dim(s$evectors), c(5L, 0L))
        expect_null(s$laplacian)
    }
})

test_that("sparse and dense Laplacians agree across backends", {
    skip_if_not_installed("Matrix")
    for (n in c(0L, 1L, 5L)) for (use.R in c(FALSE, TRUE)) {
        graph <- if (n < 2) create.graph("empty", n) else create.graph("chain", n)
        sparse <- graph.spectrum(graph, use.R = use.R, return.Laplacian = TRUE)
        dense <- graph.spectrum(graph, use.R = use.R,
                                return.Laplacian = TRUE, return.dense = TRUE)
        expect_s4_class(sparse$laplacian, "sparseMatrix")
        expect_true(is.matrix(dense$laplacian))
        expect_equal(as.matrix(sparse$laplacian), dense$laplacian)
        expect_equal(sparse$evalues, dense$evalues)
    }
    weighted <- dgraph(list(2L, c(1L, 3L), 2L), list(0, c(0, 100), 100))
    expect_equal(graph.spectrum(weighted)$evalues,
                 graph.spectrum(create.graph("chain", 3))$evalues)
})

test_that("repeated eigenvalues are compared as eigenspaces", {
    graphs <- list(create.graph("cycle", 8), create.graph("complete", 6),
                   create.graph("star", arms = rep(1, 6)))
    counts <- c(2L, 5L, 5L) # Include complete repeated eigenspaces.
    expected <- list(rep(2 - 2 * cos(2*pi/8), 2), rep(6, 5), rep(1, 5))
    for (i in seq_along(graphs)) {
        a <- graph.spectrum(graphs[[i]], counts[i])
        b <- graph.spectrum(graphs[[i]], counts[i], use.R = TRUE)
        expect_equal(a$evalues, expected[[i]], tolerance = 1e-9)
        expect_equal(a$evalues, b$evalues, tolerance = 1e-9)
        expect_equal(tcrossprod(a$evectors), tcrossprod(b$evectors), tolerance = 1e-9)
        expect_equal(as.matrix(dist(graph.spectral.embedding(a, counts[i]))),
                     as.matrix(dist(graph.spectral.embedding(b, counts[i]))), tolerance = 1e-9)
    }
})

test_that("embedding selects all requested positive modes with explicit scaling", {
    graph <- create.graph("chain", 6)
    a <- graph.spectrum(graph)
    b <- graph.spectrum(graph, use.R = TRUE)
    for (scale in c("none", "inverse.sqrt")) {
        emb <- graph.spectral.embedding(a, 5, scale = scale)
        expect_equal(dim(emb), c(6L, 5L))
        expect_equal(colnames(emb), paste0("Dim", 1:5))
        expect_equal(as.matrix(dist(emb)),
                     as.matrix(dist(graph.spectral.embedding(b, 5, scale = scale))), tolerance = 1e-9)
        flipped <- a
        flipped$evectors <- sweep(a$evectors, 2, c(-1, 1, -1, 1, -1), "*")
        expect_equal(as.matrix(dist(emb)),
                     as.matrix(dist(graph.spectral.embedding(flipped, 5, scale = scale))), tolerance = 1e-9)
    }
    expect_equal(unname(graph.spectral.embedding(a, 2)), a$evectors[, 1:2])
    resistance <- as.matrix(dist(graph.spectral.embedding(a, 5, "inverse.sqrt")))^2
    # Unit-resistance edges in a tree add in series along the unique path.
    expect_equal(unname(resistance), abs(outer(1:6, 1:6, "-")), tolerance = 1e-9)
})

test_that("spectrum counts, flags, tolerances and embedding requests are validated", {
    graph <- create.graph("chain", 4)
    for (nev in list(-1, 4, 1.5, NA_real_, NaN, Inf, numeric(), c(1, 2), TRUE, "2", 1i))
        expect_error(graph.spectrum(graph, nev), "nev must be an integer")
    for (tol in list(0, -1, NA_real_, NaN, Inf, numeric(), c(1, 2), TRUE, "x", 1i))
        expect_error(graph.spectrum(graph, tol = tol), "tol must be")
    for (name in c("use.R", "return.Laplacian", "return.dense"))
        for (value in list(NA, 1, "TRUE", logical(), c(TRUE, FALSE)))
            expect_error(do.call(graph.spectrum, c(list(graph = graph), setNames(list(value), name))),
                         "must be TRUE or FALSE")
    for (use.R in c(FALSE, TRUE))
        expect_error(graph.spectrum(graph, tol = 10, use.R = use.R), "zero modes do not match")
    s <- graph.spectrum(graph, 2)
    for (dim in list(0, -1, 3, 1.5, NA_real_, NaN, Inf, numeric(), c(1, 2), TRUE, "2", 1i))
        expect_error(graph.spectral.embedding(s, dim), "dim must be")
    invalid <- s; invalid$components <- integer()
    expect_error(graph.spectral.embedding(invalid, 1), "Invalid spectrum")
    expect_error(graph.spectral.embedding(s$evectors, 2), "graph_spectrum object")
    expect_error(graph.spectral.embedding(s, 2, scale = "reciprocal"), "arg")
    for (value in list(c(0, 1), c(1, NA), c(2, 1), 1)) {
        invalid <- s; invalid$evalues <- value
        expect_error(graph.spectral.embedding(invalid, 1), "Invalid spectrum")
    }
})
