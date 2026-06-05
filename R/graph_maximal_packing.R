#' Create a Maximal Packing of Vertices in a Graph
#'
#' @description Creates a maximal packing of vertices based on a specified grid
#'     size. The algorithm places vertices in the graph using a separation distance
#'     that produces a vertex set packing of size approximately equal to the
#'     given grid size. A vertex packing is a set of vertices where each pair
#'     is separated by at least a specified distance.
#'
#' @param adj.list A list where each element is a vector of adjacent vertex
#'        indices (1-based) for the corresponding vertex. Must represent an
#'        undirected graph.
#' @param weight.list A list where each element is a vector of edge weights
#'        corresponding to the adjacencies in \code{adj.list}. All weights
#'        must be positive.
#' @param grid.size A positive integer (>= 2) specifying the approximate
#'        separation distance between vertices in the packing.
#' @param max.iterations Maximum number of iterations for the algorithm to
#'        converge. Default is 20.
#' @param precision Precision threshold for convergence of the algorithm.
#'        Must be between 0 and 0.5. Default is 0.1.
#'
#' @return A list with class "maximal_packing" containing five components:
#'   \item{adj_list}{A list of adjacency vectors for each vertex in the
#'         resulting grid graph}
#'   \item{weight_list}{A list of weight vectors corresponding to each
#'         adjacency}
#'   \item{grid_vertices}{An integer vector of vertex indices that form
#'         the maximal packing}
#'   \item{graph_diameter}{A numeric value representing the maximum shortest
#'         path distance between any two vertices in the graph}
#'   \item{max_packing_radius}{A numeric value representing the optimal radius
#'         used for the final packing, which is the minimum guaranteed distance
#'         between any two vertices in the packing}
#'
#' @details The function computes a maximal packing by iteratively selecting
#'     vertices that are approximately \code{grid.size} apart from each other.
#'     The process starts from one of the graph's diameter endpoints (determined
#'     automatically) and continues until no more vertices can be added to the
#'     packing without violating the distance constraint.
#'
#'     The returned \code{graph_diameter} represents the longest shortest path
#'     in the graph, which provides insight into the graph's overall structure
#'     and extent.
#'
#'     The \code{max_packing_radius} value indicates the minimum distance that
#'     separates any two vertices in the packing. This value is determined
#'     through binary search to achieve a packing of approximately the
#'     requested size.
#'
#'     The function validates input parameters and ensures that the graph
#'     structure is properly specified before computing the packing. The graph
#'     must be undirected (symmetric adjacency) and connected.
#'
#' @examples
#' adj.list <- list(c(2), c(1, 3), c(2, 4), c(3, 5), c(4))
#' weight.list <- list(c(1), c(1, 1), c(1, 1), c(1, 1), c(1))
#'
#' result <- create.maximal.packing(adj.list, weight.list, grid.size = 2)
#' result$grid_vertices
#' result$max_packing_radius
#'
#' @seealso \code{\link{validate.maximal.packing}},
#'          \code{\link{verify.maximal.packing}}
#' @export
create.maximal.packing <- function(adj.list,
                                   weight.list,
                                   grid.size,
                                   max.iterations = 20,
                                   precision = 0.1) {

  # Input validation
  if (!is.list(adj.list)) {
    stop("'adj.list' must be a list")
  }

  if (!is.list(weight.list)) {
    stop("'weight.list' must be a list")
  }

  # Check if lists have the same length
  n.vertices <- length(adj.list)

  if (n.vertices < 2) {
    stop("'adj.list' must have at least 2 vertices")
  }

  if (length(weight.list) != n.vertices) {
    stop("'adj.list' and 'weight.list' must have the same length")
  }

  # Validate grid.size
  if (!is.numeric(grid.size) || length(grid.size) != 1) {
    stop("'grid.size' must be a single numeric value")
  }

  if (!is.finite(grid.size) || grid.size != floor(grid.size) || grid.size < 2) {
    stop("'grid.size' must be a positive integer >= 2")
  }

  # Validate max.iterations
  if (!is.numeric(max.iterations) || length(max.iterations) != 1) {
    stop("'max.iterations' must be a single numeric value")
  }

  if (!is.finite(max.iterations) || max.iterations != floor(max.iterations) ||
      max.iterations < 1) {
    stop("'max.iterations' must be a positive integer")
  }

  # Validate precision
  if (!is.numeric(precision) || length(precision) != 1) {
    stop("'precision' must be a single numeric value")
  }

  if (!is.finite(precision) || precision < 0 || precision > 0.5) {
    stop("'precision' must be between 0 and 0.5")
  }

  # Validate structure of adjacency and weight lists
  for (i in seq_len(n.vertices)) {
    # Check adjacency list
    if (!is.numeric(adj.list[[i]])) {
      stop(sprintf("adj.list[[%d]] must be a numeric vector", i))
    }

    if (length(adj.list[[i]]) > 0) {
      # Check for integer values
      if (!all(adj.list[[i]] == floor(adj.list[[i]]))) {
        stop(sprintf("adj.list[[%d]] must contain only integer values", i))
      }

      # Check for valid vertex indices
      if (any(adj.list[[i]] < 1) || any(adj.list[[i]] > n.vertices)) {
        stop(sprintf("adj.list[[%d]] contains invalid vertex indices", i))
      }

      # Check for self-loops
      if (i %in% adj.list[[i]]) {
        stop(sprintf("Self-loop detected at vertex %d", i))
      }
    }

    # Check weight list
    if (!is.numeric(weight.list[[i]])) {
      stop(sprintf("weight.list[[%d]] must be a numeric vector", i))
    }

    # Check matching lengths
    if (length(adj.list[[i]]) != length(weight.list[[i]])) {
      stop(sprintf("Length mismatch at vertex %d: adj.list has %d elements, weight.list has %d",
                   i, length(adj.list[[i]]), length(weight.list[[i]])))
    }

    # Check for positive weights
    if (length(weight.list[[i]]) > 0 && any(weight.list[[i]] <= 0)) {
      stop(sprintf("All weights in weight.list[[%d]] must be positive", i))
    }
  }

  # Check for undirected graph structure (edge symmetry)
  for (i in seq_len(n.vertices)) {
    for (j in seq_along(adj.list[[i]])) {
      neighbor <- adj.list[[i]][j]
      # Check if vertex i appears in neighbor's adjacency list
      if (!(i %in% adj.list[[neighbor]])) {
        stop(sprintf("Graph is not undirected: edge (%d, %d) exists but edge (%d, %d) does not",
                     i, neighbor, neighbor, i))
      }

      # Check for matching weights
      idx <- which(adj.list[[neighbor]] == i)
      if (length(idx) != 1) {
        stop(sprintf("Multiple edges detected between vertices %d and %d", i, neighbor))
      }

      if (abs(weight.list[[i]][j] - weight.list[[neighbor]][idx]) > .Machine$double.eps) {
        stop(sprintf("Weight mismatch for edge (%d, %d): %g vs %g",
                     i, neighbor, weight.list[[i]][j], weight.list[[neighbor]][idx]))
      }
    }
  }

  # Convert to 0-based indexing for C++ function
  adj.list.0based <- lapply(adj.list, function(x) as.integer(x - 1))

  # Call the C++ implementation
  result <- .Call("S_create_maximal_packing",
                  adj.list.0based,
                  weight.list,
                  as.integer(grid.size),
                  as.integer(max.iterations),
                  as.numeric(precision))

  # Add class attribute
  class(result) <- c("maximal_packing", "list")

  return(result)
}


