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
