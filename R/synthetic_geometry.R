# Draw-free geometry specifications and embedding operators.

.synthetic.frame.parameters <- function(frame, frame.algorithm,
                                        frame.matrix, offset,
                                        ambient.dim, canonical.dim) {
  frame <- match.arg(frame, c("canonical", "random.orthonormal", "supplied"))
  if (is.null(offset)) offset <- rep(0, ambient.dim)
  offset <- as.double(offset)
  if (length(offset) != ambient.dim || any(!is.finite(offset))) {
    stop("offset must be a finite vector of length ambient.dim.",
         call. = FALSE)
  }
  if (frame == "canonical") {
    if (ambient.dim != canonical.dim) {
      stop("canonical frame requires ambient.dim equal to canonical dimension.",
           call. = FALSE)
    }
    if (!is.null(frame.algorithm) || !is.null(frame.matrix)) {
      stop("canonical frame cannot carry an algorithm or frame matrix.",
           call. = FALSE)
    }
  } else if (frame == "random.orthonormal") {
    if (!is.null(frame.matrix)) {
      stop("random.orthonormal frame cannot carry frame.matrix.",
           call. = FALSE)
    }
    if (is.null(frame.algorithm)) frame.algorithm <- "base.qr.gaussian.v1"
    frame.algorithm <- .synthetic.scalar.character(
      frame.algorithm, "frame.algorithm")
    allowed <- c("base.qr.gaussian.v1", "legacy.base.qr.gaussian.v1")
    if (!frame.algorithm %in% allowed) {
      stop("Unknown frame.algorithm: ", frame.algorithm, call. = FALSE)
    }
  } else {
    if (!is.null(frame.algorithm)) {
      stop("supplied frame cannot carry frame.algorithm.", call. = FALSE)
    }
    frame.matrix <- as.matrix(frame.matrix)
    storage.mode(frame.matrix) <- "double"
    if (!identical(dim(frame.matrix),
                   c(as.integer(ambient.dim), as.integer(canonical.dim))) ||
        any(!is.finite(frame.matrix))) {
      stop("frame.matrix has invalid dimensions or nonfinite entries.",
           call. = FALSE)
    }
    if (!isTRUE(all.equal(crossprod(frame.matrix), diag(canonical.dim),
                         tolerance = 1e-10))) {
      stop("frame.matrix columns must be orthonormal.", call. = FALSE)
    }
    dimnames(frame.matrix) <- NULL
  }
  list(
    frame = frame,
    frame.algorithm = frame.algorithm,
    frame.matrix = frame.matrix,
    offset = offset
  )
}

#' Specify a quadform geometry
#'
#' @param intrinsic.dim Intrinsic dimension.
#' @param ambient.dim Ambient dimension.
#' @param forms List of finite symmetric quadratic-form matrices.
#' @param frame Frame policy.
#' @param frame.algorithm Versioned random-frame algorithm or `NULL`.
#' @param frame.matrix Supplied orthonormal frame or `NULL`.
#' @param offset Ambient offset or `NULL`.
#' @return A synthetic geometry component.
#' @examples
#' synthetic.quadform(1L, 2L, forms = list(matrix(0.5)))
#' @export
synthetic.quadform <- function(
    intrinsic.dim, ambient.dim, forms = list(),
    frame = c("canonical", "random.orthonormal", "supplied"),
    frame.algorithm = NULL, frame.matrix = NULL, offset = NULL) {
  intrinsic.dim <- .synthetic.scalar.integer(
    intrinsic.dim, "intrinsic.dim", 1L)
  ambient.dim <- .synthetic.scalar.integer(ambient.dim, "ambient.dim", 1L)
  if (!is.list(forms)) stop("forms must be a list.", call. = FALSE)
  forms <- lapply(forms, function(A) {
    A <- as.matrix(A)
    storage.mode(A) <- "double"
    if (!identical(dim(A), c(intrinsic.dim, intrinsic.dim)) ||
        any(!is.finite(A)) ||
        !isTRUE(all.equal(A, t(A), tolerance = 1e-12))) {
      stop("Each form must be a finite symmetric intrinsic.dim square matrix.",
           call. = FALSE)
    }
    dimnames(A) <- NULL
    A
  })
  canonical.dim <- intrinsic.dim + length(forms)
  if (ambient.dim < canonical.dim) {
    stop("ambient.dim must be at least intrinsic.dim + length(forms).",
         call. = FALSE)
  }
  frame.args <- .synthetic.frame.parameters(
    match.arg(frame), frame.algorithm, frame.matrix, offset,
    ambient.dim, canonical.dim)
  .new.synthetic.component(
    "geometry", "quadform",
    c(list(
      intrinsic.dim = intrinsic.dim,
      ambient.dim = ambient.dim,
      forms = forms,
      canonical.dim = canonical.dim
    ), frame.args),
    subclass = "synthetic_quadform_geometry"
  )
}

