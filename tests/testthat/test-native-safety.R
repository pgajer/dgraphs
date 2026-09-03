test_that("adjacency comparisons are silent unless requested", {
    first <- list(2L, 1L)
    second <- list(integer(), integer())
    expect_output(result <- compare.adj.lists(first, second), NA)
    expect_false(result)
    expect_output(compare.adj.lists(first, second, verbose = TRUE), "1 2")
})

test_that("native nearest-neighbor entry validates dimensions and search size", {
    native.knn <- function(x, k) .Call("S_kNN", x, as.integer(k), PACKAGE = "dgraphs")
    x <- matrix(as.double(1:6), ncol = 2)
    for (k in c(-1L, 0L, 4L, NA_integer_)) {
        expect_error(native.knn(x, k), "1 <= k")
    }
    expect_error(native.knn(matrix(numeric(), 0, 2), 1), "positive matrix")
    expect_error(native.knn(matrix(1:6, ncol = 2), 1), "numeric matrix")
    expect_error(native.knn(matrix(c(1, Inf), ncol = 1), 1), "finite values")
    expect_equal(dim(native.knn(x, 1)$indices), c(3L, 1L))
})
