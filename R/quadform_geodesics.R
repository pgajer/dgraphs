#' Estimate distances on a declared quadratic graph surface
#'
#' Internal common interface for paired endpoint queries on
#' \eqn{F(u)=(u,u^T A u)}. A method must be selected explicitly.
#'
#' @param A Finite exactly symmetric 2 by 2 matrix.
#' @param from,to Two-element numeric vectors or matching two-column matrices
#'   of domain coordinates. Rows define pairs; no recycling or Cartesian product.
#' @param domain A list with `kind = "ball"`, `center` and `radius`, or
#'   `kind = "box"`, `lower` and `upper`. The domain is closed and convex.
#' @param method One of `"single_point"`, `"local_network"`, `"best_of_six"`,
#'   `"grid_dijkstra"` or `"paraboloid_clairaut"`. No partial matching.
#' @param control Named list of method-specific controls; unknown names are
#'   errors. Refinements accept the corresponding lower-level function's
#'   controls, with `cache_edges = 0` and `trace = FALSE` by default.
#'   Grid controls are `grid_size = c(33,33)` (3--257 per axis),
#'   `direction_radius = 2` (1--8), `endpoint_neighbors = 8` (1--32),
#'   `include_direct = TRUE`, `max_edges = 1000000` (0--2000000),
#'   `keep_graph = FALSE` and `max_seconds = Inf`.
#'   Clairaut controls are `iterations = 80` (1--256), `path_samples = 257`
#'   (3--4097), `domain_check_depth = 16` (0--20),
#'   `angle_tolerance = 1e-12` (1e-15--1e-8) and `max_seconds = Inf`.
#'   Time and calculation limits apply to each pair, not the whole batch.
#' @param return.paths Whether to retain paths, including those in nested
#'   refinement results. Default `FALSE`. No files or checkpoints are written.
#'
#' @return A list with `method`, `geometry`, `domain`, resolved `control`,
#'   row-preserving `summary`, and detailed pair `results`. Status is
#'   `"candidate"`, `"partial"`, `"unsupported"` or `"failed"`.
#'   Summary `length` is the numerical distance estimate; `length_error_estimate`
#'   concerns numerical length evaluation, not discretization or optimization
#'   error. `approximation_error` is missing and `global_optimality_certified`
#'   is `FALSE`. Detailed results retain `backend_result`, including all six
#'   outcomes and total costs for the best-of-six strategy. A completed budget
#'   is not an accuracy certificate. User interrupts and input errors propagate.
#'
#' @details Grid edges use the native analytic lifted-segment lengths. Primitive
#'   lattice offsets up to `direction_radius` supply directions; radius one is
#'   the eight-neighbor stencil. Finer spacing alone does not remove its
#'   directional bias. Off-grid endpoints attach to nearest retained vertices.
#'   The optional direct connector is an explicit graph edge, not a fallback.
#'   Search uses strict binary64 comparisons; the selected path total is
#'   recomputed with the native exact accumulator.
#'
#'   Clairaut requires `A = a I` exactly. It solves radial-monotone or turning
#'   branches of the continuous surface metric, with separate flat, apex,
#'   radial and antipodal cases. Origin-centered disks use a whole-path radial
#'   envelope; other domains require conservative radial/angular section
#'   enclosures. Leaving the domain or unresolved containment returns
#'   `unsupported`, not a boundary-constrained replacement. Curved polar cases
#'   outside the initial numeric scope (minimum endpoint radius below 1e-100,
#'   maximum above 1e100, or twice absolute curvature times maximum radius above
#'   1e6) are explicitly unsupported. These restrictions do not apply to flat,
#'   coincident or apex cases.
#'
#'   For `analytic_clairaut_curve`, `path` is a sampled display of the curve,
#'   not a polyline whose length equals `length`. `curve_parameters` describe
#'   the authoritative curve; the numerical endpoint residual is retained.
#'   Parameterize it by `t = t_from + s * t_span`, for `s` between zero and
#'   one; use the retained `t_span`, not subtraction of rounded endpoints.
#'   With \eqn{r = \sqrt{c^2 + t^2}}, its polar angle is `theta_turn` plus
#'   `angular_sign * sign(t) * H(c, abs(t))`, where
#'   \eqn{H(c,t)=kc\,\mathrm{asinh}(kt/\sqrt{1+k^2c^2})+
#'   \mathrm{atan2}(t,c\sqrt{1+k^2c^2+k^2t^2})}.
#'   `caller_reversed` indicates whether to traverse this parameterization
#'   backward to follow the caller's endpoint order.
#'   For `lifted_domain_polyline`, consecutive domain points specify lifted
#'   straight segments. All numerical error estimates are nonrigorous.
#'   The historical development adapter registry is independent of this
#'   package interface and is not activated by these methods.
#'   Grid and Clairaut results are symmetric under endpoint reversal. A single
#'   randomized refinement run is not required to be: its internal orientation
#'   is randomized relative to the supplied endpoints. The wrapper preserves
#'   the lower-level solver's behavior and seed semantics.
#' @keywords internal
quadform_geodesics <- function(A, from, to, domain, method,
                              control = list(), return.paths = FALSE) {
  methods <- c("single_point", "local_network", "best_of_six",
               "grid_dijkstra", "paraboloid_clairaut")
  if (missing(method) || !is.character(method) || length(method) != 1L ||
      is.na(method) || !method %in% methods)
    stop("method must explicitly name one of: ", paste(methods, collapse = ", "))
  if (!is.matrix(A) || !is.numeric(A) || !identical(dim(A), c(2L, 2L)) ||
      any(!is.finite(A)) || A[1L, 2L] != A[2L, 1L])
    stop("A must be a finite symmetric 2 by 2 numeric matrix")
  endpoints <- function(x, name) {
    if (is.numeric(x) && is.null(dim(x)) && length(x) == 2L)
      x <- matrix(x, nrow = 1L)
    if (!is.matrix(x) || !is.numeric(x) || ncol(x) != 2L ||
        !nrow(x) || any(!is.finite(x)))
      stop(name, " must be a two-element vector or a finite two-column matrix")
    unname(x)
  }
  from <- endpoints(from, "from"); to <- endpoints(to, "to")
  if (nrow(from) != nrow(to)) stop("from and to must have the same number of rows")
  if (!is.logical(return.paths) || length(return.paths) != 1L || is.na(return.paths))
    stop("return.paths must be TRUE or FALSE")
  if (!is.list(domain) || is.null(names(domain)) || anyDuplicated(names(domain)) ||
      !is.character(domain$kind) || length(domain$kind) != 1L || is.na(domain$kind))
    stop("domain must be a named ball or box list")
  finite_pair <- function(x) is.numeric(x) && is.null(dim(x)) && length(x) == 2L && all(is.finite(x))
  if (domain$kind == "ball") {
    if (!setequal(names(domain), c("kind", "center", "radius")) ||
        !finite_pair(domain$center) || !is.numeric(domain$radius) ||
        length(domain$radius) != 1L || !is.finite(domain$radius) ||
        domain$radius < .Machine$double.xmin || domain$radius > 1e150)
      stop("Invalid ball domain")
    inside <- function(x) {
      h <- sweep(x, 2L, domain$center)
      s <- apply(abs(h), 1L, max)
      n <- s * sqrt(rowSums((h / ifelse(s == 0, 1, s))^2))
      is.finite(n) & n <= domain$radius
    }
  } else if (domain$kind == "box") {
    if (!setequal(names(domain), c("kind", "lower", "upper")) ||
        !finite_pair(domain$lower) || !finite_pair(domain$upper) ||
        any(domain$lower >= domain$upper) || any(!is.finite(domain$upper - domain$lower)))
      stop("Invalid box domain")
    inside <- function(x) rowSums(sweep(x, 2L, domain$lower, ">=") &
                                   sweep(x, 2L, domain$upper, "<=")) == 2L
  } else stop("domain kind must be ball or box")
  if (!all(inside(from)) || !all(inside(to))) stop("Endpoints must be inside the domain")
  if (!is.list(control) || (length(control) &&
      (is.null(names(control)) || anyNA(names(control)) || any(!nzchar(names(control))) ||
       anyDuplicated(names(control))))) stop("control must be a uniquely named list")
  if (method %in% c("single_point", "local_network", "best_of_six")) {
    fn <- if (method == "best_of_six") quadform_geodesics_best_of_six else quadform_geodesics_solver
    keys <- setdiff(names(formals(fn)), c("A", "from", "to", "domain", "method"))
    defaults <- lapply(formals(fn)[keys], eval, envir = environment(fn))
    defaults$cache_edges <- 0L; defaults$trace <- FALSE
    if (!is.null(defaults$neighborhood)) defaults$neighborhood <- defaults$neighborhood[1L]
  } else if (method == "grid_dijkstra") {
    defaults <- list(grid_size = c(33L, 33L), direction_radius = 2L,
      endpoint_neighbors = 8L, include_direct = TRUE, max_edges = 1000000,
      keep_graph = FALSE, max_seconds = Inf)
  } else {
    defaults <- list(iterations = 80L, path_samples = 257L,
      domain_check_depth = 16L, angle_tolerance = 1e-12, max_seconds = Inf)
  }
  unknown <- setdiff(names(control), names(defaults))
  if (length(unknown)) stop("Unsupported controls for ", method, ": ", paste(unknown, collapse = ", "))
  defaults[names(control)] <- control
  strip_paths <- function(x) {
    if (!is.list(x) || is.data.frame(x)) return(x)
    fields <- intersect(names(x), c("path", "surface_path", "initial_path"))
    x[fields] <- rep(list(NULL), length(fields))
    lapply(x, strip_paths)
  }
  results <- lapply(seq_len(nrow(from)), function(i) {
    args <- list(A = A, from = from[i, ], to = to[i, ], domain = domain)
    if (method %in% c("single_point", "local_network", "best_of_six")) {
      if (method != "best_of_six") args$method <- method
      raw <- do.call(fn, c(args, defaults))
      if (method == "best_of_six") status <- switch(raw$ensemble$status,
        complete = "candidate", partial = "partial", no_path = "failed")
      else status <- if (raw$status == "no_path") "failed" else
        if (raw$status == "direct_fallback" || !raw$termination %in%
            c("epoch_limit", "local_stagnation", "identity")) "partial" else "candidate"
      representation <- "lifted_domain_polyline"
    } else {
      raw <- do.call(rcpp_quadform_geodesics_method,
        c(args, list(method = method, control = defaults)))
      status <- raw$status; representation <- raw$path_representation
    }
    result <- list(method = method, backend = raw$implementation, status = status,
      termination = raw$termination, length = raw$length,
      length_error_estimate = raw$error_estimate, approximation_error = NA_real_,
      global_optimality_certified = FALSE, path_representation = representation,
      path = raw$path, surface_path = raw$surface_path,
      curve_parameters = raw$curve_parameters, backend_result = raw, state_saving = FALSE)
    if (!return.paths) result <- strip_paths(result)
    result
  })
  summary <- data.frame(pair = seq_len(nrow(from)),
    length = vapply(results, `[[`, 0, "length"),
    length_error_estimate = vapply(results, `[[`, 0, "length_error_estimate"),
    approximation_error = rep(NA_real_, nrow(from)), global_optimality_certified = FALSE,
    status = vapply(results, `[[`, "", "status"),
    termination = vapply(results, `[[`, "", "termination"),
    backend = vapply(results, `[[`, "", "backend"), stringsAsFactors = FALSE)
  list(interface_version = "1.0.0-internal", method = method, geometry = list(A = A),
       domain = domain, from = from, to = to, control = defaults,
       summary = summary, results = results)
}