.synthetic.parametric.geometry <- function(
    family, intrinsic.dim, canonical.dim, ambient.dim, parameters,
    frame, frame.algorithm, frame.matrix, offset, subclass) {
  ambient.dim <- .synthetic.scalar.integer(ambient.dim, "ambient.dim", 1L)
  if (ambient.dim < canonical.dim) {
    stop("ambient.dim is smaller than the canonical geometry dimension.",
         call. = FALSE)
  }
  frame.args <- .synthetic.frame.parameters(
    frame, frame.algorithm, frame.matrix, offset, ambient.dim, canonical.dim)
  .new.synthetic.component(
    "geometry", family,
    c(list(
      intrinsic.dim = as.integer(intrinsic.dim),
      ambient.dim = ambient.dim,
      canonical.dim = as.integer(canonical.dim)
    ), parameters, frame.args),
    subclass = subclass
  )
}

#' Specify a sphere-cap geometry
#' @param radius Sphere radius.
#' @param footprint.radius Radius of the planar cap footprint.
#' @param ambient.dim Ambient dimension.
#' @param frame,frame.algorithm,frame.matrix,offset Frame parameters.
#' @return A synthetic geometry component.
#' @examples
#' synthetic.sphere.cap(radius = 2, footprint.radius = 1)
#' @export
synthetic.sphere.cap <- function(
    radius = 2, footprint.radius = 1, ambient.dim = 3L,
    frame = c("canonical", "random.orthonormal", "supplied"),
    frame.algorithm = NULL, frame.matrix = NULL, offset = NULL) {
  radius <- .synthetic.scalar.double(radius, "radius", 0, strict = TRUE)
  footprint.radius <- .synthetic.scalar.double(
    footprint.radius, "footprint.radius", 0, strict = TRUE)
  if (footprint.radius >= radius) {
    stop("footprint.radius must be smaller than radius.", call. = FALSE)
  }
  .synthetic.parametric.geometry(
    "sphere.cap", 2L, 3L, ambient.dim,
    list(radius = radius, footprint.radius = footprint.radius),
    match.arg(frame), frame.algorithm, frame.matrix, offset,
    "synthetic_sphere_cap_geometry")
}

#' Specify a helix geometry
#' @param pitch Helix pitch.
#' @param t.range Admissible parameter interval.
#' @inheritParams synthetic.sphere.cap
#' @return A synthetic geometry component.
#' @examples
#' synthetic.helix(pitch = 0.25, t.range = c(0, pi))
#' @export
synthetic.helix <- function(
    pitch = 0.2, t.range = c(0, 2 * pi), ambient.dim = 3L,
    frame = c("canonical", "random.orthonormal", "supplied"),
    frame.algorithm = NULL, frame.matrix = NULL, offset = NULL) {
  pitch <- .synthetic.scalar.double(pitch, "pitch")
  t.range <- as.double(t.range)
  if (length(t.range) != 2L || any(!is.finite(t.range)) ||
      t.range[1] >= t.range[2]) {
    stop("t.range must be a finite increasing pair.", call. = FALSE)
  }
  .synthetic.parametric.geometry(
    "helix", 1L, 3L, ambient.dim,
    list(pitch = pitch, t.range = t.range),
    match.arg(frame), frame.algorithm, frame.matrix, offset,
    "synthetic_helix_geometry")
}

