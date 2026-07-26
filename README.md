# dgraphs

`dgraphs` constructs and analyzes graphs derived from numerical observations.
It includes mutual and shared-neighbor graphs, intersection and geodesic
nearest-neighbor graphs, radius and adaptive-radius graphs, and
minimum-spanning-tree completion. Utilities for conversion, pruning,
diagnostics, spectral embedding, endpoints, and paths are also provided.

## Installation

Once the package is available from CRAN, install it with:

```r
install.packages("dgraphs")
```

## Example

```r
library(dgraphs)

set.seed(1)
x <- matrix(rnorm(80), ncol = 2)
graph <- create.mknn.graph(x, k = 4)

length(graph$adjacency.list)
```
