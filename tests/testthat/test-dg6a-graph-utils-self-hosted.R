test_that("DG6a utilities run self-hosted on edge cases", {
    expect_true(dgraphs::compare.adj.lists(list(integer(0)), list(integer(0))))
    expect_equal(dgraphs::count.edges(list()), 0)
    singleton.mat <- dgraphs::convert.adjacency.list.to.adjacency.matrix(list(integer(0)))
    expect_equal(singleton.mat, matrix(0, nrow = 1, ncol = 1))
    disconnected.adj <- list(c(2L), c(1L), integer(0))
    disconnected.weights <- list(1, 1, numeric(0))
    disk <- dgraphs::geodesic.disk(disconnected.adj, disconnected.weights, center.vertex = 1L, n = 5L)
    expect_equal(disk$vertices, c(1L, 2L))
    expect_equal(disk$radius, 1)
    expect_error(dgraphs::extract.trajectory.edge.lengths(c(1L, 3L), disconnected.adj, disconnected.weights),
        "not found")
    weights <- graph.edges(dgraph(list(c(2L, 3L), c(1L), c(1L)), list(c(0.5, 0.7), 0.5, 0.7)))$length
    expect_equal(weights, c(0.5, 0.7))
    parallel.weights <- graph.edges(dgraph(list(c(2L, 3L), c(1L), c(1L)), list(c(0.5, 0.7), 0.5, 0.7)))$length
    expect_equal(parallel.weights, weights)
    named.S <- matrix(seq_len(6), nrow = 3)
    rownames(named.S) <- c("a", "b", "c")
    graph <- dgraph(list(2L, c(1L, 3L), 2L), list(1, c(1, 2), 2))
    sub <- create.subgraph(graph, vertices = match(c("a", "c"), rownames(named.S)))
    expect_equal(unname(graph.adjacency(sub)), list(integer(), integer()))
    expect_equal(sub$metadata$original.vertices, c(1L, 3L))
})
