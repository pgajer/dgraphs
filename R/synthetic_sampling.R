# Sampling component specifications and exact draw algorithms.

.new.synthetic.sampling <- function(family, parameters, version = 1L,
                                    subclass = "synthetic_sampling_component") {
  .new.synthetic.component(
    "sampling", family, parameters, version,
    subclass = c(paste0("synthetic_", gsub("\\.", "_", family), "_sampling"),
                 subclass))
}

#' Uniform-box sampling specification
#' @param lower,upper Scalar or coordinate-wise bounds.
#' @param order Row ordering policy.
#' @param algorithm Versioned draw algorithm.
#' @return A synthetic sampling component.
#' @examples
#' synthetic.sampling.uniform.box(lower = c(-1, 0), upper = c(1, 2))
#' @export
synthetic.sampling.uniform.box <- function(
    lower, upper, order = c("draw", "ascending.first.coordinate"),
    algorithm = "column.major.runif.v1") {
  lower <- as.double(lower)
  upper <- as.double(upper)
  if (!length(lower) || !length(upper) || any(!is.finite(lower)) ||
      any(!is.finite(upper))) {
    stop("lower and upper must be nonempty finite numeric vectors.",
         call. = FALSE)
  }
  order <- match.arg(order)
  .new.synthetic.sampling(
    "uniform.box",
    list(lower = lower, upper = upper, order = order,
         algorithm = .synthetic.scalar.character(algorithm, "algorithm")))
}

#' Uniform-disk sampling specification
#' @param radius Disk radius.
#' @param algorithm Versioned draw algorithm.
#' @return A synthetic sampling component.
#' @examples
#' synthetic.sampling.uniform.disk(radius = 2)
#' @export
synthetic.sampling.uniform.disk <- function(
    radius = 1, algorithm = "radial.sqrt.v1") {
  radius <- .synthetic.scalar.double(radius, "radius", 0, strict = TRUE)
  .new.synthetic.sampling(
    "uniform.disk", list(radius = radius, algorithm = algorithm))
}

#' Uniform-interval sampling specification
#' @param lower,upper Interval bounds.
#' @param order Ordering policy.
#' @param algorithm Versioned draw algorithm.
#' @return A synthetic sampling component.
#' @examples
#' synthetic.sampling.uniform.interval(0, 1, order = "ascending")
#' @export
synthetic.sampling.uniform.interval <- function(
    lower, upper, order = c("draw", "ascending"),
    algorithm = "runif.v1") {
  lower <- .synthetic.scalar.double(lower, "lower")
  upper <- .synthetic.scalar.double(upper, "upper")
  if (lower >= upper) stop("lower must be smaller than upper.", call. = FALSE)
  .new.synthetic.sampling(
    "uniform.interval",
    list(lower = lower, upper = upper, order = match.arg(order),
         algorithm = algorithm))
}

#' Deterministic interval-grid sampling specification
#'
#' @param lower,upper Interval bounds.
#' @param endpoints Endpoint convention. `"exclude.lower"` reproduces the
#'   historical circle grid; `"include.both"` reproduces the historical
#'   uniform trefoil grid.
#' @return A deterministic synthetic sampling component.
#' @examples
#' synthetic.sampling.grid.interval(0, 2 * pi, endpoints = "exclude.lower")
#' @export
synthetic.sampling.grid.interval <- function(
    lower, upper,
    endpoints = c("exclude.lower", "exclude.upper", "include.both")) {
  lower <- .synthetic.scalar.double(lower, "lower")
  upper <- .synthetic.scalar.double(upper, "upper")
  if (lower >= upper) stop("lower must be smaller than upper.", call. = FALSE)
  .new.synthetic.sampling(
    "grid.interval",
    list(
      lower = lower,
      upper = upper,
      endpoints = match.arg(endpoints),
      algorithm = "base.seq.length.out.v1"))
}

