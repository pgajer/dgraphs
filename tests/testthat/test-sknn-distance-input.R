test_that("distance input reproduces Euclidean support, weights and stages", {
    set.seed(47)
    X <- matrix(rnorm(36), 12, 3)
    for (method in c("component.mst", "global.mst")) {
        old <- create.sknn.graph(X, 2, connect.components = TRUE, connect.method = method)
        new <- create.sknn.graph(dist(X), 2, input.type = "distances",
                                 connect.components = TRUE, connect.method = method)
        expect_identical(graph.stages(new), graph.stages(old))
        for (stage in graph.stages(old)) expect_equal(graph.edges(new, stage), graph.edges(old, stage))
        expect_equal(new$metadata$mst_edge_matrix, old$metadata$mst_edge_matrix)
        expect_equal(new$metadata$mst_edge_weight, old$metadata$mst_edge_weight)
    }
})

test_that("non-Euclidean distances determine ranks, lengths and component MST", {
    # Three close pairs; cheapest pair-to-pair links are 2--3 and 4--5.
    D <- matrix(20, 6, 6); diag(D) <- 0
    set <- function(i, j, d) { D[i, j] <<- d; D[j, i] <<- d }
    set(1, 2, 0); set(3, 4, 1); set(5, 6, 2)
    set(2, 3, 3); set(4, 5, 4); set(1, 6, 9)
    graph <- create.sknn.graph(D, 1, input.type = "distances", connect.components = TRUE)
    expect_equal(graph.edges(graph, "raw"), data.frame(from = c(1L, 3L, 5L),
                 to = c(2L, 4L, 6L), length = c(0, 1, 2)))
    expect_equal(graph.edges(graph), data.frame(from = 1:5, to = 2:6, length = c(0, 3, 1, 4, 2)))
    expect_equal(graph$metadata$n_components_before, 3)
    expect_equal(graph$metadata$n_mst_edges_added, 2)
    expect_equal(graph$metadata$n_components_after, 1)
    expect_equal(sum(graph$metadata$mst_edge_weight), 7)
    for (stage in graph.stages(graph)) {
        edges <- graph.edges(graph, stage)
        expect_equal(edges$length, D[cbind(edges$from, edges$to)])
    }
})

test_that("distance series shares stable non-self rankings with scalar constructors", {
    D <- matrix(1, 5, 5); diag(D) <- 0
    D[1, 2] <- D[2, 1] <- 0
    series <- create.sknn.graphs(D, c(1, 2, 4), input.type = "distances", connect.components = TRUE)
    expect_identical(series$graphs[["2"]]$metadata$knn_index[1, ], c(2L, 3L))
    expect_identical(series$graphs[["2"]]$metadata$knn_index[2, ], c(1L, 3L))
    previous <- character()
    for (k in c(1, 2, 4)) {
        scalar <- create.sknn.graph(D, k, input.type = "distances", connect.components = TRUE)
        expect_equal(series$graphs[[as.character(k)]], scalar)
        edges <- graph.edges(scalar, "raw")
        keys <- paste(edges$from, edges$to)
        expect_true(all(previous %in% keys)); previous <- keys
    }
})

test_that("distance validation rejects invalid inputs and Euclidean-only controls", {
    D <- as.matrix(dist(1:4))
    expect_equal(graph.edges(create.sknn.graph(D, 1, input.type = "distances")),
                 graph.edges(create.sknn.graph(as.dist(D), 1, input.type = "distances")))
    bad <- D; bad[1, 2] <- 9
    expect_error(create.sknn.graph(bad, 1, input.type = "distances"), "symmetric")
    bad <- D; bad[1, 1] <- 1
    expect_error(create.sknn.graph(bad, 1, input.type = "distances"), "zero diagonal")
    bad <- D; bad[1, 2] <- -1
    expect_error(create.sknn.graph(bad, 1, input.type = "distances"), "nonnegative")
    bad <- D; bad[1, 2] <- NA
    expect_error(create.sknn.graph(bad, 1, input.type = "distances"), "finite")
    dimnames(D) <- list(letters[1:4], letters[1:4])
    bad <- D; colnames(bad) <- rev(colnames(bad))
    expect_error(create.sknn.graph(bad, 1, input.type = "distances"), "names")
    expect_error(create.sknn.graph(D, 1, input.type = "distances", neighbor.method = "ann"), "exact search")
    expect_error(create.sknn.graph(D, 1, input.type = "distances", connect.method = "component.mst.ann"), "ANN")
    expect_error(create.sknn.graph(D, 1, input.type = "distances", prune.edges = TRUE), "Pruning")
    expect_error(create.sknn.graphs(D, 1:2, input.type = "distances", neighbor.method = "ann"), "exact search")
    expect_error(create.sknn.graphs(D, 1:2, input.type = "distances", knn.index = matrix(1)), "internally")
    expect_equal(create.sknn.graph(D, 1, input.type = "distances")$metadata$vertex_names, letters[1:4])
})
