#' Construct a Minimal Spanning Tree (MST) Completion Graph
#'
#' Constructs a completion of the Minimal Spanning Tree (MST) graph from a
#' numeric data matrix. The graph is constructed in two steps: first, a MST is
#' built connecting all data points using minimal total edge length; then,
#' additional edges are added between any pair of points whose Euclidean
#' distance is less than or equal to a quantile threshold based on the MST edge
#' length distribution.
#'
#' @param X A numeric matrix or data frame of shape \eqn{n \times d}, where
#'   each row represents a data point in d-dimensional space.
#' @param q.thld Numeric scalar between 0 and 1 (exclusive). The quantile
#'   threshold for MST completion. Edges are added between points whose
#'   distance is less than or equal to the q.thld-quantile of MST edge weights.
#'   Default is 0.9.
#' @param pca.dim Positive integer or NULL. If provided and \code{ncol(X) > pca.dim},
#'   dimensionality is reduced to this many principal components before graph
#'   construction. Must be less than min(n-1, p) where n is the number of
#'   observations and p is the number of variables. Default is 100.
#' @param variance.explained Numeric between 0 and 1 (exclusive) or NULL. If
#'   provided, selects the minimal number of PCA components such that this
#'   proportion of total variance is retained (up to \code{pca.dim} components).
#'   Ignored if \code{pca.dim} is NULL. Default is 0.99.
#' @param verbose Logical. If \code{TRUE}, prints progress messages during
#'   computation. Default is \code{TRUE}.
#'
#' @details
#' The MST completion process enhances connectivity in the original MST by
#' adding edges between vertices that are "close" according to the distance
#' distribution in the MST. This can be useful for creating more robust graph
#' representations of data that maintain local structure while avoiding
#' long-range connections.
#'
#' When PCA is applied (either through \code{pca.dim} or \code{variance.explained}),
#' the data is first centered and projected onto the leading principal components
#' before graph construction. This can significantly reduce computation time
#' for high-dimensional data while preserving the most important variation.
#'
#' @return An object of class \code{mst_completion_graph}, which is a list
#'   containing:
#'   \describe{
#'     \item{\code{mst_adj_list}}{A list of length n, where element i contains
#'       the indices of vertices adjacent to vertex i in the MST.}
#'     \item{\code{mst_weight_list}}{A list of length n, where element i
#'       contains the edge weights corresponding to the adjacent vertices in
#'       \code{mst_adj_list[[i]]}.}
#'     \item{\code{cmst_adj_list}}{A list of length n containing adjacency
#'       information for the completed MST graph.}
#'     \item{\code{cmst_weight_list}}{A list of length n containing edge
#'       weights for the completed MST graph.}
#'     \item{\code{mst_edge_weights}}{Numeric vector containing all unique MST
#'       edge weights.}
#'     \item{\code{cmst_distance_threshold}}{Numeric scalar containing the
#'       actual Euclidean distance threshold used for completion.}
#'   }
#'
#'   The returned object also has the following attributes:
#'   \describe{
#'     \item{\code{q_thld}}{The quantile threshold used for MST completion.}
#'     \item{\code{pca}}{If PCA was applied, a list containing:
#'       \itemize{
#'         \item \code{original_dim}: The original number of dimensions
#'         \item \code{n_components}: The number of PCA components used
#'         \item \code{variance_explained}: The proportion of variance explained
#'         \item \code{cumulative_variance}: Cumulative variance by component (if applicable)
#'       }
#'     }
#'     \item{\code{call}}{The matched function call.}
#'   }
#'
#' @examples
#' \dontrun{
#' # Generate sample data
#' set.seed(123)
#' X <- matrix(rnorm(100 * 3), nrow = 100, ncol = 3)
#'
#' # Create MST completion graph with default parameters
#' graph <- create.cmst.graph(X)
#'
#' # Create graph with PCA dimensionality reduction
#' X_high <- matrix(rnorm(100 * 200), nrow = 100, ncol = 200)
#' graph_pca <- create.cmst.graph(X_high, pca.dim = 50, variance.explained = 0.95)
#'
#' # Print summary
#' print(graph_pca)
#' summary(graph_pca)
#' }
#' @seealso
#' \code{\link[stats:prcomp]{stats::prcomp()}} for principal component analysis.
#'
#' @references
#' Gower, J. C., & Ross, G. J. S. (1969). Minimum spanning trees and single
#' linkage cluster analysis. Applied Statistics, 18(1), 54-64.
#'
#' @export
create.cmst.graph <- function(X,
                              q.thld = 0.9,
                              pca.dim = 100,
                              variance.explained = 0.99,
                              verbose = TRUE) {

    # Store the original call for later reference
    cl <- match.call()

    # Input validation for X
    if (!is.matrix(X) && !is.data.frame(X)) {
        stop("'X' must be a matrix or data frame", call. = FALSE)
    }

    # Convert to matrix if necessary
    if (!is.matrix(X)) {
        X <- as.matrix(X)
    }

    # Check numeric type
    if (!is.numeric(X)) {
        stop("'X' must contain numeric values", call. = FALSE)
    }

    # Check for missing or infinite values
    if (anyNA(X)) {
        stop("'X' contains missing values (NA/NaN)", call. = FALSE)
    }

    if (any(is.infinite(X))) {
        stop("'X' contains infinite values", call. = FALSE)
    }

    if (!is.double(X)) {
        storage.mode(X) <- "double"
    }

    # Check dimensions
    n <- nrow(X)
    p <- ncol(X)

    if (n < 2L) {
        stop("'X' must contain at least 2 observations (rows)", call. = FALSE)
    }

    if (p < 1L) {
        stop("'X' must contain at least 1 variable (column)", call. = FALSE)
    }

    # Validate q.thld
    if (!is.numeric(q.thld) || length(q.thld) != 1L) {
        stop("'q.thld' must be a single numeric value", call. = FALSE)
    }

    if (is.na(q.thld) || q.thld <= 0 || q.thld >= 1) {
        stop("'q.thld' must be a value strictly between 0 and 1", call. = FALSE)
    }

    # Validate pca.dim
    if (!is.null(pca.dim)) {
        if (!is.numeric(pca.dim) || length(pca.dim) != 1L) {
            stop("'pca.dim' must be a single numeric value or NULL", call. = FALSE)
        }

        if (is.na(pca.dim) || pca.dim < 1 || pca.dim != floor(pca.dim)) {
            stop("'pca.dim' must be a positive integer", call. = FALSE)
        }

        # Check against data dimensions
        max_components <- min(n - 1L, p)
        if (pca.dim > max_components) {
            warning(sprintf("'pca.dim' (%d) exceeds maximum possible components (%d), using %d",
                          pca.dim, max_components, max_components),
                    call. = FALSE)
            pca.dim <- max_components
        }
    }

    # Validate variance.explained
    if (!is.null(variance.explained)) {
        if (!is.numeric(variance.explained) || length(variance.explained) != 1L) {
            stop("'variance.explained' must be a single numeric value or NULL",
                 call. = FALSE)
        }

        if (is.na(variance.explained) || variance.explained <= 0 ||
            variance.explained >= 1) {
            stop("'variance.explained' must be a value strictly between 0 and 1",
                 call. = FALSE)
        }
    }

    # Validate verbose
    if (!is.logical(verbose) || length(verbose) != 1L || is.na(verbose)) {
        stop("'verbose' must be TRUE or FALSE", call. = FALSE)
    }

    # Apply PCA if needed
    pca_info <- NULL

    if (!is.null(pca.dim) && p > pca.dim) {
        if (verbose) {
            message(sprintf("Applying PCA: reducing from %d to at most %d dimensions",
                          p, pca.dim))
        }

        original_dim <- p

        # Handle variance.explained if specified
        if (!is.null(variance.explained)) {
            # Determine optimal components
            pca_analysis <- pca.optimal.components(
                X,
                variance.threshold = variance.explained,
                max.components = pca.dim
            )

            n_components <- pca_analysis$n.components

            if (verbose) {
                message(sprintf(
                    "Selected %d principal components (%.1f%% variance explained)",
                    n_components,
                    pca_analysis$variance.explained * 100
                ))
            }

            # Project data
            X <- pca.project(X, pca_analysis$pca.result, n_components)

            # Store PCA metadata
            pca_info <- list(
                original_dim = original_dim,
                n_components = n_components,
                variance_explained = pca_analysis$variance.explained,
                cumulative_variance = pca_analysis$cumulative.variance
            )

        } else {
            # Use fixed number of components
            if (verbose) {
                message(sprintf("Projecting onto first %d principal components",
                              pca.dim))
            }

            # Perform PCA
            pca_result <- stats::prcomp(X, center = TRUE, scale. = FALSE)

            # Ensure we don't exceed available components
            n_components <- min(pca.dim, length(pca_result$sdev))

            # Project data
            X <- pca.project(X, pca_result, n_components)

            # Calculate variance explained
            var_explained <- sum(pca_result$sdev[1:n_components]^2) /
                           sum(pca_result$sdev^2)

            # Store PCA metadata
            pca_info <- list(
                original_dim = original_dim,
                n_components = n_components,
                variance_explained = var_explained
            )
        }
    }

    result <- .Call("S_create_mst_completion_graph",
                    X,
                    as.double(q.thld),
                    as.logical(verbose))

    # Validate the result structure
    expected_names <- c("mst_adj_list", "mst_weight_list",
                       "cmst_adj_list", "cmst_weight_list",
                       "mst_edge_weights", "cmst_distance_threshold")

    if (!is.list(result) || !all(expected_names %in% names(result))) {
        stop("Internal error: unexpected result structure from compiled code",
             call. = FALSE)
    }

    # Add attributes
    attr(result, "q_thld") <- q.thld
    attr(result, "cmst_distance_threshold") <- result$cmst_distance_threshold
    attr(result, "call") <- cl

    if (!is.null(pca_info)) {
        attr(result, "pca") <- pca_info
    }

    # Set class
    class(result) <- c("mst_completion_graph", "list")

    result
}


