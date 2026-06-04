test_that("DG3 graph constructors create simple graphs locally", {
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

test_that("DG2 shortest paths and path graph are self-hosted", {
    adj <- list(c(2L), c(1L, 3L), c(2L))
    weights <- list(c(1), c(1, 2), c(2))

    D <- shortest.path(adj, weights, 1:3)
    expect_equal(D, matrix(c(0, 1, 3, 1, 0, 2, 3, 2, 0), nrow = 3,
                           byrow = TRUE))

    pg <- create.path.graph(adj, weights, h = 2)
    expect_s3_class(pg, "path.graph")
    expect_equal(pg$adj.list[[1]], c(2L, 3L))
    expect_equal(pg$edge.length.list[[1]], c(1, 3))
    expect_equal(pg$hop.list[[1]], c(1L, 2L))
    expect_equal(get.shortest.path(pg, 1, 3)$path, c(1L, 2L, 3L))

    series <- create.path.graph.series(adj, weights, c(1, 2))
    expect_s3_class(series, "path.graph.series")
    expect_equal(attr(series[[2]], "h"), 2L)
})

test_that("DG2 graph geodesic distances use lifecycle payloads", {
    g <- structure(
        list(
            adj_list = list(c(2L), c(1L, 3L), c(2L)),
            weight_list = list(c(1), c(1, 2), c(2)),
            raw_adj_list = list(c(2L), c(1L), integer(0)),
            raw_weight_list = list(c(10), c(10), numeric(0))
        ),
        class = "mknn_graph"
    )
    expect_equal(graph.geodesic.distances(g),
                 matrix(c(0, 1, 3, 1, 0, 2, 3, 2, 0), nrow = 3,
                        byrow = TRUE))
    expect_true(any(!is.finite(graph.geodesic.distances(g, stage = "raw"))))
    expect_equal(graph.geodesic.distances(g, vertices = c(1, 3)),
                 matrix(c(0, 3, 3, 0), nrow = 2, byrow = TRUE))
})

test_that("DG2 long-edge pruning and grid graph run locally", {
    graph <- list(c(2L, 3L), c(1L, 3L), c(1L, 2L))
    weights <- list(c(1, 2), c(1, 3), c(2, 3))
    pruned <- wgraph.prune.long.edges(
        graph,
        weights,
        alt.path.len.ratio.thld = 1.1,
        use.total.length.constraint = TRUE
    )
    expect_named(pruned, c("adj_list", "edge_lengths_list", "path_lengths",
                           "edge_lengths"))
    expect_true(2L %in% pruned$adj_list[[3]])
    expect_equal(pruned$path_lengths, numeric(0))

    refined <- create.grid.graph(list(c(2L), c(1L, 3L), c(2L)),
                                 list(c(1), c(1, 2), c(2)),
                                 grid.size = 5)
    expect_named(refined, c("adj_list", "weight_list", "grid_vertices"))
    expect_equal(length(refined$grid_vertices), 6L)
    expect_equal(length(refined$adj_list), 7L)
})
