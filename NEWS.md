# dgraphs 0.4.0

Planned CRAN update from dgraphs 0.2.0; not yet released.

* Installed vignettes use compact static illustrations by default. All seven
  guides, numerical results and original figure sources are retained. Set
  `DGRAPHS_STATIC_VIGNETTES=false` when rendering interactive galleries;
  website builds use that mode.

## Breaking changes and migration

* Graph constructors now return `dgraph` objects. Use `graph.adjacency()`,
  `graph.lengths()`, `graph.edges()`, `graph.order()`, `graph.stages()` and
  `graph.edge.attribute()` to access their contents. The legacy `adj_list` and
  `weight_list` fields remain available for one transition release without
  warnings and contain the final-stage adjacency and lengths. Treat them as
  read-only snapshots and migrate to the accessors. Native constructor results
  also retain `edge_matrix` for this release. Other old graph fields,
  conversion overloads, `get.edge.weights()` and `extract.edge.lengths()` have
  been removed. Functions accepting raw metric data use `adj.list` and
  `length.list` arguments.

* `create.graph(type, ...)` replaces the individual constructors for standard
  graphs. It supports eight graph types, vertex labels and argument validation.
  Chains use a per-side `span`; circles include coordinates and a choice of
  arc or chord lengths; random graphs support isolated random seeds.

* Use `graph.geodesic.distances()` for graph distance matrices, with either a
  graph or points and an explicit symmetric-kNN or minimum-spanning-tree
  construction. Setting `k = 1` no longer selects a minimum spanning tree.
  `estimate.geodesic.distances()` has been removed.

* `shortest.path(graph, edge.lengths, vertices)` remains available for one
  transition release without deprecation warnings. New code should use
  `graph.geodesic.distances(dgraph(graph, edge.lengths), vertices = vertices)`.

* `create.path.graph(graph, h.values)` now returns a named collection for all
  requested hop limits, including a single limit. It replaces
  `create.path.graph.series()`. Path results store their graph in `$graph`.

* `plot()` for `dgraph` replaces `plot2D.colored.graph()`. Numeric vertex values
  and explicit colors are separate arguments, layouts can be reused, and
  three-dimensional coordinates require an explicit projection. Constant values
  plot correctly, and undirected edges are drawn once. Graph layouts
  select edge attributes and transformations explicitly; nerve-graph overlap
  counts are stored as attributes rather than edge lengths.

* `graph.spectral.embedding(spectrum, dim, scale)` now takes the complete object
  returned by `graph.spectrum()`, replacing separate eigenvector and eigenvalue
  arguments. Scaling is selected with `scale = "none"` or `"inverse.sqrt"`.
  Disconnected graphs must be embedded one component at a time.

* Graph sequences use strictly increasing `k.values`. Intersection covers
  include each vertex and its `k` other neighbors. Geodesic neighbor queries
  exclude the query vertex by identity, retain coincident observations and
  break distance ties by vertex index. Insufficient reachable neighbors raise
  an error unless `small.component = "truncate"`; truncated results use
  `NA`/`Inf` padding and report `effective.k`.

* Removed unused intersection parallel controls, `edge.col` in `path.dist()`,
  `method` in `geodesic.knnx()`, `k` in `plot.IkNNgraphs()`, and the explorer's
  `run_dir` alias and old cache option.

## New features

* `fermat.distances()` computes Fermat distances on the complete Euclidean
  graph, a symmetric-kNN graph or a supplied graph, with optional rooted
  output. An implicit complete-graph backend supports selected source and
  target queries with a workspace limit. `return.graph = TRUE` also returns
  the union of selected shortest-path edges, their powered base lengths and
  source/target coverage information.

* `fermat.knn()` and `create.fermat.sknn.graph()` provide exact nearest neighbors
  for complete-graph Fermat distances. The resulting graph uses path distances
  as edge lengths; it need not be connected or preserve all pairwise distances.

* `linf.simplex.distances()` computes intrinsic Euclidean-length distances on
  the max-normalized compositional simplex, allowing paths through intermediate
  faces. It supports source/target blocks, selected pairs and returned paths.

