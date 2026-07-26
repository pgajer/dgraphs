#' Calculate Graph Edit Distance (Pure R Implementation)
#'
#' Computes the graph edit distance between two weighted graphs with identical
#' vertex sets using a pure R implementation. This function considers edge
#' insertions, deletions, and weight modifications.
#'
#' @param graph1.adj.list A list of integer vectors representing the adjacency
#'   list of the first graph. Each element contains the neighbors of the
#'   corresponding vertex.
#' @param graph1.weights A list of numeric vectors representing the edge weights
#'   of the first graph. Must have the same structure as \code{graph1.adj.list}.
#' @param graph2.adj.list A list of integer vectors representing the adjacency
#'   list of the second graph.
#' @param graph2.weights A list of numeric vectors representing the edge weights
#'   of the second graph.
#' @param edge.cost A positive numeric scalar representing the cost of adding or
#'   removing an edge (default: 1).
#' @param weight.cost.factor A non-negative numeric scalar representing the
#'   factor to scale weight differences (default: 0.1).
#'
#' @return A non-negative numeric value representing the graph edit distance
#'   between the two input graphs.
#'
#' @details
#' The graph edit distance is calculated as:
#' \itemize{
#'   \item For edges present in one graph but not the other: \code{edge.cost}
#'   \item For edges present in both graphs with different weights:
#'     \code{abs(weight1 - weight2) * weight.cost.factor}
#' }
#'
#' Both graphs must have the same number of vertices. The function assumes
#' undirected graphs.
#'
#' @importFrom igraph graph_from_edgelist vcount E get.edge.ids E<-
#' @importFrom utils combn
#'
#' @examples
#' # Create two simple graphs
#' graph1.adj <- list(c(2, 3), c(1, 3), c(1, 2))
#' graph1.wts <- list(c(1, 2), c(1, 3), c(2, 3))
#'
#' graph2.adj <- list(c(2, 3), c(1, 3), c(1, 2))
#' graph2.wts <- list(c(1.5, 2), c(1.5, 2.5), c(2, 2.5))
#'
#' # Calculate distance
#' dist <- graph.edit.distance(graph1.adj, graph1.wts,
#'                            graph2.adj, graph2.wts)
#' print(dist)  # Weight differences only
#'
#' @export
graph.edit.distance <- function(graph1.adj.list,
                               graph1.weights,
                               graph2.adj.list,
                               graph2.weights,
                               edge.cost = 1,
                               weight.cost.factor = 0.1) {

  # Input validation
  if (!is.list(graph1.adj.list) || !is.list(graph1.weights) ||
      !is.list(graph2.adj.list) || !is.list(graph2.weights)) {
    stop("All graph inputs must be lists")
  }

  n1 <- length(graph1.adj.list)
  n2 <- length(graph2.adj.list)

  if (n1 == 0 || n2 == 0) {
    stop("Graphs cannot be empty")
  }

  if (n1 != n2) {
    stop(sprintf("Graphs must have same number of vertices: %d != %d", n1, n2))
  }

  if (length(graph1.weights) != n1 || length(graph2.weights) != n2) {
    stop("Weight lists must have same length as adjacency lists")
  }

  # Parameter validation
  if (!is.numeric(edge.cost) || length(edge.cost) != 1 ||
      is.na(edge.cost) || edge.cost < 0) {
    stop("edge.cost must be a single non-negative numeric value")
  }

  if (!is.numeric(weight.cost.factor) || length(weight.cost.factor) != 1 ||
      is.na(weight.cost.factor) || weight.cost.factor < 0) {
    stop("weight.cost.factor must be a single non-negative numeric value")
  }

  # Validate graph structure
  for (i in seq_len(n1)) {
    if (length(graph1.adj.list[[i]]) != length(graph1.weights[[i]])) {
      stop(sprintf("Mismatch in adjacency and weights dimensions for graph1 at vertex %d", i))
    }
    if (length(graph2.adj.list[[i]]) != length(graph2.weights[[i]])) {
      stop(sprintf("Mismatch in adjacency and weights dimensions for graph2 at vertex %d", i))
    }

    # Check for NAs
    if (any(is.na(graph1.adj.list[[i]])) || any(is.na(graph1.weights[[i]]))) {
      stop(sprintf("NAs found in graph1 at vertex %d", i))
    }
    if (any(is.na(graph2.adj.list[[i]])) || any(is.na(graph2.weights[[i]]))) {
      stop(sprintf("NAs found in graph2 at vertex %d", i))
    }

    # Check vertex indices
    if (length(graph1.adj.list[[i]]) > 0) {
      if (any(graph1.adj.list[[i]] < 1) || any(graph1.adj.list[[i]] > n1)) {
        stop(sprintf("Invalid vertex indices in graph1 at vertex %d", i))
      }
    }
    if (length(graph2.adj.list[[i]]) > 0) {
      if (any(graph2.adj.list[[i]] < 1) || any(graph2.adj.list[[i]] > n2)) {
        stop(sprintf("Invalid vertex indices in graph2 at vertex %d", i))
      }
    }
  }

  # Convert to igraph objects
  graph1.obj <- convert.adjacency.to.edge.matrix(graph1.adj.list, graph1.weights)
  graph2.obj <- convert.adjacency.to.edge.matrix(graph2.adj.list, graph2.weights)

  # Create empty graphs if no edges
  if (nrow(graph1.obj$edge.matrix) == 0) {
    graph1 <- igraph::make_empty_graph(n = n1, directed = FALSE)
  } else {
    graph1 <- igraph::graph_from_edgelist(graph1.obj$edge.matrix, directed = FALSE)
    igraph::E(graph1)$weight <- graph1.obj$weights
  }

  if (nrow(graph2.obj$edge.matrix) == 0) {
    graph2 <- igraph::make_empty_graph(n = n2, directed = FALSE)
  } else {
    graph2 <- igraph::graph_from_edgelist(graph2.obj$edge.matrix, directed = FALSE)
    igraph::E(graph2)$weight <- graph2.obj$weights
  }

  # Initialize GED
  ged <- 0

  # Get all possible edges
  if (n1 < 2) {
    return(0)  # No edges possible with less than 2 vertices
  }

  all.edges <- utils::combn(n1, 2, simplify = TRUE)

  for (i in seq_len(ncol(all.edges))) {
    v1 <- all.edges[1, i]
    v2 <- all.edges[2, i]

    # Check if edge exists in each graph
    edge1.id <- igraph::get.edge.ids(graph1, c(v1, v2))
    edge2.id <- igraph::get.edge.ids(graph2, c(v1, v2))

    if (edge1.id == 0 && edge2.id == 0) {
      # Edge doesn't exist in either graph
      next
    } else if (edge1.id == 0 || edge2.id == 0) {
      # Edge exists in one graph but not the other
      ged <- ged + edge.cost
    } else {
      # Edge exists in both graphs, calculate weight difference
      weight1 <- igraph::E(graph1)[edge1.id]$weight
      weight2 <- igraph::E(graph2)[edge2.id]$weight
      ged <- ged + abs(weight1 - weight2) * weight.cost.factor
    }
  }

  return(ged)
}

