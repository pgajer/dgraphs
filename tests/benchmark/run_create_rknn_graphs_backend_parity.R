#!/usr/bin/env Rscript

find.package.root <- function(start = getwd()) {
    current <- normalizePath(start, mustWork = TRUE)
    while (TRUE) {
        if (file.exists(file.path(current, "DESCRIPTION")) &&
            dir.exists(file.path(current, "R"))) {
            return(current)
        }
        parent <- dirname(current)
        if (identical(parent, current)) {
            stop("Could not locate package root from ", start, call. = FALSE)
        }
        current <- parent
    }
}

package.root <- find.package.root()
if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(package.root, quiet = TRUE)
} else {
    library(dgraphs)
}

as.positive.integer <- function(value, name) {
    value <- suppressWarnings(as.integer(value))
    if (length(value) != 1L || is.na(value) || value < 1L) {
        stop(name, " must be a positive integer.", call. = FALSE)
    }
    value
}

as.nonnegative.integer <- function(value, name) {
    value <- suppressWarnings(as.integer(value))
    if (length(value) != 1L || is.na(value) || value < 0L) {
        stop(name, " must be a nonnegative integer.", call. = FALSE)
    }
    value
}

bench.repetitions <- as.positive.integer(
    Sys.getenv("DGRAPHS_RKNN_BENCH_REPETITIONS", "3"),
    "DGRAPHS_RKNN_BENCH_REPETITIONS"
)
warmup.repetitions <- as.nonnegative.integer(
    Sys.getenv("DGRAPHS_RKNN_BENCH_WARMUP_REPETITIONS", "1"),
    "DGRAPHS_RKNN_BENCH_WARMUP_REPETITIONS"
)

make.noisy.grid <- function() {
    set.seed(101)
    side <- 15L
    grid <- expand.grid(x = seq(0, 1, length.out = side),
                        y = seq(0, 1, length.out = side))
    X <- as.matrix(grid)
    X + matrix(rnorm(length(X), sd = 0.006), ncol = 2)
}

make.curve <- function() {
    set.seed(102)
    t <- seq(0, 3 * pi, length.out = 120L)
    cbind(
        t / max(t),
        sin(t) + rnorm(length(t), sd = 0.015)
    )
}

make.high.dim.cloud <- function() {
    set.seed(103)
    X <- matrix(rnorm(180L * 6L), ncol = 6L)
    scales <- seq(1, 1.8, length.out = ncol(X))
    sweep(X, 2L, scales, `*`)
}

make.separated.clusters <- function() {
    set.seed(104)
    cluster.a <- matrix(rnorm(45L * 2L, sd = 0.08), ncol = 2L)
    cluster.b <- matrix(rnorm(45L * 2L, sd = 0.08), ncol = 2L)
    cluster.b <- sweep(cluster.b, 2L, c(4, 4), `+`)
    rbind(cluster.a, cluster.b)
}

benchmark.cases <- list(
    list(
        name = "noisy.grid.minimal",
        X = make.noisy.grid(),
        k.values = c(3L, 6L, 12L, 18L),
        controls = list(
            radius.factor = 1.05,
            radius.rule = "max",
            prune.method = "none",
            graph.detail = "minimal",
            connect.components = FALSE
        )
    ),
    list(
        name = "curve.local.geodesic",
        X = make.curve(),
        k.values = c(3L, 5L, 9L),
        controls = list(
            radius.factor = 1.15,
            radius.rule = "geomean",
            prune.method = "local.geodesic",
            prune.local.k = 5L,
            with.pruned.edge.stats = TRUE,
            graph.detail = "full",
            connect.components = FALSE
        )
    ),
    list(
        name = "high.dim.cloud",
        X = make.high.dim.cloud(),
        k.values = c(4L, 8L, 14L),
        controls = list(
            radius.factor = 1.1,
            radius.rule = "min",
            prune.method = "none",
            graph.detail = "minimal",
            connect.components = FALSE
        )
    ),
    list(
        name = "separated.clusters.repair",
        X = make.separated.clusters(),
        k.values = c(6L, 2L, 4L),
        controls = list(
            radius.factor = 1.02,
            radius.rule = "max",
            prune.method = "none",
            graph.detail = "full",
            connect.components = TRUE,
            connect.method = "component.mst.ann",
            bridge.k = 1L,
            bridge.k.max = 2L
        )
    )
)

strip.timing.fields <- function(graphs) {
    graphs$timing <- NULL
    if (!is.null(graphs$graphs)) {
        for (i in seq_along(graphs$graphs)) {
            graphs$graphs[[i]]$timing <- NULL
            graphs$graphs[[i]]$finalization_timing <- NULL
        }
    }
    graphs
}

assert.backend.parity <- function(case.name, r.graphs, cpp.graphs) {
    comparison <- all.equal(
        strip.timing.fields(cpp.graphs),
        strip.timing.fields(r.graphs),
        tolerance = 1e-12
    )
    if (!isTRUE(comparison)) {
        stop(
            "Backend parity failed for case ", sQuote(case.name), ":\n",
            paste(comparison, collapse = "\n"),
            call. = FALSE
        )
    }
}

