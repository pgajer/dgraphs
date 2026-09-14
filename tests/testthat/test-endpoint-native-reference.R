test_that("DG5 endpoint utilities run self-hosted", {
    adj <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L))
    w <- list(1, c(1, 1), c(1, 1), c(1, 1), 1)
    layout <- cbind(seq_len(5), 0, 0)

    scores <- compute.graph.endpoint.scores(
        adj.list = adj,
        length.list = w,
        layout.3d = layout,
        k = c(2L, 3L),
        min.neighborhood.size = 2L
    )
    expect_s3_class(scores, "graph_endpoint_scores")
    expect_equal(nrow(scores$summary), 5L)

    endpoints <- detect.graph.endpoints(
        adj.list = adj,
        length.list = w,
        layout.3d = layout,
        k = c(2L, 3L),
        min.neighborhood.size = 2L,
        detect.max.radius = 2,
        detect.min.neighborhood.size = 2L,
        smooth = FALSE
    )
    expect_s3_class(endpoints, "graph_endpoints")
    expect_true(all(endpoints$endpoints %in% seq_along(adj)))
})

test_that("DG5 endpoint utilities use package-local native acceleration", {
    adj <- list(c(2L), c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L))
    w <- list(1, c(1, 1), c(1, 1), c(1, 1), 1)
    layout <- cbind(seq_len(5), 0, 0)
    local.max <- matrix(
        c(
            TRUE, FALSE,
            FALSE, TRUE,
            TRUE, FALSE,
            FALSE, TRUE,
            TRUE, FALSE
        ),
        nrow = 5,
        ncol = 2
    )
    score.by.scale <- matrix(
        c(
            0.9, 0.1,
            0.7, 0.8,
            0.5, 0.4,
            0.3, 0.6,
            0.1, 0.2
        ),
        nrow = 5,
        ncol = 2
    )

    expect_true(is.function(get("rcpp_compute_graph_endpoint_scores",
                                envir = asNamespace("dgraphs"))))
    expect_true(is.function(get("rcpp_graph_multi_source_support_by_scale",
                                envir = asNamespace("dgraphs"))))
    expect_true(is.function(get("rcpp_graph_greedy_maxima_suppression_by_scale",
                                envir = asNamespace("dgraphs"))))

    native.scores <- dgraphs:::.compute.graph.endpoint.scores.reference(
        adj.list = adj,
        length.list = w,
        layout.3d = layout,
        scales = c(2, 3),
        neighborhood = "geodesic_k",
        q = 0.1,
        neighbor.weighting = "uniform",
        gaussian.sigma = NULL,
        min.neighborhood.size = 2L,
        prefer.cpp = TRUE
    )
    reference.scores <- dgraphs:::.compute.graph.endpoint.scores.reference(
        adj.list = adj,
        length.list = w,
        layout.3d = layout,
        scales = c(2, 3),
        neighborhood = "geodesic_k",
        q = 0.1,
        neighbor.weighting = "uniform",
        gaussian.sigma = NULL,
        min.neighborhood.size = 2L,
        prefer.cpp = FALSE
    )
    expect_equal(native.scores, reference.scores, tolerance = 1e-12)

    native.support <- dgraphs:::.compute.graph.endpoint.support.by.scale(
        adj.list = adj,
        length.list = w,
        local.max.by.scale = local.max,
        radius = 1,
        prefer.cpp = TRUE
    )
    reference.support <- dgraphs:::.compute.graph.endpoint.support.by.scale(
        adj.list = adj,
        length.list = w,
        local.max.by.scale = local.max,
        radius = 1,
        prefer.cpp = FALSE
    )
    expect_equal(native.support, reference.support)

    native.keep <- dgraphs:::.suppress.graph.endpoint.maxima.by.scale(
        adj.list = adj,
        length.list = w,
        local.max.by.scale = local.max,
        score.by.scale = score.by.scale,
        radius = 1,
        prefer.cpp = TRUE
    )
    reference.keep <- dgraphs:::.suppress.graph.endpoint.maxima.by.scale(
        adj.list = adj,
        length.list = w,
        local.max.by.scale = local.max,
        score.by.scale = score.by.scale,
        radius = 1,
        prefer.cpp = FALSE
    )
    expect_equal(native.keep, reference.keep)
})
