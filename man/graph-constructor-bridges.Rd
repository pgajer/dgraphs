\name{graph-constructor-bridges}
\alias{graph-constructor-bridges}
\alias{create.iknn.graphs}
\alias{create.single.iknn.graph}
\alias{create.iterated.iknn.graphs}
\alias{create.geodesic.iknn.graph}
\alias{create.threshold.distance.graph}
\alias{as_igraph}
\alias{remove.knn.outliers}
\title{Bridge exports for data-derived graph construction}
\usage{
create.iknn.graphs(...)
create.single.iknn.graph(...)
create.iterated.iknn.graphs(...)
create.geodesic.iknn.graph(...)
create.threshold.distance.graph(...)
as_igraph(...)
remove.knn.outliers(...)
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
\pkg{gflow} for graph-construction families that have not yet been migrated.
ANN-backed MkNN, radius-family, SkNN, and CMST constructors are now local to
\pkg{dgraphs}; intersection and geodesic kNN bridge functions remain for a
later migration phase.
}
