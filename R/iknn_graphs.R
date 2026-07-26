#' Create intersection k-nearest neighbor graphs with dual pruning
#'
#' @description
#' For each \eqn{k \in [k_{\mathrm{min}},\,k_{\mathrm{max}}]}, builds an
#' intersection-weighted k-NN graph and applies two pruning schemes:
#' (1) geometric (path-to-edge ratio) and (2) intersection-size.
#' Optionally performs PCA before graph construction.
#'
#' @param X A numeric matrix (or object coercible to a numeric matrix) with rows
#'     = observations and columns = features.
#'
#' @param kmin Integer \eqn{\ge 1}, the minimum k.
#'
#' @param kmax Integer \eqn{> k_{\mathrm{min}}}, the maximum k.
#'
#' @param max.path.edge.ratio.deviation.thld Numeric in \eqn{[0, 0.2)}.
#'     Geometric pruning removes an edge \eqn{(i,j)} when there exists an
#'     alternative path between \eqn{i} and \eqn{j} whose path/edge length ratio
#'     minus 1.0 is \emph{less than} this threshold. This is a deviation
#'     threshold \eqn{\delta} in \eqn{[0, 0.2)}. Internally we compare the
#'     path-to-edge ratio R to \eqn{1 + \delta}.
#'
#' @param path.edge.ratio.percentile Numeric in \eqn{[0,1]}. Only edges with
#'     length above this percentile are considered for geometric pruning.
#'
#' @param threshold.percentile Numeric in \eqn{[0, 0.5]}. Percentile threshold for
#'     quantile-based edge length pruning. Default is 0 (no quantile pruning).
#'     When greater than 0, edges in the top (1 - threshold.percentile) quantile
#'     by length are removed if their removal preserves graph connectivity.
#'     For example, threshold.percentile = 0.9 removes edges in the top 10\% by length.
#'     This pruning is applied after geometric pruning and targets unusually long edges
#'     based on absolute edge lengths rather than path-to-edge ratios.
#'
#' @param compute.full Logical controlling graph-list outputs.
#'     If `TRUE`, return `geom_pruned_graphs` (and `isize_pruned_graphs` when
#'     `with.isize.pruning = TRUE`).
#'     If `FALSE`, both graph lists are `NULL` and only summary outputs are returned
#'     (`k_statistics`, plus `edge_pruning_stats` when requested).
#'
#' @param with.isize.pruning Logical. If `TRUE`, compute and return
#'     intersection-size pruned graphs/statistics. Default is `FALSE`.
#'
#' @param with.edge.pruning.stats Logical. If `TRUE`, compute and return
#'     edge-level pruning statistics. Default is `FALSE`.
#'
#' @param pca.dim Positive integer or `NULL`. If not `NULL` and `ncol(X) >
#'     pca.dim`, PCA is used to reduce to at most `pca.dim` components.
#'
#' @param variance.explained Numeric in \eqn{(0,1]} or `NULL`. If not `NULL`,
#'     choose the smallest number of PCs whose cumulative variance explained
#'     exceeds this threshold, capped by `pca.dim`.
#'
#' @param knn.metric Character scalar specifying the geometry used for kNN search.
#'     \code{"euclidean"} uses ordinary ambient Euclidean distance.
#'     \code{"linf.simplex"} uses the unfolded intrinsic metric on the
#'     \eqn{L^\infty}-simplex and requires rows of \code{X} to be
#'     \eqn{L^\infty}-normalized.
#'
#' @param linf.tol Positive numeric tolerance used only when
#'     \code{knn.metric = "linf.simplex"} to identify active simplex faces and
#'     validate that \code{max(row) = 1}.
#'
#' @param n.cores Integer or `NULL`. Number of CPU cores. `NULL` uses the
#'     maximum available (OpenMP build only).
#'
#' @param parallel.mode Character execution mode for graph construction:
#'     `"auto"`, `"k"`, `"bucket"`, `"hybrid"` (or alias `"bucket.prune"`).
#'     `"hybrid"` performs
#'     bucket-parallel graph build and then k-parallel pruning in batches.
#'
#' @param hybrid.batch.size Positive integer batch size used when
#'     `parallel.mode = "hybrid"`.
#'
#' @param knn.cache.path Optional character scalar path to a binary kNN cache file.
#'     Used only when `knn.cache.mode != "none"`.
#'
#' @param knn.cache.mode Character cache mode:
#'   \itemize{
#'     \item \code{"none"}: always compute kNN; do not read/write cache.
#'     \item \code{"read"}: read kNN from cache only; if cache is missing/invalid, error.
#'     \item \code{"write"}: always compute kNN and atomically write/overwrite cache.
#'     \item \code{"readwrite"}: read valid cache when available; if cache file is missing,
#'       compute and write cache; if cache exists but is invalid, error.
#'   }
#'
#' @param verbose Logical; print progress and timing.
#'
#' @return A list of class `"iknn_graphs"` with entries:
#' \describe{
#'   \item{k_statistics}{Matrix of per-\eqn{k} edge counts and reductions.
#'     (If the C++ side supplies column names, they’re preserved.
#'     Otherwise we add names consistent with what the C++ returns.)}
#'   \item{geom_pruned_graphs}{If `compute.full=TRUE`, list of geometrically
#'     pruned graphs (adjacency + weights); otherwise `NULL`.}
#'   \item{isize_pruned_graphs}{If `compute.full=TRUE` and
#'     `with.isize.pruning=TRUE`, list of intersection-size pruned graphs;
#'     otherwise `NULL`.}
#'   \item{edge_pruning_stats}{If `with.edge.pruning.stats=TRUE`, list (per
#'     \eqn{k}) of edge-level statistics; otherwise `NULL`.}
#' }
#'
#' @details
#' Geometric pruning uses the deviation threshold
#' `max.path.edge.ratio.deviation.thld` and the filtering percentile
#' `path.edge.ratio.percentile`. Intersection-size pruning currently uses
#' a maximum alternative path length of 2.
#'
#' Output behavior by flags:
#' - `compute.full = FALSE`: both `geom_pruned_graphs` and `isize_pruned_graphs`
#'   are `NULL`.
#' - `compute.full = TRUE` and `with.isize.pruning = FALSE`:
#'   `geom_pruned_graphs` is returned and `isize_pruned_graphs` is `NULL`.
#'
#' @examples
#' # Generate sample data
#' X <- matrix(rnorm(100 * 5), 100, 5)
#'
#' # Basic usage
#' res1 <- create.iknn.graphs(
#'   X, kmin = 3, kmax = 10, n.cores = 1,
#'   compute.full = FALSE
#' )
#'
#' # With custom pruning parameters
#' res2 <- create.iknn.graphs(
#'   X, kmin = 3, kmax = 10,
#'   max.path.edge.ratio.deviation.thld = 0.1,
#'   path.edge.ratio.percentile = 0.5,
#'   compute.full = TRUE,
#'   n.cores = 1,
#'   verbose = TRUE
#' )
#'
#' # View statistics for each k
#' print(res2$k_statistics)
#'
#' @export
create.iknn.graphs <- function(X,
                               kmin,
                               kmax,
                               max.path.edge.ratio.deviation.thld = 0.1,
                               path.edge.ratio.percentile = 0.5,
                               threshold.percentile = 0,
                               compute.full = TRUE,
                               with.isize.pruning = FALSE,
                               with.edge.pruning.stats = FALSE,
                               pca.dim = 100,
                               variance.explained = 0.99,
                               knn.metric = c("euclidean", "linf.simplex"),
                               linf.tol = sqrt(.Machine$double.eps),
                               n.cores = 1L,
                               parallel.mode = c("auto", "k", "bucket", "hybrid", "bucket.prune"),
                               hybrid.batch.size = 2L,
                               verbose = TRUE,
                               knn.cache.path = NULL,
                               knn.cache.mode = c("none", "read", "write", "readwrite")) {

    ## Coerce & basic checks
    if (!is.matrix(X)) {
        X <- try(as.matrix(X), silent = TRUE)
        if (inherits(X, "try-error"))
            stop("X must be a matrix or coercible to a numeric matrix.")
    }
    if (!is.numeric(X)) stop("X must be numeric.")
    if (any(!is.finite(X))) stop("X cannot contain NA/NaN/Inf.")

    if (!is.double(X)) {
        storage.mode(X) <- "double"
    }

    knn.metric <- .normalize.knn.metric(knn.metric)
    linf.tol <- .normalize.linf.tol(linf.tol)

    n <- nrow(X)
    if (n < 2) stop("X must have at least 2 rows (observations).")

    if (!is.numeric(kmin) || length(kmin) != 1 || kmin < 1 || kmin != floor(kmin))
        stop("kmin must be a positive integer.")
    if (!is.numeric(kmax) || length(kmax) != 1 || kmax < kmin || kmax != floor(kmax))
        stop("kmax must be an integer not smaller than kmin.")
    if (n <= kmax)
        stop("Number of observations (nrow(X)) must be greater than kmax.")

    if (!is.numeric(max.path.edge.ratio.deviation.thld) || length(max.path.edge.ratio.deviation.thld) != 1)
        stop("max.path.edge.ratio.deviation.thld must be numeric.")
    if (max.path.edge.ratio.deviation.thld < 0 || max.path.edge.ratio.deviation.thld >= 0.2)
        stop("max.path.edge.ratio.deviation.thld must be in [0, 0.2).")

    if (!is.numeric(path.edge.ratio.percentile) || length(path.edge.ratio.percentile) != 1 ||
        path.edge.ratio.percentile < 0 || path.edge.ratio.percentile > 1)
        stop("path.edge.ratio.percentile must be in [0, 1].")

    if (!is.logical(compute.full) || length(compute.full) != 1)
        stop("compute.full must be TRUE/FALSE.")
    if (!is.logical(with.isize.pruning) || length(with.isize.pruning) != 1)
        stop("with.isize.pruning must be TRUE/FALSE.")
    if (!is.logical(with.edge.pruning.stats) || length(with.edge.pruning.stats) != 1)
        stop("with.edge.pruning.stats must be TRUE/FALSE.")
    if (!is.logical(verbose) || length(verbose) != 1)
        stop("verbose must be TRUE/FALSE.")
    parallel.mode <- match.arg(parallel.mode)
    if (identical(parallel.mode, "bucket.prune")) {
        parallel.mode <- "hybrid"
    }
    parallel.mode.id <- switch(parallel.mode,
                               auto = 0L,
                               k = 1L,
                               bucket = 2L,
                               hybrid = 3L)
    if (!is.numeric(hybrid.batch.size) || length(hybrid.batch.size) != 1 ||
        hybrid.batch.size < 1 || hybrid.batch.size != floor(hybrid.batch.size)) {
        stop("hybrid.batch.size must be a positive integer.")
    }
    knn.cache.mode <- match.arg(knn.cache.mode)
    knn.cache.path <- .normalize.knn.cache.path(knn.cache.path, knn.cache.mode)
    knn.metric.id <- .knn.metric.id(knn.metric)
    knn.cache.mode.id <- switch(knn.cache.mode,
                                none = 0L,
                                read = 1L,
                                write = 2L,
                                readwrite = 3L)

    if (!is.numeric(threshold.percentile) || length(threshold.percentile) != 1)
        stop("threshold.percentile must be numeric.")
    if (threshold.percentile < 0 || threshold.percentile > 0.5)
        stop("threshold.percentile must be in [0, 0.5].")

    if (!is.logical(compute.full) || length(compute.full) != 1) {
        stop("compute.full must be a single logical value")
    }

    if (!is.null(pca.dim)) {
        if (!is.numeric(pca.dim) || length(pca.dim) != 1 || pca.dim < 1 || pca.dim != floor(pca.dim))
            stop("pca.dim must be a positive integer or NULL.")
    }
    if (identical(knn.metric, "linf.simplex")) {
        if (!is.null(pca.dim)) {
            stop("pca.dim must be NULL when knn.metric = 'linf.simplex'.")
        }
        .validate.linf.simplex.input(X, linf.tol)
    }
    if (!is.null(variance.explained)) {
        if (!is.numeric(variance.explained) || length(variance.explained) != 1 ||
            variance.explained <= 0 || variance.explained > 1)
            stop("variance.explained must be in (0, 1], or NULL.")
    }

    ## PCA (optional)
    pca_info <- NULL
    if (!is.null(pca.dim) && ncol(X) > pca.dim) {
        if (verbose) message("High-dimensional data detected. Performing PCA.")
        original_dim <- ncol(X)
        if (!is.null(variance.explained)) {
            pca_analysis <- pca.optimal.components(
                X, variance.threshold = variance.explained, max.components = pca.dim
            )
            n_components <- pca_analysis$n.components
            if (verbose) {
                message(sprintf("Using %d PCs (explains %.2f%% variance)",
                                n_components, 100 * pca_analysis$variance.explained))
            }
            X <- pca.project(X, pca_analysis$pca.result, n_components)
            pca_info <- list(
                original_dim = original_dim,
                n_components = n_components,
                variance_explained = pca_analysis$variance.explained,
                cumulative_variance = pca_analysis$cumulative.variance
            )
        } else {
            if (verbose) message(sprintf("Projecting to first %d PCs", pca.dim))
            pca_result <- stats::prcomp(X)
            X <- pca.project(X, pca_result, pca.dim)
            variance_explained <- sum(pca_result$sdev[1:pca.dim]^2) / sum(pca_result$sdev^2)
            pca_info <- list(
                original_dim = original_dim,
                n_components = pca.dim,
                variance_explained = variance_explained
            )
        }
    }

    if (verbose && !compute.full) {
        message("compute.full=FALSE: geom_pruned_graphs and isize_pruned_graphs will be NULL; returning k_statistics (and edge_pruning_stats if requested).")
    } else if (verbose && !with.isize.pruning) {
        message("with.isize.pruning=FALSE: isize_pruned_graphs will be NULL.")
    }

    ## Note on k: ANN returns self in its kNN sets, this is why k+1 is passed here (for kmin and kmax).
    ## We need to ensure the C++ labels/columns reflect the *original* k.
    result <- .Call("S_create_iknn_graphs",
                    X,
                    as.integer(kmin + 1L),
                    as.integer(kmax + 1L),
                    as.double(max.path.edge.ratio.deviation.thld + 1.0),
                    as.double(path.edge.ratio.percentile),
                    as.double(threshold.percentile),
                    as.logical(compute.full),
                    as.logical(with.isize.pruning),
                    as.logical(with.edge.pruning.stats),
                    if (is.null(n.cores)) NULL else as.integer(n.cores),
                    as.integer(parallel.mode.id),
                    as.integer(hybrid.batch.size),
                    if (is.null(knn.cache.path)) NULL else as.character(knn.cache.path),
                    as.integer(knn.cache.mode.id),
                    as.integer(knn.metric.id),
                    as.double(linf.tol),
                    as.logical(verbose),
                    PACKAGE = "dgraphs")

    ## Normalize optional matrices (placeholders may be empty)
    if (!is.null(result$birth_death_matrix)) {
        if (!is.matrix(result$birth_death_matrix) || nrow(result$birth_death_matrix) == 0) {
            result$birth_death_matrix <- matrix(
                numeric(0), nrow = 0, ncol = 4,
                dimnames = list(NULL, c("start","end","birth_time","death_time"))
            )
        } else if (is.null(colnames(result$birth_death_matrix))) {
            colnames(result$birth_death_matrix) <- c("start","end","birth_time","death_time")
        }
    }
    if (!is.null(result$double_birth_death_matrix)) {
        if (!is.matrix(result$double_birth_death_matrix) || nrow(result$double_birth_death_matrix) == 0) {
            result$double_birth_death_matrix <- matrix(
                numeric(0), nrow = 0, ncol = 4,
                dimnames = list(NULL, c("start","end","birth_time","death_time"))
            )
        }
    }

    ## Add column names to k_statistics only if missing, and match column count
    if (!is.null(result$k_statistics) && is.matrix(result$k_statistics) &&
        is.null(colnames(result$k_statistics))) {
        nc <- ncol(result$k_statistics)
        ## Common layouts: with k (8 cols) or without k (7 cols)
        if (nc == 8L) {
            colnames(result$k_statistics) <- c("k",
                                               "n_edges",
                                               "n_edges_in_geom_pruned_graph",
                                               "n_geom_removed_edges",
                                               "geom_edge_reduction_ratio",
                                               "n_edges_in_isize_pruned_graph",
                                               "n_isize_removed_edges",
                                               "isize_edge_reduction_ratio"
                                               )
        } else if (nc == 7L) {
            colnames(result$k_statistics) <- c(
                "n_edges",
                "n_edges_in_geom_pruned_graph",
                "n_geom_removed_edges",
                "geom_edge_reduction_ratio",
                "n_edges_in_isize_pruned_graph",
                "n_isize_removed_edges",
                "isize_edge_reduction_ratio"
            )
        }
    }

    attr(result, "kmin") <- kmin
    attr(result, "kmax") <- kmax
    attr(result, "max_path_edge_ratio_deviation_thld") <- max.path.edge.ratio.deviation.thld
    attr(result, "path_edge_ratio_percentile") <- path.edge.ratio.percentile
    attr(result, "with.isize.pruning") <- with.isize.pruning
    attr(result, "with.edge.pruning.stats") <- with.edge.pruning.stats
    attr(result, "parallel.mode") <- parallel.mode
    attr(result, "hybrid.batch.size") <- as.integer(hybrid.batch.size)
    attr(result, "knn.metric") <- knn.metric
    attr(result, "linf.tol") <- linf.tol
    if (!is.null(pca_info)) attr(result, "pca") <- pca_info
    class(result) <- "iknn_graphs"
    result
}

