test_that("minimal sKNN graphs preserve fitting fields without lifecycle repair", {
    X <- rbind(c(0, 0), c(1, 0), c(10, 0), c(11, 0))
    graph <- create.sknn.graph(X, k = 1, neighbor.method = "ann", graph.detail = "minimal", connect.components = FALSE)
    expect_s3_class(graph, "sknn_graph")
    expect_identical(graph$metadata$graph_detail, "minimal")
    expect_false(graph$metadata$lifecycle_branches)
    expect_equal(graph.adjacency(graph, "raw"), graph.adjacency(graph))
    expect_equal(graph.lengths(graph, "raw"), graph.lengths(graph))
    expect_equal(graph.adjacency(graph, "pruned"), graph.adjacency(graph))
    expect_equal(graph.lengths(graph, "pruned"), graph.lengths(graph))
    expect_error(graph.adjacency(graph, "raw.repaired"), "no stored stage")
    expect_equal(graph$metadata$n_components_before, 2L)
    expect_equal(graph$metadata$n_components_after, 2L)
})

test_that("minimal sKNN graphs reject lifecycle operations", {
    X <- matrix(c(0, 1, 3, 4), ncol = 1)
    expect_error(create.sknn.graph(X, 1, graph.detail = "minimal", connect.components = TRUE), "requires prune.method = 'none'")
    expect_error(create.sknn.graph(X, 1, graph.detail = "minimal", prune.edges = TRUE), "requires prune.method = 'none'")
})

test_that("precomputed ordered neighbors reproduce scalar ANN construction", {
    set.seed(20260908)
    X <- matrix(stats::rnorm(120), ncol = 4)
    k <- 4L
    raw <- .Call("S_kNN", X, k + 1L, PACKAGE = "dgraphs")$indices
    cached <- matrix(NA_integer_, nrow(X), k)
    for (i in seq_len(nrow(X))) {
        cached[i, ] <- raw[i, raw[i, ] != i - 1L][seq_len(k)] + 1L
    }
    direct <- create.sknn.graph(X, k, neighbor.method = "ann", graph.detail = "minimal")
    supplied <- create.sknn.graph(X, k, neighbor.method = "ann", knn.index = cached, graph.detail = "minimal")
    expect_equal(supplied, direct)
    expect_error(create.sknn.graph(X, k, neighbor.method = "exact", knn.index = cached), "supported only")
    expect_error(create.sknn.graph(X, k, neighbor.method = "ann", knn.index = cached[-1, ]), "integer-valued matrix")
})

test_that("create.sknn.graphs matches scalar graphs in requested order", {
    set.seed(20260908)
    X <- matrix(stats::rnorm(180), ncol = 3)
    k.values <- c(2L, 4L, 5L)
    series <- create.sknn.graphs(X, k.values = k.values, graph.detail = "minimal", connect.components = FALSE)
    expect_s3_class(series, "sknn_graphs")
    expect_identical(attr(series, "k.values"), k.values)
    expect_identical(names(series$graphs), as.character(k.values))
    expect_identical(series$k_statistics$k, k.values)
    expect_true("create.sknn.graphs" %in% getNamespaceExports("dgraphs"))
    for (k in k.values) {
        scalar <- create.sknn.graph(X, k, neighbor.method = "ann", graph.detail = "minimal", connect.components = FALSE)
        expect_equal(series$graphs[[as.character(k)]], scalar)
    }
})

test_that("create.sknn.graphs validates series-specific controls", {
    X <- matrix(seq_len(30), ncol = 3)
    expect_error(create.sknn.graphs(X, k.values = c(1, 1)), "strictly increasing")
    expect_error(create.sknn.graphs(X, k.values = 2, neighbor.method = "exact"), "requires neighbor.method = 'ann'")
})
