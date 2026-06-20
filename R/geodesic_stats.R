#' Compute Geodesic Statistics for Grid Vertices
#'
#' @description
#' Analyzes how the number of geodesics scales with radius for each grid vertex.
#' This function helps determine if collapsing/clustering geodesics is necessary
#' and provides insights into the graph structure around grid vertices.
#'
#' @param adj.list List of integer vectors. Each vector contains indices of vertices
#'        adjacent to the corresponding vertex. Indices should be 1-based.
#' @param weight.list List of numeric vectors. Each vector contains weights of edges
#'        corresponding to adjacencies in adj.list.
#' @param min.radius Numeric. Minimum radius as a fraction of graph diameter.
#' @param max.radius Numeric. Maximum radius as a fraction of graph diameter.
#' @param n.steps Integer. Number of radius steps to test.
#' @param n.packing.vertices Integer. Number of vertices in the grid/packing.
#' @param max.packing.iterations Integer. Maximum iterations for packing algorithm.
#' @param packing.precision Numeric. Precision parameter for packing algorithm.
#' @param verbose Logical. Whether to print progress information.
#'
#' @return A list of class "geodesic_stats" containing:
#' \describe{
#'   \item{radii}{Numeric vector. Actual radii used in the analysis.}
#'   \item{geodesic_rays}{Matrix. Number of geodesic rays for each vertex at each radius.}
#'   \item{composite_geodesics}{Matrix. Number of composite geodesics for each vertex at each radius.}
#'   \item{path_overlap}{List of matrices. Overlap statistics for each vertex at each radius.}
#'   \item{grid_vertices}{Integer vector. The vertices selected as grid vertices.}
#'   \item{summary}{Data frame. Summary statistics for each radius.}
#' }
#'
#' @export
compute.geodesic.stats <- function(adj.list,
                                 weight.list,
                                 min.radius = 0.2,
                                 max.radius = 0.5,
                                 n.steps = 5,
                                 n.packing.vertices = length(adj.list),
                                 max.packing.iterations = 20,
                                 packing.precision = 0.0001,
                                 verbose = FALSE) {

    # Input validation
    if (!is.list(adj.list) || !is.list(weight.list))
        stop("adj.list and weight.list must be lists")

    if (length(adj.list) != length(weight.list))
        stop("adj.list and weight.list must have the same length")

    if (min.radius <= 0 || max.radius <= min.radius)
        stop("Invalid radius range: min.radius must be positive and max.radius > min.radius")

    if (n.steps < 2)
        stop("n.steps must be at least 2")

    # Convert to 0-based indices for C++
    adj.list.0based <- lapply(adj.list, function(x) as.integer(x - 1))

    # Call the C++ function
    result <- .Call("S_compute_geodesic_stats",
                   adj.list.0based,
                   weight.list,
                   as.double(min.radius),
                   as.double(max.radius),
                   as.integer(n.steps),
                   as.integer(n.packing.vertices),
                   as.integer(max.packing.iterations),
                   as.double(packing.precision),
                   as.logical(verbose))

    # Extract matrices
    geodesic_rays_matrix <- result$geodesic_rays
    composite_geodesics_matrix <- result$composite_geodesics
    path_overlap <- result$path_overlap

    # Create summary statistics
    summary_df <- data.frame(
        radius = result$radii,
        min_rays = apply(geodesic_rays_matrix, 2, min),
        avg_rays = colMeans(geodesic_rays_matrix),
        median_rays = apply(geodesic_rays_matrix, 2, stats::median),
        max_rays = apply(geodesic_rays_matrix, 2, max),
        avg_composite = colMeans(composite_geodesics_matrix),
        median_composite = apply(composite_geodesics_matrix, 2, stats::median),
        max_composite = apply(composite_geodesics_matrix, 2, max)
    )

    ## Add overlap statistics to summary
    if (!is.null(path_overlap)) {
        summary_df$avg_overlap_median <- colMeans(path_overlap$median)
    }

    # Calculate ratio of composite geodesics to potential pairs
    summary_df$composite_ratio <- summary_df$avg_composite /
        pmax(0.5, (summary_df$avg_rays * (summary_df$avg_rays - 1) / 2))

    # Return processed results
    result <- list(
        radii = result$radii,
        geodesic_rays = geodesic_rays_matrix,
        composite_geodesics = composite_geodesics_matrix,
        path_overlap = path_overlap,
        radius_overlaps = result$radius_overlaps,
        grid_vertices = result$grid_vertices,
        summary = summary_df
    )

    class(result) <- c("geodesic_stats", "list")

    return(result)
}

