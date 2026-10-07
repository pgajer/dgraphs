test_that("component MST repair and ANN fallback avoid dense allocation", {
  set.seed(71)
  X <- rbind(matrix(rnorm(30,0,.03),10,3),matrix(rnorm(30,10,.03),10,3),
             matrix(rnorm(30,25,.03),10,3))
  exact <- create.sknn.graph(X,2,neighbor.method="ann",connect.components=TRUE)
  fallback <- create.sknn.graph(X,2,neighbor.method="ann",connect.components=TRUE,
    connect.method="component.mst.ann",bridge.k=1,bridge.k.max=1)
  # Explicit small dense reference is outside the production ANN path.
  dense <- create.sknn.graph(as.matrix(dist(X)),2,input.type="distances",connect.components=TRUE)
  for (g in list(exact,fallback)) {
    expect_false(g$metadata$dense_distance_matrix_allocated)
    expect_equal(g$metadata$n_components_after,1)
    expect_equal(g$metadata$n_mst_edges_added,g$metadata$n_components_before-1)
    expect_equal(sum(g$metadata$mst_edge_weight),sum(dense$metadata$mst_edge_weight),tolerance=1e-12)
    expect_gt(g$metadata$bridge_distance_evaluations,0)
    expect_lte(g$metadata$bridge_distance_evaluations,choose(nrow(X),2))
  }
  expect_true(fallback$metadata$bridge_exact_fallback_used)
})

test_that("projection selects neighbors while original coordinates define lengths and repair", {
  set.seed(72); X <- matrix(rnorm(160),40,4); U <- X[,1,drop=FALSE]
  series <- create.sknn.graphs(X,c(2,4,6),search.data=U,graph.detail="minimal")
  previous <- character()
  for (g in series$graphs) {
    e <- graph.edges(g)
    keys <- paste(e$from,e$to)
    expect_true(all(previous %in% keys)); previous <- keys
    expect_equal(e$length,sqrt(rowSums((X[e$from,]-X[e$to,])^2)),tolerance=1e-12)
    expect_false(g$metadata$dense_distance_matrix_allocated)
    expect_equal(g$metadata$search_dimension,1)
  }
  expect_error(create.sknn.graph(X,2,search.data=U),"requires neighbor.method")
  expect_error(create.sknn.graph(X,2,search.data=U[-1,,drop=FALSE],neighbor.method="ann"),"nrow")
})

test_that("streaming repair handles deterministic tied bridge lengths", {
  X <- as.matrix(expand.grid(c(0,1,10,11),c(0,10)))
  a <- create.sknn.graph(X,1,neighbor.method="ann",connect.components=TRUE)
  b <- create.sknn.graph(as.matrix(dist(X)),1,input.type="distances",connect.components=TRUE)
  expect_equal(sum(a$metadata$mst_edge_weight),sum(b$metadata$mst_edge_weight))
  expect_equal(a$metadata$n_components_after,1)
  expect_false(a$metadata$dense_distance_matrix_allocated)
})
