test_that("legacy shortest.path preserves selected raw-list distances", {
    graph <- list(a = 2L, b = c(1L, 3L), c = 2L, isolated = integer())
    lengths <- list(0, c(0, 2), 2, numeric())
    vertices <- c(3L, 1L, 3L, 4L)
    expected <- rbind(c(0, 2, 0, Inf), c(2, 0, 2, Inf),
                      c(0, 2, 0, Inf), c(Inf, Inf, Inf, 0))
    expect_no_warning(result <- shortest.path(graph, lengths, vertices))
    expect_identical(result, expected)
    expect_null(dimnames(result))
    expect_equal(shortest.path(graph, lengths, c(3L, 1L)),
                 unname(graph.geodesic.distances(dgraph(graph, lengths),
                                                vertices = c(3L, 1L))))
})

test_that("legacy shortest.path keeps argument validation", {
    graph <- list(2L, c(1L, 3L), 2L)
    lengths <- list(1, c(1, 2), 2)
    for (vertices in list(integer(), NULL, 0, 4, 1.5, NA_real_, Inf))
        expect_error(shortest.path(graph, lengths, vertices), "vertices")
    expect_error(shortest.path(graph, list(1, 1, 2), 1:3), "length")
    expect_identical(shortest.path(graph, lengths, 2L), matrix(0, 1L, 1L))
})
