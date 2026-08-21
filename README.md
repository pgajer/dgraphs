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

graph$n_edges
```

For an end-to-end introduction to graph construction, connectivity repair,
parameter sequences, conversion, and diagnostics, run:

```r
vignette("data-derived-graph-workflow", package = "dgraphs")
```