#' Uniform-rectangle sampling specification
#' @param lower,upper Length-two coordinate bounds.
#' @param algorithm Versioned draw algorithm.
#' @return A synthetic sampling component.
#' @examples
#' synthetic.sampling.uniform.rectangle(c(-1, -2), c(1, 2))
#' @export
synthetic.sampling.uniform.rectangle <- function(
    lower, upper, algorithm = "coordinate.sequential.runif.v1") {
  lower <- as.double(lower)
  upper <- as.double(upper)
  if (length(lower) != 2L || length(upper) != 2L ||
      any(!is.finite(c(lower, upper))) || any(lower >= upper)) {
    stop("lower and upper must be finite increasing length-two bounds.",
         call. = FALSE)
  }
  .new.synthetic.sampling(
    "uniform.rectangle",
    list(lower = lower, upper = upper, algorithm = algorithm))
}

#' Truncated-normal sampling specification
#' @param mean,sd Normal parameters.
#' @param lower,upper Truncation bounds.
#' @param order Ordering policy.
#' @param algorithm Versioned draw algorithm.
#' @return A synthetic sampling component.
#' @examples
#' synthetic.sampling.truncated.normal(0, 1, -2, 2)
#' @export
synthetic.sampling.truncated.normal <- function(
    mean, sd, lower, upper, order = c("draw", "ascending"),
    algorithm = "inverse.cdf.v1") {
  mean <- .synthetic.scalar.double(mean, "mean")
  sd <- .synthetic.scalar.double(sd, "sd", 0, strict = TRUE)
  lower <- .synthetic.scalar.double(lower, "lower")
  upper <- .synthetic.scalar.double(upper, "upper")
  if (lower >= upper) stop("lower must be smaller than upper.", call. = FALSE)
  .new.synthetic.sampling(
    "truncated.normal",
    list(mean = mean, sd = sd, lower = lower, upper = upper,
         order = match.arg(order), algorithm = algorithm))
}

#' Gapped-uniform sampling specification
#' @param intervals Two-column matrix of disjoint intervals.
#' @param allocation Allocation policy.
#' @param probabilities Optional allocation probabilities.
#' @param counts Optional fixed counts.
#' @param rounding Fixed-proportion rounding rule.
#' @param order Ordering policy.
#' @param algorithm Versioned draw algorithm.
#' @return A synthetic sampling component.
#' @examples
#' intervals <- rbind(c(-1, -0.25), c(0.25, 1))
#' synthetic.sampling.gapped.uniform(intervals, probabilities = c(0.5, 0.5))
#' @export
synthetic.sampling.gapped.uniform <- function(
    intervals,
    allocation = c("multinomial", "fixed.proportion", "fixed.count"),
    probabilities = NULL, counts = NULL,
    rounding = c("largest.remainder", "floor.first.remainder.last"),
    order = c("draw", "ascending"),
    algorithm = "sequential.interval.runif.v1") {
  intervals <- as.matrix(intervals)
  storage.mode(intervals) <- "double"
  if (ncol(intervals) != 2L || !nrow(intervals) ||
      any(!is.finite(intervals)) || any(intervals[, 1] >= intervals[, 2])) {
    stop("intervals must be a nonempty two-column matrix of increasing bounds.",
         call. = FALSE)
  }
  ord <- order(intervals[, 1])
  intervals <- intervals[ord, , drop = FALSE]
  if (nrow(intervals) > 1L &&
      any(intervals[-nrow(intervals), 2] >= intervals[-1L, 1])) {
    stop("intervals must be disjoint.", call. = FALSE)
  }
  allocation <- match.arg(allocation)
  if (!is.null(probabilities)) {
    probabilities <- as.double(probabilities)
    if (length(probabilities) != nrow(intervals) ||
        any(!is.finite(probabilities)) || any(probabilities < 0) ||
        abs(sum(probabilities) - 1) > 1e-12) {
      stop("probabilities must be nonnegative and sum to one.", call. = FALSE)
    }
  }
  if (!is.null(counts)) counts <- as.integer(counts)
  .new.synthetic.sampling(
    "gapped.uniform",
    list(intervals = intervals, allocation = allocation,
         probabilities = probabilities, counts = counts,
         rounding = match.arg(rounding), order = match.arg(order),
         algorithm = algorithm))
}

