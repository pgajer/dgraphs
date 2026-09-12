# Validation — 11 September 2026

The application was tested on the current workstation with R development
version r90190, Shiny 1.14.0, igraph 2.3.3, plotly 4.12.1, and the installed
ivue/GRIP development packages. UMAP used the supplied study's Python
environment (umap-learn 0.5.8). No historical experiment was rerun or modified.

## Numerical and data checks

`tests/test-engine.R` passed nine test groups (424 assertions). These cover:

- All seven quadratic presets, both domains and all five sampling methods,
  with exactly the requested sample counts and correct analytic coordinates.
- Deterministic seeds, noise separated from noiseless truth, and the expected
  outward shift when sampling a steep bowl uniformly by surface area.
- Translation/rotation/reflection/scale recovery; zero reconstruction errors
  and unit neighborhood scores for an equivalent configuration; degraded
  neighborhood scores for permuted sample correspondence.
- Exact neighbor identities and edge weights, explicit disconnected-graph
  refusal, and finite three-column coordinates from PCA, Isomap, metric MDS,
  weighted GRIP and each corresponding edge-KK refinement.
- All four UMAP initializations, the explicit `k + 1` neighbor convention,
  and bitwise identical coordinates from repeated seeded spectral UMAP runs.
- Bundle round-trip and rejection of mismatched IDs, invalid face indices,
  nonfinite fit coordinates and duplicate sample IDs.
- Exact identity of an imported historical coordinate matrix and its recorded
  scores, checked directly against the saved RDS file and source checksum.

These checks establish implementation behavior on small examples, not the
scientific superiority or convergence of any embedding method.

## Shiny lifecycle and rendering

`tests/test-server.R` passed its lifecycle test (15 assertions): a background
PCA fit completes, appearance and evaluation-q changes preserve experiment
state, an invalid UMAP run reports failure without replacing completed fits,
and cancellation retains that same completed state. Restoring a bundle after
generating a different cloud recovers the original cloud and completed fits.

`tests/test-viewer.R` passed six assertions exercising headless ivue construction with all layers,
graph routes, no selected points, and every point selected. It also verifies
that incomplete route endpoints produce no route rather than an error.

Two development defects were found and fixed during browser testing: a custom
Shiny message handler had an unsupported function signature, and a background
process handle initially did not persist in the session's polling scope. The
current browser launch and lifecycle tests include the corrected code.

## Browser and export checks

Verified in the Codex in-app browser at the default 1280 × 720 viewport:

- Initial 300-point saddle and Isomap scenes render; sampling can replace the
  cloud and reset its history.
- UMAP-specific initialization and optimization controls appear; a live
  300-point UMAP run with 60-step edge-KK completes and retains both results.
- Zooming one view changes all three magnification readouts together. Brushing
  a region selected 45 IDs, with all three scene widgets reporting those same
  45 selected samples. Selection persists through recoloring and appears in
  the combined overlay.
- The study index reads 34,020 attempts and 84 clouds. Filtering to a square
  saddle with 240 samples, sampling seed 4102 and graph k = 8 identifies saved
  metric MDS and its profiled 60-step edge-KK counterpart. Both load into the
  same cloud and display distinct live diagnostics.
- The S4.3-style overlay renders both carried sample meshes, the full-domain
  analytic surface and correspondence segments. Graphs and display meshes
  remain separate objects.
- RDS, coordinate CSV and specification JSON downloads return HTTP 200.
  Downloaded RDS validation passes; CSV sample IDs match it exactly, and raw
  fit-A coordinates agree within CSV serialization precision (1e-12). The
  exported cloud specification identifies the actual imported 240-point cloud.
- Large optimizer arrays are summarized in the JSON/provenance display while
  remaining intact in the RDS; termination metadata is preserved.

The initial browser errors listed above occurred before their fixes; subsequent
browser interactions produced no new console errors. Browser screenshots were
inspected directly. Mobile breakpoints have CSS support but were not separately
validated on a mobile browser. The browser automation's file-chooser event timed
out, so restoration was verified through the Shiny server test rather than a
completed browser upload. The renderer test initially asserted the wrong widget
class name (`rglwidget` instead of the returned `rglWebGL`); correcting that test
produced the passing renderer result without changing the working renderer.

## Boundaries

Live generation is capped at 1,200 samples and each session permits one fitting
job with a five-minute budget. Dense distance matrices limit larger examples.
The tests do not qualify every extreme slider setting or a full factorial
method sweep. A fit that exhausts its optimization budget is not automatically
converged. Transparent intersecting meshes can obscure one another; use the
separate views and correspondence diagnostics alongside the overlay.

The first release implements flat/quadratic truth surfaces. The 16S and general
simplex-complex adapters are specified future work. Live diagnostics do not
compute the best-of-six surface-geodesic reference solver; imported historical
scores retain that study's separate definitions and calibration.

Run from the app folder:

```sh
Rscript tests/test-engine.R
Rscript tests/test-server.R
Rscript tests/test-viewer.R
```

Local development logs and downloaded verification files are under
`~/.codex/private/geosmooth/geometry-lab/`; private study assets are not vendored
into this repository.
