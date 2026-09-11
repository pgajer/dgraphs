# Public geometry-only boundary. Statistical recipe and retry policy belong
# to the caller; these functions neither generate responses nor hash datasets.

.synthetic.validate.component <- function(x, kind) {
  if (!is.list(x) || !.is.synthetic.component(x, kind) ||
      !identical(x$version, 1L) || !is.list(x$parameters) ||
      .synthetic.prohibited(x$parameters))
    stop("Expected a version-1 synthetic ", kind, " component.", call. = FALSE)
  family <- .synthetic.scalar.character(x$family, "family")
  if (family %in% c("stratified.g4", "g4.segment.rectangle"))
    stop("Legacy G4 geometry and sampling remain in geosmooth; unsupported by dgraphs.", call. = FALSE)
  families <- if (kind == "geometry") {
    c("quadform", "sphere.cap", "helix", "circle", "trefoil", "torus.patch",
      "simplex", "stratified")
  } else {
    c("uniform.box", "uniform.disk", "uniform.interval", "grid.interval",
      "uniform.rectangle", "truncated.normal", "gapped.uniform", "clustered",
      "dirichlet.zeros")
  }
  if (!family %in% families) stop("Unsupported ", kind, " family: ", family, call. = FALSE)
  prefix <- if (kind == "geometry") "synthetic." else "synthetic.sampling."
  constructor <- get(paste0(prefix, family), envir = environment(.synthetic.validate.component))
  args <- x$parameters[intersect(names(x$parameters), names(formals(constructor)))]
  rebuilt <- do.call(constructor, args)
  a <- x$parameters[sort(names(x$parameters))]
  b <- rebuilt$parameters[sort(names(rebuilt$parameters))]
  if (!isTRUE(all.equal(a, b))) stop("Inconsistent ", kind, " parameters.", call. = FALSE)
  invisible(x)
}

#' Validate a geometry specification or its latent coordinates
#' @param geometry A geometry component constructed by this package.
#' @param latent Optional latent coordinate matrix.
#' @return With no latent input, the unchanged geometry invisibly. Otherwise,
#'   the validated latent coordinates as a double matrix.
#' @examples
#' validate.synthetic.geometry(synthetic.circle(), matrix(c(0, pi), ncol = 1))
#' @export
validate.synthetic.geometry <- function(geometry, latent = NULL) {
  .synthetic.validate.component(geometry, "geometry")
  if (is.null(latent)) return(invisible(geometry))
  .validate.synthetic.latent(geometry, latent)
}

#' Validate a point-sampling specification and geometric support
#' @param sampling A sampling component constructed by this package.
#' @param geometry Optional geometry component for support checks.
#' @return The unchanged sampling specification, invisibly.
#' @examples
#' validate.synthetic.sampling(synthetic.sampling.uniform.disk(0.5),
#'   synthetic.sphere.cap())
#' @export
validate.synthetic.sampling <- function(sampling, geometry = NULL) {
  .synthetic.validate.component(sampling, "sampling")
  if (!is.null(geometry)) {
    validate.synthetic.geometry(geometry)
    .validate.synthetic.support(geometry, sampling)
    d <- geometry$parameters$intrinsic.dim
    family <- sampling$family
    expected <- if (family %in% c("uniform.disk", "uniform.rectangle", "clustered")) 2L
      else if (family %in% c("uniform.interval", "grid.interval", "truncated.normal", "gapped.uniform")) 1L
      else NULL
    if (!is.null(expected) && !identical(as.integer(d), expected))
      stop("Sampling dimension does not match geometry.", call. = FALSE)
    if (family == "dirichlet.zeros" && geometry$family != "simplex")
      stop("Dirichlet sampling requires simplex geometry.", call. = FALSE)
  }
  invisible(sampling)
}

.synthetic.validate.state <- function(state, name) {
  # Explicit state interchange supports the two RNG kinds used by the
  # historical generators, with Inversion normals and Rejection sampling.
  if (!is.integer(state) || anyNA(state) ||
      !((length(state) == 7L && state[1L] == 10407L) ||
        (length(state) == 626L && state[1L] == 10403L)))
    stop(name, " must be a complete L'Ecuyer-CMRG or Mersenne-Twister state with Inversion/Rejection.", call. = FALSE)
  if (state[1L] == 10403L && (state[2L] < 0L || state[2L] > 624L))
    stop(name, " has an invalid Mersenne-Twister position.", call. = FALSE)
  if (state[1L] == 10407L) {
    words <- as.double(state[-1L]); words[words < 0] <- words[words < 0] + 2^32
    if (any(words[1:3] >= 4294967087) || any(words[4:6] >= 4294944443) ||
        all(words[1:3] == 0) || all(words[4:6] == 0))
      stop(name, " has invalid L'Ecuyer-CMRG words.", call. = FALSE)
  }
  state
}

