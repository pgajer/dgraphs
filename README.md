# dgraphs

`dgraphs` constructs and analyzes graphs derived from numerical observations.
It includes mutual and shared-neighbor graphs, intersection and geodesic
nearest-neighbor graphs, radius and adaptive-radius graphs, and
minimum-spanning-tree completion. Utilities for conversion, pruning,
diagnostics, spectral embedding, endpoints, and paths are also provided.

## Installation

Install the released package from CRAN with:

```r
install.packages("dgraphs")
```

## Example

```r
library(dgraphs)

set.seed(1)
x <- matrix(rnorm(80), ncol = 2)
graph <- create.mknn.graph(x, k = 4)

nrow(graph.edges(graph))
```

For standard graph examples, choose a type with `create.graph()`:

```r
chain <- create.graph("chain", n = 10, span = 2, labels = 101:110)
circle <- create.graph("circle", n = 20, sampling = "uniform",
                        edge.length = "chord")
graph.edges(chain)
circle$metadata$coordinates
```

Other types are `"empty"`, `"complete"`, `"cycle"`, `"complete_bipartite"`,
`"star"` and `"random"`. Type-specific arguments are documented together in
`help("create.graph")` and the function guide.

Distances, stored routes, and plotting share the graph representation:

```r
D <- graph.geodesic.distances(chain, vertices = c(1, 10))
paths <- create.path.graph(chain, h.values = c(2, 5))
get.shortest.path(paths[["h_5"]], from = 10, to = 1)
xy <- plot(chain, vertex.values = seq_len(graph.order(chain)))
plot(chain, coordinates = xy, vertex.colors = "navy")
```

For an end-to-end introduction to graph construction, connectivity repair,
parameter sequences, conversion, and diagnostics, run:

```r
vignette("data-derived-graph-workflow", package = "dgraphs")
```

## Guides

- [Finding your way around dgraphs](vignettes/function-guide.Rmd): choose an
  entry point by task and browse the complete public-function catalog.
- [Synthetic geometry and point sampling](vignettes/synthetic-geometry.Rmd):
  create reproducible curves, surfaces and compositions, then build graphs.
- [Constructing and Diagnosing Data-Derived Graphs](vignettes/data-derived-graph-workflow.Rmd):
  compare graph families, connectivity repair and geodesic diagnostics.

After installing a version containing the new guides, open the rendered
vignettes with:

```r
vignette("function-guide", package = "dgraphs")
vignette("synthetic-geometry", package = "dgraphs")
```

## Synthetic geometry (0.3.0)

Version 0.3.0 supplies reusable surfaces, curves and point samplers.
For example, construct a graph on a quadratic saddle:

```r
surface <- synthetic.quadform(2, 3, list(diag(c(1, -1))))
points <- sample.synthetic.geometry(surface,
  synthetic.sampling.uniform.disk(1), n = 100, seed = 4101)
graph <- create.mknn.graph(points$predictors, k = 6)
```

Geometry-only samples contain coordinates, geometric metadata and reproducible
random-state information. Statistical truth, responses, named recipe registries
and dataset identities remain in geosmooth. The forthcoming geosmooth release imports these geometry helpers from dgraphs. The development Geometry Lab app
is documented in `dev/apps/embedding-explorer/README.md`; it is not installed
with the R package.
