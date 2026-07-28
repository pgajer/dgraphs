#' Compute a Mutual k-Nearest Neighbor Graph with Weights
#'
#' @description
#' Creates an undirected graph where two points are connected by an edge if and
#' only if they are present in each other's k-nearest neighbor (kNN) lists.
#' The weight of each edge represents the distance between the connected vertices.
#'
#' @param X A numeric matrix or data frame where each row represents a data point
#'   and each column represents a feature/dimension.
#' @param k A positive integer specifying the number of nearest neighbors to
#'   consider. Must be at least 2.
#' @param prune.method Character scalar. `"none"` disables geometric pruning.
#'   `"local.geodesic"` applies the experimental local geometric pruning stage
#'   before optional MST connectivity repair. `"global.geodesic.ratio"` applies
#'   whole-graph geodesic-ratio pruning before optional MST connectivity repair.
#' @param max.path.edge.ratio.deviation.thld Numeric scalar in `[0, 0.2)`.
#'   For `prune.method = "global.geodesic.ratio"`, an edge may be removed when
#'   the shortest alternative path is at most
#'   `1 + max.path.edge.ratio.deviation.thld` times the direct edge length.
#' @param path.edge.ratio.percentile Numeric scalar in `[0, 1]`. For
#'   `prune.method = "global.geodesic.ratio"`, only edges at or above this edge
#'   length percentile are considered.
#' @param prune.tau Numeric scalar greater than 1. For local geometric pruning,
#'   an edge may be removed when a retained local alternative path is at most
#'   this multiplicative factor times the direct edge length.
#' @param prune.local.k Integer scalar or `NULL`. Number of nearest neighbors
#'   used to form local neighborhoods for pruning. Defaults to `k`.
#' @param with.pruned.edge.stats Logical scalar. If `TRUE`, return a data frame
#'   with one row per locally pruned edge.
#' @param connect.components Logical scalar. If `TRUE`, add MST bridge edges
#'   so the final graph is connected whenever possible.
#' @param connect.method Character scalar. `"component.mst"` adds exact shortest
#'   inter-component bridges. `"component.mst.ann"` tries sparse ANN bridge
#'   candidates before automatic exact fallback. `"global.mst"` unions the graph
#'   with the full Euclidean MST.
#' @param bridge.k Integer scalar or `NULL`. Initial ANN bridge neighborhood
#'   size for `connect.method = "component.mst.ann"`.
#' @param bridge.k.max Integer scalar or `NULL`. Maximum ANN bridge neighborhood
#'   size before exact fallback.
#' @param bridge.growth Numeric scalar greater than 1. Multiplicative growth
#'   factor for ANN bridge neighborhoods.
#'
#' @return A list with class "mknn_graph" containing:
#'   \describe{
#'     \item{adj_list}{A list where element i contains the indices of vertices
#'       connected to vertex i by an edge in the final graph after optional MST
#'       component repair.}
#'     \item{weight_list}{A list where element i contains the distances between
#'       vertex i and its connected neighbors in the final graph (in the same
#'       order as \code{adj_list[[i]]}).}
#'     \item{raw_adj_list, raw_weight_list}{The native mutual-kNN graph before
#'       pruning and before optional MST component repair.}
#'     \item{pruned_adj_list, pruned_weight_list}{The graph after optional local
#'       geometric pruning and before optional MST component repair. If pruning
#'       is disabled, these fields are identical to the raw graph.}
#'     \item{raw_repaired_adj_list, raw_repaired_weight_list}{The native mutual
#'       kNN graph after MST component repair.}
#'     \item{pruned_repaired_adj_list, pruned_repaired_weight_list}{The
#'       prune-first branch after MST component repair.}
#'     \item{repaired_pruned_adj_list, repaired_pruned_weight_list}{The
#'       repair-first branch after applying local geometric pruning to the
#'       repaired raw graph.}
#'     \item{n_vertices}{The number of vertices in the graph.}
#'     \item{n_edges}{The total number of edges in the graph.}
#'     \item{k}{The k value used to construct the graph.}
#'   }
#'
#' @details
#' The mutual k-nearest neighbor graph is a symmetric graph where an edge between
#' vertices i and j exists if and only if:
#' \itemize{
#'   \item j is among the k nearest neighbors of i, AND
#'   \item i is among the k nearest neighbors of j
#' }
#'
#' This mutual relationship ensures that the resulting graph is undirected and
#' typically sparser than a standard k-nearest neighbor graph.
#'
#' The final graph is always stored in \code{adj_list}/\code{weight_list}.
#' Lifecycle diagnostic fields follow the same convention as the other graph
#' constructors: \code{raw_*} is before pruning and MST repair, and
#' \code{pruned_*} is after pruning but before MST repair.
#' The \code{raw_repaired_*}, \code{pruned_repaired_*}, and
#' \code{repaired_pruned_*} branches allow one constructor call to compare
#' native, prune-first, and repair-first graph geodesic geometries.
#'
#' @examples
#' set.seed(123)
#' X <- matrix(rnorm(60), ncol = 2)
#' graph <- create.mknn.graph(X, k = 4)
#' graph$n_vertices
#' graph$n_edges
#' graph$adj_list[[1]]
#'
#' @seealso
#' \code{\link{create.mknn.graphs}} for creating multiple graphs with different k values,
#' \code{\link{summary.mknn_graphs}} for summarizing graph properties
#'
#' @export
create.mknn.graph <- function(X,
                              k,
                              prune.method = c("none", "local.geodesic", "global.geodesic.ratio"),
                              max.path.edge.ratio.deviation.thld = 0.1,
                              path.edge.ratio.percentile = 0.5,
                              prune.tau = 1.05,
                              prune.local.k = NULL,
                              with.pruned.edge.stats = FALSE,
                              connect.components = FALSE,
                              connect.method = c("component.mst", "component.mst.ann", "global.mst"),
                              bridge.k = NULL,
                              bridge.k.max = NULL,
                              bridge.growth = 2) {
  # Input validation
  if (!is.numeric(k) || length(k) != 1) {
    stop("'k' must be a single numeric value.", call. = FALSE)
  }

  k <- as.integer(k)
  if (k < 2) {
    stop("'k' must be at least 2.", call. = FALSE)
  }

  # Validate X
  if (!(is.matrix(X) || is.data.frame(X))) {
    stop("'X' must be a matrix or data frame.", call. = FALSE)
  }

  # Convert data frame to matrix if necessary
  if (is.data.frame(X)) {
    X <- as.matrix(X)
  }

  # Check for numeric data
  if (!is.numeric(X)) {
    stop("'X' must contain numeric data.", call. = FALSE)
  }

    if (!is.double(X)) {
        storage.mode(X) <- "double"
    }

  # Check for missing values
  if (any(is.na(X))) {
    stop("'X' cannot contain NA values.", call. = FALSE)
  }

  # Check dimensions
  n <- nrow(X)
  if (n < k + 1) {
    stop(sprintf("Number of data points (%d) must be greater than k (%d).",
                 n, k), call. = FALSE)
  }
  if (!is.logical(connect.components) || length(connect.components) != 1L ||
      is.na(connect.components)) {
    stop("'connect.components' must be TRUE or FALSE.", call. = FALSE)
  }
  prune.method <- .normalize.prune.method(prune.method)
  prune.controls <- .normalize.local.prune.controls(
    n, k, prune.tau, prune.local.k, with.pruned.edge.stats
  )
  global.ratio.controls <- .normalize.global.ratio.prune.controls(
    max.path.edge.ratio.deviation.thld,
    path.edge.ratio.percentile
  )
  connect.method <- match.arg(connect.method)
  bridge.controls <- .normalize.bridge.controls(n, k, bridge.k, bridge.k.max, bridge.growth)

  # Call C++ implementation
  # Note: k+1 because the C++ code includes the point itself in the kNN search
    result <- .Call("S_create_mknn_graph",
                    X,
                    as.integer(k + 1))
  raw.adj.list <- result$adj_list
  raw.weight.list <- result$weight_list

  if (!identical(prune.method, "none")) {
    pruning <- .prune.graph.by.method(
      X = X,
      adj.list = result$adj_list,
      weight.list = result$weight_list,
      k = k,
      prune.method = prune.method,
      max.path.edge.ratio.deviation.thld =
        global.ratio.controls$max.path.edge.ratio.deviation.thld,
      path.edge.ratio.percentile = global.ratio.controls$path.edge.ratio.percentile,
      prune.tau = prune.controls$prune.tau,
      prune.local.k = prune.controls$prune.local.k,
      with.pruned.edge.stats = prune.controls$with.pruned.edge.stats
    )
    result$adj_list <- pruning$adj_list
    result$weight_list <- pruning$weight_list
  } else {
    n.edges.raw <- nrow(.graph.edge.table(result$adj_list, result$weight_list))
    pruning <- list(
      n_edges_before_pruning = n.edges.raw,
      n_edges_after_pruning = n.edges.raw,
      n_pruned_edges = 0L,
      pruned_edge_stats = .empty.pruned.edge.stats(),
      prune_tau = prune.controls$prune.tau,
      prune_local_k = prune.controls$prune.local.k,
      with_pruned_edge_stats = prune.controls$with.pruned.edge.stats
    )
  }
  pruned.adj.list <- result$adj_list
  pruned.weight.list <- result$weight_list
  n.edges.before.mst <- pruning$n_edges_after_pruning

  bridge <- .augment.graph.with.component.mst(
    X = X,
    adj.list = result$adj_list,
    weight.list = result$weight_list,
    k = k,
    connect.components = connect.components,
    connect.method = connect.method,
    bridge.k = bridge.controls$bridge.k,
    bridge.k.max = bridge.controls$bridge.k.max,
    bridge.growth = bridge.controls$bridge.growth
  )
  result$adj_list <- bridge$adj_list
  result$weight_list <- bridge$weight_list

  # Add metadata to result
  result$n_vertices <- n
  result$n_edges <- sum(sapply(result$adj_list, length)) / 2  # Divide by 2 for undirected graph
  result$raw_adj_list <- raw.adj.list
  result$raw_weight_list <- raw.weight.list
  result$pruned_adj_list <- pruned.adj.list
  result$pruned_weight_list <- pruned.weight.list
  result <- .add.graph.lifecycle.branches(
    result = result,
    X = X,
    k = k,
    raw.adj.list = result$raw_adj_list,
    raw.weight.list = result$raw_weight_list,
    pruned.adj.list = result$pruned_adj_list,
    pruned.weight.list = result$pruned_weight_list,
    connect.method = connect.method,
    bridge.k = bridge.controls$bridge.k,
    bridge.k.max = bridge.controls$bridge.k.max,
    bridge.growth = bridge.controls$bridge.growth,
    prune.method = prune.method,
    max.path.edge.ratio.deviation.thld =
      global.ratio.controls$max.path.edge.ratio.deviation.thld,
    path.edge.ratio.percentile = global.ratio.controls$path.edge.ratio.percentile,
    prune.tau = prune.controls$prune.tau,
    prune.local.k = prune.controls$prune.local.k,
    with.pruned.edge.stats = prune.controls$with.pruned.edge.stats
  )
  result$n_edges_before_pruning <- pruning$n_edges_before_pruning
  result$n_edges_after_pruning <- pruning$n_edges_after_pruning
  result$n_pruned_edges <- pruning$n_pruned_edges
  result$pruned_edge_stats <- pruning$pruned_edge_stats
  result$prune_method <- prune.method
  result$prune_tau <- pruning$prune_tau
  result$prune_local_k <- pruning$prune_local_k
  result$with_pruned_edge_stats <- pruning$with_pruned_edge_stats
  result$n_edges_before_mst <- n.edges.before.mst
  result$n_edges_after_mst <- result$n_edges
  result$k <- k
  result$n_components_before <- bridge$n_components_before
  result$n_components_after <- bridge$n_components_after
  result$component_id_before <- bridge$component_id_before
  result$component_id_after <- bridge$component_id_after
  result$mst_edge_matrix <- bridge$mst_edge_matrix
  result$mst_edge_weight <- bridge$mst_edge_weight
  result$n_mst_edges_added <- bridge$n_mst_edges_added
  result$connect_components <- bridge$connect_components
  result$connect_method <- bridge$connect_method
  result$bridge_method <- bridge$bridge_method
  result$bridge_k <- bridge$bridge_k
  result$bridge_k_max <- bridge$bridge_k_max
  result$bridge_growth <- bridge$bridge_growth
  result$bridge_k_used <- bridge$bridge_k_used
  result$bridge_exact_fallback_used <- bridge$bridge_exact_fallback_used

  # Set class
  class(result) <- c("mknn_graph", "list")

  return(result)
}


