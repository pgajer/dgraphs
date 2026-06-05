test_that("DG6b offset chain graph fixture runs self-hosted", {
    chain <- dgraphs::create.chain.graph.with.offset(4, offset = 10)

    expect_equal(length(chain), 4L)
    expect_equal(names(chain), as.character(11:14))
    expect_equal(chain[["11"]], 12)
    expect_equal(chain[["12"]], c(11, 13))
    expect_equal(chain[["13"]], c(12, 14))
    expect_equal(chain[["14"]], 13L)
})

test_that("DG6b offset chain graph fixture handles small edge cases", {
    chain <- dgraphs::create.chain.graph.with.offset(2)

    expect_equal(names(chain), c("1", "2"))
    expect_equal(chain[["1"]], 2)
    expect_equal(chain[["2"]], 1L)

    expect_error(
        dgraphs::create.chain.graph.with.offset(1),
        "A chain has to have at least two vertices."
    )
})
