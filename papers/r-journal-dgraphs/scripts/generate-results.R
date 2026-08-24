#!/usr/bin/env Rscript

required <- c("dgraphs", "FNN", "dbscan", "igraph")
missing <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
if (length(missing)) {
    stop("Install the benchmark dependencies: ", paste(missing, collapse = ", "))
}

dir.create("data", showWarnings = FALSE, recursive = TRUE)

edge.key <- function(edge.matrix) {
    if (!nrow(edge.matrix)) return(character())
    edge.matrix <- cbind(
        pmin(edge.matrix[, 1L], edge.matrix[, 2L]),
        pmax(edge.matrix[, 1L], edge.matrix[, 2L])
    )
    sort(sprintf("%d:%d", edge.matrix[, 1L], edge.matrix[, 2L]))
}

materialize.symmetric.graph <- function(x, nn.index) {
    n <- nrow(nn.index)
    from <- rep(seq_len(n), each = ncol(nn.index))
    to <- as.integer(t(nn.index))
    edges <- unique(cbind(pmin(from, to), pmax(from, to)))
    edges <- edges[edges[, 1L] != edges[, 2L], , drop = FALSE]
    delta <- x[edges[, 1L], , drop = FALSE] - x[edges[, 2L], , drop = FALSE]
    weights <- sqrt(rowSums(delta * delta))
    list(edge_matrix = edges, weights = weights)
}

build.symmetric.graph <- function(backend, x, k) {
    if (backend == "dgraphs") {
        return(dgraphs::create.sknn.graph(
            x,
            k = k,
            neighbor.method = "ann",
            connect.components = FALSE
        ))
    }
    if (backend == "FNN") {
        neighbors <- FNN::get.knn(x, k = k, algorithm = "kd_tree")
        return(materialize.symmetric.graph(x, neighbors$nn.index))
    }
    neighbors <- dbscan::kNN(x, k = k, sort = TRUE)
    materialize.symmetric.graph(x, neighbors$id)
}

benchmark.graph.pipeline <- function() {
    scenarios <- expand.grid(
        n = c(500L, 1500L, 3000L),
        dimension = c(2L, 10L, 50L),
        stringsAsFactors = FALSE
    )
    backends <- c("dgraphs", "FNN", "dbscan")
    repetitions <- 3L
    k <- 10L
    rows <- vector("list", nrow(scenarios) * length(backends) * repetitions)
    at <- 0L

    for (s in seq_len(nrow(scenarios))) {
        n <- scenarios$n[s]
        dimension <- scenarios$dimension[s]
        set.seed(9100L + 13L * n + dimension)
        x <- matrix(stats::rnorm(n * dimension), nrow = n)
        message("Pipeline scenario ", s, "/", nrow(scenarios),
                ": n = ", n, ", dimension = ", dimension)

        reference <- build.symmetric.graph("dgraphs", x, k)
        reference.edges <- edge.key(reference$edge_matrix)

        for (backend in backends) {
            warmup <- build.symmetric.graph(backend, x, k)
            parity <- identical(edge.key(warmup$edge_matrix), reference.edges)
            if (!parity) {
                stop("Edge-set mismatch for ", backend, ", n = ", n,
                     ", dimension = ", dimension)
            }
            for (repetition in seq_len(repetitions)) {
                gc()
                elapsed <- system.time({
                    graph <- build.symmetric.graph(backend, x, k)
                })[["elapsed"]]
                at <- at + 1L
                rows[[at]] <- data.frame(
                    backend = backend,
                    n = n,
                    dimension = dimension,
                    k = k,
                    repetition = repetition,
                    elapsed_seconds = elapsed,
                    edges = nrow(graph$edge_matrix),
                    edge_set_matches = identical(
                        edge.key(graph$edge_matrix), reference.edges
                    )
                )
            }
        }
    }
    do.call(rbind, rows)
}

circle.sample <- function(n, density, noise, seed) {
    set.seed(seed)
    u <- if (density == "uniform") stats::runif(n) else stats::rbeta(n, 0.8, 1.8)
    theta <- sort(2 * pi * u)
    x <- cbind(cos(theta), sin(theta))
    x <- x + matrix(stats::rnorm(2L * n, sd = noise), ncol = 2L)
    list(x = x, theta = theta)
}

circle.arc.distances <- function(theta) {
    delta <- abs(outer(theta, theta, "-"))
    pmin(delta, 2 * pi - delta)
}