#' Create Multiple Mutual kNN Graphs with Geometric Pruning
#'
#' @description
#' Constructs a series of mutual k-nearest neighbor (MkNN) graphs across a range
#' of k values, with optional geometric pruning to remove redundant edges based
#' on alternative path analysis.
#'
#' @param X A numeric matrix where rows represent data points and columns represent
#'   features. Data frames will be converted to matrices.
#' @param kmin Minimum k value to consider (positive integer, at least 2).
#' @param kmax Maximum k value to consider (must be >= kmin).
#' @param max.path.edge.ratio.thld Maximum acceptable ratio of alternative path
#'   length to direct edge length for pruning. Edges with alternative paths having
#'   ratio <= this value will be pruned. Default is 1.2. Set to 0 or negative to
#'   disable pruning.
#' @param path.edge.ratio.percentile Percentile threshold (0.0-1.0) for edge
#'   lengths to consider for pruning. Only edges with length greater than this
#'   percentile are evaluated. Default is 0.5.
#' @param compute.full Logical; if TRUE, returns complete graph structures for
#'   each k value. If FALSE, returns only summary statistics. Default is FALSE.
#' @param pca.dim Maximum number of principal components to use if dimensionality
#'   reduction is applied. Default is 100. Set to NULL to skip dimensionality reduction.
#' @param variance.explained Target percentage of variance to be explained by the
#'   principal components (0-1). Default is 0.99. If this can be achieved with
#'   fewer than pca.dim components, the smaller number is used. Set to NULL to
#'   use exactly pca.dim components.
#' @param verbose Logical; if TRUE, displays progress messages. Default is FALSE.
#'
#' @return An object of class "mknn_graphs" containing:
#'   \describe{
#'     \item{k_statistics}{A data frame with columns: k (k value), n_edges
#'       (edges before pruning), n_edges_pruned (edges after pruning),
#'       n_removed (number of removed edges), reduction_ratio (proportion of
#'       edges removed).}
#'     \item{pruned_graphs}{If compute.full=TRUE, a named list of pruned graphs
#'       for each k value. NULL otherwise.}
#'     \item{edge_pruning_stats}{A list of pruning statistics for each k value,
#'       containing edge lengths and path ratios.}
#'   }
#'
#'   The returned object also has the following attributes:
#'   \itemize{
#'     \item kmin, kmax: The k range used
#'     \item max.path.edge.ratio.thld: The pruning threshold used
#'     \item path.edge.ratio.percentile: The percentile threshold used
#'     \item pca: If PCA was performed, contains dimensionality reduction details
#'   }
#'
#' @details
#' This function performs the following steps for each k value:
#'
#' 1. **Mutual kNN Graph Construction**: Creates a graph where edges exist only
#'    between mutually nearest neighbors.
#'
#' 2. **Geometric Pruning** (optional): Removes edges where alternative paths
#'    exist with acceptable length ratios. An edge (i,j) is pruned if there
#'    exists a path i->k->j such that (d(i,k) + d(k,j)) / d(i,j) <= threshold.
#'
#' 3. **Dimensionality Reduction** (optional): If the data has more than pca.dim
#'    dimensions, PCA is applied before graph construction to improve computational
#'    efficiency and reduce noise.
#'
#' The geometric pruning step helps create sparser graphs by removing edges that
#' can be well-approximated by two-hop paths, which can improve graph quality
#' for clustering and visualization tasks.
#'
#' @examples
#' set.seed(123)
#' X <- matrix(rnorm(80), ncol = 2)
#' result <- create.mknn.graphs(
#'   X, kmin = 3, kmax = 4, compute.full = TRUE, verbose = FALSE
#' )
#' result$k_statistics
#'
#' X.high <- matrix(rnorm(120), nrow = 20, ncol = 6)
#' result.pca <- create.mknn.graphs(
#'   X.high, kmin = 2, kmax = 3, pca.dim = 3, verbose = FALSE
#' )
#' attr(result.pca, "pca")$n_components
#'
#' @seealso
#' \code{\link{create.mknn.graph}} for creating a single MkNN graph,
#' \code{\link{summary.mknn_graphs}} for summarizing the results
#'
#' @export
create.mknn.graphs <- function(X,
                              kmin,
                              kmax,
                              max.path.edge.ratio.thld = 1.2,
                              path.edge.ratio.percentile = 0.5,
                              compute.full = FALSE,
                              pca.dim = 100,
                              variance.explained = 0.99,
                              verbose = FALSE) {

    ## Convert data frame to matrix if necessary
    if (is.data.frame(X)) {
        X <- as.matrix(X)
    }

    ## Comprehensive input validation
    if (!is.matrix(X) || !is.numeric(X)) {
        stop("'X' must be a numeric matrix or data frame.", call. = FALSE)
    }

    if (any(is.na(X))) {
        stop("'X' cannot contain NA values.", call. = FALSE)
    }

    if (!is.double(X)) {
        storage.mode(X) <- "double"
    }

    ## Validate k parameters
    if (!is.numeric(kmin) || length(kmin) != 1 || kmin < 2) {
        stop("'kmin' must be a single integer >= 2.", call. = FALSE)
    }
    kmin <- as.integer(kmin)

    if (!is.numeric(kmax) || length(kmax) != 1 || kmax < kmin) {
        stop("'kmax' must be a single integer >= kmin.", call. = FALSE)
    }
    kmax <- as.integer(kmax)

    ## Check that we have enough data points
    n <- nrow(X)
    if (n <= kmax) {
        stop(sprintf("Number of data points (%d) must be greater than kmax (%d).",
                     n, kmax), call. = FALSE)
    }

    ## Validate other parameters
    if (!is.numeric(max.path.edge.ratio.thld) || length(max.path.edge.ratio.thld) != 1) {
        stop("'max.path.edge.ratio.thld' must be a single numeric value.", call. = FALSE)
    }

    if (!is.numeric(path.edge.ratio.percentile) || length(path.edge.ratio.percentile) != 1 ||
        path.edge.ratio.percentile < 0 || path.edge.ratio.percentile > 1) {
        stop("'path.edge.ratio.percentile' must be a single value between 0 and 1.",
             call. = FALSE)
    }

    if (!is.logical(compute.full) || length(compute.full) != 1) {
        stop("'compute.full' must be TRUE or FALSE.", call. = FALSE)
    }

    if (!is.logical(verbose) || length(verbose) != 1) {
        stop("'verbose' must be TRUE or FALSE.", call. = FALSE)
    }

    ## PCA dimensionality reduction if needed
    pca_info <- NULL
    X_original <- X

    if (!is.null(pca.dim) && ncol(X) > pca.dim) {
        if (verbose) {
            message(sprintf("Performing PCA: reducing from %d to max %d dimensions...",
                            ncol(X), pca.dim))
        }

        ## Store original dimensions
        original_dim <- ncol(X)

        ## Perform PCA
        pca_result <- stats::prcomp(X, center = TRUE, scale. = TRUE)

        ## Determine number of components to use
        if (!is.null(variance.explained) && variance.explained > 0 && variance.explained <= 1) {
            ## Find number of components needed for target variance
            cum_var <- cumsum(pca_result$sdev^2) / sum(pca_result$sdev^2)
            n_components <- min(which(cum_var >= variance.explained))
            n_components <- min(n_components, pca.dim)
            actual_var <- cum_var[n_components]
        } else {
            ## Use fixed number of components
            n_components <- min(pca.dim, ncol(X))
            actual_var <- sum(pca_result$sdev[1:n_components]^2) / sum(pca_result$sdev^2)
        }

        if (verbose) {
            message(sprintf("Using %d principal components (explains %.1f%% of variance)",
                            n_components, actual_var * 100))
        }

        ## Project data onto selected components
        X <- pca_result$x[, 1:n_components, drop = FALSE]

        ## Store PCA information
        pca_info <- list(
            original_dim = original_dim,
            n_components = n_components,
            variance_explained = actual_var,
            center = pca_result$center,
            scale = pca_result$scale,
            rotation = pca_result$rotation[, 1:n_components, drop = FALSE]
        )
    }

    ## Call C++ implementation
    ## Note: Adding 1 to k values for C++ compatibility (includes self in kNN)
    result <- .Call("S_create_mknn_graphs",
                    X,
                    as.integer(kmin + 1),
                    as.integer(kmax + 1),
                    as.double(max.path.edge.ratio.thld + 1.0),
                    as.double(path.edge.ratio.percentile),
                    as.logical(compute.full),
                    as.logical(verbose))

    ## Post-process results
    ## Ensure k_statistics is a proper data frame
    if (!is.null(result$k_statistics)) {
        result$k_statistics <- as.data.frame(result$k_statistics)
        names(result$k_statistics) <- c("k", "n_edges", "n_edges_pruned",
                                        "n_removed", "reduction_ratio")
        result$k_statistics$k <- kmin:kmax  ## Correct k values
    }

    ## Set names for pruned graphs
    if (compute.full && !is.null(result$pruned_graphs)) {
        names(result$pruned_graphs) <- as.character(kmin:kmax)

        ## Add metadata to each graph
        for (i in seq_along(result$pruned_graphs)) {
            result$pruned_graphs[[i]]$k <- kmin + i - 1
            result$pruned_graphs[[i]]$n_vertices <- n
            class(result$pruned_graphs[[i]]) <- c("mknn_graph", "list")
        }
    }

    ## Add attributes
    attr(result, "kmin") <- kmin
    attr(result, "kmax") <- kmax
    attr(result, "max.path.edge.ratio.thld") <- max.path.edge.ratio.thld
    attr(result, "path.edge.ratio.percentile") <- path.edge.ratio.percentile
    attr(result, "n_vertices") <- n

    if (!is.null(pca_info)) {
        attr(result, "pca") <- pca_info
    }

    class(result) <- "mknn_graphs"

    return(result)
}


