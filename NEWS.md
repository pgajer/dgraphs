# dgraphs (development version)

* Correct `subdivide.path()` to include both endpoints and interpolate at equal
  arc-length intervals along the polyline, skipping repeated points instead of
  returning missing rows. Singleton and zero-length paths now have length zero,
  normalized cumulative distances of zero, and repeated-location subdivisions.
  Empty/malformed paths and invalid subdivision counts or vertex indices are
  rejected explicitly; subdivision requires at least two output points.

* Add `explore.graphs()`, the Graph Reconstruction Explorer migrated from
  dggraphui, with optional Shiny dependencies. `read.graph.benchmark()` reads
  existing benchmark manifests; `register.graph.project()` remembers external
  projects without moving or changing their data.
* Retain saved-layout viewing and add current weighted-GRIP support for explicit
  missing-layout generation. Cache keys distinguish full project paths; legacy
  cache entries require matching graph provenance.

# dgraphs 0.3.0

* Consolidate distance matrices under `graph.geodesic.distances()`, accepting
  either a graph or points with explicit symmetric-kNN/MST construction. MST
  construction preserves zero-length edges; k = 1 no longer implies an MST.
* `create.path.graph(graph, h.values)` always returns a named collection.
  Correct hop-constrained route reconstruction and support reverse and self
  queries in `get.shortest.path()`. Remove the raw public `shortest.path()`,
  `estimate.geodesic.distances()` and `create.path.graph.series()` interfaces.
* Replace `plot2D.colored.graph()` with `plot()` for `dgraph`. Layouts can be
  reused, numeric values and explicit colors are distinct, constant values
  plot correctly, and undirected edges are drawn once. Three-dimensional
  coordinates require explicit projection. Layout and plotting share stage
  selection. No compatibility wrappers are retained.

* Replace ten basic graph constructors with `create.graph(type, ...)`, without
  compatibility wrappers. Eight types share vertex counts, optional labels and
  strict argument validation. Chains use per-side `span`; circles return
  coordinates and explicit arc/chord lengths; random graphs enforce feasible
  edge budgets and support isolated seeds.

* Breaking graph API: every constructor returns `dgraph`; use `graph.adjacency`,
  `graph.lengths`, `graph.edges`, `graph.order`, `graph.stages` and
  `graph.edge.attribute`. Raw metric inputs use `adj.list` and `length.list`.
  Old graph fields, conversion overloads, `get.edge.weights` and
  `extract.edge.lengths` are removed without compatibility wrappers.
* Graph sequences use increasing `k.values`. Coordinate, geodesic and iterated
  intersection covers contain self plus k other vertices, with distance ties
  resolved by vertex index. Undersized components require explicit truncation.
  Neighbor caches use format 3 and validate working coordinates and row order.
* Mutual-neighbor sequences now use the documented path/edge ratio directly;
  zero disables pruning. The former unintended addition of one is removed.
* Graph layouts select edge attributes and transformations explicitly. Nerve
  overlaps are attributes rather than lengths. Path results contain `$graph`;
  path series compute each requested hop limit independently.

- Expand quadratic-geometry examples with interactive ivue galleries, labeled
  x/y/z axes, all specialized sampling modes, frames, dimensions and metric
  diagnostics. Optional visualization dependencies have static fallbacks.

- Add installed function-guide and synthetic-geometry vignettes, with a
  task-oriented catalog, method workflows, reproducible examples and explicit
  geometry/sampling limits. Link all guides from the package overview and
  README; add automated export and method-help coverage checks.

- Fix one-point box sampling and multiple-height embeddings to retain matrix
  dimensions. These inputs previously failed in inherited geometry kernels.
- Add explicit current-stream sampling for Geometry Lab compatibility with
  nondefault RNG kinds; the default isolated seed/state modes are unchanged.

- Add reusable synthetic geometry constructors, embeddings, geometric edge
  lengths, and sampling specifications previously provided by geosmooth.