#' Validate a Maximal Packing
#'
#' @description Validates whether a given vertex packing is maximal and correctly
#'     satisfies the distance constraints. A packing is valid if all vertices
#'     are separated by at least the specified radius, and is maximal if no
#'     additional vertices can be added without violating this constraint.
#'
#' @param adj.list A list where each element is a vector of adjacent vertex
#'        indices (1-based) for the corresponding vertex.
#' @param weight.list A list where each element is a vector of edge weights
#'        corresponding to the adjacencies in \code{adj.list}.
#' @param packing.vertices An integer vector of vertex indices (1-based) that
#'        form the packing to be validated.
#' @param max.packing.radius A numeric value representing the minimum distance
#'        that should separate any two vertices in the packing.
#'
#' @return A list with class "packing_validation" containing validation results:
#'   \item{valid}{Logical indicating whether the packing satisfies the
#'         distance constraint}
#'   \item{min.packing.distance}{The minimum distance found between any two
#'         packing vertices}
#'   \item{max.coverage.distance}{The maximum distance from any non-packing
#'         vertex to its nearest packing vertex}
#'   \item{violations}{A data frame containing details of any violations found,
#'         or NULL if none. Contains columns: type, vertex1, vertex2, distance}
#'   \item{is.maximal}{Logical indicating whether the packing is maximal
#'         (no vertices can be added)}
#'   \item{potential.additions}{Integer vector of vertex indices that could
#'         potentially be added to the packing if it's not maximal, or NULL
#'         if maximal}
#'
#' @details This function performs two key validations:
#'   \enumerate{
#'     \item \strong{Packing Property}: Verifies that all vertices in the
#'           packing are separated by at least \code{max.packing.radius}.
#'     \item \strong{Maximality}: Verifies that no additional vertex can be
#'           added to the packing without violating the packing property.
#'   }
#'
#'   The function uses the \code{igraph} package to compute shortest path
#'   distances between vertices using Dijkstra's algorithm.
#'
#' @examples
#' adj.list <- list(c(2), c(1, 3), c(2, 4), c(3, 5), c(4))
#' weight.list <- list(c(1), c(1, 1), c(1, 1), c(1, 1), c(1))
#' packing <- c(1, 3, 5)
#' radius <- 2
#'
#' result <- validate.maximal.packing(adj.list, weight.list, packing, radius)
#' result$valid
#' result$is.maximal
#'
#' @importFrom igraph graph_from_data_frame distances E
#' @export
validate.maximal.packing <- function(adj.list,
                                     weight.list,
                                     packing.vertices,
                                     max.packing.radius) {

  # Input validation
  if (!is.list(adj.list) || !is.list(weight.list)) {
    stop("Both 'adj.list' and 'weight.list' must be lists")
  }

  if (length(adj.list) != length(weight.list)) {
    stop("'adj.list' and 'weight.list' must have the same length")
  }

  if (!is.numeric(packing.vertices) || length(packing.vertices) == 0) {
    stop("'packing.vertices' must be a non-empty numeric vector")
  }

  if (!all(packing.vertices == floor(packing.vertices))) {
    stop("'packing.vertices' must contain only integer values")
  }

  n_vertices <- length(adj.list)

  if (any(packing.vertices < 1) || any(packing.vertices > n_vertices)) {
    stop("'packing.vertices' contains invalid vertex indices")
  }

  if (length(unique(packing.vertices)) != length(packing.vertices)) {
    stop("'packing.vertices' contains duplicate vertices")
  }

  if (!is.numeric(max.packing.radius) || length(max.packing.radius) != 1) {
    stop("'max.packing.radius' must be a single numeric value")
  }

  if (!is.finite(max.packing.radius) || max.packing.radius <= 0) {
    stop("'max.packing.radius' must be a positive finite number")
  }

  # Validate adjacency and weight list consistency
  if (!all(sapply(seq_along(adj.list), function(i) {
    length(adj.list[[i]]) == length(weight.list[[i]])
  }))) {
    stop("Each adjacency list entry must have a corresponding weight list of the same length")
  }

  # Create edge list for igraph
  edge_list <- data.frame(
    from = integer(0),
    to = integer(0),
    weight = numeric(0)
  )

  for (i in seq_len(n_vertices)) {
    if (length(adj.list[[i]]) > 0) {
      # Only add edges in one direction (i < j) to avoid duplicates
      neighbors <- adj.list[[i]]
      mask <- neighbors > i
      if (any(mask)) {
        new_edges <- data.frame(
          from = i,
          to = neighbors[mask],
          weight = weight.list[[i]][mask]
        )
        edge_list <- rbind(edge_list, new_edges)
      }
    }
  }

  # Create the graph
  g <- igraph::graph_from_data_frame(
    edge_list,
    directed = FALSE,
    vertices = seq_len(n_vertices)
  )

  # Compute shortest path distances between all vertices
  dist_matrix <- igraph::distances(g, weights = igraph::E(g)$weight)

  # Initialize result components
  violations_df <- NULL
  min_packing_distance <- Inf
  max_coverage_distance <- 0
  is_maximal <- TRUE
  potential_additions <- NULL

  # Validate packing property
  packing_indices <- as.integer(packing.vertices)

  # Check distances between packing vertices
  if (length(packing_indices) > 1) {
    # Get all pairwise distances within the packing
    packing_distances_matrix <- dist_matrix[packing_indices, packing_indices]

    # Find minimum non-zero distance
    lower_tri_indices <- which(
      lower.tri(packing_distances_matrix),
      arr.ind = TRUE
    )

    if (nrow(lower_tri_indices) > 0) {
      packing_distances <- packing_distances_matrix[lower_tri_indices]
      min_packing_distance <- min(packing_distances)

      # Check for violations
      violation_mask <- packing_distances < max.packing.radius

      if (any(violation_mask)) {
        violation_indices <- lower_tri_indices[violation_mask, , drop = FALSE]

        violations_df <- data.frame(
          type = "packing_violation",
          vertex1 = packing_indices[violation_indices[, 1]],
          vertex2 = packing_indices[violation_indices[, 2]],
          distance = packing_distances[violation_mask],
          stringsAsFactors = FALSE
        )
      }
    }
  }

  # Validate maximality
  non_packing_indices <- setdiff(seq_len(n_vertices), packing_indices)

  if (length(non_packing_indices) > 0) {
    potential_additions <- integer(0)

    for (v in non_packing_indices) {
      distances_to_packing <- dist_matrix[v, packing_indices]
      min_distance <- min(distances_to_packing)

      # Update maximum coverage distance
      max_coverage_distance <- max(max_coverage_distance, min_distance)

      # Check if this vertex could be added
      if (min_distance >= max.packing.radius) {
        is_maximal <- FALSE
        potential_additions <- c(potential_additions, v)
      }
    }

    if (length(potential_additions) == 0) {
      potential_additions <- NULL
    }
  }

  # Determine overall validity
  is_valid <- is.null(violations_df)

  # Prepare result
  result <- list(
    valid = is_valid,
    min.packing.distance = ifelse(is.finite(min_packing_distance),
                                  min_packing_distance,
                                  NA_real_),
    max.coverage.distance = max_coverage_distance,
    violations = violations_df,
    is.maximal = is_maximal,
    potential.additions = potential_additions
  )

  class(result) <- c("packing_validation", "list")

  return(result)
}