#' Clustered sampling specification
#' @param cluster.count Number of clusters.
#' @param observations.per.cluster Rows per cluster.
#' @param center.lower,center.upper Center box bounds.
#' @param within.sd Within-cluster standard deviation.
#' @param algorithm Versioned draw algorithm.
#' @return A fixed-size synthetic sampling component.
#' @examples
#' synthetic.sampling.clustered(3L, 5L, within.sd = 0.1)
#' @export
synthetic.sampling.clustered <- function(
    cluster.count, observations.per.cluster,
    center.lower = -1, center.upper = 1, within.sd,
    algorithm = "centers.then.gaussian.offsets.v1") {
  cluster.count <- .synthetic.scalar.integer(
    cluster.count, "cluster.count", 1L)
  observations.per.cluster <- .synthetic.scalar.integer(
    observations.per.cluster, "observations.per.cluster", 1L)
  within.sd <- .synthetic.scalar.double(within.sd, "within.sd", 0)
  center.lower <- .synthetic.scalar.double(center.lower, "center.lower")
  center.upper <- .synthetic.scalar.double(center.upper, "center.upper")
  if (center.lower >= center.upper) {
    stop("center.lower must be smaller than center.upper.", call. = FALSE)
  }
  .new.synthetic.sampling(
    "clustered",
    list(cluster.count = cluster.count,
         observations.per.cluster = observations.per.cluster,
         center.lower = center.lower, center.upper = center.upper,
         within.sd = within.sd, algorithm = algorithm,
         fixed.n = cluster.count * observations.per.cluster))
}

.stop.empty.zero.parts <- function() {
  condition <- structure(
    list(message = paste0(
      "zero.parts must contain at least one and fewer than parts indices; ",
      "use zero.fraction = 0 for ordinary Dirichlet sampling.")),
    class = c("geosmooth_empty_zero_parts", "error", "condition"))
  stop(condition)
}

#' Dirichlet sampling with structural zeros
#' @param concentration Scalar or part-wise Dirichlet concentration.
#' @param zero.fraction Fraction of rows receiving structural zeros.
#' @param zero.parts Part indices set to zero.
#' @param zero.row.policy Row-selection policy.
#' @param count.rounding Count rule.
#' @param algorithm Versioned draw algorithm.
#' @return A synthetic sampling component.
#' @examples
#' synthetic.sampling.dirichlet.zeros(
#'   concentration = rep(1, 3), zero.fraction = 0.2, zero.parts = 1L
#' )
#' @export
synthetic.sampling.dirichlet.zeros <- function(
    concentration, zero.fraction, zero.parts,
    zero.row.policy = c("first", "random"),
    count.rounding = "round", algorithm = "normalized.gamma.v1") {
  concentration <- as.double(concentration)
  if (!length(concentration) || any(!is.finite(concentration)) ||
      any(concentration <= 0)) {
    stop("concentration must contain positive finite values.", call. = FALSE)
  }
  zero.fraction <- .synthetic.scalar.double(
    zero.fraction, "zero.fraction")
  if (zero.fraction < 0 || zero.fraction > 1) {
    stop("zero.fraction must lie in [0, 1].", call. = FALSE)
  }
  zero.parts <- as.integer(zero.parts)
  if (!length(zero.parts)) .stop.empty.zero.parts()
  if (anyNA(zero.parts) || any(zero.parts < 1L) ||
      anyDuplicated(zero.parts)) {
    stop("zero.parts must contain unique positive indices.", call. = FALSE)
  }
  .new.synthetic.sampling(
    "dirichlet.zeros",
    list(concentration = concentration, zero.fraction = zero.fraction,
         zero.parts = zero.parts,
         zero.row.policy = match.arg(zero.row.policy),
         count.rounding = count.rounding, algorithm = algorithm))
}

.synthetic.fixed.n <- function(sampling) sampling$parameters$fixed.n

