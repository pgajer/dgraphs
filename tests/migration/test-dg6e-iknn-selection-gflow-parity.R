.dg6e.ensure.gflow.parity.source <- function() {
    gflow.path <- Sys.getenv(
        "DGRAPHS_GFLOW_PARITY_SOURCE",
        "/Users/pgajer/current_projects/gflow"
    )
    if (file.exists(file.path(gflow.path, "DESCRIPTION")) &&
        requireNamespace("pkgload", quietly = TRUE)) {
        pkgload::load_all(gflow.path, quiet = TRUE)
    } else {
        skip_if_not_installed("gflow")
    }
}

.dg6e.function <- function(pkg, fname) {
    if (pkg == "gflow") .dg6e.ensure.gflow.parity.source()
    ns <- asNamespace(pkg)
    if (exists(fname, envir = ns, mode = "function", inherits = FALSE)) {
        return(get(fname, envir = ns, mode = "function", inherits = FALSE))
    }
    getExportedValue(pkg, fname)
}

.dg6e.point.cloud <- function() {
    set.seed(642)
    t <- seq(0, 2 * pi, length.out = 18)
    X <- cbind(cos(t), sin(t), 0.15 * sin(2 * t)) +
        matrix(stats::rnorm(18 * 3, sd = 0.01), ncol = 3)
    rownames(X) <- paste0("s", seq_len(nrow(X)))
    X
}

.dg6e.mixing.point.cloud <- function() {
    set.seed(718)
    t <- seq(0, 2 * pi, length.out = 20)
    X <- cbind(cos(t), sin(t), 0.2 * cos(2 * t)) +
        matrix(stats::rnorm(20 * 3, sd = 0.01), ncol = 3)
    rownames(X) <- paste0("pt", seq_len(nrow(X)))
    X
}

.dg6e.canonical.mixing <- function(df) {
    df <- df[order(df$k), , drop = FALSE]
    idx.by.k <- split(seq_len(nrow(df)), df$k)
    out <- do.call(
        rbind,
        lapply(idx.by.k, function(idx) {
            df[idx[1L], , drop = FALSE]
        })
    )
    rownames(out) <- NULL
    out
}

.dg6e.graphs <- function(pkg, X, with.isize.pruning = TRUE) {
    .dg6e.function(pkg, "create.iknn.graphs")(
        X,
        kmin = 2,
        kmax = 5,
        pca.dim = NULL,
        variance.explained = NULL,
        compute.full = TRUE,
        with.isize.pruning = with.isize.pruning,
        n.cores = 1,
        verbose = FALSE
    )
}

test_that("DG6e stability metrics and optimal k match gflow", {
    X <- .dg6e.point.cloud()
    d.graphs <- .dg6e.graphs("dgraphs", X)
    g.graphs <- .dg6e.graphs("gflow", X)

    d.stab <- .dg6e.function("dgraphs", "compute.stability.metrics")(d.graphs, graph.type = "geom")
    g.stab <- .dg6e.function("gflow", "compute.stability.metrics")(g.graphs, graph.type = "geom")

    expect_equal(d.stab$k.values, g.stab$k.values)
    expect_equal(d.stab$edit.distances, g.stab$edit.distances, tolerance = 1e-12)
    expect_equal(d.stab$js.div, g.stab$js.div, tolerance = 1e-12)
    expect_equal(d.stab$n.edges.in.pruned.graph, g.stab$n.edges.in.pruned.graph, tolerance = 1e-12)

    d.opt <- .dg6e.function("dgraphs", "find.optimal.k")(d.stab)
    g.opt <- .dg6e.function("gflow", "find.optimal.k")(g.stab)
    expect_equal(d.opt$opt.k, g.opt$opt.k)
    expect_equal(d.opt$stability.scores, g.opt$stability.scores, tolerance = 1e-12)
})