#' Specify a circle geometry
#'
#' @param radius Circle radius.
#' @param angle.range Admissible angular interval.
#' @inheritParams synthetic.sphere.cap
#' @return A synthetic geometry component.
#' @examples
#' synthetic.circle(radius = 2, angle.range = c(0, pi))
#' @export
synthetic.circle <- function(
    radius = 1, angle.range = c(0, 2 * pi), ambient.dim = 2L,
    frame = c("canonical", "random.orthonormal", "supplied"),
    frame.algorithm = NULL, frame.matrix = NULL, offset = NULL) {
  radius <- .synthetic.scalar.double(radius, "radius", 0, strict = TRUE)
  angle.range <- as.double(angle.range)
  if (length(angle.range) != 2L || any(!is.finite(angle.range)) ||
      angle.range[1] >= angle.range[2]) {
    stop("angle.range must be a finite increasing pair.", call. = FALSE)
  }
  .synthetic.parametric.geometry(
    "circle", 1L, 2L, ambient.dim,
    list(radius = radius, angle.range = angle.range),
    match.arg(frame), frame.algorithm, frame.matrix, offset,
    "synthetic_circle_geometry")
}

#' Specify a trefoil-knot geometry
#'
#' This preserves the legacy `gflow` parameterization:
#' `x = scale * sin(t) + 2 * sin(2*t)`,
#' `y = scale * cos(t) - 2 * cos(2*t)`, and
#' `z = -scale * sin(3*t)`.
#'
#' @param scale Scale applied to the first harmonic and third coordinate.
#' @param t.range Admissible parameter interval.
#' @inheritParams synthetic.sphere.cap
#' @return A synthetic geometry component.
#' @examples
#' synthetic.trefoil(scale = 0.5, t.range = c(0, pi))
#' @export
synthetic.trefoil <- function(
    scale = 1, t.range = c(0, 2 * pi), ambient.dim = 3L,
    frame = c("canonical", "random.orthonormal", "supplied"),
    frame.algorithm = NULL, frame.matrix = NULL, offset = NULL) {
  scale <- .synthetic.scalar.double(scale, "scale", 0, strict = TRUE)
  t.range <- as.double(t.range)
  if (length(t.range) != 2L || any(!is.finite(t.range)) ||
      t.range[1] >= t.range[2]) {
    stop("t.range must be a finite increasing pair.", call. = FALSE)
  }
  .synthetic.parametric.geometry(
    "trefoil", 1L, 3L, ambient.dim,
    list(scale = scale, t.range = t.range),
    match.arg(frame), frame.algorithm, frame.matrix, offset,
    "synthetic_trefoil_geometry")
}

#' Specify a torus-patch geometry
#' @param major.radius,minor.radius Torus radii.
#' @param u.range,v.range Admissible angular intervals.
#' @inheritParams synthetic.sphere.cap
#' @return A synthetic geometry component.
#' @examples
#' synthetic.torus.patch(major.radius = 2, minor.radius = 0.5)
#' @export
synthetic.torus.patch <- function(
    major.radius = 1, minor.radius = 0.35,
    u.range = c(-pi / 2, pi / 2), v.range = c(-pi / 2, pi / 2),
    ambient.dim = 3L,
    frame = c("canonical", "random.orthonormal", "supplied"),
    frame.algorithm = NULL, frame.matrix = NULL, offset = NULL) {
  major.radius <- .synthetic.scalar.double(
    major.radius, "major.radius", 0, strict = TRUE)
  minor.radius <- .synthetic.scalar.double(
    minor.radius, "minor.radius", 0, strict = TRUE)
  if (minor.radius >= major.radius) {
    stop("minor.radius must be smaller than major.radius.", call. = FALSE)
  }
  check.range <- function(x, name) {
    x <- as.double(x)
    if (length(x) != 2L || any(!is.finite(x)) || x[1] >= x[2]) {
      stop(name, " must be a finite increasing pair.", call. = FALSE)
    }
    x
  }
  .synthetic.parametric.geometry(
    "torus.patch", 2L, 3L, ambient.dim,
    list(u.range = check.range(u.range, "u.range"),
         v.range = check.range(v.range, "v.range"),
         major.radius = major.radius, minor.radius = minor.radius),
    match.arg(frame), frame.algorithm, frame.matrix, offset,
    "synthetic_torus_patch_geometry")
}

#' Specify a simplex geometry
#' @param parts Number of compositional parts.
#' @return A synthetic geometry component.
#' @examples
#' synthetic.simplex(parts = 3L)
#' @export
synthetic.simplex <- function(parts) {
  parts <- .synthetic.scalar.integer(parts, "parts", 2L)
  .new.synthetic.component(
    "geometry", "simplex",
    list(parts = parts, ambient.dim = parts, intrinsic.dim = parts - 1L),
    subclass = "synthetic_simplex_geometry")
}

