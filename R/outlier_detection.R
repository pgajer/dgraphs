#' Remove Outliers from a State Space Using k-Nearest Neighbors
#'
#' @description
#' Identifies and removes outliers from a multivariate state space based on k-nearest neighbor
#' distances. This function implements several strategies for outlier detection, all based on
#' the principle that outliers tend to be isolated from the main data clusters and thus have
#' larger distances to their nearest neighbors.
#'
#' @details
#' The function determines outliers by analyzing the distances between points and their K nearest
#' neighbors. Several detection methods are available:
#'
#' \describe{
#'   \item{When K = 1:}{Points are flagged as outliers if their distance to the nearest neighbor
#'   exceeds the p-th percentile threshold of all nearest neighbor distances.}
#'
#'   \item{"dist.factor":}{Points are considered outliers if the ratio of the K-th nearest neighbor
#'   distance to the 1st nearest neighbor distance exceeds \code{dist.factor}.}
#'
#'   \item{"diff.dist.factor" (default):}{For each point, finds the maximum jump in distance between
#'   consecutive neighbors, normalizes by the median jump across all points, and flags points as
#'   outliers if their relative jump exceeds \code{dist.factor}. This method is particularly robust
#'   as it adapts to the overall distribution of distances.}
#'
#'   \item{Default unnamed method:}{Iteratively checks if the first nearest neighbor distance exceeds
#'   the threshold or if any consecutive difference between neighbor distances exceeds the threshold.}
#' }
#'
#' @param S A numeric matrix or data frame representing the state space, where each row is an observation
#'   and each column is a dimension or feature. Must contain at least \code{K+1} observations.
#' @param y An optional numeric vector containing values of a variable defined over the state space.
#'   If provided, must have length equal to \code{nrow(S)}. The function will filter this vector
#'   to match the filtered state space.
#' @param p A numeric value between 0 and 1 (exclusive) indicating the percentile threshold for
#'   outlier removal. The default value of 0.98 removes points whose distance to the nearest
#'   neighbor exceeds the 98th percentile of all nearest neighbor distances.
#' @param dist.factor A positive numeric value used as a threshold factor in certain outlier detection
#'   methods. In "diff.dist.factor", points with relative jumps greater than this factor are
#'   considered outliers. Default is 100.
#' @param K A positive integer specifying the number of nearest neighbors to compute for each point.
#'   Must be less than the number of observations in \code{S}. Default is 30.
#' @param method A character string specifying the outlier detection method to use when K > 1.
#'   Must be one of "dist.factor", "diff.dist.factor" (default), or "default" for the unnamed method.
#'
#' @return A list of class "knn.outliers" containing the following components:
#' \describe{
#'   \item{S.q}{The filtered state space matrix with outliers removed.}
#'   \item{y.q}{The filtered dependent variable (if \code{y} was provided), otherwise \code{NULL}.}
#'   \item{nn.d}{A matrix of dimensions \code{nrow(S)} x \code{K} containing distances to the K
#'               nearest neighbors for each point.}
#'   \item{d.thld}{The distance threshold used for outlier detection.}
#'   \item{idx}{A logical vector indicating which points were kept (\code{TRUE}) and which were
#'              identified as outliers (\code{FALSE}).}
#'   \item{n.outliers}{The number of outliers detected.}
#'   \item{method}{The outlier detection method used.}
#' }
#'
#' @examples
#' # Create a sample dataset with outliers
#' set.seed(123)
#' n_normal <- 120
#' n_outliers <- 6
#'
#' # Generate normal data
#' normal_data <- matrix(rnorm(n_normal * 2), ncol = 2)
#'
#' # Generate outliers far from the main cluster
#' outliers <- cbind(rnorm(n_outliers, mean = 10, sd = 0.5),
#'                   rnorm(n_outliers, mean = 10, sd = 0.5))
#'
#' # Combine data
#' S <- rbind(normal_data, outliers)
#' y <- c(rnorm(n_normal), rnorm(n_outliers, mean = 5))
#'
#' # Remove outliers using the default method
#' result <- remove.knn.outliers(S, y, K = 10)
#'
#' # Print summary
#' cat("Number of outliers detected:", result$n.outliers, "\n")
#' cat("Percentage of data retained:",
#'     round(100 * nrow(result$S.q) / nrow(S), 2), "%\n")
#'
#' # Use a different method with more conservative threshold
#' result2 <- remove.knn.outliers(S, y, p = 0.95, method = "dist.factor",
#'                                dist.factor = 5, K = 10)
#'
#' # Plot the original and filtered state space
#' par(mfrow = c(1, 2))
#' plot(S, col = "gray", main = "Original State Space",
#'      xlab = "Dimension 1", ylab = "Dimension 2")
#' points(S[!result$idx, ], col = "red", pch = 16, cex = 1.2)
#'
#' plot(result$S.q, col = "blue", pch = 16,
#'      main = "Filtered State Space",
#'      xlab = "Dimension 1", ylab = "Dimension 2")
#' legend("topright", legend = c("Retained", "Removed"),
#'        col = c("blue", "red"), pch = 16)
#'
#' @seealso
#' \code{\link[FNN]{get.knn}} for the k-nearest neighbor calculation,
#' \code{\link[stats]{quantile}} for percentile calculations
#'
#' @importFrom FNN get.knn
#' @importFrom stats quantile median
#'
#' @export
remove.knn.outliers <- function(S, y = NULL, p = 0.98, dist.factor = 100,
                                K = 30, method = "diff.dist.factor") {

    # Input validation
    if (!is.matrix(S) && !is.data.frame(S)) {
        stop("'S' must be a matrix or data frame")
    }

    # Convert data frame to matrix if necessary
    if (is.data.frame(S)) {
        S <- as.matrix(S)
    }

    if (!is.numeric(S)) {
        stop("'S' must contain only numeric values")
    }

    if (any(!is.finite(S))) {
        stop("'S' contains non-finite values (NA, NaN, or Inf)")
    }

    n <- nrow(S)

    if (n <= K) {
        stop(sprintf("Number of observations (%d) must be greater than K (%d)", n, K))
    }

    # Validate K
    if (!is.numeric(K) || length(K) != 1) {
        stop("'K' must be a single numeric value")
    }

    K <- as.integer(K)
    if (K < 1) {
        stop("'K' must be a positive integer")
    }

    # Validate p
    if (!is.numeric(p) || length(p) != 1) {
        stop("'p' must be a single numeric value")
    }

    if (p <= 0 || p >= 1) {
        stop("'p' must be between 0 and 1 (exclusive)")
    }

    # Validate dist.factor
    if (!is.numeric(dist.factor) || length(dist.factor) != 1) {
        stop("'dist.factor' must be a single numeric value")
    }

    if (dist.factor <= 0) {
        stop("'dist.factor' must be positive")
    }

    # Validate method
    valid_methods <- c("dist.factor", "diff.dist.factor", "default")
    if (!is.character(method) || length(method) != 1) {
        stop("'method' must be a single character string")
    }

    if (!(method %in% valid_methods)) {
        stop(sprintf("'method' must be one of: %s",
                     paste(valid_methods, collapse = ", ")))
    }

    # Validate y if provided
    if (!is.null(y)) {
        if (!is.numeric(y)) {
            stop("'y' must be numeric")
        }

        if (length(y) != n) {
            stop(sprintf("Length of 'y' (%d) must equal number of rows in 'S' (%d)",
                         length(y), n))
        }

        if (any(!is.finite(y))) {
            warning("'y' contains non-finite values which will be preserved in output")
        }
    }

    # Compute k-nearest neighbors
    nn <- FNN::get.knn(S, k = K)
    nn.d <- nn$nn.dist

    # Get distances to first nearest neighbor
    d.nn <- nn.d[, 1]

    # Calculate threshold
    d.thld <- stats::quantile(d.nn, probs = p, na.rm = TRUE)

    # Initialize index vector
    idx <- rep(TRUE, n)

    # Apply outlier detection method
    if (K == 1) {
        # Simple threshold method for K=1
        idx <- d.nn < d.thld

    } else if (method == "dist.factor") {
        # Ratio of K-th to 1st neighbor distance
        d.rat <- nn.d[, K] / d.nn
        # Handle division by zero
        d.rat[!is.finite(d.rat)] <- Inf
        idx <- d.rat < dist.factor

    } else if (method == "diff.dist.factor") {
        # Maximum jump in consecutive neighbor distances
        jump <- apply(nn.d, 1, function(x) {
            diffs <- diff(x)
            if (length(diffs) == 0) return(0)
            max(diffs)
        })

        jump.median <- stats::median(jump, na.rm = TRUE)

        # Handle edge case where all jumps are zero
        if (jump.median == 0) {
            warning("All distance jumps are zero; no outliers will be detected")
            rel.jump <- rep(0, length(jump))
        } else {
            rel.jump <- jump / jump.median
        }

        idx <- rel.jump < dist.factor

    } else {
        # Default method: iterative checking
        for (i in seq_len(n)) {
            d <- nn.d[i, ]
            d1 <- d[1]
            dd <- diff(d)

            # Check if first distance or any difference exceeds threshold
            if (d1 >= d.thld || any(dd >= d.thld)) {
                idx[i] <- FALSE
            }
        }
    }

    # Filter data
    S.q <- S[idx, , drop = FALSE]
    y.q <- NULL

    if (!is.null(y)) {
        y.q <- y[idx]
    }

    # Count outliers
    n.outliers <- sum(!idx)

    # Prepare result
    result <- list(
        S.q = S.q,
        y.q = y.q,
        nn.d = nn.d,
        d.thld = d.thld,
        idx = idx,
        n.outliers = n.outliers,
        method = method
    )

    class(result) <- "knn.outliers"

    return(result)
}


