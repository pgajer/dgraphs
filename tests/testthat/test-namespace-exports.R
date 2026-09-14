test_that("path graph helpers are exported", {
    exports <- getNamespaceExports("dgraphs")

    expect_true("graph.geodesic.distances" %in% exports)
    expect_true("create.path.graph" %in% exports)
    expect_true("get.shortest.path" %in% exports)
})
