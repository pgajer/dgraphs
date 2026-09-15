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
user cache keyed by the full project path and graph setting. The cache option is
`dgraphs.graph_explorer_cache_dir`; old package cache options are not consulted.

The default display preserves original coordinates with equal x/y/z data units.
Graph layout coordinates are arbitrary visualization coordinates, not physical
ambient coordinates. Optional centering with one scale factor preserves shape;
per-axis normalization explicitly warns that it distorts proportions. Above
4,000 edges, deterministic display thinning is disclosed beside the plots.
Saved metric tables always describe the full graph and remain unchanged.

## Try the installed example

Choose **Open circle demo**, or run:

```r
demo <- system.file("extdata", "graph-explorer-demo", package = "dgraphs")
benchmark <- dgraphs::read.graph.benchmark(demo)
dgraphs::explore.graphs(demo)
```

The example has twelve equally spaced unit-circle points, two symmetric
nearest-neighbor graphs (k=2 and k=4), saved GRIP layouts, and errors against
exact shorter circle arcs. Extra chords at k=4 shorten distances and increase
relative RMS error from about 1.14% to 4.13%. Layout appearance is not that
error measure. The installed demo README defines all metrics and provenance.
No fitting, registration, or write to the installed package occurs on opening.

The saved benchmark format remains readable after migration from dggraphui.
Use `project`, not the removed `run_dir` R argument. This component's license
is recorded in LICENSE and the package copyright inventory.