#' Summary method for geodesic_stats objects
#'
#' @description
#' Provides a summary table of geodesic statistics with percentages and counts
#' for different metric types.
#'
#' @param object A geodesic_stats object from compute.geodesic.stats().
#' @param type Character. Type of summary to generate:
#'        "rays" (default), "composite", or "overlap".
#' @param ... Additional arguments passed to summary.
#'
#' @return A matrix with row for each radius and columns for each unique count value.
#'        Each cell contains a string with "percent (count)" format.
#'
#' @examples
#' stats <- list(
#'   radii = c(0.2, 0.4),
#'   geodesic_rays = matrix(c(2, 3, 3, 4), nrow = 2, byrow = TRUE),
#'   composite_geodesics = matrix(c(1, 1, 1, 2), nrow = 2, byrow = TRUE),
#'   path_overlap = list(
#'     min = matrix(c(0.1, 0.2, 0.2, 0.3), nrow = 2, byrow = TRUE),
#'     p05 = matrix(c(0.1, 0.2, 0.2, 0.3), nrow = 2, byrow = TRUE),
#'     p25 = matrix(c(0.2, 0.3, 0.3, 0.4), nrow = 2, byrow = TRUE),
#'     median = matrix(c(0.3, 0.4, 0.4, 0.5), nrow = 2, byrow = TRUE),
#'     p75 = matrix(c(0.4, 0.5, 0.5, 0.6), nrow = 2, byrow = TRUE),
#'     p95 = matrix(c(0.5, 0.6, 0.6, 0.7), nrow = 2, byrow = TRUE),
#'     max = matrix(c(0.6, 0.7, 0.7, 0.8), nrow = 2, byrow = TRUE)
#'   )
#' )
#' class(stats) <- c("geodesic_stats", "list")
#'
#' summary(stats)
#' summary(stats, type = "composite")
#' summary(stats, type = "overlap")
#'
#' @export
summary.geodesic_stats <- function(object, type = c("rays", "composite", "overlap"), ...) {
    ## Match the type argument
    type <- match.arg(type)

    ## Select the appropriate matrix based on type
    if (type == "rays") {
        data_matrix <- object$geodesic_rays
        metric_name <- "Geodesic Rays"
    } else if (type == "composite") {
        data_matrix <- object$composite_geodesics
        metric_name <- "Composite Geodesics"
    } else if (type == "overlap") {
        ## For overlap, we'll provide a different summary focusing on the distribution
        overlap_summary <- summarize_overlap_statistics(object)
        return(overlap_summary)
    }

    ## Get radii
    radii <- object$radii

    ## Get the number of grid vertices
    n_vertices <- nrow(data_matrix)

    ## Calculate frequency tables for each radius
    freq_tables <- lapply(seq_along(radii), function(r) {
        ## Get the data for this radius
        ray_counts <- data_matrix[, r]
        ## Create frequency table
        table(ray_counts)
    })

    ## Find all unique count values across all radii
    all_counts <- sort(as.integer(unique(unlist(lapply(freq_tables, names)))))
    all_counts <- all_counts

    ## Create result matrix
    result <- matrix(NA, nrow = length(radii), ncol = length(all_counts))
    rownames(result) <- sprintf("%.4f", radii)
    colnames(result) <- all_counts

    ## Fill the matrix with percentage and count values
    for (r in seq_along(radii)) {
        freq_table <- freq_tables[[r]]

        for (count in names(freq_table)) {
            count_idx <- which(all_counts == as.integer(count))
            freq <- freq_table[[count]]
            percent <- round(100 * freq / n_vertices, 1)
            result[r, count_idx] <- sprintf("%.1f (%d)", percent, freq)
        }
    }

    ## Create a prettier output
    cat(sprintf("Summary of %s (%d grid vertices):\n\n", metric_name, n_vertices))

    ## Print the result table
    row_names <- sprintf("Radius %.4f", radii)
    col_names <- sprintf("%d rays", all_counts)

    ## Create formatted table for printing
    formatted_table <- as.data.frame(result)
    names(formatted_table) <- all_counts
    rownames(formatted_table) <- row_names

    ## Replace NA with empty strings for cleaner printing
    formatted_table[is.na(formatted_table)] <- ""

    ## Print table
    print(formatted_table, row.names = TRUE, right = FALSE)

    ## Return the result matrix invisibly
    invisible(result)
}

