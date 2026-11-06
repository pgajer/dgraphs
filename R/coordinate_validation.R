
# Validate once at the public boundary, preserving one-dimensional matrices.
.path.coordinates <- function(X, name) {
    if (!is.matrix(X) || !is.numeric(X) || is.complex(X) || nrow(X) < 1L || ncol(X) < 1L ||
        any(!is.finite(X))) {
        stop(name, " must be a finite numeric matrix with at least one row and one column.",
             call. = FALSE)
    }
    storage.mode(X) <- "double"
    X
}
