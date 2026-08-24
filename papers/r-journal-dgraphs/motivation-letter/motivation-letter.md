---
title: "Motivation letter: dgraphs"
author: "Pawel Gajer"
date: "2026-08-24"
output: pdf_document
geometry: margin=1in
---

Dear Editors,

Please consider the package article, “dgraphs: Constructing and Assessing
Data-Derived Graphs in R,” for publication in *The R Journal*.
The lowercase initial in `dgraphs` is intentional: the title retains the
package's official spelling despite the title-case diagnostic from `rjtools`.

Data-derived graphs are often created as a preliminary step in manifold,
spectral, clustering, or trajectory analyses, yet their construction and
connectivity repair are commonly hidden inside a downstream method. The
`dgraphs` package makes these decisions inspectable. It provides several
established graph families through a consistent R interface, retains native,
pruned, and connectivity-repaired lifecycle stages, and connects construction
to parameter sequences, stability summaries, geodesic diagnostics, spectral
utilities, and `igraph` interoperability.

The article's contribution is the software design and its reproducible use,
not a claim to a new graph construction. It includes an end-to-end example,
edge-set parity checks against `FNN` and `dbscan`, and a factor-specific
comparison that separates native construction and connectivity repair before
assessing final graph-geodesic fidelity. The benchmark scripts, raw results,
session metadata, and citation verification record accompany the source.

We intend to submit a separate companion package article about `grip` at the
same time. The manuscripts use a shared two-stage notation but do not duplicate
their software contributions. This `dgraphs` article covers construction of a
data-derived graph and fidelity of data dissimilarities to graph geodesics
($X\to G$, comparing $D_X$ with $D_G$). The `grip` article begins with a fixed
graph and covers layout, scoring, and refinement of its coordinate
representation ($G\to Z$, comparing $D_G$ with $D_{G,Z}$). Each package has
its own code, examples, experiments, source archive, and motivation letter.

Version 0.2.0 of `dgraphs` and the companion 0.2.0 release of `grip` will be
available on CRAN before the articles are submitted. `dgraphs` is developed
publicly at <https://github.com/pgajer/dgraphs>.
The article is original, is not under review elsewhere, and has been prepared
using the current R Journal article template and checking tools.

Sincerely,

Pawel Gajer<br>
Center for Advanced Microbiome Research and Innovation<br>
Institute for Genome Sciences<br>
University of Maryland School of Medicine<br>
pgajer@gmail.com