.new.synthetic.stratum <- function(id, family, parameters, intrinsic.dim) {
  id <- .synthetic.scalar.character(id, "id")
  structure(
    list(
      id = id, family = family, version = 1L,
      intrinsic.dim = as.integer(intrinsic.dim),
      parameters = parameters),
    class = c(paste0("synthetic_", family, "_stratum"),
              "synthetic_stratum", "list"))
}

#' Specify a point stratum
#' @param id Stable stratum identifier.
#' @param location Finite ambient location.
#' @return A draw-free `synthetic_stratum`.
#' @examples
#' synthetic.stratum.point("origin", c(0, 0))
#' @export
synthetic.stratum.point <- function(id, location) {
  location <- as.double(location)
  if (!length(location) || any(!is.finite(location))) {
    stop("location must be a nonempty finite vector.", call. = FALSE)
  }
  .new.synthetic.stratum(
    id, "point", list(location = location), intrinsic.dim = 0L)
}

#' Specify a line-segment stratum
#' @param id Stable stratum identifier.
#' @param coordinate.range Finite increasing intrinsic range.
#' @param origin Finite ambient origin.
#' @param direction Unit ambient direction.
#' @return A draw-free `synthetic_stratum`.
#' @examples
#' synthetic.stratum.segment("line", c(-1, 1), c(0, 0), c(1, 0))
#' @export
synthetic.stratum.segment <- function(
    id, coordinate.range, origin, direction) {
  coordinate.range <- as.double(coordinate.range)
  origin <- as.double(origin)
  direction <- as.double(direction)
  if (length(coordinate.range) != 2L ||
      any(!is.finite(coordinate.range)) ||
      coordinate.range[1] >= coordinate.range[2]) {
    stop("coordinate.range must be a finite increasing pair.",
         call. = FALSE)
  }
  if (!length(origin) || length(direction) != length(origin) ||
      any(!is.finite(c(origin, direction))) ||
      abs(sum(direction^2) - 1) > 1e-10) {
    stop("origin and direction must share an ambient dimension and direction ",
         "must have unit length.", call. = FALSE)
  }
  .new.synthetic.stratum(
    id, "segment",
    list(coordinate.range = coordinate.range,
         origin = origin, direction = direction),
    intrinsic.dim = 1L)
}

#' Specify a rectangle stratum
#' @param id Stable stratum identifier.
#' @param coordinate.ranges Two-row matrix of finite increasing ranges.
#' @param origin Finite ambient origin.
#' @param basis Orthonormal ambient-by-two basis.
#' @return A draw-free `synthetic_stratum`.
#' @examples
#' synthetic.stratum.rectangle(
#'   "square", rbind(c(-1, 1), c(-1, 1)), c(0, 0), diag(2)
#' )
#' @export
synthetic.stratum.rectangle <- function(
    id, coordinate.ranges, origin, basis) {
  coordinate.ranges <- as.matrix(coordinate.ranges)
  storage.mode(coordinate.ranges) <- "double"
  origin <- as.double(origin)
  basis <- as.matrix(basis)
  storage.mode(basis) <- "double"
  if (!identical(dim(coordinate.ranges), c(2L, 2L)) ||
      any(!is.finite(coordinate.ranges)) ||
      any(coordinate.ranges[, 1] >= coordinate.ranges[, 2])) {
    stop("coordinate.ranges must be a two-row matrix of increasing bounds.",
         call. = FALSE)
  }
  if (!length(origin) ||
      !identical(dim(basis), c(length(origin), 2L)) ||
      any(!is.finite(c(origin, basis))) ||
      !isTRUE(all.equal(crossprod(basis), diag(2), tolerance = 1e-10))) {
    stop("basis must have two orthonormal columns in origin's ambient space.",
         call. = FALSE)
  }
  dimnames(coordinate.ranges) <- NULL
  dimnames(basis) <- NULL
  .new.synthetic.stratum(
    id, "rectangle",
    list(coordinate.ranges = coordinate.ranges,
         origin = origin, basis = basis),
    intrinsic.dim = 2L)
}

