\name{graph-constructor-bridges}
\alias{graph-constructor-bridges}
\alias{create.mknn.graph}
\alias{create.mknn.graphs}
\alias{create.rknn.graph}
\alias{create.sknn.graph}
\alias{create.cknn.graph}
\alias{create.radius.graph}
\alias{create.adaptive.radius.graph}
\alias{create.cmst.graph}
\alias{create.iknn.graphs}
\alias{create.single.iknn.graph}
\alias{create.iterated.iknn.graphs}
\alias{create.geodesic.iknn.graph}
\alias{create.threshold.distance.graph}
\alias{create.grid.graph}
\alias{create.path.graph}
\alias{graph.geodesic.distances}
\alias{as_igraph}
\alias{remove.knn.outliers}
\alias{wgraph.prune.long.edges}
\title{Bridge exports for data-derived graph construction}
\usage{
create.mknn.graph(...)
create.mknn.graphs(...)
create.rknn.graph(...)
create.sknn.graph(...)
create.cknn.graph(...)
create.radius.graph(...)
create.adaptive.radius.graph(...)
create.cmst.graph(...)
create.iknn.graphs(...)
create.single.iknn.graph(...)
create.iterated.iknn.graphs(...)
create.geodesic.iknn.graph(...)
create.threshold.distance.graph(...)
create.grid.graph(...)
create.path.graph(...)
graph.geodesic.distances(...)
as_igraph(...)
remove.knn.outliers(...)
wgraph.prune.long.edges(...)
}
\arguments{
\item{...}{Arguments forwarded unchanged to the corresponding \pkg{gflow}
function.}
}
\value{
The object returned by the delegated \pkg{gflow} implementation.
}
\description{
These functions are the first \pkg{dgraphs} landing surface for graph
construction APIs that currently live in \pkg{gflow}. They delegate to
\pkg{gflow} for now. The package vendors ANN under \code{inst/include/ANN} so
native kNN/radius graph code can be migrated here in smaller audited slices.
}