.synthetic.allocate.gapped <- function(p, n) {
  k <- nrow(p$intervals)
  if (p$allocation == "fixed.count") {
    if (length(p$counts) != k || sum(p$counts) != n || any(p$counts < 0)) {
      stop("Fixed counts must be nonnegative and sum to n.", call. = FALSE)
    }
    return(as.integer(p$counts))
  }
  if (is.null(p$probabilities)) {
    stop("probabilities are required for this allocation.", call. = FALSE)
  }
  if (p$allocation == "multinomial") {
    return(as.integer(stats::rmultinom(1L, n, p$probabilities)[, 1]))
  }
  if (p$rounding == "floor.first.remainder.last") {
    counts <- floor(n * p$probabilities)
    if (k > 1L) counts[k] <- n - sum(counts[-k])
    return(as.integer(counts))
  }
  raw <- n * p$probabilities
  counts <- floor(raw)
  remainder <- n - sum(counts)
  if (remainder > 0L) {
    idx <- order(raw - counts, decreasing = TRUE)[seq_len(remainder)]
    counts[idx] <- counts[idx] + 1L
  }
  as.integer(counts)
}

.draw.synthetic.sampling <- function(sampling, n, geometry) {
  p <- sampling$parameters
  gp <- geometry$parameters
  family <- sampling$family
  n <- .synthetic.scalar.integer(n, "n", 1L)
  out <- list(latent = NULL, predictors = NULL, latent.mask = NULL,
              region = NULL, parameters = list())
  if (family == "uniform.box") {
    d <- gp$intrinsic.dim
    lower <- rep(p$lower, length.out = d)
    upper <- rep(p$upper, length.out = d)
    if (length(p$lower) > 1L && length(p$lower) != d ||
        length(p$upper) > 1L && length(p$upper) != d ||
        any(lower >= upper)) {
      stop("Uniform-box bounds are incompatible with geometry dimension.",
           call. = FALSE)
    }
    out$latent <- vapply(
      seq_len(d),
      function(j) stats::runif(n, lower[j], upper[j]),
      numeric(n))
    if (d == 1L) out$latent <- matrix(out$latent, ncol = 1L)
    if (p$order == "ascending.first.coordinate") {
      out$latent <- out$latent[order(out$latent[, 1], seq_len(n)), ,
                               drop = FALSE]
    }
  } else if (family == "uniform.disk") {
    u <- stats::runif(n)
    v <- stats::runif(n)
    r <- p$radius * sqrt(u)
    theta <- 2 * pi * v
    out$latent <- cbind(r * cos(theta), r * sin(theta))
  } else if (family == "uniform.interval") {
    x <- stats::runif(n, p$lower, p$upper)
    if (p$order == "ascending") x <- sort(x)
    out$latent <- matrix(x, ncol = 1L)
  } else if (family == "grid.interval") {
    x <- if (p$endpoints == "exclude.lower") {
      seq(p$lower, p$upper, length.out = n + 1L)[-1L]
    } else if (p$endpoints == "exclude.upper") {
      seq(p$lower, p$upper, length.out = n + 1L)[-(n + 1L)]
    } else {
      seq(p$lower, p$upper, length.out = n)
    }
    out$latent <- matrix(x, ncol = 1L)
  } else if (family == "uniform.rectangle") {
    x1 <- stats::runif(n, p$lower[1], p$upper[1])
    x2 <- stats::runif(n, p$lower[2], p$upper[2])
    out$latent <- cbind(x1, x2)
  } else if (family == "truncated.normal") {
    p0 <- stats::pnorm(p$lower, p$mean, p$sd)
    p1 <- stats::pnorm(p$upper, p$mean, p$sd)
    x <- stats::qnorm(stats::runif(n, p0, p1), p$mean, p$sd)
    if (p$order == "ascending") x <- sort(x)
    out$latent <- matrix(x, ncol = 1L)
  } else if (family == "gapped.uniform") {
    counts <- .synthetic.allocate.gapped(p, n)
    x <- unlist(lapply(seq_along(counts), function(j) {
      stats::runif(counts[j], p$intervals[j, 1], p$intervals[j, 2])
    }), use.names = FALSE)
    if (p$order == "ascending") x <- sort(x)
    out$latent <- matrix(x, ncol = 1L)
    out$parameters$interval.counts <- counts
  } else if (family == "clustered") {
    K <- p$cluster.count
    m <- p$observations.per.cluster
    centers <- matrix(stats::runif(K * 2L, p$center.lower, p$center.upper),
                      ncol = 2L)
    cluster <- rep(seq_len(K), each = m)
    offsets <- matrix(stats::rnorm(n * 2L, sd = p$within.sd), ncol = 2L)
    out$latent <- centers[cluster, , drop = FALSE] + offsets
    out$region <- as.character(cluster)
    out$parameters$centers <- centers
    out$parameters$cluster <- cluster
  } else if (family == "dirichlet.zeros") {
    D <- gp$parts
    alpha <- rep(p$concentration, length.out = D)
    if (length(p$concentration) > 1L && length(p$concentration) != D) {
      stop("concentration length must be one or parts.", call. = FALSE)
    }
    if (any(p$zero.parts > D) || length(p$zero.parts) >= D) {
      stop("zero.parts must be a nonempty proper subset of parts.",
           call. = FALSE)
    }
    G <- matrix(stats::rgamma(n * D, shape = rep(alpha, each = n)),
                nrow = n)
    comp <- G / rowSums(G)
    nzero <- round(p$zero.fraction * n)
    zero.idx <- if (!nzero) integer() else if (p$zero.row.policy == "first") {
      seq_len(nzero)
    } else {
      sample.int(n, nzero)
    }
    if (length(zero.idx)) {
      comp[zero.idx, p$zero.parts] <- 0
      comp[zero.idx, ] <- comp[zero.idx, , drop = FALSE] /
        rowSums(comp[zero.idx, , drop = FALSE])
    }
    out$predictors <- comp
    out$region <- rep("interior", n)
    out$region[zero.idx] <- "zero"
    out$parameters$zero.idx <- zero.idx
    out$parameters$active.parts <- list(
      interior = seq_len(D), zero = setdiff(seq_len(D), p$zero.parts))
  } else {
    stop("Unsupported sampling family: ", family, call. = FALSE)
  }
  out
}

