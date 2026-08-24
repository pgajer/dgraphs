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
