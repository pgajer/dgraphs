# dgraphs 0.3.0 graph API implementation

The graph redesign is implemented without compatibility wrappers. Every graph
constructor returns `dgraph`; path and packing results contain a `graph` member.
Adjacency, lengths and named attributes have one validated representation, with
explicit stage accessors. Graph-taking operations use `graph`; raw metric
operations use `adj.list` and `length.list`. Generic matrix weights retain
`weight.list` because they need not represent distances.

Coordinate, graph-geodesic and iterated intersection covers contain self plus
k other vertices. Distance ties use vertex index. Undersized graph components
error unless truncation is requested, and effective counts are recorded for
each vertex. Version 3 caches contain non-self neighbors and fingerprint the
working coordinate values and row order, including the result of preprocessing;
metric, feature count and adequate maximum k are also checked. The exact
L-infinity simplex search currently evaluates every candidate to resolve ties.

The implementation also fixes two inconsistencies exposed by the new tests:
path series now compute each hop limit independently and retain aligned hop
counts; mutual-neighbor sequences use the documented path/edge ratio directly,
with zero disabling pruning. The random connected-graph generator now samples
from singleton vertex vectors correctly and assigns reciprocal edge lengths.
Raw symmetrization preserves vertex order and isolated vertices.

## Standard graph construction

The ten basic constructors have been consolidated into `create.graph(type, ...)`.
The old exports and their definitions are removed; there are no compatibility
wrappers. Eight types cover empty, complete, chain, cycle, complete bipartite,
star, random and sampled-circle graphs. Chains use `span` for the number of
positions on each side. Labels apply to every type independently of compact
adjacency indices, and coordinate-sorted chains retain an explicit input-order
mapping. A subdivided star specifies the number of edges in each arm.

Circle graphs now return coordinates and distinguish shorter arc lengths from
chords, correcting the old help/implementation mismatch. Random graphs enforce
an exact feasible edge budget and document the growing-tree sampling procedure
and quadratic candidate storage. Explicit seeds restore the caller's random
state; omitted seeds advance the current stream. Type-specific names and
conflicting sizes are validated strictly.

The new tests check each defining topology, chain ordering and zero lengths,
labels on all eight types, geometric length identities, random edge budgets
and connectivity, RNG preservation, invalid arguments and absence of the
retired functions from the namespace. A follow-up read-only scan of geosmooth,
gflow, ivue, grip, linf and gcstflow R sources and namespaces found no direct
qualified calls or imports of these ten constructors. The broader downstream
migration requirements below remain unchanged.

## Validation

The source tarball passed `R_TIDYCMD=/opt/homebrew/bin/tidy make check` on
macOS Apple Silicon with R-devel 4.7.0: 0 errors, 0 warnings, 1 NOTE for ivue
being absent from mainstream repositories. All 2,754 expectations passed
without failures, warnings or skips. Installed examples, self-containment,
three vignettes and their rebuilds passed. The catalog verifies 113 explicit
exports and 38 registered S3 methods. HTML validation checked 500 local links.
Before the standard-constructor consolidation, all 36 gallery choices updated
in a WebGL browser; saddle rotation, labeled x/y/z axes, camera reset and guide
navigation were inspected. The forced-static geometry render passed as well.
The unchanged geometry gallery was rebuilt for this update. The new standard-graph
tables and their example results were checked in generated HTML, including
column counts and section navigation. A fresh browser preview was blocked by
the browser local-URL policy; no workaround or fresh visual inspection is claimed.

The first check identified stale argument documentation and an installed test
reading retired fields. A later sparse-sequence test exposed the pruning-ratio
translation error described above; both were fixed before the passing check.
Private execution logs preserve those earlier failures.

A separate pkgload debug build aborted at the preexisting invalid-matrix test
for a native quadratic-geodesic wrapper, even after a clean debug rebuild.
The standard optimized installation passed this same test. The cause of the
debug-only failure was not established, and this configuration is not claimed
to pass. No platform other than the documented macOS/R-devel installation and
no downstream runtime check was qualified. Behavior tests cover reciprocal values, zero lengths,
isolates, missing stages and lengths, all retained-stage conversions, sparse
sequences, deterministic ties, component truncation, iteration, and cache
invalidation. Coordinate and graph-geodesic edge lengths retain their distinct
definitions even when the cover topology agrees.

The 0.2-era pinned-gflow comparisons of entire legacy objects are archived in
`dev/shared/history/graph-migration-0.2`. They document that earlier migration;
they do not define the breaking 0.3.0 interface. Independent endpoint native/R
comparisons were moved into the current package test suite. Current development
Geometry Lab tools use their own edge-table structures and unchanged geometry
functions, so their graph operations require no interface translation.

## Owned downstream audit (read-only)

The geometry/sampling imports used by geosmooth remain available. Other graph
callers do require migration. No sibling package was edited or claimed tested.
Locations below are source locations at the time of this audit.

| Package and location | Required follow-up |
|---|---|
| geosmooth `R/pttf_geometry.R:246–258` | Read the constructed radius graph with `graph.adjacency()` and `graph.lengths()`. |
| geosmooth `R/ssrhe_hessian_energy.R:897–911` | Read radius-graph adjacency through its accessor. |
| geosmooth `R/lpl_tf.R:1543` and `R/split_bridge_helpers.R:28` | Replace dgraphs field-detection branches with stage accessors; keep any geosmooth-owned raw input contract explicit. |
| geosmooth graph-boundary, trend-filtering and Hessian-energy tests | Update graph fixtures and direct field reads, then run downstream checks. |
| gflow `R/basin_cx.R:1030`, `R/cluster_local_extrema.R:265` | Pass `dgraph` objects to connected-component calculations; explicitly construct them from gflow-owned raw lists. |
| gflow `R/basin_cx.R:2218` | Pass a `dgraph` to layout and select the edge quantity and transformation explicitly. |
| gflow `R/graphics.R:802–807` | Read nerve adjacency and its `overlap` attribute; overlap is not a length. |
| gflow `R/lcor.R:379–388` | Read adjacency and lengths from the path result's `graph` member. |

Source/dependency scans of grip, ivue, linf and gcstflow found no direct dgraphs
imports or qualified calls requiring this migration. This is a call-site audit,
not proof of runtime downstream compatibility. After publication, geosmooth
should require `dgraphs (>= 0.3.0)` and rerun its repository-only dependency
check. Publication and external platform checks remain release coordination
steps for the maintainer.
