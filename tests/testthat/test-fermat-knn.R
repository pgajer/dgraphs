reference.neighbors <- function(x, k, p, rooted = FALSE) {
    d <- fermat.distances(points = x, p = p, rooted = rooted)
    diag(d) <- Inf
    list(d = d, cutoff = apply(d, 1L, function(z) sort(z)[k]))
}

test_that("pruned neighbors and distances agree with complete paths", {
    set.seed(293)
    examples <- list(matrix(runif(120), 40, 3),
                     cbind(c(0, .1, .3, .7, 1.4, 2), 0),
                     rbind(matrix(0, 8, 2), matrix(runif(24), 12, 2)),
                     as.matrix(expand.grid(1:4, 1:4)))
    for (x in examples) for (p in c(1, 2, 3)) for (k in c(1, 4, nrow(x)-1)) {
        ref <- reference.neighbors(x, k, p)
        a <- fermat.knn(x, k, p)
        observed <- ref$d[cbind(rep(seq_len(nrow(x)), times=k), as.vector(a$index))]
        expect_equal(as.vector(a$distance), observed, tolerance = 1e-11)
        expect_true(all(a$distance[, k] <= ref$cutoff + 1e-11))
        expect_true(all(vapply(seq_len(nrow(x)), function(i)
            !i %in% a$index[i, ] && !anyDuplicated(a$index[i, ]), logical(1))))
    }
})

test_that("rooting, algorithms, names, and graph union are correct", {
    set.seed(765)
    x <- matrix(runif(60), 20, dimnames = list(letters[1:20], NULL))
    a <- fermat.knn(x, 5)
    for (algorithm in "brute")
        expect_equal(fermat.knn(x, 5, algorithm=algorithm), a, tolerance=1e-11)
    b <- fermat.knn(x, 5, rooted=TRUE)
    expect_equal(b$index, a$index)
    expect_equal(b$distance, sqrt(a$distance))
    expect_equal(rownames(a$index), rownames(x))
    g <- create.fermat.sknn.graph(x, 5)
    e <- graph.edges(g)
    ref <- reference.neighbors(x, 5, 2)$d
    expect_equal(e$length, unname(ref[cbind(e$from, e$to)]), tolerance=1e-11)
    expected <- unique(paste(pmin(rep(1:20,5),a$index),pmax(rep(1:20,5),a$index)))
    expect_setequal(paste(e$from,e$to), expected)
    expect_true(all(lengths(graph.adjacency(g)) >= 5))
    expect_equal(graph.order(g), 20L)
    expect_equal(names(graph.adjacency(g)), rownames(x))
    z <- create.fermat.sknn.graph(matrix(0, 8, 2), 3)
    expect_true(all(graph.edges(z)$length == 0))
})

test_that("inputs and numeric range are checked", {
    x <- matrix(1:12, 6)
    for (k in list(0, 6, 1.5, NA_real_, c(1,2))) expect_error(fermat.knn(x,k))
    for (p in list(0, Inf, NA_real_, c(1,2))) expect_error(fermat.knn(x,2,p))
    expect_error(fermat.knn(x,2,rooted=1), "rooted")
    expect_error(fermat.knn(x,2,algorithm="approx"), "algorithm")
    expect_error(fermat.knn(matrix(NA_real_,3,2),1), "finite")
    expect_error(fermat.knn(matrix(1,1,2),1), "two rows")
    expect_error(fermat.knn(matrix(c(0,1e200,2e200),ncol=1),1), "overflow")
    expect_error(fermat.knn(matrix(c(0,1e-200,2e-200),ncol=1),1), "underflow")
    expect_equal(fermat.knn(matrix(c(0,1e150,2e150),ncol=1),1,p=1)$distance,
                 matrix(rep(1e150,3),ncol=1), tolerance=1e-12)
})
