#' Estimate distances on a declared quadratic graph surface
#'
#' Internal common interface for paired endpoint queries on
#' \eqn{F(u)=(u,u^T A u)}. A method must be selected explicitly.
#'
#' @param A Finite exactly symmetric 2 by 2 matrix. The Delaunay and radius
#'   graph references also accept 3 by 3 and 4 by 4 matrices, representing
#'   a single quadratic height over the corresponding domain dimension.
#' @param from,to Two-element numeric vectors or matching two-column matrices
#'   of domain coordinates. Rows define pairs; no recycling or Cartesian product.
#' @param domain A list with `kind = "ball"`, `center` and `radius`, or
#'   `kind = "box"`, `lower` and `upper`. The domain is closed and convex.
#' @param method One of `"single_point"`, `"local_network"`, `"best_of_six"`,
#'   `"grid_dijkstra"`, `"paraboloid_clairaut"`, `"geodesic_shooting"` or
#'   `"geodesic_collocation"`, `"boundary_optimization"`, `"polyhedral_mesh"`,
#'   `"delaunay_graph"` or `"radius_graph"`. No partial matching.
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
#'   The two continuous methods accept `ode_tolerance = 1e-6` (1e-10--1e-2),
#'   `endpoint_tolerance = 1e-8` (1e-12--1e-3), `path_tolerance = 1e-7`
#'   (1e-10--1e-2), `iterations = 30` (1--100), `continuation_steps = 8`
#'   (1--128), `continuation_attempts = 128` (1--1024), `initial_nodes = 17`
#'   (3--257), `max_nodes = 1025` (initial_nodes--4097),
#'   `max_path_vertices = 4097` (3--65537), `max_evaluations = 500000`
#'   (0--10000000), `domain_check_depth = 20` (0--24),
#'   `initial_bends = c(0,-1,1)` (1--9 distinct values between -4 and 4),
#'   and `max_seconds = Inf`. Shooting additionally accepts
#'   `integration_tolerance = 1e-10` (1e-13--1e-5).
#'   Boundary optimization accepts `initial_edges = 8` (2--64), `levels = 2`
#'   (1--3), `evaluations_per_start = 2000` (1--100000),
#'   `max_evaluations = 20000` (0--1000000), `position_tolerance = 1e-6`
#'   (1e-10--1e-2), `initial_step = 0.05` (1e-6--0.5),
#'   `initial_bends = c(0,-0.5,0.5)` (1--9 distinct values in -4--4),
#'   `initial_path = NULL` (otherwise a feasible two-column path with 2--65
#'   rows and exactly matching endpoints), and `max_seconds = Inf`.
#'   Reference graphs and meshes accept `resolution` (2--33; defaults 17, 5,
#'   3 in domain dimensions 2, 3, 4), `vertices = NULL` (otherwise a finite
#'   domain-coordinate matrix), `max_vertices`, `max_edges = 200000`
#'   (0--2000000), `max_pair_checks = 1000000` (0--10000000),
#'   `max_seconds = Inf` and `keep_graph = FALSE`. Default vertex caps are
#'   4096 for radius graphs, 2048/512/128 for 2D/3D/4D Delaunay graphs,
#'   and 1024 for meshes; the Delaunay and mesh caps cannot be raised.
#'   Radius graphs accept `radius`, defaulting to twice the largest domain
#'   bounding-box width divided by resolution minus one, in domain units.
#'   Mesh controls additionally include `max_faces = 2048` (1--4096),
#'   `max_propagations = 100000` (0--1000000),
#'   `max_intervals = 200000` (1--1000000), and `keep_mesh = FALSE`.
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
#'   Boundary optimization uses NLopt COBYLA to vary interior vertices of
#'   a lifted domain polyline. Bounds constrain a rectangle; a quadratic
#'   inequality per vertex constrains a disk. All accepted vertices must also
#'   pass the strict floating-point domain check, independently of NLopt's
#'   constraint status. Convexity then keeps every lifted domain segment in D.
#'   The direct connector is an explicit initial candidate. Each accepted
#'   replacement must be shorter by more than the sum of the two numerical
#'   length-error estimates. A feasible supplied initial path competes with
#'   the direct connector, rather than silently replacing it.
#'
#'   Optimization coordinates are centered and divided by the domain radius
#'   or largest box width. The position tolerance and initial step use these
#'   normalized units. Starts add sine-shaped normal displacements controlled
#'   by `initial_bends`, projected into D only to construct feasible initial
#'   guesses. Subsequent levels bisect the retained path, up to 257 vertices.
#'   Objective-evaluation or time limits, and incomplete individual searches,
#'   retain the best feasible path as `partial`. A position-tolerance stop is
#'   not a stationarity or global-optimality certificate. No states are saved.
#'
#'   Delaunay and radius references insert endpoints into either the supplied
#'   vertex set or a regular lattice clipped to D, remove exact duplicates,
#'   and sort vertices lexicographically. Delaunay uses `geometry::delaunayn`
#'   with Qhull options `Qt Qbb Qc Qz`, without randomized perturbation. The
#'   package geometry is an optional dependency for Delaunay and mesh methods.
#'   Its simplices supply all one-skeleton edges. Radius graphs instead join
#'   all pairs at Euclidean domain distance at most `radius`. There is no
#'   direct-edge override or silent connectivity repair. Edge weights are
#'   analytic lifted straight-segment lengths, not ambient chords. Boost
#'   Dijkstra selects a graph path, whose length is recomputed with the exact
#'   accumulator. In 3D and 4D, the same analytic integral is used with
#'   higher-dimensional endpoint slopes and propagated numerical error estimates.
#'   The entire triangulation and pair preparation count toward total time,
#'   but Qhull is an indivisible call: its time allowance is checked before
#'   and after it, not enforced as an operating-system deadline.
#'
#'   The polyhedral method uses Kirsanov's implementation of the
#'   Mitchell--Mount--Papadimitriou triangle-interior propagation algorithm on
#'   a two-dimensional Delaunay triangulation lifted at its vertices. Its
#'   domain is the triangulated convex hull of these points, a subset of D,
#'   not the whole disk when D is circular. The upstream small-interval cutoff
#'   is 1e-6 times edge length. Live intervals and propagation counts are
#'   bounded; user interrupts release owned intervals before propagating to R.
#'   Degenerate triangles or unresolved numerical invariants return no path.
#'
#'   For `polyhedral_surface_polyline`, `surface_path` is a path across flat
#'   mesh triangles and `path` is its domain projection. `length` measures
#'   that mesh path, not a smooth-surface path. The separate diagnostic
#'   `smooth_lifted_length` measures the lifted domain polyline obtained from
#'   its projection. These two numbers must not be interchanged in comparisons.
#'   Mesh `length_error_estimate` is missing, not zero; the algorithm's name
#'   does not imply a rigorous certificate. Kept mesh vertices and triangles
#'   are available under `backend_result$mesh` when `keep_mesh = TRUE`.
#'
#'   Shooting adjusts the initial velocity of the geodesic equation using
#'   its variational equations and damped Newton iterations. Integration uses
#'   Boost's controlled Dormand--Prince 5(4) stepper. Collocation independently
#'   solves the four-state boundary-value equations with fourth-order
#'   Lobatto collocation, a sparse analytic Jacobian and damped Newton steps.
#'   Both use the equation
#'   \deqn{u''=-\frac{2Au}{1+\|2Au\|^2}(u'^T(2A)u').}
#'   Coordinates are translated to the canonical first endpoint and divided
#'   by the domain-coordinate distance between endpoints. Thus endpoint
#'   tolerance is relative to that distance, not to the domain's diameter.
#'
#'   A zero initial bend starts with a flat surface and continues through
#'   increasing multiples of A to the requested surface. The initial step is
#'   `1/continuation_steps`; successful steps grow by 1.5 and unsuccessful
#'   steps halve. Nonzero bends are additional direct starts on the full
#'   surface. If delta joins the normalized endpoints and J rotates by 90
#'   degrees, shooting starts with velocity `delta + bend * J delta`;
#'   collocation starts with the curve
#'   `a + t * delta + bend * sin(pi*t) * J delta`, with its derivative.
#'   `initial_nodes` sets the initial collocation mesh; shooting uses adaptive
#'   integration nodes. The shortest accepted start is retained, with
#'   overlapping numerical length-error intervals resolved by start order.
#'
#'   `ode_tolerance` bounds a sampled, componentwise scaled residual of
#'   cubic Hermite state interpolation, not a rigorous solution error.
#'   Intervals are tested at fractions 0.2113248654, 0.5 and 0.7886751346.
#'   Collocation doubles the mesh resolution when needed; shooting reduces
#'   the maximum integration step. Shooting's relative integration tolerance
#'   is `integration_tolerance`, with absolute tolerance one hundredth of it.
#'   `iterations` limits each Newton solve; `max_evaluations` counts equation
#'   evaluations across all starts, continuation and residual checks.
#'
#'   Continuous candidates are converted to lifted domain polylines.
#'   Recursive cubic Bezier control-hull checks establish containment of the
#'   interpolated domain curve using floating-point arithmetic. Midpoint and
#'   quarter-point subdivision compares lifted-connector lengths using a
#'   total allowance of `path_tolerance` times the direct connector length.
#'   This is a refinement diagnostic, not a certified discretization bound.
#'   `length_error_estimate` concerns only the returned polyline's length.
#'   Endpoint residuals are measured before fixing the returned endpoints
#'   exactly; reported residuals have the original domain-coordinate units.
#'
#'   A stationary path need not be the shortest path. The diagnostics retain
#'   each start's outcome, the selected start, equation and endpoint residuals,
#'   and the direct connector length for comparison. There is no silent
#'   fallback to a different method and no boundary-following solver.
#'   A retained candidate with unresolved starts or an exhausted overall
#'   budget is `partial`; no usable path gives `failed`, or `unsupported`
#'   when rejected solutions leave the domain. These methods do not handle
#'   more than one quadratic form or domain dimension other than two.
#'   Nontrivial pairs require endpoint separation between 1e-100 and 1e100, maximum
#'   absolute entry of `2 * separation * A` at most 2048 and maximum absolute
#'   component of `2 * A * canonical_from` at most 1e6. Out-of-scope cases
#'   return `unsupported`; flat and coincident pairs bypass these restrictions.
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
#'   Grid, Clairaut and continuous results are symmetric under endpoint reversal
#'   when calculation limits, rather than wall-clock timing, determine completion.
#'   A single
#'   randomized refinement run is not required to be: its internal orientation
#'   is randomized relative to the supplied endpoints. The wrapper preserves
#'   the lower-level solver's behavior and seed semantics.
#' @keywords internal
quadform_geodesics <- function(A, from, to, domain, method,
                              control = list(), return.paths = FALSE) {
  methods <- c("single_point", "local_network", "best_of_six",
               "grid_dijkstra", "paraboloid_clairaut",
               "geodesic_shooting", "geodesic_collocation", "boundary_optimization",
               "polyhedral_mesh", "delaunay_graph", "radius_graph")
  if (missing(method) || !is.character(method) || length(method) != 1L ||
      is.na(method) || !method %in% methods)
    stop("method must explicitly name one of: ", paste(methods, collapse = ", "))
  if (method %in% c("polyhedral_mesh", "delaunay_graph", "radius_graph"))
    return(quadform_geodesics_graph_reference(A, from, to, domain, method, control, return.paths))
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
  } else if (method == "paraboloid_clairaut") {
    defaults <- list(iterations = 80L, path_samples = 257L,
      domain_check_depth = 16L, angle_tolerance = 1e-12, max_seconds = Inf)
  } else if (method == "boundary_optimization") {
    defaults <- list(initial_edges = 8L, levels = 2L, evaluations_per_start = 2000L,
      max_evaluations = 20000L, position_tolerance = 1e-6, initial_step = .05,
      initial_bends = c(0, -.5, .5), initial_path = NULL, max_seconds = Inf)
    if (!requireNamespace("nloptr", quietly = TRUE)) stop("nloptr is required")
  } else {
    defaults <- list(ode_tolerance = 1e-6, endpoint_tolerance = 1e-8,
      path_tolerance = 1e-7, iterations = 30L, continuation_steps = 8L,
      continuation_attempts = 128L, initial_nodes = 17L, max_nodes = 1025L,
      max_path_vertices = 4097L, max_evaluations = 500000L,
      domain_check_depth = 20L, initial_bends = c(0, -1, 1), max_seconds = Inf)
    if (method == "geodesic_shooting") defaults$integration_tolerance <- 1e-10
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