#' Summary Method for mknn_graphs Objects
#'
#' @description
#' Provides a comprehensive summary of mutual k-nearest neighbor graphs created
#' by \code{create.mknn.graphs}, including structural statistics and connectivity
#' information for each k value.
#'
#' @param object An object of class "mknn_graphs", typically output from
#'   \code{create.mknn.graphs}.
#' @param ... Additional arguments (currently unused).
#'
#' @return Invisibly returns a data frame containing graph statistics with columns:
#'   \describe{
#'     \item{idx}{Index of the k value (1 to number of graphs)}
#'     \item{k}{The k value used for the graph}
#'     \item{n_components}{Number of connected components}
#'     \item{n_edges}{Number of edges in the graph}
#'     \item{mean_degree}{Average vertex degree}
#'     \item{min_degree}{Minimum vertex degree}
#'     \item{max_degree}{Maximum vertex degree}
#'     \item{density}{Graph density (proportion of possible edges present)}
#'     \item{sparsity}{Graph sparsity (1 - density)}
#'   }
#'
#' @details
#' The summary provides insights into how graph structure changes with k:
#' \itemize{
#'   \item **Connected Components**: Indicates graph fragmentation. A value of 1
#'     means the graph is fully connected.
#'   \item **Degree Statistics**: Shows the distribution of vertex connectivity.
#'     Large differences between min and max degree may indicate hub vertices.
#'   \item **Density/Sparsity**: Measures how many of the possible edges are
#'     present. MkNN graphs are typically very sparse.
#' }
#'
#' For pruned graphs, the statistics reflect the structure after geometric pruning
#' has been applied.
#'
#' @examples
#' mknn_result <- list(
#'   pruned_graphs = list(
#'     list(adj_list = list(c(2L), c(1L, 3L), c(2L))),
#'     list(adj_list = list(c(2L, 3L), c(1L, 3L), c(1L, 2L)))
#'   ),
#'   k_statistics = data.frame(
#'     k = 2:3,
#'     n_edges = c(2L, 3L),
#'     n_edges_pruned = c(2L, 3L),
#'     n_removed = c(0L, 0L),
#'     reduction_ratio = c(0, 0)
#'   )
#' )
#' attr(mknn_result, "kmin") <- 2L
#' attr(mknn_result, "kmax") <- 3L
#' attr(mknn_result, "n_vertices") <- 3L
#' attr(mknn_result, "max.path.edge.ratio.thld") <- 1.2
#' class(mknn_result) <- "mknn_graphs"
#'
#' stats <- summary(mknn_result)
#' plot(stats$k, stats$mean_degree, type = "b",
#'      xlab = "k", ylab = "Mean Degree")
#'
#' @method summary mknn_graphs
#' @export
summary.mknn_graphs <- function(object, ...) {
  # Validate input
  if (!inherits(object, "mknn_graphs")) {
    stop("'object' must be of class 'mknn_graphs'.", call. = FALSE)
  }

  # Check if full graphs are available
  if (is.null(object$pruned_graphs)) {
    stop("Full graph structures not available. ",
         "Set compute.full = TRUE when calling create.mknn.graphs().",
         call. = FALSE)
  }

  # Extract attributes
  kmin <- attr(object, "kmin")
  kmax <- attr(object, "kmax")
  n_vertices <- attr(object, "n_vertices")
  pruning_threshold <- attr(object, "max.path.edge.ratio.thld")
  pca_info <- attr(object, "pca")

  # Initialize statistics table
  k_values <- kmin:kmax
  n_graphs <- length(k_values)

  stats_table <- data.frame(
    idx = seq_len(n_graphs),
    k = k_values,
    n_components = integer(n_graphs),
    n_edges = integer(n_graphs),
    mean_degree = numeric(n_graphs),
    min_degree = integer(n_graphs),
    max_degree = integer(n_graphs),
    density = numeric(n_graphs),
    sparsity = numeric(n_graphs),
    stringsAsFactors = FALSE
  )

  # Calculate statistics for each graph
  for (i in seq_len(n_graphs)) {
    graph <- object$pruned_graphs[[i]]

    # Get adjacency list
    adj_list <- graph$adj_list

    # Number of edges (divide by 2 for undirected graph)
    n_edges <- sum(sapply(adj_list, length)) / 2

    # Vertex degrees
    degrees <- sapply(adj_list, length)

    # Connected components
    n_components <- .count_connected_components(adj_list)

    # Calculate density
    max_edges <- n_vertices * (n_vertices - 1) / 2
    density <- n_edges / max_edges

    # Fill in statistics
    stats_table$n_components[i] <- n_components
    stats_table$n_edges[i] <- n_edges
    stats_table$mean_degree[i] <- mean(degrees)
    stats_table$min_degree[i] <- min(degrees)
    stats_table$max_degree[i] <- max(degrees)
    stats_table$density[i] <- density
    stats_table$sparsity[i] <- 1 - density
  }

  # Print summary header
  cat("Mutual k-Nearest Neighbor Graphs Summary\n")
  cat("========================================\n")
  cat(sprintf("Number of vertices: %d\n", n_vertices))
  cat(sprintf("k range: %d to %d\n", kmin, kmax))
  cat(sprintf("Pruning threshold: %.2f\n", pruning_threshold))

  if (!is.null(pca_info)) {
    cat(sprintf("PCA applied: %d dims -> %d components (%.1f%% variance)\n",
                pca_info$original_dim, pca_info$n_components,
                pca_info$variance_explained * 100))
  }

  cat("\nGraph Statistics:\n")
  cat("-----------------\n")

  # Format numeric columns for display
  display_table <- stats_table
  display_table$mean_degree <- sprintf("%.2f", stats_table$mean_degree)
  display_table$density <- sprintf("%.5f", stats_table$density)
  display_table$sparsity <- sprintf("%.5f", stats_table$sparsity)

  print(display_table, row.names = FALSE)

  # Print summary of pruning if it was applied
  if (pruning_threshold > 0 && !is.null(object$k_statistics)) {
    cat("\nPruning Summary:\n")
    cat("----------------\n")

    pruning_stats <- object$k_statistics
    total_removed <- sum(pruning_stats$n_removed)
    total_original <- sum(pruning_stats$n_edges)

    cat(sprintf("Total edges removed: %d of %d (%.1f%%)\n",
                total_removed, total_original,
                100 * total_removed / total_original))
  }

  invisible(stats_table)
}


