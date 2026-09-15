test_that("DG6d graph.embedding returns stable layout-shaped matrices", {
    path.graph <- dgraph(list(c(2L), c(1L, 3L), c(2L, 4L), c(3L)))
    set.seed(123)
    layout <- dgraphs::graph.embedding(path.graph, dim = 2, method = "fr")
    expect_equal(dim(layout), c(4L, 2L))
    expect_true(all(is.finite(layout)))
    empty <- dgraphs::graph.embedding(dgraph(list()), dim = 3)
    expect_equal(dim(empty), c(0L, 3L))
    set.seed(321)
    no.edges <- dgraphs::graph.embedding(create.graph("empty", 3), dim = 2)
    expect_equal(dim(no.edges), c(3L, 2L))
    expect_true(all(is.finite(no.edges)))
})

test_that("DG6d plot.dgraph prepares plotting on an off-screen device", {
    embedding <- matrix(c(0, 0, 1, 0, 1, 1, 0, 1), ncol = 2, byrow = TRUE)
    graph <- list(c(2L, 4L), c(1L, 3L), c(2L, 4L), c(1L, 3L))
    colors <- c(-1, 0, 1, 2)
    out <- tempfile(fileext = ".pdf")
    grDevices::pdf(out)
    res <- tryCatch({
        oldpar <- graphics::par(c("mar", "xpd"))
        value <- plot(dgraph(graph), coordinates = embedding, vertex.values = colors, vertex.size = 1.2, edge.alpha = 0.4,
            add.legend = FALSE)
        expect_equal(graphics::par(c("mar", "xpd")), oldpar)
        value
    }, finally = grDevices::dev.off())
    expect_equal(res, embedding)
    expect_true(file.exists(out))
    expect_gt(file.info(out)$size, 0)
})
