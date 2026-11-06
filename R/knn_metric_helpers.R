.normalize.knn.metric <- function(knn.metric) {
    match.arg(knn.metric, c("euclidean", "linf.simplex"))
}

.knn.metric.id <- function(knn.metric) {
    switch(knn.metric,
           euclidean = 0L,
           linf.simplex = 1L)
}

.normalize.linf.tol <- function(linf.tol) {
    if (!is.numeric(linf.tol) || length(linf.tol) != 1L || !is.finite(linf.tol) || linf.tol <= 0) {
        stop("linf.tol must be a positive finite numeric scalar.")
    }
    as.double(linf.tol)
}

.validate.linf.simplex.input <- function(X, linf.tol) {
    if (any(X < -linf.tol)) {
        stop("X must be nonnegative for knn.metric = 'linf.simplex'.")
    }

    row.max <- apply(X, 1L, max)
    bad <- which(abs(row.max - 1) > linf.tol)
    if (length(bad) > 0L) {
        stop("Each row of X must be L-infinity normalized: max(row) must equal 1 within linf.tol.")
    }

    invisible(TRUE)
}