* `create.ian.graph()` adds iterated adaptive neighborhood graphs with
  connectivity-preserving pruning and one checked retry after an eligible
  solver rejection by default. Results include initial and final graphs,
  profile mappings and numerical diagnostics. Strict numerical and reference
  pruning options remain available. The optional backend is built separately
  with `build.ian.backend()`; setup currently supports macOS arm64.

* Synthetic geometry constructors, embeddings, geometric edge lengths and
  sampling specifications are now available in dgraphs.
  `sample.synthetic.geometry()` supports random-state continuation and restores
  the caller's random state by default, with an explicit option to sample from
  the current stream. Statistical responses and dataset registries remain in
  geosmooth.

* `create.sknn.graphs()` constructs a sequence of symmetric-kNN graphs from one
  neighbor search. `create.sknn.graph()` also accepts validated precomputed
  neighbors and offers `graph.detail = "minimal"` for workflows that do not
  need the full set of graph stages.

* `explore.graphs()` adds the Graph Reconstruction Explorer with optional Shiny
  dependencies and a saved circle example. `read.graph.benchmark()` reads saved
  benchmarks, and `register.graph.project()` records their locations. Saved
  layouts can be viewed directly; missing weighted layouts can be generated
  explicitly with grip. Displays preserve coordinate proportions by default
  and identify normalization and edge thinning.

## Improvements and bug fixes

* `graph.spectrum()` now returns a `graph_spectrum` object consistently across
  the R and native backends. `nev` counts positive eigenpairs in increasing
  order and defaults to all positive modes. Results exclude every component's
  zero mode and include component IDs, nullity and the zero-mode tolerance.
  Empty and edgeless graphs return zero-column spectra. Both backends support
  dense or sparse Laplacian output.

* Intrinsic simplex neighbor search now considers paths through intermediate
  faces, correcting distances and neighbor rankings. Rows within the accepted
  normalization tolerance are normalized exactly, and small negative roundoff
  is clamped to zero. Simplex neighbor caches now use version 4 and reject
  version 3; Euclidean caches remain at version 3. Caches validate coordinates
  and row order.

* Fixed hop-constrained route reconstruction and reverse and self queries in
  `get.shortest.path()`. Each requested hop limit is computed independently.
  `shortest.path()` now repeats rows and columns correctly for repeated query
  vertices. Minimum-spanning-tree construction preserves zero-length edges.

* `subdivide.path()` now includes both endpoints and spaces points equally
  along the polyline, skipping repeated locations. Singleton and zero-length
  paths have zero length and normalized cumulative distance, and their
  subdivisions repeat the location. Invalid paths and subdivision counts are
  rejected explicitly.

* Mutual-neighbor sequences now use the documented path-to-edge ratio directly.
  A zero threshold disables pruning; the unintended addition of one was removed.

* Fixed one-point box sampling and multiple-height embeddings to preserve
  matrix dimensions. Random-state validation accepts the additional
  binomial-generator field used by newer R runtimes.

* ANN failures now raise R errors, and native graph routines handle C++
  exceptions and release nearest-neighbor and minimum-spanning-tree resources
  safely. Unsupported OpenMP branches and compiler-warning suppression were
  removed; native graph construction remains serial. The optional IAN interface
  validates native routine registration and argument count before dispatch.

* Empty `detect.local.extrema()` summaries now retain the requested maxima or
  minima type. Legacy results without that information report `NA`.
  `compare.adj.lists()` is silent unless `verbose = TRUE`, and
  `graph.embedding(verbose = TRUE)` reports layout time. Geometry samples and
  path collections have print and summary methods.

## Documentation

* Added installed guides to the function catalog, synthetic geometry, IAN and
  Fermat distances. The catalog links to help for every export and registered
  method. Geometry examples include interactive galleries with static fallbacks.

* The Fermat surface and density/curvature vignettes include saved synthetic
  results, figures and offline links. Package builds use those bundled results
  without rerunning the numerical studies; reproduction scripts are provided
  separately. The README and package website include worked graph and geometry
  examples.

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