#' Print method for geodesic_stats objects
#'
#' @description
#' Prints a brief overview of the geodesic statistics.
#'
#' @param x A geodesic_stats object from compute.geodesic.stats().
#' @param ... Additional arguments passed to print.
#'
#' @return The object invisibly.
#'
#' @export
print.geodesic_stats <- function(x, ...) {
    cat("Geodesic Statistics Analysis\n")
    cat("----------------------------\n")
    cat("Radii analyzed:", length(x$radii), "from", min(x$radii), "to", max(x$radii), "\n")
    cat("Grid vertices:", nrow(x$geodesic_rays), "\n\n")

    cat("Summary statistics:\n")
    print(x$summary)

    cat("\nUse summary() for more detailed analysis.\n")
    cat("Use plot() for visualization.\n")

    invisible(x)
}

#' Compute Geodesic Statistics for a Single Grid Vertex
#'
#' @description
#' Analyzes how the number of geodesics scales with radius for a specific grid vertex.
#'
#' @param adj.list List of integer vectors. Each vector contains indices of vertices
#'        adjacent to the corresponding vertex. Indices should be 1-based.
#' @param weight.list List of numeric vectors. Each vector contains weights of edges
#'        corresponding to adjacencies in adj.list.
#' @param grid.vertex Integer. The grid vertex to analyze.
#' @param min.radius Numeric. Minimum radius as a fraction of graph diameter.
#' @param max.radius Numeric. Maximum radius as a fraction of graph diameter.
#' @param n.steps Integer. Number of radius steps to test.
#' @param n.packing.vertices Integer. Number of vertices in the grid/packing.
#' @param packing.precision Numeric. Precision threshold for packing convergence.
#'
#' @return A data frame of class "vertex_geodesic_stats" with columns:
#' \describe{
#'   \item{radius}{Actual radius used.}
#'   \item{rays}{Number of geodesic rays within radius.}
#'   \item{composite_geodesics}{Number of composite geodesics.}
#'   \item{overlap_min}{Minimum overlap ratio.}
#'   \item{overlap_p05}{5th percentile overlap ratio.}
#'   \item{overlap_p25}{25th percentile overlap ratio.}
#'   \item{overlap_median}{Median overlap ratio.}
#'   \item{overlap_p75}{75th percentile overlap ratio.}
#'   \item{overlap_p95}{95th percentile overlap ratio.}
#'   \item{overlap_max}{Maximum overlap ratio.}
#' }
#'
#' @export
compute.vertex.geodesic.stats <- function(adj.list,
                                          weight.list,
                                          grid.vertex,
                                          min.radius = 0.2,
                                          max.radius = 0.5,
                                          n.steps = 5,
                                          n.packing.vertices = length(adj.list),
                                          packing.precision = 0.0001) {

                                        # Input validation
    if (!is.list(adj.list) || !is.list(weight.list))
        stop("adj.list and weight.list must be lists")

    if (length(adj.list) != length(weight.list))
        stop("adj.list and weight.list must have the same length")

    if (grid.vertex < 1 || grid.vertex > length(adj.list))
        stop("grid.vertex must be between 1 and length(adj.list)")

                                        # Convert to 0-based indices for C++
    adj.list.0based <- lapply(adj.list, function(x) as.integer(x - 1))
    grid.vertex.0based <- as.integer(grid.vertex - 1)

    ## Call the C++ function
    result <- .Call("S_compute_vertex_geodesic_stats",
                    adj.list.0based,
                    weight.list,
                    grid.vertex.0based,
                    as.double(min.radius),
                    as.double(max.radius),
                    as.integer(n.steps),
                    as.integer(n.packing.vertices),
                    as.double(packing.precision))

                                        # Extract the result matrix and convert to data frame
    df <- as.data.frame(result$data)

                                        # Add vertex information
    attr(df, "vertex") <- result$vertex

                                        # Add potential_pairs and composite_ratio
    df$potential_pairs <- ifelse(df$rays > 1,
                                 df$rays * (df$rays - 1) / 2,
                                 0)
    df$composite_ratio <- ifelse(df$potential_pairs > 0,
                                 df$composite_geodesics / df$potential_pairs,
                                 0)

                                        # Set class for custom methods
    class(df) <- c("vertex_geodesic_stats", "data.frame")

    return(df)
}

