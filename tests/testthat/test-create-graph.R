test_that("standard graph types have their defining topologies", {
    expect_equal(graph.order(create.graph("empty", n = 0)), 0L)
    expect_equal(nrow(graph.edges(create.graph("empty", n = 5))), 0L)
    expect_equal(nrow(graph.edges(create.graph("complete", n = 5))), 10L)
    expect_equal(lengths(graph.adjacency(create.graph("cycle", n = 5))), rep(2L, 5))
    bipartite <- create.graph("complete_bipartite", sizes = c(2, 3))
    edges <- graph.edges(bipartite)
    expect_equal(nrow(edges), 6L)
    expect_true(all(edges$from <= 2 & edges$to >= 3))
    star <- create.graph("star", arms = c(2, 3, 1))
    expect_equal(graph.order(star), 7L)
    expect_equal(graph.adjacency(star)[[1]], c(2L, 4L, 7L))
    expect_equal(graph.geodesic.distances(star, distance = "hop")[1, ], c(0, 1, 2, 1, 2, 3, 1))
    for (g in list(bipartite, star, create.graph("cycle", n = 3),
                   create.graph("empty", n = 3), create.graph("complete", n = 3))) {
        expect_s3_class(g, "dgraph")
        expect_null(graph.lengths(g))
        expect_identical(graph.stages(g), "final")
    }
})

test_that("chain span and coordinate sorting have explicit semantics", {
    g <- create.graph("chain", n = 6, span = 2)
    expect_equal(lengths(graph.adjacency(g)), c(2L, 3L, 4L, 4L, 3L, 2L))
    expect_true(all(unlist(graph.lengths(g)) == 1))
    g <- create.graph("chain", x = c(3, 1, 1, 8), y = letters[1:4],
                      labels = c("three", "one-a", "one-b", "eight"))
    expect_equal(g$metadata$order, c(2L, 3L, 1L, 4L))
    expect_equal(g$metadata$x.sorted, c(1, 1, 3, 8))
    expect_equal(g$metadata$y.sorted, c("b", "c", "a", "d"))
    expect_equal(names(graph.adjacency(g)), c("one-a", "one-b", "three", "eight"))
    expect_equal(graph.edges(g)$length, c(0, 2, 5))
    expect_equal(graph.geodesic.distances(g)[1, 4], 7)
    expect_equal(graph.edges(create.graph("chain", n = 4, span = 3))[, 1:2],
                 graph.edges(create.graph("complete", n = 4)))
})

test_that("labels work for every type without changing vertex indices", {
    cases <- list(empty = list(n = 4), complete = list(n = 4), chain = list(n = 4),
                  cycle = list(n = 4), complete_bipartite = list(sizes = c(2, 2)),
                  star = list(arms = c(1, 2)), circle = list(n = 4, sampling = "uniform"),
                  random = list(n = 4, mean.degree = 2, seed = 7))
    for (type in names(cases)) {
        g <- do.call(create.graph, c(list(type = type, labels = 101:104), cases[[type]]))
        expect_identical(g$metadata$labels, 101:104)
        expect_identical(names(graph.adjacency(g)), as.character(101:104))
        expect_true(all(unlist(graph.adjacency(g)) %in% 1:4))
        expect_identical(g$metadata$type, type)
    }
})

test_that("circle lengths agree with independent geometry", {
    arc <- create.graph("circle", n = 4, sampling = "uniform")
    chord <- create.graph("circle", n = 4, sampling = "uniform", edge.length = "chord")
    expect_equal(graph.edges(arc)$length, rep(pi / 2, 4))
    expect_equal(graph.edges(chord)$length, rep(sqrt(2), 4))
    expect_equal(rowSums(chord$metadata$coordinates^2), rep(1, 4))
    sparse <- create.graph("circle", n = 3, seed = 1)
    angles <- sparse$metadata$angles
    wrap.gap <- 2 * pi - (max(angles) - min(angles))
    expect_gt(wrap.gap, pi)
    expect_equal(graph.lengths(sparse)[[1]][2], 2 * pi - wrap.gap)
    for (metric in c("arc", "chord")) {
        g <- create.graph("circle", n = 9, seed = 12, edge.length = metric)
        e <- graph.edges(g); xy <- g$metadata$coordinates
        delta <- xy[e$from, , drop = FALSE] - xy[e$to, , drop = FALSE]
        expected <- sqrt(rowSums(delta^2))
        if (metric == "arc") expected <- 2 * asin(expected / 2)
        expect_equal(e$length, expected)
        expect_true(all(diff(g$metadata$angles) >= 0))
    }
})