#' Print Method for MST Completion Graph Objects
#'
#' @description
#' Displays a concise summary of an MST completion graph object, including
#' basic graph statistics and parameter information.
#'
#' @param x An object of class \code{mst_completion_graph}, as returned by
#'   \code{\link{create.cmst.graph}}.
#' @param ... Additional arguments (currently ignored).
#'
#' @details
#' This method provides a human-readable overview of the graph structure without
#' displaying the full adjacency lists. For detailed inspection of graph
#' components, use direct indexing (e.g., \code{x$mst_adj_list}) or the
#' \code{\link{summary}} method.
#'
#' @return
#' Invisibly returns the input object \code{x}.
#'
#' @examples
#' graph <- list(
#'   mst_adj_list = list(c(2L), c(1L, 3L), c(2L)),
#'   mst_weight_list = list(1.1, c(1.1, 0.9), 0.9),
#'   cmst_adj_list = list(c(2L, 3L), c(1L, 3L), c(1L, 2L)),
#'   cmst_weight_list = list(c(1.1, 1.4), c(1.1, 0.9), c(1.4, 0.9)),
#'   mst_edge_weights = c(1.1, 0.9),
#'   cmst_distance_threshold = 1.08
#' )
#' attr(graph, "q_thld") <- 0.8
#' attr(graph, "cmst_distance_threshold") <- graph$cmst_distance_threshold
#' class(graph) <- c("mst_completion_graph", "list")
#'
#' print(graph)
#'
#' @seealso
#' \code{\link{summary.mst_completion_graph}} for more detailed summaries,
#' \code{\link{create.cmst.graph}} for creating MST completion graphs
#'
#' @export
print.mst_completion_graph <- function(x, ...) {
    cat("Minimal Spanning Tree Completion Graph\n")
    cat("======================================\n")

    # Basic graph information
    n_vertices <- length(x$mst_adj_list)
    n_mst_edges <- length(x$mst_edge_weights)
    q_thld <- attr(x, "q_thld")
    completion_threshold <- attr(x, "cmst_distance_threshold")
    if (is.null(completion_threshold)) {
        completion_threshold <- x$cmst_distance_threshold
    }

    cat(sprintf("Number of vertices: %d\n", n_vertices))
    cat(sprintf("Number of MST edges: %d\n", n_mst_edges))
    cat(sprintf("Quantile threshold: %.3f\n", q_thld))
    if (!is.null(completion_threshold)) {
        cat(sprintf("Distance threshold: %.3f\n", completion_threshold))
    }

    # Count completed graph edges
    n_cmst_edges <- sum(lengths(x$cmst_adj_list)) / 2
    cat(sprintf("Number of completed graph edges: %d\n", n_cmst_edges))
    cat(sprintf("Edge increase factor: %.2fx\n", n_cmst_edges / n_mst_edges))

    # PCA information if available
    pca_info <- attr(x, "pca")
    if (!is.null(pca_info)) {
        cat("\nPCA dimensionality reduction:\n")
        cat(sprintf("  Original dimensions: %d\n", pca_info$original_dim))
        cat(sprintf("  PCA components used: %d\n", pca_info$n_components))
        cat(sprintf("  Variance explained: %.1f%%\n",
                  pca_info$variance_explained * 100))
    }

    invisible(x)
}