#' Plot method for vertex_geodesic_stats objects
#'
#' @param x A vertex_geodesic_stats object
#' @param ... Additional arguments passed to plot
#'
#' @return Invisibly returns NULL
#'
#' @examples
#' x <- data.frame(
#'   radius = c(0.2, 0.4, 0.6),
#'   rays = c(3, 5, 6),
#'   composite_geodesics = c(1, 2, 3),
#'   overlap_min = c(0.10, 0.15, 0.20),
#'   overlap_p05 = c(0.15, 0.20, 0.25),
#'   overlap_p25 = c(0.20, 0.25, 0.30),
#'   overlap_median = c(0.30, 0.40, 0.50),
#'   overlap_p75 = c(0.40, 0.50, 0.60),
#'   overlap_p95 = c(0.55, 0.65, 0.75),
#'   overlap_max = c(0.60, 0.70, 0.80),
#'   potential_pairs = c(3, 10, 15),
#'   composite_ratio = c(1/3, 0.2, 0.2),
#'   overlap_ratio = c(0.30, 0.40, 0.50)
#' )
#' class(x) <- c("vertex_geodesic_stats", "data.frame")
#' attr(x, "vertex") <- 7L
#'
#' plot(x)
#'
#' @export
plot.vertex_geodesic_stats <- function(x, ...) {
    # Get the vertex ID
    vertex <- attr(x, "vertex")

    # Set up plot margins and parameters
    oldpar <- par(mar = c(5, 4, 4, 8), xpd = TRUE)
    on.exit(par(oldpar))

    # Determine y-axis range
    y_max <- max(c(x$rays, x$composite_geodesics * 5, x$overlap_median * 100), na.rm = TRUE)

    # Create the base plot with rays
    plot(x$radius, x$rays,
         type = "b", pch = 16, col = "blue", lwd = 2,
         xlim = range(x$radius), ylim = c(0, y_max * 1.1),
         xlab = "Radius", ylab = "Count",
         main = paste("Geodesic Analysis for Vertex", vertex))

    # Add composite geodesics (scaled by 5)
    lines(x$radius, x$composite_geodesics * 5,
          type = "b", pch = 17, col = "red", lwd = 2)

    # Add overlap median (scaled by 100)
    lines(x$radius, x$overlap_median * 100,
          type = "b", pch = 18, col = "green3", lwd = 2)

    # Add legend outside plot area
    legend("topright", inset = c(-0.35, 0),
           legend = c("Rays", "Composite (x5)", "Overlap Median (x100)"),
           col = c("blue", "red", "green3"),
           pch = c(16, 17, 18),
           lty = 1, lwd = 2,
           bty = "n")

    # Add grid
    grid()

    invisible(NULL)
}

