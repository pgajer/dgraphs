test_that("DG3 graph constructors create simple graphs locally", {
    set.seed(1)
    X <- matrix(runif(40), ncol = 2)
    graph <- create.mknn.graph(X, k = 3, connect.components = TRUE)
    expect_true(is.list(graph))
    expect_equal(length(graph.adjacency(graph)), nrow(X))
    expect_equal(length(graph.lengths(graph)), nrow(X))
    components <- graph.connected.components(graph)
    expect_false(is.null(components))
})

.dg6f.edge.count <- function(adj.list) {
    sum(lengths(adj.list))/2
}

.dg6f.expect.weighted.adjacency <- function(adj.list, weight.list, n) {
    expect_equal(length(adj.list), n)
    expect_equal(length(weight.list), n)
    for (i in seq_len(n)) {
        expect_equal(length(adj.list[[i]]), length(weight.list[[i]]))
        expect_true(all(adj.list[[i]] >= 1L & adj.list[[i]] <= n))
        expect_true(all(is.finite(weight.list[[i]])))
    }
}

test_that("DG6f lifecycle branches and MST repair metadata are self-hosted", {
    X <- rbind(c(0, 0), c(0.08, 0), c(0, 0.08), c(10, 10), c(10.08, 10), c(10, 10.08))
    graph <- create.mknn.graph(X, k = 2, prune.method = "none", connect.components = TRUE, connect.method = "component.mst")
    stages <- c("final", "raw", "pruned", "raw.repaired", "pruned.repaired", "repaired.pruned")
    expect_setequal(graph.stages(graph), stages)
    for (stage in stages) {
        .dg6f.expect.weighted.adjacency(graph.adjacency(graph, stage), graph.lengths(graph, stage), nrow(X))
    }
    expect_equal(graph$metadata$n_components_raw, 2L)
    expect_equal(graph$metadata$n_components_raw_repaired, 1L)
    expect_equal(graph$metadata$n_components_pruned, 2L)
    expect_equal(graph$metadata$n_components_pruned_repaired, 1L)
    expect_equal(graph$metadata$n_components_repaired_pruned, 1L)
    expect_equal(graph$metadata$n_mst_edges_added, 1L)
    expect_equal(nrow(graph$metadata$mst_edge_matrix), 1L)
    expect_equal(length(graph$metadata$mst_edge_weight), 1L)
    expect_equal(graph$metadata$n_edges_in_raw_graph, .dg6f.edge.count(graph.adjacency(graph, "raw")))
    expect_equal(graph$metadata$n_edges_in_raw_repaired_graph, .dg6f.edge.count(graph.adjacency(graph,
        "raw.repaired")))
    expect_equal(graph$metadata$n_edges_in_pruned_repaired_graph, .dg6f.edge.count(graph.adjacency(graph,
        "pruned.repaired")))
    expect_equal(graph$metadata$n_edges_in_repaired_pruned_graph, .dg6f.edge.count(graph.adjacency(graph,
        "repaired.pruned")))
    raw.dist <- graph.geodesic.distances(graph, stage = "raw")
    final.dist <- graph.geodesic.distances(graph, stage = "final")
    expect_false(is.finite(raw.dist[1, 4]))
    expect_true(is.finite(final.dist[1, 4]))
})

test_that("ANN headers are vendored for native graph migration", {
    ann.header <- system.file("include", "ANN", "ANN.h", package = "dgraphs")
    expect_true(file.exists(ann.header))
})

test_that("DG1 pure-R graph constructors are self-hosted", {
    complete <- create.graph("complete", 4)
    expect_equal(graph.order(complete), 4)
    expect_equal(sort(graph.adjacency(complete)[[1]]), 2:4)
    empty <- create.graph("empty", 3)
    expect_equal(vapply(graph.adjacency(empty), length, integer(1)), c(0L, 0L, 0L))
    joined <- join.graphs(dgraph(list(2L, 1L)), dgraph(list(2L, 1L)), 2, 1)
    expect_equal(graph.order(joined), 3)
    expect_equal(graph.adjacency(joined)[[2]], c(1L, 3L))
    expect_equal(graph.adjacency(joined)[[3]], 2L)
    star <- create.graph("star", arms = c(2, 3, 1))
    expect_true(graph.order(star) > 1)
    expect_true(length(graph.adjacency(star)[[1]]) >= 3)
})