#' Load Graph Data from RDA Files
#'
#' Loads pruned graph data from a series of RDA files for different k values
#' and combines them into a list structure containing adjacency and distance lists.
#'
#' @param k.values Numeric vector of k values to process. Must be positive integers.
#' @param prefix Character string specifying the path and prefix of the RDA files.
#' @param suffix Character string specifying the suffix of the RDA files
#'   (default: "_NN_graph.rda").
#' @param graph.object.name Character string specifying the name of the graph
#'   object stored in the RDA files (default: "S.graph").
#' @param verbose Logical indicating whether to show progress messages
#'   (default: TRUE).
#'
#' @return A list containing two components:
#'   \item{adj.list}{Named list of adjacency lists, one for each k value}
#'   \item{dist.list}{Named list of distance lists, one for each k value}
#'
#' @details
#' The function expects RDA files to be named according to the pattern:
#' \code{paste0(prefix, k, suffix)} for each k value.
#'
#' Each RDA file should contain an object with the name specified in
#' \code{graph.object.name}, which must have components \code{pruned_adj_list}
#' and \code{pruned_dist_list}.
#'
#' @examples
#' prefix <- file.path(tempdir(), "dgraphs-k")
#' S.graph <- list(
#'   pruned_adj_list = list(c(2L), c(1L)),
#'   pruned_dist_list = list(1, 1)
#' )
#' save(S.graph, file = paste0(prefix, 2, ".rda"))
#' graph.data <- load.graph.data(
#'   2, prefix = prefix, suffix = ".rda", verbose = FALSE
#' )
#' unlink(paste0(prefix, 2, ".rda"))
#' names(graph.data$adj.list)
#'
#' @export
load.graph.data <- function(k.values,
                           prefix,
                           suffix = "_NN_graph.rda",
                           graph.object.name = "S.graph",
                           verbose = TRUE) {

  # Input validation
  if (!is.numeric(k.values) || any(k.values <= 0) || any(k.values != round(k.values))) {
    stop("k.values must be positive integers")
  }

  if (!is.character(prefix) || length(prefix) != 1) {
    stop("prefix must be a single character string")
  }

  if (!is.character(suffix) || length(suffix) != 1) {
    stop("suffix must be a single character string")
  }

  if (!is.character(graph.object.name) || length(graph.object.name) != 1) {
    stop("graph.object.name must be a single character string")
  }

  # Initialize output structure
  graph.data <- list(
    adj.list = list(),
    dist.list = list()
  )

  # Load data for each k value
  for (k in k.values) {
    if (verbose) {
      message(sprintf("Loading graph data for k = %d", k))
    }

    file <- paste0(prefix, k, suffix)

    if (!file.exists(file)) {
      stop(sprintf("File not found: %s", file))
    }

    # Load the RDA file in a new environment to avoid namespace pollution
    env <- new.env()
    load(file, envir = env)

    if (!exists(graph.object.name, envir = env)) {
      stop(sprintf("Object '%s' not found in file: %s", graph.object.name, file))
    }

    loaded.graph <- get(graph.object.name, envir = env)

    # Check for required components
    if (is.null(loaded.graph$pruned_adj_list)) {
      stop(sprintf("Component 'pruned_adj_list' not found in object '%s' from file: %s",
                   graph.object.name, file))
    }
    if (is.null(loaded.graph$pruned_dist_list)) {
      stop(sprintf("Component 'pruned_dist_list' not found in object '%s' from file: %s",
                   graph.object.name, file))
    }

    # Store data using k as character key to ensure consistent naming
    k.char <- as.character(k)
    graph.data$adj.list[[k.char]] <- loaded.graph$pruned_adj_list
    graph.data$dist.list[[k.char]] <- loaded.graph$pruned_dist_list
  }

  return(graph.data)
}