#' Summarize an iknn_graphs Object
#'
#' @description
#' Provides a detailed summary of an iknn_graphs object created by the create.iknn.graphs() function.
#' The summary includes statistics for each intersection kNN graph in the sequence, displaying information
#' about the connectivity and structure of the graphs for different k values.
#'
#' @param object An object of class 'iknn_graphs', typically the output of create.iknn.graphs().
#' @param use.isize.pruned Logical. If TRUE, computes and displays statistics for the intersection-size
#'        pruned graphs (isize_pruned_graphs). If FALSE (default), computes statistics for the
#'        geometrically pruned graphs (geom_pruned_graphs).
#' @param ... Additional arguments passed to or from other methods (not currently used).
#'
#' @return Invisibly returns a data frame containing statistics for each graph. The data frame has the following columns:
#'   \item{idx}{The index of the given k value}
#'   \item{k}{The k value for the intersection kNN graph}
#'   \item{n_ccomp}{Number of connected components of the graph}
#'   \item{edges}{Number of edges in the graph}
#'   \item{mean_degree}{Average number of connections per vertex}
#'   \item{min_degree}{Minimum vertex degree (least connected vertex)}
#'   \item{max_degree}{Maximum vertex degree (most connected vertex)}
#'   \item{sparsity}{Graph sparsity, calculated as 1 - density. It measures how many (proportion) potential connections are missing.}
#'
#' @details
#' The summary function extracts and presents key statistics about the structure of each
#' intersection kNN graph in the iknn_graphs object. All graphs share the same number of vertices
#' (equal to the number of rows in the input data matrix), but they differ in the number of edges
#' due to varying k values and the pruning methods applied during graph creation.
#'
#' The function displays general information about the graph sequence, including the number of vertices,
#' the range of k values, and the pruning parameters used. It then presents a tabular summary of statistics
#' for each individual graph, showing how the graph structure changes as k increases.
#'
#' For each intersection kNN graph, the following metrics are calculated:
#' - Number of edges: Total number of connections in the graph
#' - Mean degree: Average number of connections per vertex
#' - Min/Max degree: Range of vertex connectivity
#' - Density: Proportion of potential connections that are actually present
#' - Sparsity: 1 - density, measuring the proportion of missing connections
#'
#' @examples
#' # Create sample data
#' set.seed(123)
#' x <- matrix(rnorm(1000), ncol = 5)
#'
#' # Generate intersection kNN graphs
#' iknn.res <- create.iknn.graphs(
#'   x,
#'   kmin = 3,
#'   kmax = 10,
#'   n.cores = 1,
#'   with.isize.pruning = TRUE
#' )
#'
#' # Summarize the geometrically pruned graphs
#' summary(iknn.res)
#'
#' # Summarize the intersection-size pruned graphs
#' summary(iknn.res, use.isize.pruned = TRUE)
#'
#' @seealso \code{\link{create.iknn.graphs}} for creating intersection kNN graphs.
#'
#' @export
summary.iknn_graphs <- function(object,
                                use.isize.pruned = FALSE,
                                ...) {

    ## Check if the object is of the correct class
    if (!inherits(object, "iknn_graphs")) {
        stop("Object must be of class 'iknn_graphs'")
    }

    ## Determine which graphs to use
    if (use.isize.pruned) {
        graphs_to_use <- object$isize_pruned_graphs
        graph_type <- "intersection-size pruned"
        if (is.null(graphs_to_use)) {
            stop("Intersection-size pruned graphs not available. Set compute.full = TRUE and with.isize.pruning = TRUE when creating the graphs.")
        }
    } else {
        graphs_to_use <- object$geom_pruned_graphs
        graph_type <- "geometrically pruned"
        if (is.null(graphs_to_use)) {
            stop("Geometrically pruned graphs not available. Set compute.full = TRUE when creating the graphs.")
        }
    }

    ## Extract relevant information
    kmin <- attr(object, "kmin")
    kmax <- attr(object, "kmax")
    max_path_edge_ratio_deviation_thld <- attr(object, "max_path_edge_ratio_deviation_thld")
    path_edge_ratio_percentile <- attr(object, "path_edge_ratio_percentile")

    ## Get number of vertices (same for all graphs)
    n_vertices <- length(graphs_to_use[[1]]$adj_list)

    ## Initialize table of statistics
    k_values <- kmin:kmax
    n_graphs <- length(k_values)
    stats_table <- data.frame(
        idx = seq_along(k_values),
        k = k_values,
        n_ccomp = numeric(n_graphs),
        edges = numeric(n_graphs),
        mean_degree = numeric(n_graphs),
        min_degree = numeric(n_graphs),
        max_degree = numeric(n_graphs),
        sparsity = numeric(n_graphs),
        stringsAsFactors = FALSE
    )

    ## Calculate statistics for each graph
    for (i in 1:n_graphs) {
        graph <- graphs_to_use[[i]]
        adj_list <- graph$adj_list
        weight_list <- graph$weight_list

        ## Calculate number of edges (sum of adjacency list lengths divided by 2 because each edge is counted twice)
        edge_count <- sum(sapply(adj_list, length)) / 2

        ## Calculate degrees for each vertex
        degrees <- sapply(adj_list, length)

        ## Calculate mean degree
        mean_deg <- mean(degrees)

        ## Calculate min and max degree
        min_deg <- min(degrees)
        max_deg <- max(degrees)

        ## Calculate graph density (ratio of actual edges to potential edges)
        density <- edge_count / (n_vertices * (n_vertices - 1) / 2)

        ## Sparsity measures how many potential connections are missing
        sparsity <- 1 - density

        ## Number of connected components
        n.ccomp <- length(table(graph.connected.components(adj_list)))

        ## Store statistics
        stats_table$edges[i] <- edge_count
        stats_table$mean_degree[i] <- mean_deg
        stats_table$min_degree[i] <- min_deg
        stats_table$max_degree[i] <- max_deg
        stats_table$sparsity[i] <- sparsity
        stats_table$n_ccomp[i] <- n.ccomp
    }

    ## Print summary
    cat("Summary of iknn_graphs object\n")
    cat("----------------------------\n")
    cat("Number of vertices:", n_vertices, "\n")
    cat("k range:", kmin, "to", kmax, "\n")
    cat("Max path-edge ratio deviation threshold:", max_path_edge_ratio_deviation_thld, "\n")
    cat("Path-edge ratio percentile:", path_edge_ratio_percentile, "\n")
    cat("Graph type:", graph_type, "\n\n")

    ## Round numeric columns for cleaner display
    stats_table$mean_degree <- round(stats_table$mean_degree, 2)
    stats_table$sparsity <- round(stats_table$sparsity, 5)

    ## Print table
    print(stats_table, row.names = FALSE)

    ## Return the statistics table invisibly
    invisible(stats_table)
}
