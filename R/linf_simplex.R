#' Intrinsic Euclidean distances on the nonnegative L-infinity simplex
#'
#' Max-normalizes each sample and computes the shortest Euclidean-length path
#' constrained to the union of faces where at least one coordinate is one.
#' This is not Chebyshev distance and does not use a data-derived graph.
#'
#' @param points Numeric matrix with samples in rows and nonnegative abundances
#'   in columns. Each row must have a positive maximum. Relative abundances,
#'   counts, and max-normalized coordinates give the same answer.
#' @param sources,targets Optional vectors of one-based row indices. Defaults
#'   to every row. Repeated indices are allowed.
#' @param pairs Optional two-column integer matrix of one-based row pairs.
#'   When supplied, sources and targets must be NULL.
#' @param return.paths Return one shortest piecewise-linear path per requested
#'   pair, together with the distances? Intended for small diagnostic queries.
#' @details Same-face distances equal Euclidean chords. Different-face paths
#'   may visit intermediate faces. The algorithm minimizes an exact unfolding
#'   cost over face sequences using Dijkstra's algorithm. It does not restrict
#'   paths to the endpoint faces. Computation uses double precision.
#'
#'   With deficits a = 1 - u and b = 1 - v, a face sequence contributes
#'   squared distance sum((u-v)^2) + 2 C, where C is the sum of
#'   a[j] * (b[i] + b[j]) over successive faces i,j. Start faces have a[i]=0;
#'   end faces have b[j]=0. A minimum-cost sequence has ordered unfolding
#'   crossings and therefore realizes a path on the simplex.
#'
#'   Work per pair is quadratic in the number of features present in either
#'   sample, with additional pruning. Matrix output uses sources-by-targets
#'   memory. Use pairs or selected sources to avoid a dense all-pairs result.
#' @return A sources-by-targets numeric matrix, or a vector for pairs. With
#'   return.paths=TRUE, a list with distances and paths; paths are ordered
#'   like as.vector(distances). Each path contains points in max-normalized
#'   coordinates, one-based face indices, and unfolded-segment times.
#' @examples
#' X <- rbind(c(1, 0, .99), c(0, 1, .99))
#' linf.simplex.distances(X)
#' linf.simplex.distances(X, pairs = matrix(c(1, 2), 1, 2), return.paths = TRUE)
#' @export
linf.simplex.distances <- function(points, sources = NULL, targets = NULL,
                                   pairs = NULL, return.paths = FALSE) {
  if (!is.matrix(points) || !is.numeric(points) || !nrow(points) || !ncol(points) ||
      anyNA(points) || any(!is.finite(points)) || any(points < 0) ||
      any(apply(points, 1L, max) <= 0))
    stop("points must be a finite nonnegative numeric matrix with positive row maxima")
  if (!is.logical(return.paths) || length(return.paths) != 1L || is.na(return.paths))
    stop("return.paths must be TRUE or FALSE")
  n <- nrow(points)
  indices <- function(z) {
    if (!is.numeric(z) || !length(z) || anyNA(z) || any(!is.finite(z)) ||
        any(z < 1 | z > n | z != trunc(z))) stop("indices must be integers between 1 and nrow(points)")
    as.integer(z)
  }
  if (!is.null(pairs)) {
    if (!is.null(sources) || !is.null(targets)) stop("pairs cannot be combined with sources or targets")
    if (!is.matrix(pairs) || ncol(pairs) != 2L || nrow(pairs) < 1L) stop("pairs must have two columns and at least one row")
    pairs <- matrix(indices(pairs), ncol = 2L)
    sources <- targets <- integer()
  } else {
    sources <- indices(if (is.null(sources)) seq_len(n) else sources)
    targets <- indices(if (is.null(targets)) seq_len(n) else targets)
    pairs <- matrix(integer(), 0L, 2L)
  }
  storage.mode(points) <- "double"
  answer <- .Call("_dgraphs_linf_simplex", points, sources, targets, pairs,
                  return.paths, PACKAGE = "dgraphs")
  if (!nrow(pairs) && !is.null(rownames(points))) {
    dn <- list(rownames(points)[sources], rownames(points)[targets])
    if (return.paths) dimnames(answer$distances) <- dn else dimnames(answer) <- dn
  }
  answer
}
