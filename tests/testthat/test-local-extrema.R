local.extrema.chain <- function(detect.maxima = TRUE, min.neighborhood.size = 2) {
    detect.local.extrema(
        adj.list = list(2L, c(1L, 3L), 2L),
        weight.list = list(1, c(1, 1), 1),
        y = c(1, 3, 0),
        max.radius = 1,
        min.neighborhood.size = min.neighborhood.size,
        detect.maxima = detect.maxima
    )
}

test_that("empty extrema retain the requested maxima or minima type", {
    for (detect.maxima in c(TRUE, FALSE)) {
        x <- local.extrema.chain(detect.maxima, min.neighborhood.size = 4)
        expected.type <- if (detect.maxima) "Maximum" else "Minimum"

        expect_identical(class(x), "local_extrema")
        expect_identical(x$vertices, integer())
        expect_identical(x$is_maxima, logical())
        expect_identical(x$type, character())
        expect_identical(x$detect.maxima, detect.maxima)

        s <- summary(x)
        expect_identical(class(s), "summary.local_extrema")
        expect_identical(s$n_extrema, 0L)
        expect_identical(s$extrema_type, expected.type)
        expect_identical(s$extrema_details, data.frame())
        expect_output(print(s), paste("Extrema type:", expected.type))
    }
})

test_that("legacy empty extrema have an unknown type instead of a guessed type", {
    x <- local.extrema.chain(min.neighborhood.size = 4)
    x$detect.maxima <- NULL
    expect_identical(summary(x)$extrema_type, NA_character_)
})

test_that("nonempty extrema remain compatible with legacy objects", {
    for (detect.maxima in c(TRUE, FALSE)) {
        x <- local.extrema.chain(detect.maxima)
        expected.type <- if (detect.maxima) "Maximum" else "Minimum"
        expected.vertices <- if (detect.maxima) 2L else c(1L, 3L)
        expect_identical(x$vertices, expected.vertices)
        expect_identical(x$detect.maxima, detect.maxima)
        expect_identical(x$type, rep(expected.type, length(expected.vertices)))

        s <- summary(x)
        expect_identical(s$extrema_type, expected.type)
        expect_identical(s$extrema_details$fn_value,
                         sort(x$values, decreasing = detect.maxima))

        x$detect.maxima <- NULL
        expect_identical(summary(x), s)
    }
})

test_that("the requested detection type must be known", {
    expect_error(local.extrema.chain(NA), "'detect.maxima' must be a scalar logical",
                 fixed = TRUE)
})
