#' Jensen-Shannon Divergence
#'
#' @param p Numeric probability vector.
#' @param q Numeric probability vector.
#'
#' @return Jensen-Shannon divergence using log base 2.
#'
#' @examples
#' jensen.shannon.divergence(c(0.75, 0.25), c(0.5, 0.5))
#'
#' @export
jensen.shannon.divergence <- function(p, q) {
    p <- as.numeric(p)
    q <- as.numeric(q)
    if (length(p) != length(q)) {
        max.length <- max(length(p), length(q))
        if (length(p) < max.length) {
            p <- c(p, rep(0, max.length - length(p)))
        } else {
            q <- c(q, rep(0, max.length - length(q)))
        }
    }
    if (any(!is.finite(p)) || any(!is.finite(q))) {
        stop("Probability vectors must be finite.", call. = FALSE)
    }
    if (any(p < 0) || any(q < 0)) {
        stop("Probability vectors cannot contain negative values.", call. = FALSE)
    }
    if (sum(p) <= 0 || sum(q) <= 0) {
        stop("Probability vectors must have positive total mass.", call. = FALSE)
    }
    p <- p / sum(p)
    q <- q / sum(q)
    m <- (p + q) / 2
    kl <- function(x, y) {
        idx <- x > 0
        sum(x[idx] * log2(x[idx] / y[idx]))
    }
    (kl(p, m) + kl(q, m)) / 2
}