test_that("DG1 graph utilities run without native gflow calls", {
    adj <- list(c(2L, 3L), c(1L, 4L), c(1L), c(2L), integer(0))
    weights <- list(c(1, 2), c(1, 3), 2, 3, numeric(0))
    expect_equal(graph.connected.components(dgraph(adj)), c(1L, 1L, 1L, 1L, 5L))
    expect_equal(compute.graph.distance(i = 1, j = 4, graph = dgraph(adj, weights)), 4)
    X <- matrix(c(0, 0, 1, 0, 1, 1), ncol = 2, byrow = TRUE)
    E <- matrix(c(1, 2, 2, 3), ncol = 2, byrow = TRUE)
    A <- dgraphs:::.graph.adj.mat(X, E)
    expect_equal(A[1, 2], 1)
    expect_equal(A[2, 3], 1)
    expect_equal(A[1, 3], 0)
    ig <- as_igraph(dgraph(adj, weights))
    expect_equal(igraph::vcount(ig), 5)
    expect_equal(igraph::ecount(ig), 3)
    expect_equal(igraph::E(ig)$length, c(1, 2, 3))
    diam <- compute.graph.diameter(dgraph(adj, weights))
    expect_equal(diam$diameter, 6)
})

test_that("DG2 shortest paths and path graph are self-hosted", {
    adj <- list(c(2L), c(1L, 3L), c(2L))
    weights <- list(c(1), c(1, 2), c(2))
    D <- graph.geodesic.distances(dgraph(adj, weights), vertices = 1:3)
    expect_equal(D, matrix(c(0, 1, 3, 1, 0, 2, 3, 2, 0), nrow = 3, byrow = TRUE))
    pg <- create.path.graph(dgraph(adj, weights), h.values = 2)[[1L]]
    expect_s3_class(pg, "path.graph")
    expect_equal(graph.adjacency(pg$graph)[[1]], c(2L, 3L))
    expect_equal(graph.lengths(pg$graph)[[1]], c(1, 3))
    expect_equal(graph.edge.attribute(pg$graph, "hops")[[1]], c(1L, 2L))
    expect_equal(get.shortest.path(pg, 1, 3)$path, c(1L, 2L, 3L))
    series <- create.path.graph(dgraph(adj, weights), h.values = c(1, 2))
    expect_s3_class(series, "path.graph.series")
    expect_equal(attr(series[[2]], "h"), 2L)
})

test_that("DG2 graph geodesic distances use lifecycle payloads", {
    g <- dgraph(list(2L, c(1L, 3L), 2L), list(1, c(1, 2), 2))
    g$stages$raw <- dgraph(list(2L, 1L, integer()), list(10, 10, numeric()))$stages$final
    expect_equal(graph.geodesic.distances(g), matrix(c(0, 1, 3, 1, 0, 2, 3, 2, 0), nrow = 3, byrow = TRUE))
    expect_true(any(!is.finite(graph.geodesic.distances(g, stage = "raw"))))
    expect_equal(graph.geodesic.distances(g, vertices = c(1, 3)), matrix(c(0, 3, 3, 0), nrow = 2, byrow = TRUE))
})

test_that("as_igraph converts current graphs and rejects legacy basin graphs", {
    X <- rbind(c(0, 0), c(1, 0), c(2, 0), c(10, 0))
    current <- create.mknn.graph(X, k = 2, connect.components = TRUE)
    current.igraph <- as_igraph(current)
    expect_s3_class(current.igraph, "igraph")
    expect_equal(igraph::vcount(current.igraph), nrow(X))
    expect_equal(igraph::ecount(current.igraph), nrow(graph.edges(current)))
    expect_true("length" %in% igraph::edge_attr_names(current.igraph))
    legacy <- list(adjacency.list = list(2L, 1L, integer(0)), weight.list = list(1, 1, numeric(0)), intersection.matrix = matrix(c(0,
        3, 0, 3, 0, 0, 0, 0, 0), nrow = 3, byrow = TRUE), basin.metadata = data.frame(label = c("a",
        "b", "isolated"), type = c("maximum", "minimum", "other"), size = c(2, 3, 1), extremum.vertex = c(1,
        2, 3), extremum.value = c(4, 2, 1)))
    expect_error(as_igraph(legacy), "must be a dgraph")
})

test_that("DG2 long-edge pruning and grid graph run locally", {
    graph <- list(c(2L, 3L), c(1L, 3L), c(1L, 2L))
    weights <- list(c(1, 2), c(1, 3), c(2, 3))
    pruned <- wgraph.prune.long.edges(graph, weights, alt.path.len.ratio.thld = 1.1, use.total.length.constraint = TRUE)
    expect_s3_class(pruned, "dgraph")
    expect_true(2L %in% graph.adjacency(pruned)[[3]])
    expect_equal(pruned$metadata$path_lengths, numeric(0))
    refined <- create.grid.graph(list(c(2L), c(1L, 3L), c(2L)), list(c(1), c(1, 2), c(2)), grid.size = 5)
    expect_s3_class(refined, "dgraph")
    expect_equal(length(refined$metadata$grid_vertices), 6L)
    expect_equal(length(graph.adjacency(refined)), 7L)
})