#' Assemble a stratified geometry
#' @param strata Nonempty list of compatible `synthetic_stratum` objects.
#' @param junctions Optional data frame describing stratum boundary junctions.
#' @return A draw-free synthetic geometry component.
#' @examples
#' point <- synthetic.stratum.point("point", c(0, 0))
#' line <- synthetic.stratum.segment("line", c(0, 1), c(0, 0), c(1, 0))
#' synthetic.stratified(list(point, line))
#' @export
synthetic.stratified <- function(strata, junctions = NULL) {
  if (!is.list(strata) || !length(strata) ||
      !all(vapply(strata, inherits, logical(1), "synthetic_stratum"))) {
    stop("strata must be a nonempty list of synthetic strata.",
         call. = FALSE)
  }
  ids <- vapply(strata, `[[`, character(1), "id")
  if (anyDuplicated(ids)) stop("stratum IDs must be unique.", call. = FALSE)
  ambient.dims <- vapply(strata, function(x) {
    length(x$parameters$location %||% x$parameters$origin)
  }, integer(1))
  if (length(unique(ambient.dims)) != 1L) {
    stop("all strata must share one ambient dimension.", call. = FALSE)
  }
  if (!is.null(junctions)) {
    junctions <- as.data.frame(junctions, stringsAsFactors = FALSE)
    required <- c("left.id", "right.id", "left.boundary", "right.boundary")
    if (!identical(names(junctions), required) ||
        any(!junctions$left.id %in% ids) ||
        any(!junctions$right.id %in% ids)) {
      stop("junctions must have the required columns and reference known IDs.",
           call. = FALSE)
    }
  }
  .new.synthetic.component(
    "geometry", "stratified",
    list(
      strata = strata, junctions = junctions,
      ambient.dim = ambient.dims[1],
      intrinsic.dim = NA_integer_,
      intrinsic.dim.by.region = stats::setNames(
        vapply(strata, `[[`, integer(1), "intrinsic.dim"), ids),
      declared.regions = ids),
    subclass = "synthetic_stratified_geometry")
}

#' Specify a point-line junction
#' @param point.location Point location.
#' @param line.origin,line.direction,line.range Segment parameters.
#' @return A two-stratum `synthetic_stratified_geometry`.
#' @examples
#' synthetic.point.line.junction(c(0, 0), c(0, 0), c(1, 0), c(0, 1))
#' @export
synthetic.point.line.junction <- function(
    point.location, line.origin, line.direction, line.range) {
  synthetic.stratified(
    list(
      synthetic.stratum.point("point", point.location),
      synthetic.stratum.segment(
        "line", line.range, line.origin, line.direction)))
}

.draw.synthetic.frame <- function(geometry, frame.seed = NULL) {
  p <- geometry$parameters
  if (is.null(p$frame)) return(NULL)
  k <- p$canonical.dim
  if (p$frame == "canonical") return(diag(k))
  if (p$frame == "supplied") return(p$frame.matrix)
  if (!is.null(frame.seed)) set.seed(frame.seed)
  M <- matrix(stats::rnorm(p$ambient.dim * k),
              nrow = p$ambient.dim, ncol = k)
  qr.out <- qr(M, LAPACK = FALSE)
  qr.Q(qr.out, complete = FALSE)[, seq_len(k), drop = FALSE]
}

.embed.synthetic.geometry <- function(geometry, latent, frame.matrix = NULL) {
  p <- geometry$parameters
  family <- geometry$family
  if (family == "simplex") return(as.matrix(latent))
  if (family == "g4.segment.rectangle") {
    stop("G4 stratified sampling supplies observed predictors directly.",
         call. = FALSE)
  }
  U <- as.matrix(latent)
  if (family == "quadform") {
    z <- U
    if (length(p$forms)) {
      q <- vapply(p$forms, function(A) rowSums((U %*% A) * U),
                  numeric(nrow(U)))
      if (is.null(dim(q))) q <- matrix(q, nrow = nrow(U), ncol = length(p$forms))
      z <- cbind(U, q)
    }
  } else if (family == "sphere.cap") {
    rr <- rowSums(U^2)
    z <- cbind(U, p$radius - sqrt(p$radius^2 - rr))
  } else if (family == "helix") {
    tt <- U[, 1]
    z <- cbind(cos(tt), sin(tt), p$pitch * tt)
  } else if (family == "circle") {
    tt <- U[, 1]
    z <- p$radius * cbind(cos(tt), sin(tt))
  } else if (family == "trefoil") {
    tt <- U[, 1]
    z <- cbind(
      p$scale * sin(tt) + 2 * sin(2 * tt),
      p$scale * cos(tt) - 2 * cos(2 * tt),
      -p$scale * sin(3 * tt))
  } else if (family == "torus.patch") {
    u <- U[, 1]
    v <- U[, 2]
    z <- cbind(
      (p$major.radius + p$minor.radius * cos(v)) * cos(u),
      (p$major.radius + p$minor.radius * cos(v)) * sin(u),
      p$minor.radius * sin(v))
  } else {
    stop("Unsupported geometry family: ", family, call. = FALSE)
  }
  if (is.null(frame.matrix)) {
    frame.matrix <- if (p$frame == "canonical") {
      diag(p$canonical.dim)
    } else if (p$frame == "supplied") {
      p$frame.matrix
    } else {
      stop("Random geometry requires a realized frame.", call. = FALSE)
    }
  }
  X <- z %*% t(frame.matrix)
  sweep(X, 2L, p$offset, "+")
}