#' Print Method for Packing Validation Results
#'
#' @param x An object of class "packing_validation"
#' @param ... Additional arguments (currently ignored)
#'
#' @return Invisible copy of x
#'
#' @examples
#' x <- list(
#'   valid = TRUE,
#'   is.maximal = TRUE,
#'   min.packing.distance = 2,
#'   max.coverage.distance = 1,
#'   violations = NULL,
#'   potential.additions = NULL
#' )
#' class(x) <- "packing_validation"
#'
#' x
#' @export
print.packing_validation <- function(x, ...) {
  cat("Packing Validation Results\n")
  cat("--------------------------\n")
  cat("Valid packing:", x$valid, "\n")
  cat("Maximal packing:", x$is.maximal, "\n")

  if (!is.na(x$min.packing.distance)) {
    cat("Minimum packing distance:",
        format(x$min.packing.distance, digits = 4), "\n")
  }

  cat("Maximum coverage distance:",
      format(x$max.coverage.distance, digits = 4), "\n")

  if (!is.null(x$violations)) {
    cat("\nViolations found:\n")
    print(x$violations)
  }

  if (!x$is.maximal && !is.null(x$potential.additions)) {
    cat("\nVertices that could be added:",
        paste(x$potential.additions, collapse = ", "), "\n")
  }

  invisible(x)
}


