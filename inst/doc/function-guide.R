## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 6, fig.height = 4)

## ----first-graph--------------------------------------------------------------
library(dgraphs)
points <- sample.synthetic.geometry(
  synthetic.circle(),
  synthetic.sampling.grid.interval(0, 2 * pi, endpoints = "exclude.lower"),
  n = 24, seed = 17
)
X <- points$predictors
graph <- create.sknn.graph(X, k = 2, connect.components = TRUE)
print(graph)
length(unique(graph.connected.components(graph)))
D <- graph.geodesic.distances(graph)
round(D[1:4, 1:4], 3)
ig <- as_igraph(graph)
c(vertices = igraph::vcount(ig), edges = igraph::ecount(ig))

## ----standard-graphs----------------------------------------------------------
standard <- list(
  empty = create.graph("empty", n = 5),
  complete = create.graph("complete", n = 5),
  chain = create.graph("chain", n = 5, span = 2, labels = 101:105),
  cycle = create.graph("cycle", n = 5),
  complete_bipartite = create.graph("complete_bipartite", sizes = c(2, 3)),
  star = create.graph("star", arms = c(1, 2, 1)),
  random = create.graph("random", n = 5, mean.degree = 2, seed = 23),
  circle = create.graph("circle", n = 5, sampling = "uniform",
                        edge.length = "chord")
)
knitr::kable(data.frame(
  type = names(standard),
  vertices = vapply(standard, graph.order, integer(1)),
  edges = vapply(standard, function(g) nrow(graph.edges(g)), integer(1)),
  stored.lengths = vapply(standard, function(g) !is.null(graph.lengths(g)), logical(1))
), row.names = FALSE)

## ----intersection-convention--------------------------------------------------
X.line <- matrix(c(0, 1, 3, 6), ncol = 1)
initial <- create.single.iknn.graph(X.line, k = 1, prune.method = "none",
                                  connect.components = FALSE, verbose = FALSE)
rebuilt <- create.geodesic.iknn.graph(initial, k = 1)
rebuilt$metadata$neighborhood

## ----distance-inputs----------------------------------------------------------
line.points <- matrix(c(0, 0, 1, 10, 11), ncol = 1)
D.tree <- graph.geodesic.distances(points = line.points, graph.type = "mst")
D.neighbors <- graph.geodesic.distances(points = line.points,
                                       graph.type = "sknn", k = 1)
knitr::kable(data.frame(
  pair = c("Coincident observations", "First to last observation"),
  tree.distance = c(D.tree[1, 2], D.tree[1, 5]),
  symmetric.neighbor.distance = c(D.neighbors[1, 2], D.neighbors[1, 5])
), row.names = FALSE, col.names = c("Pair", "Tree distance", "Symmetric kNN distance"))

## ----constrained-paths--------------------------------------------------------
weighted.graph <- dgraph(
  list(c(2L, 3L), c(1L, 3L, 4L), c(1L, 2L), 2L),
  list(c(5, 1), c(5, 1, 1), c(1, 1), 1))
paths <- create.path.graph(weighted.graph, h.values = c(2, 3))
knitr::kable(compare.paths(paths, from = 1, to = 4)[,
  c("h", "path_exists", "path_length", "n_hops")], row.names = FALSE,
  col.names = c("Hop limit", "Route exists", "Route length", "Hops used"))
get.shortest.path(paths[["h_2"]], from = 1, to = 4)
get.shortest.path(paths[["h_3"]], from = 4, to = 1)

## ----coordinate-path----------------------------------------------------------
polyline <- rbind(c(0, 0), c(1, 0), c(1, 2))
path.length(polyline) # 3
subdivide.path(polyline, n.subdivision.pts = 5)
path.dist(1:3, polyline) # normalized cumulative distances: 0, 1/3, 1

## ----positive-spectrum--------------------------------------------------------
chain <- create.graph("chain", n = 8)
spectrum <- graph.spectrum(chain, nev = 3)
round(spectrum$evalues, 6)
spectrum$nullity
coordinates <- graph.spectral.embedding(spectrum, dim = 2)
dim(coordinates)

## ----graph-layout, fig.width=6, fig.height=4, fig.alt="Graph layout with vertex colors defined by the example; the same coordinates are reused for comparison."----
cycle <- create.graph("cycle", n = 8)
set.seed(4101)
xy <- plot(cycle, vertex.values = seq_len(8), main = "Numeric vertex values")

## ----graph-layout-reuse, fig.width=6, fig.height=4, fig.alt="Graph layout with vertex colors defined by the example; the same coordinates are reused for comparison."----
plot(cycle, coordinates = xy, vertex.values = rep(7, 8),
     main = "Same layout, constant values")

## ----graph-projection, fig.width=6, fig.height=4, fig.alt="Graph layout with vertex colors defined by the example; the same coordinates are reused for comparison."----
set.seed(4102)
xyz <- graph.embedding(cycle, dim = 3)
colnames(xyz) <- c("x", "y", "z")
plot(cycle, coordinates = xyz, projection = c(1, 3), vertex.colors = "navy",
     main = "Explicit x/z projection")

## ----explorer-demo------------------------------------------------------------
demo <- system.file("extdata", "graph-explorer-demo", package = "dgraphs")
benchmark <- read.graph.benchmark(demo)
nrow(benchmark$graph_assets)

## ----explorer-launch, eval=FALSE----------------------------------------------
# explore.graphs(demo)

## ----help, eval=FALSE---------------------------------------------------------
# help(package = "dgraphs")
# help("dgraphs-package", package = "dgraphs")
# vignette(package = "dgraphs")

## ----offline-reference, echo=FALSE, results='asis'----------------------------
source(system.file("doc-tools", "reference.R", package = "dgraphs"), local = TRUE)
render_dgraphs_reference()

