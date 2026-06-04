test_that("graph constructor bridges create simple graphs through gflow", {
    skip_if_not_installed("gflow")

    set.seed(1)
    X <- matrix(runif(40), ncol = 2)

    graph <- create.mknn.graph(X, k = 3, connect.components = TRUE)
    expect_true(is.list(graph))
    expect_equal(length(graph$adj_list), nrow(X))
    expect_equal(length(graph$weight_list), nrow(X))

    components <- graph.connected.components(graph$adj_list)
    expect_false(is.null(components))
})

test_that("ANN headers are vendored for native graph migration", {
    ann.header <- system.file("include", "ANN", "ANN.h", package = "dgraphs")
    expect_true(file.exists(ann.header))
})

test_that("DG1 pure-R graph constructors are self-hosted", {
    complete <- create.complete.graph(4)
    expect_equal(length(complete), 4)
    expect_equal(sort(complete[[1]]), 2:4)

    empty <- create.empty.graph(3)
    expect_equal(vapply(empty, length, integer(1)), c(0L, 0L, 0L))

    joined <- join.graphs(list(2L, 1L), list(2L, 1L), 2, 1)
    expect_equal(length(joined), 4)
    expect_true(3L %in% joined[[2]])
    expect_true(2L %in% joined[[3]])

    star <- create.star.graph(c(2, 3, 1))
    expect_true(length(star) > 1)
    expect_true(length(star[[1]]) >= 3)
})

test_that("DG1 graph utilities run without native gflow calls", {
    adj <- list(c(2L, 3L), c(1L, 4L), c(1L), c(2L), integer(0))
    weights <- list(c(1, 2), c(1, 3), 2, 3, numeric(0))

    expect_equal(graph.connected.components(adj), c(1L, 1L, 1L, 1L, 2L))
    expect_equal(compute.graph.distance(i = 1, j = 4,
                                        adj.list = adj,
                                        edge.lengths = weights), 4)

    X <- matrix(c(0, 0, 1, 0, 1, 1), ncol = 2, byrow = TRUE)
    E <- matrix(c(1, 2, 2, 3), ncol = 2, byrow = TRUE)
    A <- graph.adj.mat(X, E)
    expect_equal(A[1, 2], 1)
    expect_equal(A[2, 3], 1)
    expect_equal(A[1, 3], 0)

    ig <- adjlist.to.igraph(adj)
    expect_equal(igraph::vcount(ig), 5)
    expect_equal(igraph::ecount(ig), 3)

    diam <- compute.graph.diameter(adj, weights)
    expect_equal(diam$diameter, 6)
})
