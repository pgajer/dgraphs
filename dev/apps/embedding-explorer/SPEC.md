# Geometry Lab: 3D embedding explorer

## Purpose

Compare how embedding methods recover a known geometry, using exactly the same
sample identities across truth, fitted coordinates, graphs, and diagnostics.
The initial application runs locally in Shiny with the ivue/rgl rendering stack
used by gflowui and the AGP / dCST companion. It is an independent development
application, not a change to either package's public API.

## Workflow and interface

The left panel follows the experiment's causal order:

1. Choose the truth: flat square, isotropic/anisotropic bowls and saddles, or a
   custom quadratic form `z = a*u^2 + 2*b*u*v + c*v^2`. Choose square or disk
   domain and its extent. Presets match the six surfaces in the supplied study.
2. Choose sampling: uniform in parameter coordinates, uniform in surface area,
   regular grid, concentrated center, or a gap in parameter space. Choose sample
   count, sampling seed and ambient Gaussian measurement noise. Truth and noisy
   observations remain separate; noise does not alter the generating surface.
3. Generate the sample once. Changing fit parameters reuses it. Controls remain
   draft specifications until explicitly applied.
4. Choose a 3D embedding and its parameters. Initial methods: PCA, classical MDS
   of graph shortest paths (Isomap), metric MDS of those paths, weighted GRIP,
   and UMAP. Metric MDS and GRIP expose their starting/budget choices; UMAP
   exposes spectral, random, PCA and graph-MDS initialization, neighbors,
   min_dist, spread, learning rate, repulsion, negative sampling and epochs.
   Optional edge-KK refinement retains both parent and refined fits.
5. Run in a separate, cancellable R process. Capture errors and warnings,
   seed, parameters, input fingerprint, timings and dependency versions.
   Never fabricate a replacement result when a method fails.

The main workspace has three equal-aspect, orthographic 3D views: sampled truth,
fit A, and fit B. They share point colors and brushed sample IDs, with optional
linked rotation/zoom. View controls include point size, axes, generating
surface opacity, correspondence-preserving sample mesh, graph edges, route
endpoints, and similarity/rigid/raw display coordinates. A separate overlay
view combines A and B, the generating surface, and a systematic subset of
corresponding-vertex segments, following Supplement S4.3.

Below the views are fit history, diagnostics, selected samples, exports and
provenance. A saved-study tab filters cloud/surface/domain/sample count, graph
neighbors, method and seed from `main/outputs/layouts.csv`, and loads the exact
RDS coordinates into comparison history. Browsing or recoloring never reruns a
historical experiment. A parameter plot and filtered CSV expose study sweeps.

## Scientific contracts

- Identity is immutable within a cloud. Fits from different clouds cannot share
  comparison slots; loading a new cloud explicitly resets the current history.
- Nearest-neighbor graphs are the union of directed k-neighbor edges with
  observed Euclidean edge lengths. Here k counts **other** points. UMAP receives
  these exact neighbors plus self (`n_neighbors = k + 1`) for consistency with
  the supplied study. Its backend/version is recorded; it is not claimed to
  reproduce the frozen study's complete parameter configuration.
- Disconnected graphs are diagnosed. Methods needing a global path metric
  refuse them. PCA and UMAP can display them with an explicit warning.
- Similarity alignment uses translation, rotation/reflection and one uniform
  scale fitted to corresponding noiseless truth points. Rigid alignment omits
  the scale. Neither transform replaces saved raw coordinates or scores.
- Triangulate once in the original parameter plane and carry those same faces
  into every fit. Clip visualization triangles crossing deliberately sampled
  gaps. This mesh is not the neighbor graph. The dense analytic surface uses
  the entire configured domain and does not define a surface-distance score.
- New-run metrics: similarity correspondence normalized RMSE against noiseless
  truth; ambient chord normalized RMSE and graph-edge normalized RMSE after a
  single least-squares distance scale; trustworthiness, continuity and exact
  neighbor recall against observed-space Euclidean neighbors. Evaluation q is
  separate from graph k. Zero error and unit neighborhood scores are ideal.
  Raw, unscaled graph-distance stress is also retained where available.
- Historical scores are displayed separately with their original names and
  definitions. Approximate surface-geodesic errors are never relabeled as
  exact intrinsic truth. New live diagnostics do not recreate the study's
  best-of-six geodesic solver or its convergence qualification.
- Failed/cancelled runs leave completed fits intact. Synchronous rendering is
  bounded by a 1,200-sample live limit; one background job per session and a
  finite time budget keep the local app usable. History is bounded; exports
  preserve the selected experiment before replacement.

## Persistence and extensibility

An experiment bundle is a versioned list with the generating specification,
sample IDs, parameter coordinates, noiseless truth, observed input, fixed
triangles, analytic surface mesh, and fits. Each fit retains raw coordinates,
the actual graph, method arguments, diagnostics, warnings and provenance.
Export/import RDS round-trips that contract; CSV exports retain sample IDs.
Inputs are validated on import, including dimensions and face/edge indices.
Import only trusted local RDS files. Downloads are initiated by the user.

Truth generators and embedding adapters live outside the Shiny server. A
generator returns ambient method input separately from its known 3D truth
display, sample IDs, optional parameterization, surface triangles and metric
description. The first release implements analytic quadratic surfaces. Future
16S adapters can normalize selected phylotype triplets onto triangular faces,
or retain a fourth remainder component on the boundary of a tetrahedron.
Such projections must retain the original abundance data and document which
metric is being evaluated. General simplex 2-skeletons need an explicit 3D
realization/projection with possible intersections: not every such complex
embeds faithfully in 3D. Do not describe a projection as known intrinsic truth.
No fabricated biological dataset is bundled with this release.

## Acceptance checks

Check deterministic sampling, exact flat-surface reconstruction, alignment
invariance, known neighborhood-score limits, graph disconnection, all available
embedding adapters and refinement, bundle validation/round-trip, historical
coordinate identity, reactive isolation and failed-job preservation. Launch a
real browser to verify initial rendering, sample generation, background fits,
comparison changes, overlays, brushing, zoom and saved-study loading. Record
what was tested and any limitations in `VALIDATION.md`.

## References inspected

- Supplied best-of-six report, frozen runner, parameter notes and saved RDS/CSV
  assets under `~/.codex/private/geosmooth/quadform-geodesics/best-of-six-embedding-20260911`.
- AGP companion's `app.R`, helpers and camera/brush JavaScript under
  `~/.codex/linf/agp-explorer-20260910`.
- Local gflowui and ivue source, including mesh and surface layers.
- [Supplement S4](https://pgajer.github.io/grip/supplements/S4-interactive-saddle.html),
  inspected through its local R Markdown source in `grip_manuscripts` after the
  web tool could not retrieve the public page.