#' Realize points on a synthetic geometry with explicit random-state control
#'
#' Coordinates and sampling algorithms retain the existing version-1 draw
#' order. The caller's RNG kinds and seed presence/value are restored on
#' success and errors. No statistical response or dataset identity is created.
#' @param geometry A supported geometry component.
#' @param sampling A supported sampling component. Legacy G4 is excluded.
#' @param n Positive sample size, or `NULL` for fixed-size sampling.
#' @param seed Nonnegative integer seed for standalone L'Ecuyer-CMRG sampling.
#'   Supply exactly one of `seed` and `rng.plan`.
#' @param rng.plan Optional list with exactly `version = 1L`, `order` equal to
#'   `"sampling.frame"` or `"frame.sampling"`, and `sampling` and `frame` RNG
#'   states. States are complete integer `.Random.seed` vectors for
#'   L'Ecuyer-CMRG or Mersenne-Twister with Inversion/Rejection. `frame` is `NULL`
#'   unless a random frame is requested. Retry/substream selection belongs to
#'   the caller. The standalone seed assigns sampling its initial stream and
#'   the random frame the next independent stream.
#' @return A `synthetic_geometry_sample` list containing `predictors`, `latent`,
#'   `latent.mask`, `region`, `frame.matrix`, the specifications, dimensions,
#'   `n`, and `sample` (the original sampler payload). `rng` contains the
#'   effective plan, states after each draw, and `final.state` for explicit
#'   continuation by a caller. The result has no truth or response fields.
#' @examples
#' x <- sample.synthetic.geometry(synthetic.circle(),
#'   synthetic.sampling.uniform.interval(0, 2 * pi), n = 8, seed = 7)
#' dim(x$predictors)
#' @export
sample.synthetic.geometry <- function(geometry, sampling, n = NULL,
                                     seed = NULL, rng.plan = NULL) {
  validate.synthetic.sampling(sampling, geometry)
  if (geometry$family == "stratified")
    stop("General stratified geometry sampling is not implemented.", call. = FALSE)
  fixed <- .synthetic.fixed.n(sampling)
  if (!is.null(fixed)) {
    if (!is.null(n) && .synthetic.scalar.integer(n, "n", 1L) != fixed)
      stop("n disagrees with the sampling component's fixed size.", call. = FALSE)
    n <- fixed
  }
  n <- .synthetic.scalar.integer(n, "n", 1L)
  random <- identical(geometry$parameters$frame, "random.orthonormal")
  if (is.null(seed) == is.null(rng.plan))
    stop("Supply exactly one of seed and rng.plan.", call. = FALSE)
  .with.synthetic.rng.preserved({
    if (!is.null(seed)) {
      seed <- .synthetic.scalar.integer(seed, "seed", 0L)
      RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
      set.seed(seed)
      state <- get(".Random.seed", envir = .GlobalEnv)
      rng.plan <- list(version = 1L, order = "sampling.frame", sampling = state,
                       frame = if (random) parallel::nextRNGStream(state) else NULL)
    }
    if (!is.list(rng.plan) || !setequal(names(rng.plan), c("version", "order", "sampling", "frame")) ||
        length(rng.plan) != 4L || !identical(rng.plan$version, 1L) ||
        !is.character(rng.plan$order) || length(rng.plan$order) != 1L ||
        is.na(rng.plan$order) || !rng.plan$order %in% c("sampling.frame", "frame.sampling"))
      stop("Invalid version-1 geometry RNG plan.", call. = FALSE)
    .synthetic.validate.state(rng.plan$sampling, "sampling")
    if (random) .synthetic.validate.state(rng.plan$frame, "frame")
    else if (!is.null(rng.plan$frame)) stop("Nonrandom geometry requires a NULL frame state.", call. = FALSE)
    sample <- NULL; frame <- NULL; sampling.after <- NULL; frame.after <- NULL
    draw.sample <- function() {
      assign(".Random.seed", rng.plan$sampling, envir = .GlobalEnv)
      sample <<- .draw.synthetic.sampling(sampling, n, geometry)
      sampling.after <<- get(".Random.seed", envir = .GlobalEnv)
    }
    draw.frame <- function() {
      if (random) assign(".Random.seed", rng.plan$frame, envir = .GlobalEnv)
      frame <<- .draw.synthetic.frame(geometry)
      if (random) frame.after <<- get(".Random.seed", envir = .GlobalEnv)
    }
    if (rng.plan$order == "frame.sampling") { draw.frame(); draw.sample() }
    else { draw.sample(); draw.frame() }
    final <- get(".Random.seed", envir = .GlobalEnv)
    X <- if (is.null(sample$predictors))
      .embed.synthetic.geometry(geometry, sample$latent, frame) else sample$predictors
    if (!is.null(sample$latent)) .validate.synthetic.latent(geometry, sample$latent)
    if (any(!is.finite(X))) stop("Sampling produced nonfinite coordinates.", call. = FALSE)
    structure(list(predictors = X, latent = sample$latent, latent.mask = sample$latent.mask,
      region = sample$region, n = n, intrinsic.dim = geometry$parameters$intrinsic.dim,
      ambient.dim = geometry$parameters$ambient.dim, frame.matrix = frame,
      geometry.spec = geometry, sampling.spec = sampling, sample = sample,
      rng = list(plan = rng.plan, sampling.after = sampling.after,
                 frame.after = frame.after, final.state = final)),
      class = c("synthetic_geometry_sample", "list"))
  })
}
