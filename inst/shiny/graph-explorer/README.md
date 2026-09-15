# Graph Reconstruction Explorer

Launch from R with `dgraphs::explore.graphs()`. Choose a remembered project,
or enter an existing benchmark run directory and press **Open**. Use
**Remember as** and **Remember Project** to add it to the project picker.

A run can also be opened with `dgraphs::explore.graphs(project = path)`;
`path` may identify its directory or `quadform_benchmark_manifest.rds/json`.
Use `dgraphs::register.graph.project(path, name = "My study")` to remember it
from R, then `dgraphs::explore.graphs(project = "My study")` to reopen it.

## Saved data

Scientific data remain outside the package. The original dggraphui run format
is retained: quadform benchmark manifests, dataset_manifest.csv, metrics.csv,
dataset_assets.csv, graph_assets.csv, layout_assets.csv and
graph_diagnostics.csv. Relative asset paths resolve against the run directory;
absolute asset paths remain valid while those files remain at their locations.
Moving a run that contains absolute references requires updating those paths.

The project catalog contains only names and locations. Reading a project does
not refit or change benchmark results. The explicit **Generate Weighted Layout**
action computes a missing layout through grip and writes it to a separate
user cache. Legacy dggraphui cache entries are accepted only when they identify
the same graph. Unverified old cache files remain untouched.

The default 3D display preserves dggraphui's per-axis normalization. Compare
saved metric values for quantitative distances; displayed axis scales are not
original physical distances. A parameter scan and the selected graph's metrics
and diagnostics remain available in their own tabs.

## Migration

The app source and tests moved from dggraphui to dgraphs on 2026-09-15.
The old package now supplies compatibility wrappers for its three exported
functions. Existing data paths and scientific files were retained.
This component retains its original GPL (>= 3) license; see LICENSE.