local.scale.radius <- function(x, k) {
    distances <- as.matrix(stats::dist(x))
    diag(distances) <- Inf
    median(apply(distances, 1L, sort, partial = k)[k, ])
}

build.graph.family <- function(family, x, k) {
    common <- list(X = x, connect.components = TRUE,
                   connect.method = "component.mst")
    if (family == "mutual kNN") {
        return(do.call(dgraphs::create.mknn.graph, c(common, list(k = k))))
    }
    if (family == "symmetric kNN") {
        return(do.call(
            dgraphs::create.sknn.graph,
            c(common, list(k = k, neighbor.method = "ann"))
        ))
    }
    if (family == "continuous kNN") {
        return(do.call(
            dgraphs::create.cknn.graph,
            c(common, list(k.scale = k, delta = 1, radius.search = "ann"))
        ))
    }
    do.call(
        dgraphs::create.rknn.graph,
        c(common, list(type = "fixed", radius = local.scale.radius(x, k)))
    )
}

benchmark.graph.families <- function() {
    scenarios <- expand.grid(
        n = c(100L, 200L),
        density = c("uniform", "uneven"),
        noise = c(0.005, 0.05),
        repetition = seq_len(3L),
        stringsAsFactors = FALSE
    )
    families <- c("mutual kNN", "symmetric kNN", "continuous kNN", "fixed radius")
    k <- 6L
    rows <- vector("list", nrow(scenarios) * length(families))
    at <- 0L

    for (s in seq_len(nrow(scenarios))) {
        message("Graph-family scenario ", s, "/", nrow(scenarios))
        sample <- circle.sample(
            scenarios$n[s], scenarios$density[s], scenarios$noise[s],
            seed = 15000L + 100L * s
        )
        truth <- circle.arc.distances(sample$theta)

        for (family in families) {
            elapsed <- system.time({
                graph <- build.graph.family(family, sample$x, k)
            })[["elapsed"]]
            final.distances <- dgraphs::graph.geodesic.distances(graph)
            if (any(!is.finite(final.distances))) {
                stop("Connectivity repair failed for ", family)
            }
            final.summary <- dgraphs::summarize.isometry.deviation(
                final.distances,
                truth,
                scale = TRUE
            )
            final.diagnostics <- dgraphs::isometry.geodesic.diagnostics(
                final.distances,
                truth,
                scale = TRUE
            )
            native.rel.rms.error <- NA_real_
            if (graph$n_components_before == 1L) {
                native.distances <- dgraphs::graph.geodesic.distances(
                    graph,
                    stage = "raw"
                )
                native.rel.rms.error <- dgraphs::isometry.rel.rms.error(
                    native.distances,
                    truth,
                    scale = TRUE
                )
            }
            at <- at + 1L
            rows[[at]] <- data.frame(
                family = family,
                n = scenarios$n[s],
                density = scenarios$density[s],
                noise = scenarios$noise[s],
                repetition = scenarios$repetition[s],
                k = k,
                elapsed_seconds = elapsed,
                native_edges = sum(lengths(graph$raw_adj_list)) / 2,
                final_edges = graph$n_edges,
                native_components = graph$n_components_before,
                final_components = graph$n_components_after,
                bridges_added = graph$n_mst_edges_added,
                native_rel_rms_error = native.rel.rms.error,
                final_rel_rms_error = final.summary$rel_rms_error,
                final_shortcut_fraction =
                    unname(final.diagnostics[["shortcut_fraction"]]),
                final_distance_correlation = final.summary$pearson_cor
            )
        }
    }
    do.call(rbind, rows)
}

pipeline <- benchmark.graph.pipeline()
families <- benchmark.graph.families()

utils::write.csv(pipeline, "data/pipeline-benchmark.csv", row.names = FALSE)
utils::write.csv(families, "data/graph-family-benchmark.csv", row.names = FALSE)

metadata <- c(
    paste("generated_at_utc:", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    paste("R:", R.version.string),
    paste("platform:", R.version$platform),
    paste("dgraphs:", as.character(utils::packageVersion("dgraphs"))),
    paste("FNN:", as.character(utils::packageVersion("FNN"))),
    paste("dbscan:", as.character(utils::packageVersion("dbscan"))),
    paste("igraph:", as.character(utils::packageVersion("igraph")))
)
writeLines(metadata, "data/benchmark-session.txt")