#' Verify Maximal Packing Created by create.maximal.packing
#'
#' @description A convenience function to verify the correctness of a maximal
#'     packing created using the \code{\link{create.maximal.packing}} function.
#'     This function validates both the packing property (minimum separation
#'     distance) and maximality (no vertices can be added).
#'
#' @param packing.result The result returned by
#'        \code{\link{create.maximal.packing}}, which must be an object of
#'        class "maximal_packing".
#' @param verbose Logical indicating whether to print detailed validation
#'        results. Default is TRUE.
#'
#' @return A logical value: TRUE if the packing is both valid (satisfies the
#'         distance constraint) and maximal (no vertices can be added),
#'         FALSE otherwise.
#'
#' @details This function takes the output of \code{create.maximal.packing}
#'     and verifies two key properties:
#'     \enumerate{
#'       \item The packing vertices are all separated by at least
#'             \code{max_packing_radius}
#'       \item The packing is maximal (no more vertices can be added without
#'             violating the distance constraint)
#'     }
#'
#'     When \code{verbose = TRUE}, the function prints:
#'     \itemize{
#'       \item Graph diameter
#'       \item Packing radius used
#'       \item Number of vertices in the packing
#'       \item Minimum distance between packing vertices
#'       \item Maximum coverage distance
#'       \item Validity and maximality status
#'       \item Any violations or potential additions (if applicable)
#'     }
#'
#' @examples
#' adj.list <- list(c(2), c(1, 3), c(2, 4), c(3, 5), c(4))
#' weight.list <- list(c(1), c(1, 1), c(1, 1), c(1, 1), c(1))
#' result <- create.maximal.packing(adj.list, weight.list, grid.size = 2)
#'
#' verify.maximal.packing(result, verbose = FALSE)
#'
#' @seealso \code{\link{create.maximal.packing}},
#'          \code{\link{validate.maximal.packing}}
#' @export
verify.maximal.packing <- function(packing.result, verbose = TRUE) {

  # Input validation
  if (!inherits(packing.result, "maximal_packing")) {
    stop("'packing.result' must be an object of class 'maximal_packing'")
  }

  required_components <- c("adj_list", "weight_list", "grid_vertices",
                          "graph_diameter", "max_packing_radius")

  missing_components <- setdiff(required_components, names(packing.result))
  if (length(missing_components) > 0) {
    stop("'packing.result' is missing required components: ",
         paste(missing_components, collapse = ", "))
  }

  if (!is.logical(verbose) || length(verbose) != 1) {
    stop("'verbose' must be a single logical value")
  }

  # Extract components from the packing result
  adj.list <- packing.result$adj_list
  weight.list <- packing.result$weight_list
  packing.vertices <- packing.result$grid_vertices
  max.packing.radius <- packing.result$max_packing_radius

  # Validate the packing
  validation <- validate.maximal.packing(
    adj.list,
    weight.list,
    packing.vertices,
    max.packing.radius
  )

  if (verbose) {
    cat("Maximal Packing Verification\n")
    cat("============================\n")
    cat("\nGraph Properties:\n")
    cat("  - Number of vertices:", length(adj.list), "\n")
    cat("  - Graph diameter:",
        format(packing.result$graph_diameter, digits = 4), "\n")

    cat("\nPacking Properties:\n")
    cat("  - Packing radius:",
        format(packing.result$max_packing_radius, digits = 4), "\n")
    cat("  - Number of packing vertices:",
        length(packing.result$grid_vertices), "\n")
    cat("  - Packing vertices:",
        paste(packing.result$grid_vertices, collapse = ", "), "\n")

    cat("\nValidation Results:\n")
    cat("  - Minimum distance between packing vertices:",
        ifelse(is.na(validation$min.packing.distance),
               "N/A (single vertex)",
               format(validation$min.packing.distance, digits = 4)), "\n")
    cat("  - Maximum coverage distance:",
        format(validation$max.coverage.distance, digits = 4), "\n")
    cat("  - Packing is valid:", validation$valid, "\n")
    cat("  - Packing is maximal:", validation$is.maximal, "\n")

    if (!validation$valid && !is.null(validation$violations)) {
      cat("\n*** VIOLATIONS DETECTED ***\n")
      print(validation$violations)
    }

    if (!validation$is.maximal && !is.null(validation$potential.additions)) {
      cat("\n*** NOT MAXIMAL ***\n")
      cat("Vertices that could be added to the packing:\n")
      cat("  ", paste(validation$potential.additions, collapse = ", "), "\n")
    }

    overall_valid <- validation$valid && validation$is.maximal
    cat("\nOVERALL RESULT:",
        ifelse(overall_valid, "PASS", "FAIL"), "\n")
  }

  return(validation$valid && validation$is.maximal)
}


