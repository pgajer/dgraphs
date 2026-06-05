.dg6e.selfhost.point.cloud <- function() {
    set.seed(718)
    t <- seq(0, 2 * pi, length.out = 20)
    X <- cbind(cos(t), sin(t), 0.2 * cos(2 * t)) +
        matrix(stats::rnorm(20 * 3, sd = 0.01), ncol = 3)
    rownames(X) <- paste0("pt", seq_len(nrow(X)))
    X
}

test_that("DG6e stability diagnostics can be computed and plotted without gflow", {
    X <- .dg6e.selfhost.point.cloud()
    graphs <- dgraphs::create.iknn.graphs(
        X,
        kmin = 2,
        kmax = 5,
        pca.dim = NULL,
        variance.explained = NULL,
        compute.full = TRUE,
        with.isize.pruning = TRUE,
        n.cores = 1,
        verbose = FALSE
    )

    summary.out <- capture.output(summary(graphs))
    expect_true(any(grepl("Summary of iknn_graphs object", summary.out)))

    stab <- dgraphs::compute.stability.metrics(graphs, graph.type = "geom")
    expect_s3_class(stab, "iknn_stability_metrics")
    expect_equal(stab$k.values, 2:5)
    expect_length(stab$edit.distances, 3L)
    expect_length(stab$js.div, 3L)

    opt <- dgraphs:::find.optimal.k(stab)
    expect_type(opt$opt.k, "integer")
    expect_true(opt$opt.k %in% stab$k.values[-length(stab$k.values)])

    out <- tempfile(fileext = ".pdf")
    grDevices::pdf(out)
    expect_silent(dgraphs:::plot.iknn_stability_metrics(stab))
    invisible(grDevices::dev.off())
    expect_gt(file.info(out)$size, 0)
})

test_that("DG6e build/select edit object can be printed and plotted without gflow", {
    X <- .dg6e.selfhost.point.cloud()
    res <- dgraphs:::build.iknn.graphs.and.selectk(
        X,
        kmin = 2,
        kmax = 5,
        method = "edit",
        pca.dim = NULL,
        variance.explained = NULL,
        n.cores = 1,
        verbose = FALSE
    )

    expect_s3_class(res, "build_iknn_graphs_and_selectk")
    expect_equal(res$k.values, 3:6)
    expect_false(is.null(res$connectivity))
    expect_false(is.null(res$edit))
    expect_true(is.finite(res$k.opt.edit))

    print.out <- capture.output(print(res))
    expect_true(any(grepl("build.iknn.graphs.and.selectk result", print.out)))

    out <- tempfile(fileext = ".pdf")
    grDevices::pdf(out)
    expect_silent(dgraphs:::plot.build_iknn_graphs_and_selectk(res))
    invisible(grDevices::dev.off())
    expect_gt(file.info(out)$size, 0)
})

test_that("DG6e label-mixing selection path is self-hosted", {
    X <- .dg6e.selfhost.point.cloud()
    labels <- rep(c("A", "B"), length.out = nrow(X))

    res <- dgraphs:::build.iknn.graphs.and.selectk(
        X,
        kmin = 2,
        kmax = 5,
        method = "mixing",
        labels = labels,
        mixing.metric = "homophily.adjusted",
        n.perm = 0,
        pca.dim = NULL,
        variance.explained = NULL,
        n.cores = 1,
        verbose = FALSE
    )

    expect_s3_class(res, "build_iknn_graphs_and_selectk")
    expect_false(is.null(res$mixing))
    expect_named(
        res$mixing,
        c(
            "k",
            "metric",
            "homophily.z",
            "homophily.effect",
            "homophily.adjusted",
            "assortativity",
            "conductance.median",
            "conductance.wmean"
        )
    )
    expect_equal(nrow(res$mixing), length(res$k.values))
    expect_equal(res$mixing$k, res$k.values)
    expect_equal(anyDuplicated(res$mixing$k), 0L)
    expect_true(all(is.finite(res$mixing$metric) | is.na(res$mixing$metric)))
})
