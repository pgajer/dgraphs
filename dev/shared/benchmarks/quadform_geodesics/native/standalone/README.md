# Package-Integrated C++ Quadform Geodesic Solver

Package ownership changed to dgraphs on 2026-09-11. The R and C++ source paths
listed here are now relative to the dgraphs repository, and native component
tests have moved with them. This directory retains the cross-implementation R
oracle and its historical benchmark protocol until the geometry migration.

Current configuration: `self-contained-cpp-analytic-v3`. Compared with the
initial analytic configuration, returned heights now use exact binary-input
products and sums followed by one rounding. Graph search compares exact sums
of computed edge weights; reported totals round once. Point occurrence IDs
remain distinct when coordinates repeat. The initializer caps its tolerance
relative to the requested segment length. A plateau involving failed sampling
or comparison windows reports `incomplete_exploration`.

The analytic edge formula, indexed local table, optional cache and default-off
tracing are retained. Use `cache_edges=0` for the performance baseline. Exact
graph-cost comparisons do not certify true connector errors or global geodesic
optimality. Oversized local-network proposals are still rejected whole, without
searching for the best alternative fitting the vertex cap. Native component
regressions and their invocation are in [tests](../tests/README.md).

The package's internal solver finds short paths on the graph surface
`F(u) = (u, u^T A u)`, for a symmetric 2 by 2 matrix `A` and a disk or rectangular
domain. Both Single-point refinement and Local-network refinement run entirely
in compiled code, including initialization, random sampling, visit order,
numerical integration, edge caching and acceptance decisions. The R function
passes inputs and returns results. There is no Python or reticulate dependency.

"Self-contained" means self-contained within R: the code uses Rcpp and calls
the standard C++ math library for analytic connector lengths. It never calls
`stats::integrate`, `Rdqags`, or an R function from the search loop. It is not
an executable independent of R. The earlier quadrature backend remains in
historical reference scripts; it is not used for production edge measurements.

The implementation is compiled during normal package installation, not when a
solver is called. Its sources follow the package's separate Rcpp-layer convention:
`R/quadform_geodesics_solver.R`, `src/quadform_geodesics_solver.cpp`,
`src/quadform_geodesics_solver.h` and `src/quadform_geodesics_solver_rcpp.cpp`.
The R function remains internal, not exported. Previous solvers, frozen fixtures,
the comparison registry and package version remain unchanged.

## Use From R

```r
library(dgraphs)
solve_path <- getFromNamespace("quadform_geodesics_solver", "dgraphs")

result <- solve_path(
  A = diag(c(8, 8)),
  from = c(-0.45, -0.20), to = c(0.40, -0.10),
  domain = list(kind = "ball", center = c(0, 0), radius = 1),
  method = "local_network", neighborhood = "fixed_span",
  seed = 50001, length_scale = 32.0624390837628, cache_edges = 0L
)
result[c("status", "termination", "length", "initial_length", "counters")]
result$path         # Domain coordinates, in the caller's endpoint order.
result$surface_path # Corresponding three-dimensional surface coordinates.
```

For a rectangle, use `list(kind = "box", lower = c(-1,-1), upper = c(1,1))`.
The endpoints are domain coordinates, not three-dimensional surface points.
`length_scale` is a positive surface-length reference used by the absolute
numerical tolerances; use the same scale for comparisons on the same example.
The default is one. This version intentionally rejects higher dimensions,
multiple height functions and nonsymmetric matrices rather than silently
approximating unsupported geometry.

Install the current package before using this interface. Neither the installed
function nor its development loader needs `sourceCpp()`, a private build cache,
the repository checkout, or a compiler at runtime. The small `solver.R` retained
here is only a compatibility loader for development scripts; it retrieves the
installed function and does not contain a second solver implementation.

## The Calculation

Initialization subdivides the lifted straight domain connector into 16 edges
with equal estimated surface length. Canonical endpoint ordering makes that
subdivision reversal symmetric. The solver checks spacing and additive length
before using the subdivided path. A valid direct connector remains available
if initialization subsequently reaches a calculation limit or fails.