.validate.synthetic.latent <- function(geometry, latent) {
  if (!inherits(geometry, "synthetic_geometry")) {
    stop("geometry must be a synthetic geometry component.", call. = FALSE)
  }
  latent <- as.matrix(latent)
  storage.mode(latent) <- "double"
  if (!nrow(latent) || any(!is.finite(latent))) {
    stop("latent must be a nonempty finite numeric matrix.", call. = FALSE)
  }
  family <- geometry$family
  p <- geometry$parameters
  expected <- if (family == "simplex") p$parts else p$intrinsic.dim
  if (is.na(expected) || ncol(latent) != expected) {
    stop("latent has the wrong number of columns for geometry.",
         call. = FALSE)
  }
  if (family == "sphere.cap" &&
      any(rowSums(latent^2) > p$footprint.radius^2 * (1 + 1e-12))) {
    stop("latent points lie outside the sphere-cap footprint.",
         call. = FALSE)
  }
  if (family == "helix" &&
      any(latent[, 1] < p$t.range[1] | latent[, 1] > p$t.range[2])) {
    stop("latent points lie outside the helix parameter range.",
         call. = FALSE)
  }
  if (family == "circle" &&
      any(latent[, 1] < p$angle.range[1] |
          latent[, 1] > p$angle.range[2])) {
    stop("latent points lie outside the circle angle range.",
         call. = FALSE)
  }
  if (family == "trefoil" &&
      any(latent[, 1] < p$t.range[1] | latent[, 1] > p$t.range[2])) {
    stop("latent points lie outside the trefoil parameter range.",
         call. = FALSE)
  }
  if (family == "torus.patch" &&
      any(latent[, 1] < p$u.range[1] | latent[, 1] > p$u.range[2] |
          latent[, 2] < p$v.range[1] | latent[, 2] > p$v.range[2])) {
    stop("latent points lie outside the torus-patch parameter ranges.",
         call. = FALSE)
  }
  if (family == "simplex" &&
      (any(latent < 0) ||
       any(abs(rowSums(latent) - 1) > 1e-10))) {
    stop("simplex latent rows must be nonnegative and sum to one.",
         call. = FALSE)
  }
  latent
}

#' Embed latent coordinates through a synthetic geometry
#'
#' This deterministic operator performs no random draws. A realized
#' `frame.matrix` is required for random-frame geometries.
#'
#' @param geometry A synthetic geometry component.
#' @param latent Latent coordinates in rows.
#' @param frame.matrix Optional realized orthonormal frame.
#' @return A numeric matrix of observed coordinates.
#' @examples
#' geometry <- synthetic.circle()
#' embed.synthetic.geometry(geometry, matrix(c(0, pi / 2), ncol = 1))
#' @export
embed.synthetic.geometry <- function(
    geometry, latent, frame.matrix = NULL) {
  latent <- .validate.synthetic.latent(geometry, latent)
  .embed.synthetic.geometry(geometry, latent, frame.matrix)
}