#' Plot the distribution of overlap values
#'
#' @param x A vertex_geodesic_stats object
#' @param radius_idx Index of the radius to display. If NULL, uses the radius with the most composite geodesics.
#'
#' @return Invisibly returns NULL
#'
overlap.distribution.plot <- function(x, radius_idx = NULL) {
    # Get the vertex ID
    vertex <- attr(x, "vertex")

    # If radius index not specified, use the one with the most composite geodesics
    if (is.null(radius_idx)) {
        radius_idx <- which.max(x$composite_geodesics)
    }

    # Extract the row for the selected radius
    row_data <- x[radius_idx, ]

    # Extract overlap values
    overlap_values <- c(
        row_data$overlap_min, row_data$overlap_p05, row_data$overlap_p25,
        row_data$overlap_median, row_data$overlap_p75, row_data$overlap_p95,
        row_data$overlap_max
    )

    # Create a title including the radius and composite geodesic count
    title <- sprintf(
        "Overlap Distribution at Radius %.4f (Vertex %d)\n%d Rays, %d Composite Geodesics",
        row_data$radius, vertex, row_data$rays, row_data$composite_geodesics
    )

    # Set up plot margins
    oldpar <- par(mar = c(5, 4, 5, 2))
    on.exit(par(oldpar))

    # Create the boxplot-style visualization
    plot(1, type = "n", xlim = c(0.5, 1.5), ylim = c(0, 1),
         xlab = "", ylab = "Dice-Sorensen Overlap Index",
         main = title, xaxt = "n")

    # Draw the box (from p25 to p75)
    rect(0.8, row_data$overlap_p25, 1.2, row_data$overlap_p75,
         col = "lightblue", border = "black")

    # Draw the median line
    segments(0.8, row_data$overlap_median, 1.2, row_data$overlap_median,
             col = "red", lwd = 2)

    # Draw whiskers
    segments(1, row_data$overlap_p75, 1, row_data$overlap_p95, lty = 2)
    segments(1, row_data$overlap_p25, 1, row_data$overlap_p05, lty = 2)
    segments(0.95, row_data$overlap_p95, 1.05, row_data$overlap_p95)
    segments(0.95, row_data$overlap_p05, 1.05, row_data$overlap_p05)

    # Add min and max points
    points(1, row_data$overlap_min, pch = 1, cex = 1.2)
    points(1, row_data$overlap_max, pch = 1, cex = 1.2)

    # Add text labels for key statistics
    text(1.25, row_data$overlap_median, sprintf("Median: %.3f", row_data$overlap_median),
         adj = 0, cex = 0.8)
    text(1.25, row_data$overlap_p25, sprintf("Q1: %.3f", row_data$overlap_p25),
         adj = 0, cex = 0.8)
    text(1.25, row_data$overlap_p75, sprintf("Q3: %.3f", row_data$overlap_p75),
         adj = 0, cex = 0.8)

    # Add grid
    grid()

    invisible(NULL)
}

#' Summary method for vertex_geodesic_stats objects
#'
#' @param object A vertex_geodesic_stats object
#' @param ... Additional arguments passed to summary
#'
#' @return A summary of the vertex geodesic statistics
#'
#' @examples
#' x <- data.frame(
#'   radius = c(0.2, 0.4, 0.6),
#'   rays = c(3, 5, 6),
#'   composite_geodesics = c(1, 2, 3),
#'   overlap_min = c(0.10, 0.15, 0.20),
#'   overlap_p05 = c(0.15, 0.20, 0.25),
#'   overlap_p25 = c(0.20, 0.25, 0.30),
#'   overlap_median = c(0.30, 0.40, 0.50),
#'   overlap_p75 = c(0.40, 0.50, 0.60),
#'   overlap_p95 = c(0.55, 0.65, 0.75),
#'   overlap_max = c(0.60, 0.70, 0.80),
#'   potential_pairs = c(3, 10, 15),
#'   composite_ratio = c(1/3, 0.2, 0.2),
#'   overlap_ratio = c(0.30, 0.40, 0.50)
#' )
#' class(x) <- c("vertex_geodesic_stats", "data.frame")
#' attr(x, "vertex") <- 7L
#'
#' summary(x)
#'
#' @export
summary.vertex_geodesic_stats <- function(object, ...) {
                                        # Get the vertex ID
    vertex <- attr(object, "vertex")

                                        # Create a summary
    cat("Geodesic Statistics for Vertex", vertex, "\n\n")
    cat("Radius range:", min(object$radius), "to", max(object$radius), "\n")
    cat("Number of rays:", min(object$rays), "to", max(object$rays), "\n")
    cat("Number of composite geodesics:", sum(object$composite_geodesics), "\n")
    cat("Average composite ratio:", mean(object$composite_ratio), "\n")
    cat("Average overlap ratio:", mean(object$overlap_ratio), "\n\n")

                                        # Create a simple summary table
    summary_table <- data.frame(
        radius = object$radius,
        rays = object$rays,
        composite = object$composite_geodesics,
        comp_ratio = round(object$composite_ratio, 4),
        overlap = round(object$overlap_ratio, 4)
    )

    print(summary_table)

    invisible(summary_table)
}

