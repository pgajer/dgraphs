test_that("dgraphs 0.2.0 removes retired public entry points", {
    removed <- c(
        "adjlist.to.igraph",
        "calculate.edit.distances",
        "cpp.create.rknn.graphs",
        "create.adaptive.radius.graph",
        "create.distance.plot",
        "create.radius.graph",
        "dist.to.knn",
        "euclidean.distance",
        "graph.adj.mat",
        "graph.edit.distance",
        "load.graph.data"
    )

    expect_false(any(removed %in% getNamespaceExports("dgraphs")))
    still.defined <- vapply(
        removed,
        exists,
        logical(1),
        envir = asNamespace("dgraphs"),
        inherits = FALSE
    )
    expect_false(any(still.defined))
})

test_that("as_igraph replaces bare adjacency-list conversion", {
    adjacency <- list(a = c(2L, 3L), b = 1L, c = 1L, isolated = integer(0))
    weights <- list(c(1, 2), 1, 2, numeric(0))

    graph <- as_igraph(adjacency, weight.list = weights)

    expect_s3_class(graph, "igraph")
    expect_equal(igraph::vcount(graph), 4L)
    expect_equal(igraph::ecount(graph), 2L)
    expect_equal(igraph::V(graph)$name, names(adjacency))
    expect_equal(igraph::E(graph)$weight, c(1, 2))
})

test_that("as_igraph only accepts an external weight list for bare adjacency", {
    X <- matrix(c(0, 0, 1, 0, 2, 0), ncol = 2, byrow = TRUE)
    graph <- create.mknn.graph(X, k = 2)

    expect_error(
        as_igraph(graph, weight.list = graph$weight_list),
        "bare adjacency list"
    )
})
