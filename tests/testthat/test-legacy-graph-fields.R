expect.legacy.final.fields <- function(graph) {
    expect_s3_class(graph, "dgraph")
    expect_true(all(c("adj_list", "weight_list") %in% names(graph)))
    expect_identical(graph$adj_list, graph.adjacency(graph))
    expect_identical(graph[["weight_list"]], graph.lengths(graph))
}

test_that("legacy graph fields preserve aligned lengths, zero edges and isolates", {
    graph <- dgraph(list(c(3L, 2L), 1L, 1L, integer()),
                    list(c(0, 2), 2, 0, numeric()))
    expect.legacy.final.fields(graph)
    expect_identical(graph$adj_list[[1L]], c(2L, 3L))
    expect_identical(graph$weight_list[[1L]], c(2, 0))
    expect_identical(graph$adj_list[[4L]], integer())
    expect_identical(graph$weight_list[[4L]], numeric())
    expect_silent(graph$adj_list)
    expect_silent(graph$weight_list)
    expect_equal(shortest.path(graph$adj_list, graph$weight_list, 1:4),
                 graph.geodesic.distances(graph))

    for (unweighted in list(create.graph("empty", 0), create.graph("cycle", 4))) {
        expect.legacy.final.fields(unweighted)
        expect_null(unweighted$weight_list)
    }
})

test_that("legacy native-result fields describe the final stage rather than raw edges", {
    native <- list(
        adj_list = list(3L, integer(), 1L, integer()),
        weight_list = list(0, numeric(), 0, numeric()),
        edge_matrix = matrix(c(1L, 3L), nrow = 1L),
        raw_adj_list = list(c(3L, 2L), c(3L, 1L), c(2L, 1L), integer()),
        raw_weight_list = list(c(0, 2), c(4, 2), c(4, 0), numeric())
    )
    graph <- .dgraph.from.native(native, "radius_graph")
    expect.legacy.final.fields(graph)
    expect_s3_class(graph, "radius_graph")
    expect_false(identical(graph$adj_list, graph.adjacency(graph, "raw")))
    expect_identical(graph$weight_list[[1L]], 0)
    expect_identical(graph$edge_matrix, native$edge_matrix)
    expect_equal(unname(graph$edge_matrix),
                 unname(as.matrix(graph.edges(graph)[, c("from", "to")])))
    expect_false(any(c("adj_list", "weight_list", "edge_matrix") %in%
                     names(graph$metadata)))
})

test_that("radius graph constructors retain fields used by published downstream readers", {
    X <- cbind(seq_len(10L), sin(seq_len(10L)))
    graphs <- list(
        create.rknn.graph(X, type = "fixed", radius = 1.5),
        create.rknn.graph(X, type = "adaptive.radius", k.scale = 2,
                         radius.search = "all.pairs", connect.components = TRUE),
        create.rknn.graph(X, type = "adaptive.radius", k.scale = 2,
                         graph.detail = "minimal")
    )
    for (graph in graphs) {
        expect.legacy.final.fields(graph)
        expect_length(graph$adj_list, nrow(X))
        expect_equal(unname(graph$edge_matrix),
                     unname(as.matrix(graph.edges(graph)[, c("from", "to")])))
        # Published geosmooth reconstructs metric lengths from these endpoints.
        metric.length <- sqrt(rowSums((X[graph$edge_matrix[, 1L], , drop = FALSE] -
                                       X[graph$edge_matrix[, 2L], , drop = FALSE])^2))
        expect_equal(metric.length, graph.edges(graph)$length)
        expect_equal(shortest.path(graph$adj_list, graph$weight_list, seq_len(nrow(X))),
                     graph.geodesic.distances(graph))
    }
})

test_that("labels remain aligned in standard and path graph compatibility fields", {
    graph <- create.graph("chain", n = 5, labels = letters[1:5])
    expect.legacy.final.fields(graph)
    expect_identical(names(graph$adj_list), names(graph.adjacency(graph)))
    expect_identical(names(graph$weight_list), names(graph$adj_list))
    paths <- create.path.graph(graph, h.values = c(1, 3))
    for (path in paths) {
        expect.legacy.final.fields(path$graph)
        expect_identical(names(path$graph$adj_list), names(graph$adj_list))
        expect_identical(names(path$graph$weight_list), names(graph$adj_list))
    }
})
