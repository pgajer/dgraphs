.dg6b.ensure.gflow.parity.source <- function() {
    gflow.path <- Sys.getenv(
        "DGRAPHS_GFLOW_PARITY_SOURCE",
        file.path("..", "gflow")
    )
    if (file.exists(file.path(gflow.path, "DESCRIPTION")) &&
        requireNamespace("pkgload", quietly = TRUE)) {
        pkgload::load_all(gflow.path, quiet = TRUE)
    } else {
        skip_if_not_installed("gflow")
    }
}

.dg6b.gflow.function <- function(.fname) {
    .dg6b.ensure.gflow.parity.source()
    ns <- asNamespace("gflow")
    if (exists(.fname, envir = ns, mode = "function", inherits = FALSE)) {
        return(get(.fname, envir = ns, mode = "function", inherits = FALSE))
    }
    getExportedValue("gflow", .fname)
}

.dg6b.strip <- function(x) {
    if (is.list(x)) {
        x <- lapply(x, .dg6b.strip)
    }
    attributes(x)$call <- NULL
    x
}

.dg6b.expect.gflow.parity <- function(.fname, ..., seed = NULL, tolerance = 1e-12) {
    dgraphs.fun <- get(.fname, envir = asNamespace("dgraphs"), mode = "function",
                       inherits = FALSE)
    gflow.fun <- .dg6b.gflow.function(.fname)
    if (!is.null(seed)) set.seed(seed)
    dgraphs.res <- suppressWarnings(dgraphs.fun(...))
    if (!is.null(seed)) set.seed(seed)
    gflow.res <- suppressWarnings(gflow.fun(...))
    expect_equal(
        .dg6b.strip(dgraphs.res),
        .dg6b.strip(gflow.res),
        tolerance = tolerance,
        ignore_attr = TRUE
    )
}

test_that("DG6b offset chain graph fixture matches original gflow outputs", {
    .dg6b.expect.gflow.parity(
        "create.chain.graph.with.offset",
        n = 2,
        offset = 0
    )
    .dg6b.expect.gflow.parity(
        "create.chain.graph.with.offset",
        n = 5,
        offset = 0
    )
    .dg6b.expect.gflow.parity(
        "create.chain.graph.with.offset",
        n = 4,
        offset = 10
    )
    expect_error(
        get("create.chain.graph.with.offset", envir = asNamespace("dgraphs"))(1),
        "A chain has to have at least two vertices."
    )
})