#' Summary Method for MST Completion Graph Objects
#'
#' @description
#' Computes and returns a comprehensive summary of an MST completion graph,
#' including graph statistics, edge weight distributions, and PCA information
#' if applicable.
#'
#' @param object An object of class \code{mst_completion_graph}.
#' @param ... Additional arguments (currently ignored).
#'
#' @return
#' An object of class \code{summary.mst_completion_graph} containing:
#' \describe{
#'   \item{\code{n_vertices}}{Number of vertices in the graph}
#'   \item{\code{n_mst_edges}}{Number of edges in the minimal spanning tree}
#'   \item{\code{n_cmst_edges}}{Number of edges in the completed graph}
#'   \item{\code{q_thld}}{Quantile threshold used for completion}
#'   \item{\code{edge_weight_summary}}{Five-number summary of MST edge weights}
#'   \item{\code{completion_threshold}}{The actual distance threshold used}
#'   \item{\code{pca_applied}}{Logical indicating if PCA was applied}
#'   \item{\code{pca_info}}{PCA details (if applicable)}
#' }
#'
#' @examples
#' graph <- list(
#'   mst_adj_list = list(c(2L), c(1L, 3L), c(2L)),
#'   mst_weight_list = list(1.1, c(1.1, 0.9), 0.9),
#'   cmst_adj_list = list(c(2L, 3L), c(1L, 3L), c(1L, 2L)),
#'   cmst_weight_list = list(c(1.1, 1.4), c(1.1, 0.9), c(1.4, 0.9)),
#'   mst_edge_weights = c(1.1, 0.9),
#'   cmst_distance_threshold = 1.08
#' )
#' attr(graph, "q_thld") <- 0.8
#' attr(graph, "cmst_distance_threshold") <- graph$cmst_distance_threshold
#' class(graph) <- c("mst_completion_graph", "list")
#'
#' summary(graph)
#'
#' @seealso
#' \code{\link{print.summary.mst_completion_graph}} for printing summaries,
#' \code{\link{create.cmst.graph}} for creating graphs
#'
#' @export
summary.mst_completion_graph <- function(object, ...) {
    # Basic counts
    n_vertices <- length(object$mst_adj_list)
    n_mst_edges <- length(object$mst_edge_weights)
    n_cmst_edges <- sum(lengths(object$cmst_adj_list)) / 2

    # Edge weight statistics
    edge_summary <- summary(object$mst_edge_weights)

    # Completion threshold (actual distance value)
    q_thld <- attr(object, "q_thld")
    completion_threshold <- attr(object, "cmst_distance_threshold")
    if (is.null(completion_threshold)) {
        completion_threshold <- object$cmst_distance_threshold
    }
    if (is.null(completion_threshold)) {
        completion_threshold <- stats::quantile(object$mst_edge_weights,
                                                probs = q_thld,
                                                names = FALSE)
    }

    # Create summary object
    out <- list(
        n_vertices = n_vertices,
        n_mst_edges = n_mst_edges,
        n_cmst_edges = n_cmst_edges,
        q_thld = q_thld,
        edge_weight_summary = edge_summary,
        completion_threshold = completion_threshold,
        pca_applied = !is.null(attr(object, "pca"))
    )

    # Add PCA information if available
    if (out$pca_applied) {
        out$pca_info <- attr(object, "pca")
    }

    class(out) <- "summary.mst_completion_graph"
    out
}


