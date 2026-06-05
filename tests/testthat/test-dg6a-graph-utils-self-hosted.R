test_that("DG6a utilities run self-hosted on edge cases", {
    expect_true(dgraphs::compare.adj.lists(list(integer(0)), list(integer(0))))
    expect_equal(dgraphs::count.edges(list()), 0)

    singleton.mat <- dgraphs::convert.adjacency.list.to.adjacency.matrix(
        list(integer(0))
    )
    expect_equal(singleton.mat, matrix(0, nrow = 1, ncol = 1))

    disconnected.adj <- list(c(2L), c(1L), integer(0))
    disconnected.weights <- list(1, 1, numeric(0))
    disk <- dgraphs::geodesic.disk(
        disconnected.adj,
        disconnected.weights,
        center.vertex = 1L,
        n = 5L
    )
    expect_equal(disk$vertices, c(1L, 2L))
    expect_equal(disk$radius, 1)

    expect_error(
        dgraphs::extract.trajectory.edge.lengths(
            c(1L, 3L),
            disconnected.adj,
            disconnected.weights
        ),
        "not found"
    )

    weights <- dgraphs::get.edge.weights(
        list(c(2L, 3L), c(1L), c(1L)),
        list(c(0.5, 0.7), 0.5, 0.7),
        n.cores = 1
    )
    expect_equal(weights, c(0.5, 0.7))

    named.S <- matrix(seq_len(6), nrow = 3)
    rownames(named.S) <- c("a", "b", "c")
    sub <- dgraphs::create.subgraph(
        list(adj_list = list(c(2L), c(1L, 3L), c(2L)),
             dist_list = list(1, c(1, 2), 2)),
        ids = c("a", "c"),
        S = named.S
    )
    expect_equal(sub$adj_list, list("1" = integer(0), "3" = integer(0)))
    expect_equal(names(sub$adj_list), c("1", "3"))
})