#' Calculate Edit Distances Between Sequential Graphs
#'
#' Calculates edit distances between pairs of graphs separated by a specified
#' offset in the sequence of k values.
#'
#' @param k.values Numeric vector of k values corresponding to the loaded graphs.
#' @param graph.data List containing graph data as produced by
#'   \code{\link{load.graph.data}}.
#' @param offset Positive integer specifying the offset between compared graphs
#'   (default: 1). An offset of 1 compares consecutive graphs.
#' @param edge.cost Cost parameter passed to \code{\link{graph.edit.distance}}
#'   (default: 1).
#' @param weight.cost.factor Weight cost factor passed to
#'   \code{\link{graph.edit.distance}} (default: 0.1).
#' @param verbose Logical indicating whether to show progress messages
#'   (default: FALSE).
#'
#' @return A list containing:
#'   \item{indices}{Integer vector of indices in the k.values sequence}
#'   \item{k.values}{Numeric vector of k values corresponding to the first graph
#'     in each comparison}
#'   \item{distances}{Numeric vector of calculated edit distances}
#'
#' @details
#' For a sequence of k values and an offset of 1, this function compares:
#' \itemize{
#'   \item Graph at \code{k[1]} with graph at \code{k[2]}
#'   \item Graph at \code{k[2]} with graph at \code{k[3]}
#'   \item And so on...
#' }
#'
#' @examples
#' graph.data <- list(
#'   adj.list = list(
#'     `5` = list(c(2), c(1, 3), c(2)),
#'     `10` = list(c(2, 3), c(1, 3), c(1, 2)),
#'     `15` = list(c(2, 3), c(1), c(1))
#'   ),
#'   dist.list = list(
#'     `5` = list(1, c(1, 2), 2),
#'     `10` = list(c(1, 2), c(1, 3), c(2, 3)),
#'     `15` = list(c(1, 1.5), 1, 1.5)
#'   )
#' )
#' k.vals <- c(5, 10, 15)
#' distances <- calculate.edit.distances(k.vals, graph.data, offset = 1)
#' distances$distances
#'
#' @export
calculate.edit.distances <- function(k.values,
                                   graph.data,
                                   offset = 1,
                                   edge.cost = 1,
                                   weight.cost.factor = 0.1,
                                   verbose = FALSE) {

  # Input validation
  if (!is.numeric(k.values)) {
    stop("k.values must be numeric")
  }

  if (!is.list(graph.data) || !all(c("adj.list", "dist.list") %in% names(graph.data))) {
    stop("graph.data must be a list with components 'adj.list' and 'dist.list'")
  }

  if (!is.numeric(offset) || length(offset) != 1 || offset < 1 ||
      offset != round(offset)) {
    stop("offset must be a positive integer")
  }

  if (offset >= length(k.values)) {
    stop("offset must be less than the number of k values")
  }

  # Initialize output
  indices <- seq_len(length(k.values) - offset)
  distances <- numeric(length(indices))

  # Calculate distances
  for (i in indices) {
    if (verbose) {
      message(sprintf("Processing pair %d of %d (k=%g vs k=%g)",
                     i, length(indices), k.values[i], k.values[i + offset]))
    }

    k1.char <- as.character(k.values[i])
    k2.char <- as.character(k.values[i + offset])

    # Check that data exists for both k values
    if (!k1.char %in% names(graph.data$adj.list)) {
      stop(sprintf("No data found for k = %g", k.values[i]))
    }
    if (!k2.char %in% names(graph.data$adj.list)) {
      stop(sprintf("No data found for k = %g", k.values[i + offset]))
    }

    distances[i] <- graph.edit.distance(
      graph.data$adj.list[[k1.char]],
      graph.data$dist.list[[k1.char]],
      graph.data$adj.list[[k2.char]],
      graph.data$dist.list[[k2.char]],
      edge.cost = edge.cost,
      weight.cost.factor = weight.cost.factor
    )
  }

  return(list(
    indices = indices,
    k.values = k.values[indices],
    distances = distances
  ))
}