#' Print Method for Maximal Packing Results
#'
#' @param x An object of class "maximal_packing"
#' @param ... Additional arguments (currently ignored)
#'
#' @return Invisible copy of x
#'
#' @examples
#' x <- list(
#'   adj_list = list(c(2L), c(1L, 3L), c(2L, 4L), c(3L)),
#'   graph_diameter = 3,
#'   max_packing_radius = 1.5,
#'   grid_vertices = c(1L, 4L)
#' )
#' class(x) <- "maximal_packing"
#'
#' x
#' @export
print.maximal_packing <- function(x, ...) {
  cat("Maximal Packing Result\n")
  cat("----------------------\n")
  cat("Number of vertices in graph:", length(x$adj_list), "\n")
  cat("Graph diameter:", format(x$graph_diameter, digits = 4), "\n")
  cat("Packing radius:", format(x$max_packing_radius, digits = 4), "\n")
  cat("Number of packing vertices:", length(x$grid_vertices), "\n")
  cat("Packing vertices:",
      if(length(x$grid_vertices) <= 20) {
        paste(x$grid_vertices, collapse = ", ")
      } else {
        paste(c(paste(x$grid_vertices[1:20], collapse = ", "),
                "... (", length(x$grid_vertices) - 20, " more)"),
              collapse = "")
      }, "\n")

  invisible(x)
}