Each epoch visits a shuffled snapshot of the current interior point IDs.
Deleted points are skipped; newly inserted points become eligible next epoch.
Every visited point receives 32 accepted draws, uniformly distributed over its
domain disk and rejected when outside the specified surface domain. Exact
duplicates are removed without replacement, as in the reference algorithm.
Both methods use the same candidate count. Rejection is limited to 1,000
attempts per requested point; an incomplete candidate set skips that visit.

The three neighborhood settings preserve the previous definitions:

* `neighbors`: replace the section between immediate neighbors. The sampling
  disk is centered on the visited point, with radius the larger of its two
  current domain distances to those neighbors.
* `fixed_disk`: replace the same immediate-neighbor section, but hold the disk
  radius fixed at the largest domain edge length of the initialized path.
* `fixed_span` (default): use that fixed disk. To choose each section endpoint,
  walk along the current path in domain coordinates until accumulated domain
  length reaches the radius or the global endpoint. Endpoints remain existing
  path vertices, so the last edge may overshoot the radius.

Single-point refinement compares the existing section with the direct connector
and every one-candidate connector. Local-network refinement finds a shortest
path through the complete graph of candidates and existing section vertices.
Both keep the existing section on equal lengths. Other ties use the same
binary-coordinate ordering as the R reference.

Let `L_old` and `L_new` be the estimated section lengths, with numerical error
estimates `e_old` and `e_new`. A replacement requires

```
L_old - L_new > 1e-12 * length_scale + 1e-10 * L_old + e_old + e_new.
```

For h=b-a, the connector speed is hypot(||h||, (1-t)v0+t*v1), where
v0=2a^T A h and v1=2b^T A h. Both endpoint slopes are evaluated directly.
The length is evaluated analytically using scaled, cancellation-free divided
differences. An internal zero crossing is split algebraically, without sampling
the narrow minimum. Constant slopes use hypot directly. When the horizontal
contribution is below working precision, its omission is explicitly included
in the error estimate, using |hypot(c,x)-|x|| <= c.

The error estimate includes coefficient-rounding uncertainty, an allowance
for floating-point operations and math-library evaluation, and conversion to
R's double precision. It is not a rigorous interval bound. Both legacy
precision levels now use the same analytic calculation: retrying does not
reduce roundoff, so an unresolved replacement remains unaccepted. The acceptance
inequality above is unchanged. This does not prove a globally shortest path.

## Randomness and Reproducibility

The C++ generator is `std::mt19937_64`, seeded by the SplitMix64 mixing function.
The 32-bit user seed and three distinct stream labels occupy disjoint 64-bit
input ranges before mixing. Candidate draws, epoch ordering and internal
endpoint orientation use separate streams. Uniform values use the upper 53
bits explicitly; the code does not rely on implementation-specific standard
library distributions or `std::shuffle`. Visit ordering uses unbiased
32-bit rejection followed by Fisher-Yates shuffling.

The default `random_orientation = TRUE` chooses internal endpoint orientation
once per call, without consuming candidate or visit-order draws. Results and
trace paths are always returned in the caller's endpoint order. The selected
orientation is reported in `internal_orientation_reversed`. For repeated
experiments, vary the seed and use the same seed for corresponding method
comparisons; a single seed does not measure sensitivity. Separate forward and
reverse experiment groups are unnecessary for ordinary future campaigns.
Small reversal regression tests remain useful and are retained.

Seeds are whole numbers from zero through `2^32 - 1`. This generator does not
modify or create R's `.Random.seed`. It intentionally replaces the earlier
NumPy PCG64 streams. The same numeric seed therefore does not reproduce an old
Python-based run. The initial analytic results have identifier `self-contained-cpp-analytic-v2`
and must not be presented as exact replays of either historical PCG64 experiments
or the earlier `self-contained-cpp-v1` quadrature solver. Repeated
runs agree on the tested platform; transcendental functions and floating-point
behavior can still differ across compilers and platforms.

## No State Saving by Default

Normal calls do no file I/O and retain no refinement history or RNG checkpoint.
They return only the final path, small initialization record, settings and
counters. The edge cache exists only in memory and is destroyed after the call.
There is no automatic serialization, temporary checkpoint or recovery file.