#' Create Distance Plot
#'
#' Creates a plot of edit distances with optional smoothing or
#' regression results.
#'
#' @param x Numeric vector of x-axis values (e.g., k values).
#' @param y Numeric vector of y-axis values (e.g., edit distances).
#' @param smooth Logical indicating whether to add a smoothing line
#'   (default: TRUE).
#' @param smooth.method Character string specifying the smoothing method.
#'   Options include "loess" (default), "lm", "glm", "gam".
#' @param mark.x Optional numeric value(s) to mark with vertical lines.
#' @param xlab Character string for x-axis label
#'   (default: "Number of Nearest Neighbors (k)").
#' @param ylab Character string for y-axis label (default: "Edit Distance").
#' @param main Character string for plot title (default: NULL, no title).
#' @param width Numeric value for plot width in inches (default: 6).
#' @param height Numeric value for plot height in inches (default: 6).
#' @param ... Additional arguments passed to \code{plot()}.
#'
#' @return Returns \code{NULL} invisibly after drawing the plot.
#'
#' @details
#' The function creates a scatter plot with optional smoothing line. If
#' \code{mark.x} is provided, vertical dashed lines are added at those x-values.
#'
#' @importFrom graphics plot abline mtext par
#' @importFrom stats loess predict
#'
#' @examples
#' k.vals <- c(5, 10, 15, 20)
#' distances <- c(2.2, 1.4, 1.1, 1.3)
#' create.distance.plot(k.vals, distances, smooth = FALSE)
#'
#' min.k <- k.vals[which.min(distances)]
#' create.distance.plot(k.vals, distances, mark.x = min.k,
#'                      smooth = FALSE,
#'                      main = "Edit Distance vs k")
#' @export
create.distance.plot <- function(x, y,
                                smooth = TRUE,
                                smooth.method = "loess",
                                mark.x = NULL,
                                xlab = "Number of Nearest Neighbors (k)",
                                ylab = "Edit Distance",
                                main = NULL,
                                width = 6,
                                height = 6,
                                ...) {

  # Input validation
  if (!is.numeric(x) || !is.numeric(y)) {
    stop("x and y must be numeric vectors")
  }

  if (length(x) != length(y)) {
    stop("x and y must have the same length")
  }

  if (length(x) < 2) {
    stop("Need at least 2 data points to create a plot")
  }

  # Remove any NA values
  complete.cases <- !is.na(x) & !is.na(y)
  if (sum(complete.cases) < length(x)) {
    warning(sprintf("Removed %d cases with missing values",
                   length(x) - sum(complete.cases)))
    x <- x[complete.cases]
    y <- y[complete.cases]
  }

  # Set up plot parameters
  op <- graphics::par(mar = c(4, 4.5, 2, 1), mgp = c(2.5, 0.7, 0), tcl = -0.3)
  on.exit(graphics::par(op), add = TRUE)

  # Create base plot
  graphics::plot(x, y,
                xlab = xlab,
                ylab = ylab,
                main = main,
                pch = 19,
                col = "darkblue",
                ...)

  # Add smoothing line if requested
  if (smooth && length(unique(x)) > 3) {
    tryCatch({
	      if (smooth.method == "loess") {
	        lo <- stats::loess(y ~ x)
	        x.seq <- seq(min(x), max(x), length.out = 100)
	        y.pred <- stats::predict(lo, x.seq)
	        graphics::lines(x.seq, y.pred, col = "red", lwd = 2)
	      } else {
	        ss <- stats::smooth.spline(x = x, y = y)
	        graphics::lines(ss, col = "red", lwd = 2)
	      }
	    }, error = function(e) {
	      warning("Could not add smoothing line: ", e$message)
    })
  }

  # Add vertical lines if requested
  if (!is.null(mark.x)) {
    graphics::abline(v = mark.x, col = "gray60", lty = 2, lwd = 1.5)
  }

  # Add grid
  graphics::grid(col = "gray90")

  invisible(NULL)
}