#' Evaluate gradients of all quadforms
#'
#' @param geometry A `synthetic_quadform_geometry`.
#' @param latent Finite latent coordinates in rows.
#' @return For one form, an `n` by `d` matrix. For multiple forms, an
#'   `n` by `r` by `d` array. With no forms, an `n` by zero by `d` array.
#' @examples
#' geometry <- synthetic.quadform(1L, 2L, forms = list(matrix(1)))
#' quadform.gradient(geometry, matrix(c(-1, 0, 1), ncol = 1))
#' @export
quadform.gradient <- function(geometry, latent) {
  if (!inherits(geometry, "synthetic_quadform_geometry")) {
    stop("geometry must be a synthetic quadform geometry.", call. = FALSE)
  }
  latent <- .validate.synthetic.latent(geometry, latent)
  forms <- geometry$parameters$forms
  n <- nrow(latent)
  d <- ncol(latent)
  if (!length(forms)) return(array(double(), dim = c(n, 0L, d)))
  out <- array(0, dim = c(n, length(forms), d))
  for (j in seq_along(forms)) out[, j, ] <- 2 * latent %*% forms[[j]]
  if (length(forms) == 1L) {
    return(matrix(out[, 1L, ], nrow = n, ncol = d))
  }
  out
}

#' Evaluate the induced metric of a quadform geometry
#'
#' @param geometry A `synthetic_quadform_geometry`.
#' @param latent Finite latent coordinates in rows.
#' @return For one row, a `d` by `d` matrix; otherwise an
#'   `n` by `d` by `d` array.
#' @examples
#' geometry <- synthetic.quadform(1L, 2L, forms = list(matrix(1)))
#' quadform.metric(geometry, matrix(c(0, 1), ncol = 1))
#' @export
quadform.metric <- function(geometry, latent) {
  if (!inherits(geometry, "synthetic_quadform_geometry")) {
    stop("geometry must be a synthetic quadform geometry.", call. = FALSE)
  }
  latent <- .validate.synthetic.latent(geometry, latent)
  forms <- geometry$parameters$forms
  n <- nrow(latent)
  d <- ncol(latent)
  out <- array(0, dim = c(n, d, d))
  for (i in seq_len(n)) {
    metric <- diag(d)
    for (form in forms) {
      gradient <- as.numeric(2 * form %*% latent[i, ])
      metric <- metric + tcrossprod(gradient)
    }
    out[i, , ] <- metric
  }
  if (n == 1L) out[1L, , ] else out
}

.quadform.segment.length <- function(geometry, u, v, tolerance) {
  h <- v - u
  flat.speed.squared <- sum(h^2)
  if (flat.speed.squared == 0) return(0)
  forms <- geometry$parameters$forms
  if (!length(forms)) return(sqrt(flat.speed.squared))
  a <- vapply(forms, function(form) {
    2 * sum(u * as.numeric(form %*% h))
  }, numeric(1))
  b <- vapply(forms, function(form) {
    2 * sum(h * as.numeric(form %*% h))
  }, numeric(1))
  if (sum(abs(b)) <= tolerance) {
    return(sqrt(flat.speed.squared + sum(a^2)))
  }
  stats::integrate(
    function(t) {
      sqrt(flat.speed.squared +
             vapply(t, function(tt) sum((a + b * tt)^2), numeric(1)))
    },
    lower = 0, upper = 1,
    rel.tol = tolerance, abs.tol = tolerance,
    stop.on.error = TRUE)$value
}

#' Exact latent-segment lengths under a synthetic geometry
#'
#' For quadforms this integrates the induced metric along each straight
#' latent segment. Flat quadforms reduce exactly to Euclidean distance.
#'
#' @param geometry A `synthetic_quadform_geometry`.
#' @param from,to Matching endpoint matrices with one segment per row.
#' @param tolerance Positive integration tolerance.
#' @return A numeric vector of segment lengths.
#' @examples
#' geometry <- synthetic.quadform(1L, 1L)
#' edge.lengths.synthetic.geometry(geometry, matrix(0), matrix(2))
#' @export
edge.lengths.synthetic.geometry <- function(
    geometry, from, to, tolerance = 1e-10) {
  if (!inherits(geometry, "synthetic_quadform_geometry")) {
    stop("edge lengths are currently implemented only for quadforms.",
         call. = FALSE)
  }
  from <- .validate.synthetic.latent(geometry, from)
  to <- .validate.synthetic.latent(geometry, to)
  if (!identical(dim(from), dim(to))) {
    stop("from and to must have identical dimensions.", call. = FALSE)
  }
  tolerance <- .synthetic.scalar.double(
    tolerance, "tolerance", 0, strict = TRUE)
  vapply(
    seq_len(nrow(from)),
    function(i) .quadform.segment.length(
      geometry, from[i, ], to[i, ], tolerance),
    numeric(1))
}