For visualization or debugging, pass `trace = TRUE`. The returned `trace`
contains the direct path, initializer, accepted replacements, epoch visit
orders and epoch-end paths. Each accepted replacement includes its measured
decrease and required decrease. `path_ids` identify occurrences along that
event's returned path; `visit_ids` give the shuffled IDs for an epoch. IDs
remain meaningful when neighboring replacements insert or remove vertices.
The trace does not include all rejected candidates or every numerical call.

At most `trace_limit = 1000` events are retained by default. Further events are
counted, and `trace_truncated` explicitly reports omission. Tracing changes
neither random draws nor fixed-work decisions. It can change how much work
fits inside a wall-clock limit. This optional in-memory trace is not resumable
state. There is deliberately no recovery-checkpoint implementation; callers
may explicitly save a completed result when needed.

## Limits and Outcomes

Default limits are eight epochs, 200,000 newly measured edges, 257 path
vertices and a 65,536-edge least-recently-used cache. Each cached edge can retain
ordinary and tighter measurements. `max_seconds` defaults to infinity; callers
can set a finite wall-clock allowance. Two consecutive epochs with relative
improvement below `1e-5` stop the search early. `max_epochs = 0` requests only
initialization. At most 256 candidates, 257 path vertices and 10,000 trace events
are allowed, preventing unbounded user-selected graph or trace growth.

Use `cache_edges=0` for performance baselines. The indexed local edge table
is always retained; the optional cross-visit cache and its existing default
capacity are unchanged. `integrand_evaluations` is retained for compatibility
and is zero for the analytic solver. `edge_calls` counts analytic measurements.

The result distinguishes a fully initialized `candidate`, a `direct_fallback`
and `no_path`. `termination` explains whether the search exhausted its epoch
limit, stagnated locally, reached an edge/time limit, or failed numerically.
A calculation stopped within a proposed replacement returns the last completed
path, never a partially modified one. No-path results have missing length,
not zero. A user interrupt propagates to R rather than silently continuing.

Time checks occur between edge calculations and within graph and sampling
loops. One bounded analytic calculation can overshoot a very short time
allowance. This is not an operating-system memory
or hard real-time guard. Separate processes, not simultaneous threads calling
R's C API, are the appropriate way to run independent solves concurrently.
The previous campaign runner still uses the historical backend; it is not
silently redirected to this implementation.

## Verification

Focused package checks live in `tests/testthat/test-quadform-geodesics.R` and
`tests/testthat/test-quadform-edge-lengths.R`. The latter uses fixed
high-precision references for previously failing and extreme-scale edges. They
exercise the installed interface without the development tree. The larger
reference comparisons remain here. Run `Rscript native/standalone/tests.R` from
this benchmark directory, with the current dgraphs package and testthat
available. The development tests deliberately select a nonexistent Python
interpreter. They check input validation, initialization, independent R length
integration, both methods and all neighborhoods, seeded reproducibility,
random orientation, trace equivalence, budgets, cache eviction and numerical
failure. Historical matched-stream comparisons against R use the earlier
quadrature algorithm and are not an exact-replay requirement for the analytic
solver; corrected lengths and error estimates can change acceptance decisions.

`reference.R` is test-only. It supplies the new C++ random draws to the old R
algorithm, allowing algorithm comparisons without confusing a generator change
with a numerical or geometric discrepancy. It is never loaded by normal use.

`benchmark.R /new/private/output` measures the previous R loop with its C++
helpers against this implementation on matched steep-bowl workloads. It removes
Python startup, compilation, random-tape preparation and disk checkpointing
from both timed searches. Reference and first C++ comparisons disable caching
to match integration counts; a separate column measures the normal C++ cache.
These are diagnostic speed measurements, not a new scientific sensitivity
campaign or independent implementation audit.

Only that historical-helper timing comparison still compiles the old helper
code with `sourceCpp()`. Set `QGC_BUILD_CACHE` to a private directory for this
benchmark; it is not needed by the installed solver or correctness tests.

For a separate long-search cache and memory check, run
`/usr/bin/time -l Rscript native/standalone/memory_smoke.R`. It raises the epoch
limits to reach 200,000 integrations for each Local-network neighborhood,
checks cache bounds and independently integrates the returned paths in R.
