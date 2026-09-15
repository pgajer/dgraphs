test_that("subdivision follows cumulative arc distance through corners", {
    path <- rbind(c(0, 0), c(1, 0), c(1, 1), c(2, 1))
    expected <- rbind(c(0, 0), c(0.6, 0), c(1, 0.2),
                      c(1, 0.8), c(1.4, 1), c(2, 1))
    expect_equal(subdivide.path(path, 6), expected)
    # This oracle follows the input segments, rather than measuring chords
    # between output points that can skip an input corner.
    arc.distance <- c(expected[1:2, 1], 1 + expected[3:4, 2],
                      2 + expected[5:6, 1] - 1)
    expect_equal(arc.distance, seq(0, 3, length.out = 6))
    expect_equal(subdivide.path(path, 4), path)
    expect_equal(subdivide.path(path, 2), path[c(1, 4), ])
    example.path <- rbind(c(0, 0), c(1, 0), c(1, 2))
    expect_equal(subdivide.path(example.path, 5),
                 rbind(c(0, 0), c(0.75, 0), c(1, 0.5), c(1, 1.25), c(1, 2)))
})

test_that("zero-length segments and degenerate paths have defined results", {
    path <- rbind(c(0, 0), c(1, 0), c(1, 2))
    repeated <- path[c(1, 1, 2, 2, 3, 3), ]
    expect_equal(subdivide.path(repeated, 5), subdivide.path(path, 5))
    expect_equal(path.length(repeated), 3)
    expect_equal(path.dist(1:6, repeated), c(0, 0, 1/3, 1/3, 1, 1))
    for (n in c(1L, 4L)) {
        constant <- matrix(rep(c(2, -3), n), ncol = 2, byrow = TRUE)
        expect_equal(path.length(constant), 0)
        expect_equal(path.dist(seq_len(n), constant), rep(0, n))
        expect_equal(subdivide.path(constant, 3),
                     matrix(rep(c(2, -3), 3), ncol = 2, byrow = TRUE))
    }
    expect_equal(path.dist(c(2, 2), path), c(0, 0))
})

test_that("path helpers preserve geometry under traversal and coordinate changes", {
    path <- rbind(c(0, 0), c(1, 0), c(1, 2))
    sampled <- subdivide.path(path, 7)
    reversed <- path[3:1, ]
    expect_equal(subdivide.path(reversed, 7), sampled[7:1, ])
    expect_equal(path.length(reversed), path.length(path))
    expect_equal(path.dist(3:1, path), c(0, 2/3, 1))
    expect_equal(path.dist(c(3, 1, 3), path), c(0, 0.5, 1))
    shifted <- sweep(path, 2, c(4, -7), "+")
    expect_equal(subdivide.path(shifted, 7), sweep(sampled, 2, c(4, -7), "+"))
    expect_equal(path.length(shifted), path.length(path))
    expect_equal(subdivide.path(3 * path, 7), 3 * sampled)
    expect_equal(path.length(3 * path), 3 * path.length(path))
    expect_equal(path.dist(1:3, 3 * path), path.dist(1:3, path))
    rotation <- matrix(c(0, -1, 1, 0), 2)
    expect_equal(subdivide.path(path %*% rotation, 7), sampled %*% rotation)
})

test_that("one and higher dimensional paths keep their matrix shape", {
    line <- matrix(c(0, 3), ncol = 1, dimnames = list(c("a", "b"), "x"))
    expect_equal(subdivide.path(line, 4),
                 matrix(0:3, ncol = 1, dimnames = list(NULL, "x")))
    expect_equal(path.length(line), 3)
    expect_equal(path.dist(2, line), 0)
    segment <- rbind(c(0, 0, 0), c(1, 2, 2))
    expect_equal(path.length(segment), 3)
    expect_equal(subdivide.path(segment, 3),
                 rbind(c(0, 0, 0), c(0.5, 1, 1), c(1, 2, 2)))
    expect_equal(dim(subdivide.path(matrix(2, 1, 1), 2)), c(2L, 1L))
})

test_that("finite path lengths are stable across coordinate scales", {
    unit <- rbind(c(0, 0), c(3, 4))
    for (scale in c(1e-200, 1e200)) {
        path <- unit * scale
        expect_equal(path.length(path) / scale, 5)
        expect_equal(path.dist(1:2, path), c(0, 1))
        expect_equal(subdivide.path(path, 3) / scale,
                     rbind(c(0, 0), c(1.5, 2), c(3, 4)))
    }
    # Subtraction must not overflow integer arithmetic.
    expect_equal(path.length(matrix(c(-2000000000L, 2000000000L), ncol = 1)), 4e9)
    too.long <- matrix(c(-1e308, 1e308), ncol = 1)
    expect_error(path.length(too.long), "finite numeric range")
    expect_error(path.dist(1:2, too.long), "finite numeric range")
    expect_error(subdivide.path(too.long, 3), "finite numeric range")
})

test_that("malformed paths and indices are rejected before computation", {
    malformed <- list(numeric(), c(0, 1), data.frame(x = 0:1),
                      matrix(numeric(), 0, 2), matrix(numeric(), 2, 0),
                      matrix(c(0, NA), 1), matrix(c(0, Inf), 1),
                      matrix(c(0, NaN), 1), matrix("x", 1), matrix(1i, 1))
    for (path in malformed) {
        expect_error(path.length(path), "finite numeric matrix")
        expect_error(path.dist(1, path), "finite numeric matrix")
        expect_error(subdivide.path(path, 3), "finite numeric matrix")
    }
    path <- rbind(c(0, 0), c(1, 0))
    for (n in list(NULL, numeric(), c(2, 3), NA_real_, NaN, Inf, -Inf,
                   0, -1, 1, 2.5, "3", TRUE, 3i, .Machine$integer.max + 1)) {
        expect_error(subdivide.path(path, n), "n.subdivision.pts must be an integer")
    }
    for (s in list(NULL, numeric(), 0, -1, 3, 1.5, NA_real_, NaN, Inf,
                   "1", TRUE, 1i, matrix(1, 1))) {
        expect_error(path.dist(s, path), "s must be a nonempty vector")
    }
})