test_that("DG6e birth-death optimal k and isize stability match gflow", {
    X <- .dg6e.point.cloud()
    d.graphs <- .dg6e.graphs("dgraphs", X)
    g.graphs <- .dg6e.graphs("gflow", X)

    d.bd <- suppressWarnings(
        .dg6e.function("dgraphs", "find.optimal.k")(
            d.graphs$birth_death_matrix,
            kmin = attr(d.graphs, "kmin"),
            kmax = attr(d.graphs, "kmax")
        )
    )
    g.bd <- suppressWarnings(
        .dg6e.function("gflow", "find.optimal.k")(
            g.graphs$birth_death_matrix,
            kmin = attr(g.graphs, "kmin"),
            kmax = attr(g.graphs, "kmax")
        )
    )
    expect_equal(d.bd$opt.k, g.bd$opt.k)
    expect_equal(d.bd$stability.scores, g.bd$stability.scores, tolerance = 1e-12)

    d.isize <- .dg6e.function("dgraphs", "compute.stability.metrics")(d.graphs, graph.type = "isize")
    g.isize <- .dg6e.function("gflow", "compute.stability.metrics")(g.graphs, graph.type = "isize")
    expect_equal(d.isize$edit.distances, g.isize$edit.distances, tolerance = 1e-12)
    expect_equal(d.isize$js.div, g.isize$js.div, tolerance = 1e-12)
})

test_that("DG6e build/select edit diagnostics match gflow", {
    X <- .dg6e.point.cloud()
    d.build <- .dg6e.function("dgraphs", "build.iknn.graphs.and.selectk")(
        X,
        kmin = 2,
        kmax = 5,
        method = "edit",
        pca.dim = NULL,
        variance.explained = NULL,
        n.cores = 1,
        verbose = FALSE
    )
    g.build <- .dg6e.function("gflow", "build.iknn.graphs.and.selectk")(
        X,
        kmin = 2,
        kmax = 5,
        method = "edit",
        pca.dim = NULL,
        variance.explained = NULL,
        n.cores = 1,
        verbose = FALSE
    )

    expect_s3_class(d.build, "build_iknn_graphs_and_selectk")
    expect_equal(d.build$k.values, g.build$k.values)
    expect_equal(d.build$connectivity, g.build$connectivity, tolerance = 1e-12)
    expect_equal(d.build$edit, g.build$edit, tolerance = 1e-12)
    expect_equal(d.build$k.cc.edit, g.build$k.cc.edit)
    expect_equal(d.build$k.opt.edit, g.build$k.opt.edit)
})

test_that("DG6e build/select mixing diagnostics match gflow after shape policy", {
    X <- .dg6e.mixing.point.cloud()
    labels <- rep(c("A", "B"), length.out = nrow(X))
    names(labels) <- rownames(X)

    d.build <- .dg6e.function("dgraphs", "build.iknn.graphs.and.selectk")(
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
    g.build <- .dg6e.function("gflow", "build.iknn.graphs.and.selectk")(
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

    expect_s3_class(d.build, "build_iknn_graphs_and_selectk")
    expect_equal(d.build$k.opt.mixing, g.build$k.opt.mixing)
    expect_equal(d.build$k.cc.mixing, g.build$k.cc.mixing)
    expect_equal(d.build$k.values, g.build$k.values)

    expect_equal(nrow(d.build$mixing), length(d.build$k.values))
    expect_true(any(duplicated(g.build$mixing$k)))
    expect_gt(nrow(g.build$mixing), nrow(d.build$mixing))
    expect_equal(
        d.build$mixing,
        .dg6e.canonical.mixing(g.build$mixing),
        tolerance = 1e-12
    )

    params.to.compare <- c(
        "method",
        "mixing.metric",
        "mixing.min.lcc.frac",
        "mixing.eps",
        "mixing.require.local.extremum",
        "mixing.window",
        "n.perm",
        "pca.dim",
        "variance.explained"
    )
    expect_equal(d.build$params[params.to.compare], g.build$params[params.to.compare])
})

test_that("DG6e plotting methods run on off-screen devices", {
    X <- .dg6e.point.cloud()
    d.graphs <- .dg6e.graphs("dgraphs", X)
    g.graphs <- .dg6e.graphs("gflow", X)
    d.stab <- .dg6e.function("dgraphs", "compute.stability.metrics")(d.graphs, graph.type = "geom")
    g.stab <- .dg6e.function("gflow", "compute.stability.metrics")(g.graphs, graph.type = "geom")

    d.file <- tempfile(fileext = ".pdf")
    grDevices::pdf(d.file)
    expect_silent(.dg6e.function("dgraphs", "plot.IkNNgraphs")(d.stab))
    invisible(grDevices::dev.off())

    g.file <- tempfile(fileext = ".pdf")
    grDevices::pdf(g.file)
    expect_silent(.dg6e.function("gflow", "plot.IkNNgraphs")(g.stab))
    invisible(grDevices::dev.off())

    expect_gt(file.info(d.file)$size, 0)
    expect_gt(file.info(g.file)$size, 0)
})