#' Plot Geodesic Statistics
#'
#' @description
#' Creates visualizations of geodesic statistics to help understand
#' the relationship between radius and number of geodesics.
#'
#' @param x List. Output from compute.geodesic.stats().
#' @param plot.type Character. Type of plot to generate:
#'        "summary" (default), "heatmap", "vertex", or "all".
#' @param selected.vertices Integer vector. Specific vertices to highlight
#'        in "vertex" plots. If NULL, a random sample will be used.
#' @param max.vertices Integer. Maximum number of vertices to show in vertex plot.
#' @param ... Additional arguments passed to summary
#'
#' @return Invisibly returns NULL.
#'
#' @examples
#' stats <- list(
#'   radii = c(0.2, 0.4),
#'   geodesic_rays = matrix(c(2, 3, 3, 4), nrow = 2, byrow = TRUE),
#'   composite_geodesics = matrix(c(1, 1, 1, 2), nrow = 2, byrow = TRUE),
#'   grid_vertices = c(5L, 9L),
#'   summary = data.frame(
#'     radius = c(0.2, 0.4),
#'     avg_rays = c(2.5, 3.5),
#'     max_rays = c(3, 4),
#'     composite_ratio = c(0.4, 0.5),
#'     avg_overlap_median = c(0.35, 0.45)
#'   )
#' )
#' class(stats) <- c("geodesic_stats", "list")
#'
#' plot(stats, plot.type = "summary")
#' plot(stats, plot.type = "vertex", selected.vertices = 5)
#'
#' @importFrom graphics plot lines points legend grid image par layout title
#' @importFrom grDevices heat.colors rainbow
#'
#' @export
plot.geodesic_stats <- function(x,
                                plot.type = c("summary", "heatmap", "vertex", "all"),
                                selected.vertices = NULL,
                                max.vertices = 10, ...) {

    stats <- x
    plot.type <- match.arg(plot.type)

    # Save original par settings
    if (plot.type == "all") {
        oldpar <- par(mfrow = c(2, 2), mar = c(5, 4, 4, 2))
        on.exit(par(oldpar))
    }

    # Summary plot
    if (plot.type %in% c("summary", "all")) {
        if (plot.type == "summary") {
            oldpar <- par(mfrow = c(2, 1), mar = c(5, 4, 4, 2))
            on.exit(par(oldpar))
        }

        # First summary plot - Ray Counts
        y_max <- max(c(stats$summary$avg_rays, stats$summary$max_rays), na.rm = TRUE)
        plot(stats$summary$radius, stats$summary$avg_rays,
             type = "b", pch = 16, col = "blue", lwd = 2,
             xlim = range(stats$summary$radius),
             ylim = c(0, y_max * 1.1),
             xlab = "Radius", ylab = "Number of Rays",
             main = "Geodesic Ray Counts vs. Radius")
        lines(stats$summary$radius, stats$summary$max_rays,
              type = "b", pch = 17, col = "red", lwd = 2)
        legend("topleft",
               legend = c("Average Rays", "Maximum Rays"),
               col = c("blue", "red"),
               pch = c(16, 17),
               lty = 1, lwd = 2,
               bty = "n")
        grid()

        # Second summary plot - Path Properties
        y_max_prop <- max(c(stats$summary$composite_ratio,
                            stats$summary$avg_overlap_median), na.rm = TRUE)
        plot(stats$summary$radius, stats$summary$composite_ratio,
             type = "b", pch = 16, col = "darkgreen", lwd = 2,
             xlim = range(stats$summary$radius),
             ylim = c(0, y_max_prop * 1.1),
             xlab = "Radius", ylab = "Ratio",
             main = "Geodesic Path Properties vs. Radius")
        if ("avg_overlap_median" %in% names(stats$summary)) {
            lines(stats$summary$radius, stats$summary$avg_overlap_median,
                  type = "b", pch = 17, col = "purple", lwd = 2)
            legend("topleft",
                   legend = c("Composite Ratio", "Average Overlap"),
                   col = c("darkgreen", "purple"),
                   pch = c(16, 17),
                   lty = 1, lwd = 2,
                   bty = "n")
        } else {
            legend("topleft",
                   legend = "Composite Ratio",
                   col = "darkgreen",
                   pch = 16,
                   lty = 1, lwd = 2,
                   bty = "n")
        }
        grid()
    }

    # Heatmap plot
    if (plot.type %in% c("heatmap", "all")) {
        if (plot.type == "heatmap") {
            oldpar <- par(mar = c(5, 4, 4, 6))
            on.exit(par(oldpar))
        }

        # Create heatmap using image()
        rays_matrix <- t(stats$geodesic_rays)
        image(x = stats$radii,
              y = 1:nrow(stats$geodesic_rays),
              z = rays_matrix,
              col = heat.colors(100),
              xlab = "Radius",
              ylab = "Vertex Index",
              main = "Number of Geodesic Rays by Vertex and Radius")

        # Add contour lines for better visualization
        contour(x = stats$radii,
                y = 1:nrow(stats$geodesic_rays),
                z = rays_matrix,
                add = TRUE,
                col = "black",
                lwd = 0.5)
    }

    # Vertex plot
    if (plot.type %in% c("vertex", "all")) {
        if (plot.type == "vertex") {
            oldpar <- par(mar = c(5, 4, 4, 8), xpd = TRUE)
            on.exit(par(oldpar))
        }

        # Select vertices to plot
        n_vertices <- length(stats$grid_vertices)
        if (is.null(selected.vertices)) {
            if (n_vertices <= max.vertices) {
                selected_idx <- 1:n_vertices
            } else {
                selected_idx <- sample(1:n_vertices, max.vertices)
            }
        } else {
            # Find indices of selected vertices
            selected_idx <- match(selected.vertices, stats$grid_vertices)
            selected_idx <- selected_idx[!is.na(selected_idx)]
            if (length(selected_idx) == 0) {
                warning("None of the selected vertices found in grid_vertices")
                selected_idx <- sample(1:n_vertices, min(max.vertices, n_vertices))
            }
        }

        # Determine colors for vertices
        vertex_colors <- rainbow(length(selected_idx))

        # Find y-axis range
        y_max <- 0
        for (i in selected_idx) {
            rays <- stats$geodesic_rays[i,]
            composite_scaled <- stats$composite_geodesics[i,] * 5
            y_max <- max(c(y_max, rays, composite_scaled), na.rm = TRUE)
        }

        # Initialize plot
        plot(1, type = "n",
             xlim = range(stats$radii),
             ylim = c(0, y_max * 1.1),
             xlab = "Radius",
             ylab = "Count",
             main = "Geodesic Rays for Selected Vertices")

        # Plot each vertex
        for (j in seq_along(selected_idx)) {
            i <- selected_idx[j]
            col <- vertex_colors[j]

            # Plot rays
            lines(stats$radii, stats$geodesic_rays[i,],
                  type = "b", pch = 16, col = col, lwd = 2)

            # Plot composite (scaled)
            lines(stats$radii, stats$composite_geodesics[i,] * 5,
                  type = "b", pch = 17, col = col, lwd = 1, lty = 2)
        }

        # Add legend
        if (plot.type == "vertex") {
            legend("topright", inset = c(-0.35, 0),
                   legend = paste("V", stats$grid_vertices[selected_idx]),
                   col = vertex_colors,
                   lty = 1, lwd = 2,
                   bty = "n")
        }

        grid()
    }

    invisible(NULL)
}