#' Print Method for knn.outliers Objects
#'
#' @description
#' Prints a summary of the outlier detection results from \code{remove.knn.outliers}.
#'
#' @param x An object of class "knn.outliers" as returned by \code{remove.knn.outliers}.
#' @param ... Additional arguments passed to \code{print} methods.
#'
#' @return Invisibly returns the input object.
#'
#' @examples
#' knn.res <- list(
#'   S.q = matrix(c(0, 0,
#'                  1, 1,
#'                  2, 2), ncol = 2, byrow = TRUE),
#'   y.q = c(1.0, 1.5, 2.0),
#'   nn.d = matrix(c(0.2, 0.4,
#'                   0.3, 0.5,
#'                   1.4, 1.8,
#'                   0.25, 0.45),
#'                 ncol = 2, byrow = TRUE),
#'   d.thld = 1,
#'   idx = c(TRUE, TRUE, FALSE, TRUE),
#'   n.outliers = 1L,
#'   method = "qf"
#' )
#' class(knn.res) <- "knn.outliers"
#'
#' knn.res
#' @export
print.knn.outliers <- function(x, ...) {
    cat("k-Nearest Neighbor Outlier Detection Results\n")
    cat("============================================\n")
    cat("Method:", x$method, "\n")
    cat("Original observations:", length(x$idx), "\n")
    cat("Outliers detected:", x$n.outliers,
        sprintf("(%.1f%%)", 100 * x$n.outliers / length(x$idx)), "\n")
    cat("Observations retained:", sum(x$idx),
        sprintf("(%.1f%%)", 100 * sum(x$idx) / length(x$idx)), "\n")
    cat("Distance threshold:", format(x$d.thld, digits = 4), "\n")

    invisible(x)
}


