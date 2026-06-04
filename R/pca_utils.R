#' Select PCA Components by Cumulative Variance
#'
#' Internal helper used by MST-completion graph construction.
#'
#' @param X Numeric data matrix.
#' @param variance.threshold Cumulative variance fraction to retain.
#' @param max.components Maximum number of components to allow.
#' @param center,scale Arguments forwarded to [stats::prcomp()].
#'
#' @return A list containing the selected component count, variance retained,
#'   cumulative variance curve, and fitted PCA object.
#' @keywords internal
#' @noRd
pca.optimal.components <- function(X,
                                   variance.threshold = 0.99,
                                   max.components = NULL,
                                   center = TRUE,
                                   scale = FALSE) {
    if (is.null(max.components) || max.components > ncol(X)) {
        max.components <- ncol(X)
    }

    pca.result <- stats::prcomp(X, center = center, scale. = scale)
    total.variance <- sum(pca.result$sdev^2)
    cumulative.variance <- cumsum(pca.result$sdev^2) / total.variance

    n.components <- which(cumulative.variance >= variance.threshold)[1L]
    if (is.na(n.components)) {
        n.components <- length(cumulative.variance)
    }
    n.components <- min(n.components, max.components)

    list(
        n.components = n.components,
        variance.explained = cumulative.variance[n.components],
        cumulative.variance = cumulative.variance,
        pca.result = pca.result
    )
}

#' Project Data onto Principal Components
#'
#' Internal helper used by MST-completion graph construction.
#'
#' @param X Numeric data matrix.
#' @param pca.result A fitted PCA object returned by [stats::prcomp()].
#' @param n.components Number of leading principal components to retain.
#'
#' @return Projected matrix with original row names preserved.
#' @keywords internal
#' @noRd
pca.project <- function(X, pca.result, n.components) {
    row.names <- rownames(X)
    projection <- pca.result$x[, seq_len(n.components), drop = FALSE]
    if (!is.null(row.names)) {
        rownames(projection) <- row.names
    }
    projection
}
