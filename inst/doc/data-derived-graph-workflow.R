## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.width = 6.5,
  fig.height = 5,
  warning = FALSE,
  message = FALSE
)

## ----data---------------------------------------------------------------------
library(dgraphs)

set.seed(20260820)
n <- 60L
theta <- sort(c(
  runif(40L, 0, pi),
  runif(20L, pi, 2 * pi)
))
X <- cbind(x = cos(theta), y = sin(theta)) +
  matrix(rnorm(2L * n, sd = 0.015), ncol = 2)

## ----constructors-------------------------------------------------------------
graphs <- list(
  mutual = create.mknn.graph(
    X,
    k = 5,
    connect.components = TRUE
  ),
  symmetric = create.sknn.graph(
    X,
    k = 5,
    neighbor.method = "ann",
    connect.components = TRUE
  ),
  continuous = create.cknn.graph(
    X,
    k.scale = 5,
    delta = 1.2,
    connect.components = TRUE
  ),
  adaptive.max = create.rknn.graph(
    X,
    type = "adaptive.radius",
    k.scale = 5,
    radius.rule = "max",
    connect.components = TRUE
  )
)

## ----candidate-summary--------------------------------------------------------
graph.summary <- do.call(rbind, lapply(names(graphs), function(name) {
    graph <- graphs[[name]]
    data.frame(graph = name, edges = sum(lengths(graph.adjacency(graph)))/2, raw.components = length(unique(graph.connected.components(graph))),
        final.components = length(unique(graph.connected.components(graph))), bridges = graph$metadata$n_mst_edges_added)
}))
graph.summary

## ----parameter-sequence-------------------------------------------------------
radius.sequence <- create.rknn.graphs(
  X,
  k.values = 3:6,
  radius.search = "ann",
  connect.components = TRUE
)
radius.sequence$k_statistics[, c(
  "k", "n_edges_before_pruning", "n_components_before",
  "n_mst_edges_added", "n_components_after"
)]

## ----conversion---------------------------------------------------------------
selected <- graphs$continuous
selected.igraph <- as_igraph(selected)
c(
  vertices = igraph::vcount(selected.igraph),
  edges = igraph::ecount(selected.igraph)
)

degree.pmf <- compute.graph.summary.pmf(
  selected,
  summary = "degree_distribution"
)
degree.pmf$pmf

## ----graph-figure, fig.cap="Continuous-kNN graph on the variable-density circular point cloud. Lines are graph edges and points are observations.", fig.alt="A circular point cloud with denser sampling on the upper semicircle. Gray graph edges connect nearby points around the circle."----
edge.matrix <- convert.adjacency.to.edge.matrix(graph.adjacency(selected))$edge.matrix

plot(
  X,
  asp = 1,
  pch = 19,
  col = "#1F5A94",
  xlab = "Coordinate 1",
  ylab = "Coordinate 2"
)
segments(
  X[edge.matrix[, 1], 1],
  X[edge.matrix[, 1], 2],
  X[edge.matrix[, 2], 1],
  X[edge.matrix[, 2], 2],
  col = grDevices::adjustcolor("grey35", alpha.f = 0.45)
)
points(X, pch = 19, col = "#1F5A94")

## ----geodesic-diagnostics-----------------------------------------------------
graph.distance <- graph.geodesic.distances(selected)
angle.difference <- abs(outer(theta, theta, "-"))
reference.distance <- pmin(
  angle.difference,
  2 * pi - angle.difference
)

round(isometry.geodesic.diagnostics(
  graph.distance,
  reference.distance
), 3)