test_that("random graphs respect edge budgets, connectivity and reciprocal lengths", {
    for (connected in c(TRUE, FALSE)) {
        g <- create.graph("random", n = 8, mean.degree = 2.8, connected = connected, seed = 12)
        e <- graph.edges(g)
        expect_equal(nrow(e), floor(8 * 2.8 / 2))
        expect_equal(g$metadata$realized.mean.degree, 2 * nrow(e) / 8)
        expect_true(all(e$length >= 0.5 & e$length <= 1.5))
        expect_equal(graph.geodesic.distances(g), t(graph.geodesic.distances(g)))
        if (connected) expect_equal(length(unique(graph.connected.components(g))), 1L)
    }
    expect_equal(nrow(graph.edges(create.graph("random", n = 6, mean.degree = 5, seed = 1))), 15L)
    expect_equal(graph.order(create.graph("random", n = 1, mean.degree = 0)), 1L)
    expect_equal(nrow(graph.edges(create.graph("random", n = 5, mean.degree = 0, connected = FALSE))), 0L)
    expect_error(create.graph("random", n = 5, mean.degree = 1), "connectivity is impossible")
})

test_that("seeded graph generation restores RNG state and current-stream mode advances it", {
    set.seed(193)
    saved <- .Random.seed
    for (type in c("circle", "random")) {
        args <- if (type == "random") list(mean.degree = 2) else list()
        g <- do.call(create.graph, c(list(type = type, n = 8, seed = 42), args))
        expect_identical(.Random.seed, saved)
        expect_identical(do.call(create.graph, c(list(type = type, n = 8, seed = 42), args)), g)
        do.call(create.graph, c(list(type = type, n = 8), args))
        expect_false(identical(.Random.seed, saved))
        assign(".Random.seed", saved, envir = .GlobalEnv)
    }
    create.graph("circle", n = 4, sampling = "uniform")
    expect_identical(.Random.seed, saved)
    on.exit(assign(".Random.seed", saved, envir = .GlobalEnv), add = TRUE)
    rm(".Random.seed", envir = .GlobalEnv)
    create.graph("random", n = 4, mean.degree = 2, seed = 5)
    expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
})

test_that("type-specific arguments fail clearly instead of being ignored", {
    expect_error(create.graph(), "missing")
    expect_error(create.graph("comp", n = 3), "must be one of")
    expect_error(create.graph("complete", n = 3, span = 1), "Unsupported")
    expect_error(create.graph("chain", n = 3, sp = 1), "Unsupported")
    expect_error(create.graph("chain", n = 3, 1), "unique, nonempty names")
    expect_error(create.graph("chain", n = 3, span = 1, span = 2), "unique, nonempty names")
    expect_error(create.graph("chain", n = 3, x = 1:4), "conflicts")
    expect_error(create.graph("complete_bipartite", n = 4, sizes = c(2, 3)), "conflicts")
    expect_error(create.graph("star", n = 4, arms = c(2, 3)), "conflicts")
    for (n in list(NULL, NA, Inf, 1.5, "3", c(3, 4), -1))
        expect_error(create.graph("complete", n = n), "'n' must be an integer")
    expect_error(create.graph("chain", n = 4, span = 4), "less than n")
    expect_error(create.graph("chain", n = 4, span = 1.5), "'span'")
    expect_error(create.graph("chain", x = c(1, NA)), "finite numeric vector")
    expect_error(create.graph("chain", n = 4, y = 1:4), "requires 'x'")
    expect_error(create.graph("star", arms = c(1, 1.5)), "positive integers")
    expect_error(create.graph("complete_bipartite", sizes = c(1, 2, 3)), "exactly two")
    expect_error(create.graph("circle", n = 4, sampling = "rand"), "'sampling'")
    expect_error(create.graph("circle", n = 4, edge.length = "weight"), "'edge.length'")
    expect_error(create.graph("circle", n = 4, seed = -1), "'seed'")
    expect_error(create.graph("random", n = 4, mean.degree = 4), "'mean.degree'")
    expect_error(create.graph("random", n = 4, mean.degree = 2, connected = 1), "TRUE or FALSE")
    for (labels in list(c("a", "a", "b"), c("a", "b"), c("a", "b", NA), c(1, 2, Inf)))
        expect_error(create.graph("empty", n = 3, labels = labels), "'labels'")
})

test_that("retired fixture interfaces are absent even from the namespace", {
    old <- c("create.empty.graph", "create.complete.graph", "create.chain.graph",
             "create.chain.graph.with.offset", "create.bi.kNN.chain.graph",
             "create.circular.graph", "create.bipartite.graph", "create.star.graph",
             "create.random.graph", "generate.circle.graph")
    expect_false(any(old %in% getNamespaceExports("dgraphs")))
    expect_false(any(vapply(old, exists, logical(1), envir = asNamespace("dgraphs"), inherits = FALSE)))
})