#' Summary Method for knn.outliers Objects
#'
#' @description
#' Provides a detailed summary of the outlier detection results from \code{remove.knn.outliers}.
#'
#' @param object An object of class "knn.outliers" as returned by \code{remove.knn.outliers}.
#' @param ... Additional arguments (currently unused).
#'
#' @return A list of class "summary.knn.outliers" containing summary statistics.
#'
#' @examples
#' knn.res <- list(
#'   S.q = matrix(c(0, 0,
#'                  1, 1,
#'                  2, 2), ncol = 2, byrow = TRUE),
#'   y.q = c(1.0, 1.5, 2.0),
#'   nn.d = matrix(c(0.2, 0.4,
#'                   0.3, 0.5,
#'                   1.4, 1.8,
#'                   0.25, 0.45),
#'                 ncol = 2, byrow = TRUE),
#'   d.thld = 1,
#'   idx = c(TRUE, TRUE, FALSE, TRUE),
#'   n.outliers = 1L,
#'   method = "qf"
#' )
#' class(knn.res) <- "knn.outliers"
#'
#' summary(knn.res)
#' @export
summary.knn.outliers <- function(object, ...) {
    # Calculate summary statistics for nearest neighbor distances
    nn.summary <- apply(object$nn.d, 2, function(x) {
        c(Min = min(x), Q1 = stats::quantile(x, 0.25),
          Median = stats::median(x), Mean = mean(x),
          Q3 = stats::quantile(x, 0.75), Max = max(x))
    })

    colnames(nn.summary) <- paste0("NN", seq_len(ncol(nn.summary)))

    # Outlier distances
    outlier.distances <- object$nn.d[!object$idx, 1]
    retained.distances <- object$nn.d[object$idx, 1]

    result <- list(
        method = object$method,
        n.total = length(object$idx),
        n.outliers = object$n.outliers,
        n.retained = sum(object$idx),
        pct.outliers = 100 * object$n.outliers / length(object$idx),
        threshold = object$d.thld,
        nn.summary = nn.summary,
        outlier.dist.summary = if (length(outlier.distances) > 0) {
            summary(outlier.distances)
        } else {
            "No outliers detected"
        },
        retained.dist.summary = summary(retained.distances)
    )

    class(result) <- "summary.knn.outliers"
    return(result)
}