- Add `sample.synthetic.geometry()` with explicit random-state continuation
  and restoration of the caller's random-number state. Statistical responses,
  registry identities and the legacy G4 recipe remain in geosmooth.
- Move the development Geometry Lab app and maintained quadratic-surface
  fixture/reference tools into this repository. Geometry Lab uses shared
  versioned sampling while retaining its existing point identities.

## Graph construction and maintenance changes carried forward

* Adds `create.sknn.graphs()` for constructing a sequence of symmetric-kNN
  graphs from one cached ANN search. `create.sknn.graph()` now also accepts a
  validated precomputed neighbor matrix and supports
  `graph.detail = "minimal"` for scalable fitting workflows that do not need
  repaired lifecycle branches.
* Removed global compiler-warning suppression and unsupported native OpenMP
  branches. Native graph construction remains serial, including in custom
  builds with OpenMP enabled; compatibility arguments are retained.
* ANN errors now propagate as R errors instead of silently continuing.
  Native entry points catch C++ exceptions, ANN point and tree ownership is
  exception-safe in nearest-neighbor and MST helpers, and the native kNN entry
  validates dimensions, finite coordinates and neighborhood size.
* Documented all registered S3 methods and added runnable method examples.
  The documentation-coverage test now includes registered methods.
* `compare.adj.lists()` is silent by default; use `verbose = TRUE` to print
  vertices whose neighbor sets differ.

* Fixes summaries of empty `detect.local.extrema()` results by retaining the
  requested maxima/minima setting in a scalar `detect.maxima` component.
  Legacy empty objects without this metadata report an unknown (`NA`) type
  instead of being incorrectly labeled as minima.

# dgraphs 0.2.0

## Breaking API changes

* Removes the deprecated `create.radius.graph()` and
  `create.adaptive.radius.graph()` compatibility wrappers. Use
  `create.rknn.graph()` with `type = "fixed"` or
  `type = "adaptive.radius"`, respectively.
* Removes the temporary public backend entry point
  `cpp.create.rknn.graphs()`. Use `create.rknn.graphs(backend = "cpp")`.
* Internalizes the low-level `dist.to.knn()`, `euclidean.distance()`, and
  `graph.adj.mat()` helpers.
* Removes the superseded `adjlist.to.igraph()` conversion function.
  `as_igraph()` now accepts bare adjacency lists and an optional aligned
  `weight.list` argument.
* Removes the unused graph-edit workflow comprising `graph.edit.distance()`,
  `load.graph.data()`, `calculate.edit.distances()`, and
  `create.distance.plot()`.

## Other changes

* Fixes a C++ One Definition Rule violation reported by CRAN's special
  link-time-optimization check. The minimum-spanning-tree implementation now
  uses a privately scoped edge type, and an unused conflicting intersection-kNN
  helper type has been removed. This does not change the R API or graph
  semantics.
* Fixes an ANN fixed-radius boundary issue that could omit adaptive-radius
  edges lying exactly at a local-scale threshold. In particular, the
  adaptive maximum-radius rule with factor one now reproduces symmetric-kNN
  edges for exact, tie-free searches.
* Clarifies that the historical `rel_geodesic_stress` diagnostic is a
  target-normalized graph-geodesic relative RMSE, not Kruskal's Stress-1.
* Adds a full workflow vignette covering graph construction, lifecycle
  diagnostics, connectivity repair, parameter sequences, conversion to
  `igraph`, and geodesic-isometry diagnostics.
* Expands examples across the exported API in preparation for an R Journal
  package paper.
* Extends `as_igraph()` to current `dgraphs` graph objects while preserving
  support for legacy basin graph objects.

# dgraphs 0.1.0

* First public release.
* Provides mutual, shared-neighbor, intersection, geodesic nearest-neighbor,
  radius, adaptive-radius, and minimum-spanning-tree-completed graph
  constructors.
* Provides graph conversion, weighting, pruning, diagnostics, spectral
  embedding, endpoint detection, and path utilities.
* Includes native implementations for performance-sensitive graph
  construction and analysis.
