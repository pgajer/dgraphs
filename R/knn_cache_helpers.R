.normalize.knn.cache.path <- function(knn.cache.path, knn.cache.mode) {
    if (!is.null(knn.cache.path)) {
        if (!is.character(knn.cache.path) || length(knn.cache.path) != 1 || is.na(knn.cache.path) ||
            !nzchar(knn.cache.path)) {
            stop("knn.cache.path must be NULL or a non-empty character scalar.")
        }
    }
    if (!identical(knn.cache.mode, "none") && is.null(knn.cache.path)) {
        stop("knn.cache.path must be provided when knn.cache.mode is not 'none'.")
    }
    if (is.null(knn.cache.path)) {
        return(NULL)
    }

    knn.cache.path <- path.expand(knn.cache.path)
    if (!nzchar(knn.cache.path)) {
        stop("knn.cache.path must be NULL or a non-empty character scalar.")
    }

    if (grepl("[/\\\\]$", knn.cache.path) || dir.exists(knn.cache.path)) {
        stop("knn.cache.path must include a cache filename, not a directory path.")
    }

    if (knn.cache.mode %in% c("write", "readwrite")) {
        parent.dir <- dirname(knn.cache.path)
        if (!dir.exists(parent.dir)) {
            ok <- dir.create(parent.dir, recursive = TRUE, showWarnings = FALSE)
            if (!ok && !dir.exists(parent.dir)) {
                stop(sprintf("Failed to create directory for knn.cache.path: '%s'.", parent.dir))
            }
        }
    }

    knn.cache.path
}