#' Print Method for summary.knn.outliers Objects
#'
#' @description
#' Prints the summary of outlier detection results.
#'
#' @param x An object of class "summary.knn.outliers".
#' @param ... Additional arguments passed to \code{print} methods.
#'
#' @return Invisibly returns the input object.
#'
#' @examples
#' knn.res <- list(
#'   S.q = matrix(c(0, 0,
#'                  1, 1,
#'                  2, 2), ncol = 2, byrow = TRUE),
#'   y.q = c(1.0, 1.5, 2.0),
#'   nn.d = matrix(c(0.2, 0.4,
#'                   0.3, 0.5,
#'                   1.4, 1.8,
#'                   0.25, 0.45),
#'                 ncol = 2, byrow = TRUE),
#'   d.thld = 1,
#'   idx = c(TRUE, TRUE, FALSE, TRUE),
#'   n.outliers = 1L,
#'   method = "qf"
#' )
#' class(knn.res) <- "knn.outliers"
#'
#' summary(knn.res)
#'
#' @export
print.summary.knn.outliers <- function(x, ...) {
    cat("\nk-Nearest Neighbor Outlier Detection Summary\n")
    cat("=============================================\n\n")

    cat("Method:", x$method, "\n")
    cat("Distance threshold:", format(x$threshold, digits = 4), "\n\n")

    cat("Data Summary:\n")
    cat("  Total observations:", x$n.total, "\n")
    cat("  Outliers detected:", x$n.outliers,
        sprintf("(%.1f%%)", x$pct.outliers), "\n")
    cat("  Observations retained:", x$n.retained,
        sprintf("(%.1f%%)", 100 - x$pct.outliers), "\n\n")

    cat("Nearest Neighbor Distance Summary:\n")
    print(round(x$nn.summary[, 1:min(5, ncol(x$nn.summary))], 4))

    if (ncol(x$nn.summary) > 5) {
        cat("  ... and", ncol(x$nn.summary) - 5, "more neighbors\n")
    }

    cat("\nFirst Nearest Neighbor Distances:\n")
    cat("  Retained points:\n")
    print(x$retained.dist.summary)

    if (!is.character(x$outlier.dist.summary)) {
        cat("  Outlier points:\n")
        print(x$outlier.dist.summary)
    } else {
        cat("  Outlier points:", x$outlier.dist.summary, "\n")
    }

    invisible(x)
}