.count_connected_components <- function(adj_list) {
  n <- length(adj_list)
  if (n == 0) return(0)

  visited <- logical(n)
  n_components <- 0

  dfs <- function(v) {
    visited[v] <<- TRUE
    for (neighbor in adj_list[[v]]) {
      if (!visited[neighbor]) {
        dfs(neighbor)
      }
    }
  }

  for (i in seq_len(n)) {
    if (!visited[i]) {
      n_components <- n_components + 1
      dfs(i)
    }
  }

  return(n_components)
}


#' Print Method for mknn_graph Objects
#'
#' @description
#' Prints a concise summary of a mutual k-nearest neighbor graph object.
#'
#' @param x An object of class "mknn_graph".
#' @param ... Additional arguments (currently unused).
#'
#' @return Invisibly returns the input object.
#'
#' @examples
#' graph <- list(
#'   n_vertices = 3L,
#'   n_edges = 2L,
#'   k = 2L,
#'   adj_list = list(c(2L), c(1L, 3L), c(2L))
#' )
#' class(graph) <- c("mknn_graph", "list")
#'
#' print(graph)
#' @method print mknn_graph
#' @export
print.mknn_graph <- function(x, ...) {
  cat("Mutual k-Nearest Neighbor Graph\n")
  cat("-------------------------------\n")
  cat(sprintf("Number of vertices: %d\n", x$n_vertices))
  cat(sprintf("Number of edges: %d\n", x$n_edges))
  cat(sprintf("k value: %d\n", x$k))

  degrees <- sapply(x$adj_list, length)
  cat(sprintf("Mean degree: %.2f\n", mean(degrees)))
  cat(sprintf("Degree range: [%d, %d]\n", min(degrees), max(degrees)))

  invisible(x)
}