#' Summarize overlap statistics from geodesic_stats object
#'
#' @param object A geodesic_stats object containing overlap statistics
#' @return A data frame with summary statistics for overlap at each radius
#'
#' @keywords internal
summarize_overlap_statistics <- function(object) {
    ## Get radii
    radii <- object$radii

    ## Extract overlap statistics
    overlap_stats <- object$path_overlap

    ## Create a data frame to store the summary
    if (!is.null(overlap_stats)) {
        overlap_summary <- data.frame(
            radius = radii,
            min = sapply(seq_along(radii), function(r) min(overlap_stats$min[,r], na.rm = TRUE)),
            p05 = sapply(seq_along(radii), function(r) min(overlap_stats$p05[,r], na.rm = TRUE)),
            p25 = sapply(seq_along(radii), function(r) min(overlap_stats$p25[,r], na.rm = TRUE)),
            median = sapply(seq_along(radii), function(r) stats::median(overlap_stats$median[,r], na.rm = TRUE)),
            mean = sapply(seq_along(radii), function(r) mean(overlap_stats$median[,r], na.rm = TRUE)),
            p75 = sapply(seq_along(radii), function(r) max(overlap_stats$p75[,r], na.rm = TRUE)),
            p95 = sapply(seq_along(radii), function(r) max(overlap_stats$p95[,r], na.rm = TRUE)),
            max = sapply(seq_along(radii), function(r) max(overlap_stats$max[,r], na.rm = TRUE))
        )

        return(overlap_summary)
    } else {
        return(NULL)
    }
}