reported.elapsed <- function(graphs) {
    if (is.null(graphs$timing) || !"elapsed.sec" %in% names(graphs$timing)) {
        return(NA_real_)
    }
    sum(graphs$timing$elapsed.sec, na.rm = TRUE)
}

run.backend <- function(case, backend) {
    gc()
    result <- NULL
    elapsed <- system.time({
        result <- do.call(
            create.rknn.graphs,
            c(
                list(
                    X = case$X,
                    k.values = case$k.values,
                    radius.search = "ann",
                    backend = backend,
                    return.timing = TRUE
                ),
                case$controls
            )
        )
    })[["elapsed"]]

    list(
        graphs = result,
        elapsed = as.numeric(elapsed),
        reported.elapsed = reported.elapsed(result)
    )
}

raw.rows <- list()
row.index <- 1L

cat("create.rknn.graphs() backend parity benchmarks\n")
cat("package root:", package.root, "\n")
cat("repetitions:", bench.repetitions, "\n")
cat("warm-up repetitions:", warmup.repetitions, "\n\n")

for (case in benchmark.cases) {
    n <- nrow(case$X)
    p <- ncol(case$X)
    cat(sprintf(
        "case=%s n=%d p=%d k.values=%s\n",
        case$name, n, p, paste(case$k.values, collapse = ",")
    ))

    for (warmup in seq_len(warmup.repetitions)) {
        r.warmup <- run.backend(case, "r")
        cpp.warmup <- run.backend(case, "cpp")
        assert.backend.parity(case$name, r.warmup$graphs, cpp.warmup$graphs)
    }

    for (rep in seq_len(bench.repetitions)) {
        r.run <- run.backend(case, "r")
        cpp.run <- run.backend(case, "cpp")
        assert.backend.parity(case$name, r.run$graphs, cpp.run$graphs)
        speedup <- if (cpp.run$elapsed > 0) {
            r.run$elapsed / cpp.run$elapsed
        } else {
            Inf
        }

        raw.rows[[row.index]] <- data.frame(
            case = case$name,
            backend = "r",
            repetition = rep,
            n = n,
            p = p,
            k.values = paste(case$k.values, collapse = ","),
            wall.elapsed.sec = r.run$elapsed,
            reported.elapsed.sec = r.run$reported.elapsed,
            stringsAsFactors = FALSE
        )
        row.index <- row.index + 1L
        raw.rows[[row.index]] <- data.frame(
            case = case$name,
            backend = "cpp",
            repetition = rep,
            n = n,
            p = p,
            k.values = paste(case$k.values, collapse = ","),
            wall.elapsed.sec = cpp.run$elapsed,
            reported.elapsed.sec = cpp.run$reported.elapsed,
            stringsAsFactors = FALSE
        )
        row.index <- row.index + 1L

        cat(sprintf(
            "  rep=%d parity=ok r=%.4fs cpp=%.4fs speedup=%.2fx\n",
            rep, r.run$elapsed, cpp.run$elapsed, speedup
        ))
    }
    cat("\n")
}

raw.results <- do.call(rbind, raw.rows)
summary.results <- do.call(rbind, lapply(split(raw.results, raw.results$case),
                                         function(case.rows) {
    r.rows <- case.rows[case.rows$backend == "r", ]
    cpp.rows <- case.rows[case.rows$backend == "cpp", ]
    data.frame(
        case = unique(case.rows$case),
        n = unique(case.rows$n),
        p = unique(case.rows$p),
        k.values = unique(case.rows$k.values),
        r.median.wall.sec = median(r.rows$wall.elapsed.sec),
        cpp.median.wall.sec = median(cpp.rows$wall.elapsed.sec),
        median.speedup = if (median(cpp.rows$wall.elapsed.sec) > 0) {
            median(r.rows$wall.elapsed.sec) /
                median(cpp.rows$wall.elapsed.sec)
        } else {
            Inf
        },
        r.median.reported.sec = median(r.rows$reported.elapsed.sec),
        cpp.median.reported.sec = median(cpp.rows$reported.elapsed.sec),
        stringsAsFactors = FALSE
    )
}))
rownames(summary.results) <- NULL

cat("Summary:\n")
print(summary.results, row.names = FALSE)

output.dir <- Sys.getenv("DGRAPHS_RKNN_BENCH_OUTPUT_DIR", "")
if (nzchar(output.dir)) {
    dir.create(output.dir, recursive = TRUE, showWarnings = FALSE)
    stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
    raw.path <- file.path(
        output.dir,
        paste0("create_rknn_graphs_backend_parity_raw_", stamp, ".csv")
    )
    summary.path <- file.path(
        output.dir,
        paste0("create_rknn_graphs_backend_parity_summary_", stamp, ".csv")
    )
    write.csv(raw.results, raw.path, row.names = FALSE)
    write.csv(summary.results, summary.path, row.names = FALSE)
    cat("\nwrote raw results:", raw.path, "\n")
    cat("wrote summary:", summary.path, "\n")
}

cat("\nAll backend parity benchmark cases passed.\n")