#' Print Summary of MST Completion Graph
#'
#' @description
#' Formats and displays the summary information for an MST completion graph
#' in a readable format.
#'
#' @param x An object of class \code{summary.mst_completion_graph}, as returned
#'   by \code{\link{summary.mst_completion_graph}}.
#' @param digits Integer; number of significant digits for numeric output.
#'   Default is 3.
#' @param ... Additional arguments (currently ignored).
#'
#' @return
#' Invisibly returns the input summary object.
#'
#' @examples
#' graph <- list(
#'   mst_adj_list = list(c(2L), c(1L, 3L), c(2L)),
#'   mst_weight_list = list(1.1, c(1.1, 0.9), 0.9),
#'   cmst_adj_list = list(c(2L, 3L), c(1L, 3L), c(1L, 2L)),
#'   cmst_weight_list = list(c(1.1, 1.4), c(1.1, 0.9), c(1.4, 0.9)),
#'   mst_edge_weights = c(1.1, 0.9),
#'   cmst_distance_threshold = 1.08
#' )
#' attr(graph, "q_thld") <- 0.8
#' attr(graph, "cmst_distance_threshold") <- graph$cmst_distance_threshold
#' class(graph) <- c("mst_completion_graph", "list")
#'
#' graph_summary <- summary(graph)
#' print(graph_summary, digits = 4)
#'
#' @export
print.summary.mst_completion_graph <- function(x, digits = 3L, ...) {
    cat("Summary of MST Completion Graph\n")
    cat("===============================\n\n")

    # Graph structure
    cat("Graph Structure:\n")
    cat(sprintf("  Vertices: %d\n", x$n_vertices))
    cat(sprintf("  MST edges: %d\n", x$n_mst_edges))
    cat(sprintf("  Completed graph edges: %d (%.1fx increase)\n",
              x$n_cmst_edges, x$n_cmst_edges / x$n_mst_edges))

    # Edge weight distribution
    cat("\nMST Edge Weight Distribution:\n")
    ew_summary <- x$edge_weight_summary
    cat(sprintf("  Min:    %.*f\n", digits, ew_summary["Min."]))
    cat(sprintf("  Q1:     %.*f\n", digits, ew_summary["1st Qu."]))
    cat(sprintf("  Median: %.*f\n", digits, ew_summary["Median"]))
    cat(sprintf("  Mean:   %.*f\n", digits, ew_summary["Mean"]))
    cat(sprintf("  Q3:     %.*f\n", digits, ew_summary["3rd Qu."]))
    cat(sprintf("  Max:    %.*f\n", digits, ew_summary["Max."]))

    # Completion information
    cat("\nCompletion Parameters:\n")
    cat(sprintf("  Quantile threshold: %.3f\n", x$q_thld))
    cat(sprintf("  Distance threshold: %.*f\n", digits, x$completion_threshold))

    # PCA information
    if (x$pca_applied) {
        cat("\nPCA Dimensionality Reduction:\n")
        cat(sprintf("  Original dimensions: %d\n", x$pca_info$original_dim))
        cat(sprintf("  Components used: %d\n", x$pca_info$n_components))
        cat(sprintf("  Variance explained: %.1f%%\n",
                  x$pca_info$variance_explained * 100))

        # Show cumulative variance if available
        if (!is.null(x$pca_info$cumulative_variance) &&
            length(x$pca_info$cumulative_variance) > 0) {
            n_show <- min(5, length(x$pca_info$cumulative_variance))
            cat("  Cumulative variance by component:\n")
            for (i in 1:n_show) {
                cat(sprintf("    PC%d: %.1f%%\n", i,
                          x$pca_info$cumulative_variance[i] * 100))
            }
            if (n_show < length(x$pca_info$cumulative_variance)) {
                cat("    ...\n")
            }
        }
    }

    invisible(x)
}
