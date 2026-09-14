test_that("DG6b offset chain graph fixture runs self-hosted", {
    chain <- dgraphs::create.graph("chain", n = 4, labels = 11:14)

    expect_equal(graph.order(chain), 4L)
    expect_equal(names(graph.adjacency(chain)), as.character(11:14))
    expect_equal(graph.adjacency(chain)[["11"]], 2L)
    expect_equal(graph.adjacency(chain)[["12"]], c(1L, 3L))
    expect_equal(graph.adjacency(chain)[["13"]], c(2L, 4L))
    expect_equal(graph.adjacency(chain)[["14"]], 3L)
})

test_that("DG6b offset chain graph fixture handles small edge cases", {
    chain <- dgraphs::create.graph("chain", n = 2, labels = 1:2)

    expect_equal(names(graph.adjacency(chain)), c("1", "2"))
    expect_equal(graph.adjacency(chain)[["1"]], 2)
    expect_equal(graph.adjacency(chain)[["2"]], 1L)

    expect_error(
        dgraphs::create.graph("chain", n = 1),
        "'n' must be an integer >= 2"
    )
})