.validate.synthetic.support <- function(geometry, sampling) {
  gp <- geometry$parameters
  sp <- sampling$parameters
  gf <- geometry$family
  sf <- sampling$family
  if (gf == "sphere.cap" && sf == "uniform.disk" &&
      sp$radius > gp$footprint.radius) {
    stop("Disk support exceeds the sphere-cap footprint.", call. = FALSE)
  }
  if (gf == "helix" && sf %in% c("uniform.interval", "grid.interval") &&
      (sp$lower < gp$t.range[1] || sp$upper > gp$t.range[2])) {
    stop("Interval support lies outside the helix domain.", call. = FALSE)
  }
  if (gf == "circle" && sf %in% c("uniform.interval", "grid.interval") &&
      (sp$lower < gp$angle.range[1] || sp$upper > gp$angle.range[2])) {
    stop("Interval support lies outside the circle domain.", call. = FALSE)
  }
  if (gf == "trefoil" && sf %in% c("uniform.interval", "grid.interval") &&
      (sp$lower < gp$t.range[1] || sp$upper > gp$t.range[2])) {
    stop("Interval support lies outside the trefoil domain.", call. = FALSE)
  }
  if (gf == "torus.patch" && sf == "uniform.rectangle" &&
      (any(sp$lower < c(gp$u.range[1], gp$v.range[1])) ||
       any(sp$upper > c(gp$u.range[2], gp$v.range[2])))) {
    stop("Rectangle support lies outside the torus-patch domain.",
         call. = FALSE)
  }
  if (gf == "simplex" && sf != "dirichlet.zeros") {
    stop("Simplex geometry requires Dirichlet sampling.", call. = FALSE)
  }
  if (gf == "g4.segment.rectangle" && sf != "stratified.g4") {
    stop("G4 stratified geometry requires G4 stratified sampling.",
         call. = FALSE)
  }
  invisible(TRUE)
}