#' Print Method for mknn_graphs Objects
#'
#' @description
#' Prints a concise summary of a collection of mutual k-nearest neighbor graphs.
#'
#' @param x An object of class "mknn_graphs".
#' @param ... Additional arguments (currently unused).
#'
#' @return Invisibly returns the input object.
#'
#' @examples
#' graphs <- list(
#'   k_statistics = data.frame(
#'     k = 2:4,
#'     n_edges_pruned = c(2L, 3L, 3L)
#'   )
#' )
#' attr(graphs, "kmin") <- 2L
#' attr(graphs, "kmax") <- 4L
#' attr(graphs, "n_vertices") <- 3L
#' class(graphs) <- "mknn_graphs"
#'
#' print(graphs)
#' @method print mknn_graphs
#' @export
print.mknn_graphs <- function(x, ...) {
  kmin <- attr(x, "kmin")
  kmax <- attr(x, "kmax")
  n_vertices <- attr(x, "n_vertices")

  cat("Collection of Mutual k-NN Graphs\n")
  cat("--------------------------------\n")
  cat(sprintf("Number of vertices: %d\n", n_vertices))
  cat(sprintf("k range: %d to %d (%d graphs)\n", kmin, kmax, kmax - kmin + 1))

  if (!is.null(attr(x, "pca"))) {
    pca_info <- attr(x, "pca")
    cat(sprintf("PCA applied: %d -> %d dimensions\n",
                pca_info$original_dim, pca_info$n_components))
  }

  # Show brief statistics if available
  if (!is.null(x$k_statistics)) {
    cat("\nEdge counts by k:\n")
    print(x$k_statistics[, c("k", "n_edges_pruned")], row.names = FALSE)
  }

  cat("\nUse summary() for detailed statistics.\n")

  invisible(x)
}
