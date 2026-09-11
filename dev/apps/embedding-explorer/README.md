# Geometry Lab

A local Shiny application for 3D embedding experiments on known 2D geometries.
The interface uses ivue/rgl, the same rendering stack as gflowui and the AGP
companion. The app is standalone: it does not modify those applications.

Double-click **Open Geometry Lab.command**. The default local address is
<http://127.0.0.1:8462/>. A deterministic 300-point saddle with an Isomap fit
opens as a working example. The launcher reuses an existing Geometry Lab server.
Use `GEOMETRY_LAB_PORT` to choose another port. Logs and the server PID are in
`~/.codex/private/geosmooth/geometry-lab/logs/` by default.

From R, set the working directory to this app folder and run
`shiny::runApp('.', host='127.0.0.1', port=8462)`. From a terminal, run
`Rscript /absolute/path/to/embedding-explorer/launch.R`.

## Use

1. Set truth and sampling in the left panel; press **Generate samples**.
2. Choose method, neighbors, seed and method-specific parameters. Press
   **Run embedding**. Fitting is cancellable and has a five-minute budget.
3. Choose fits A and B, rotate, zoom, or switch left drag to **Brush**. The same
   sample IDs highlight across all views. Search IDs for precise selection.
4. Turn on sample meshes, reference surface or graph edges. **Surface overlay**
   compares A and B using the same faces and optional correspondence segments.
5. In **Saved study**, read the supplied study index, filter conditions and
   select a row. **Load selected fit** reads its exact saved coordinates. Repeat
   within a cloud to compare methods and parameters. Loading another cloud
   resets the comparison history. Historical metrics are retained separately.
6. Export an RDS experiment bundle before changing clouds. Restore it later to
   recover raw coordinates, graphs, meshes, parameters and provenance. The CSV
  export includes both raw and currently displayed coordinates with IDs.

The specifications JSON summarizes large optimizer diagnostic arrays; their full
contents remain in the RDS bundle. Small metadata fields, including termination
status and objective values when returned by the method, remain in the JSON.

Colors, alignment, selections and evaluation q do not rerun embeddings. The
history holds up to 40 fits. Live generation is limited to 1,200 samples because
current distance and diagnostic calculations use dense pairwise matrices.
Closing a browser session cancels that session's active fit. Completed state is
per session and must be exported to persist across browser sessions.

## Dependencies

R: `shiny`, `bslib`, `DT`, `plotly`, `ivue`, `rgl`, `geometry`, `grip`, `igraph`,
`callr`, `jsonlite`, `digest`, `htmlwidgets`. The current workstation already
has these installed. The GRIP adapter needs `grip`, `metric.mds` and `edge.kk`
with the arguments in the current local development package (0.2.0.9001).
The renderer needs ivue's `layer3D.mesh`, `layer3D.axes`, `camera.zup`, and
`plot3D.plain`. No Internet fonts or remote rendering services are used.

UMAP uses Python `umap-learn` and NumPy, invoked in an isolated fitting process.
Set `GEOMETRY_LAB_PYTHON` to that environment's absolute Python executable. On
this workstation, the app discovers the Python recorded in the supplied study's
`main/settings.rds`. If that environment is unavailable, the other methods
remain usable and UMAP gives an actionable error. To configure another machine,
create a Python virtual environment and install `umap-learn==0.5.8` there.
The Python package versions and effective neighbor count are recorded per fit.

The study path is editable. The initial value is the supplied local study, not
a required app dependency. Private data and frozen study files are read only;
they are not copied into the repository.

## Interpretation and extension

Read [SPEC.md](SPEC.md) for metric, alignment and geometry contracts. The app
supports all six study surfaces plus a custom quadratic form, square/disk
domains, parameter-uniform and surface-area-uniform sampling, grids, a central
concentration and a deliberate gap, with optional ambient measurement noise.
PCA, Isomap, metric graph MDS, weighted GRIP and UMAP can each be followed by
edge-KK refinement, retaining the parent fit.

PCA on a noiseless 3D input is an information-preserving baseline. It is not
evidence that the more difficult graph-layout problem is solved. New-run scores
are chord, edge, correspondence and neighborhood diagnostics. The app does not
run the best-of-six approximate surface-geodesic solver or reproduce the frozen
study's full convergence qualification. A completed finite-budget fit may not
have converged; method metadata and warnings remain available.

16S triplet and general simplex-complex generators are future extensions,
documented in the spec rather than shown as nonfunctional selectors. General
simplex 2-skeletons may require an intersecting 3D projection; the projection
must not silently become the intrinsic reference geometry. Add such generators
in `R/engine.R`, preserving distinct method-input and truth-display contracts.

Run focused checks with `Rscript tests/test-engine.R` from this directory.
Run background-job and reactive-state checks with `Rscript tests/test-server.R`.
See [VALIDATION.md](VALIDATION.md) for the recorded browser and numerical checks.

## Files

- `SPEC.md`: application design and scientific contracts.
- `R/engine.R`: sampling, graph construction, embedding adapters, metrics, imports.
- `R/viewer.R`, `www/`: ivue rendering, linked selection, cameras and styling.
- `app.R`: Shiny UI, reactive state, background jobs, saved-study browser, exports.
- `scripts/umap_fit.py`: explicit-neighbor Python UMAP adapter.
- `launch.R`, `scripts/start.py`, `Open Geometry Lab.command`: local startup.
