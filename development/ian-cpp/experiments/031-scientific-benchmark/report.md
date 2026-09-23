# Do numerically valid IAN graphs improve geometry and smooth-signal recovery?

**The implementation reproduces the reference, but this small scientific panel does not show a general advantage for IAN.** On three newly sampled helix datasets, pruning leaves disconnected graph pieces. Direct smoothing with the returned affinities also performs poorly there. Smoothing with IAN graph distances is much better, but simpler methods remain competitive. These are distinct findings about the graph and its downstream use; neither is a numerical implementation failure. Independent review is pending.

## What was tested

Nine independently generated coordinate datasets contain 200 points each: three flat squares, three two-turn helices and three unit spheres. Sampling is uniform in the declared square coordinates, helix parameter or spherical area. Each geometry has an analytic intrinsic distance: straight-line distance on the square, arc length along the helix and great-circle distance on the sphere. The [prospective plan](../../stages/05-scientific-benchmark/PLAN.md) fixes all seeds, formulas, methods, tuning grids and limits before execution.

Native C++ and the evaluated-LP Python reference each run once on every dataset, with the accepted retry-power policy and unchanged tolerances. Both receive identical coordinates and Euclidean distances. Simulated outcomes, true intrinsic distances and known mean functions are stored separately and never enter IAN graph construction.

For geometry, compare the initial Gabriel graph, final IAN graph and symmetric graphs connecting each point to its 5, 10 or 20 nearest Euclidean neighbors. The 10-neighbor graph is the predeclared primary simpler comparator; the others are sensitivity comparisons. Every edge carries its Euclidean length. Shortest-path distances are compared with the known intrinsic distances. The reported distance loss is absolute relative error capped at 1, with disconnected pairs assigned loss 1; smaller is better. Connectivity and recovery of the ten true nearest neighbors are reported separately, so good local neighborhoods cannot hide missing global paths.

For signal recovery, each coordinate dataset receives ten independent response-and-split replicates. The expected response is a prescribed smooth function of location; independent Gaussian noise has standard deviation 0.2. Fifty observations train the smoother, fifty tune it and one hundred evaluate it. All methods may see every coordinate, including evaluation coordinates, but never evaluation outcomes. This is **transductive** evaluation on a fixed set of points, not prediction for a newly arriving point.

The six estimators are a training mean, an unweighted nearest-labeled-neighbor average, a Euclidean Gaussian kernel, a Gaussian kernel on IAN shortest-path distances, powers of the returned IAN affinities and an oracle kernel using true intrinsic distances. Every nonconstant estimator gets exactly five predeclared candidates, selected only by noisy tuning-outcome error. Equal grid sizes do not establish universally optimal or equally flexible tuning. The oracle uses privileged geometry and is a reference, not a deployable method. Final error is measured against the known expected response before noise is added. Zero total training weight triggers the same training-mean fallback for all weighted methods, and every fallback is counted.

## Geometry: local accuracy can coexist with disconnection

Values below average the three independent coordinate datasets. The distance loss runs from 0, best, to 1, worst. Every IAN and 10-neighbor graph is connected on the square and sphere examples.

| Geometry | Gabriel distance loss | IAN distance loss | 10-neighbor distance loss | IAN connected-pair fraction |
| --- | --- | --- | --- | --- |
| Flat square | 0.136 | 0.150 | 0.057 | 100% |
| Two-turn helix | 0.318 | 0.625 | 0.006 | 37.5% |
| Unit sphere | 0.115 | 0.121 | 0.040 | 100% |

All three initial helix graphs are connected; their final IAN graphs have 6, 3 and 3 components. Only 28.8–43.8% of point pairs retain a path. Within connected pieces, mean relative distance error is very small, 0.00052–0.00078. That local success does not recover distances between pieces. IAN still retrieves 96.5% of the ten true nearest helix neighbors on average, illustrating why neighborhood recall alone would miss this limitation.

The predeclared 10-neighbor graphs remain connected and recover the helix distances well here. Five neighbors can also disconnect the helix, while twenty can create shortcuts, so the result is not “more neighbors is always better.” On the square and sphere, the 20-neighbor sensitivity graphs have the smallest tested distance losses. This panel does not establish a universal neighbor count.

![Geometry and known-mean recovery on nine independent coordinate datasets](build/benchmark.png)

**Figure 1.** Upper panels show the bounded intrinsic-distance loss; lower panels show squared error against the known conditional mean, on a logarithmic scale. Lower is better in both rows. Each dot is one independently sampled coordinate dataset; lower-panel dots first average its ten response/split replicates. Short bars average the three datasets, not confidence intervals. Blue marks IAN-based methods; the oracle uses unavailable-in-practice true geometry. In the lower labels, “Euclidean” and “IAN paths” denote Gaussian-kernel smoothers, and “k-neighbor” averages nearby labeled responses. The complete figure also shows both predeclared neighbor-count sensitivities.

## Signal recovery depends on how the graph is used

Mean squared errors below average ten held-out replicates within each coordinate dataset, then average the three datasets. Units are squared response units. Smaller means closer recovery of the prescribed expected response, not closer fitting of noisy observations.

| Estimator | Flat square | Helix | Sphere |
| --- | --- | --- | --- |
| Training mean | 0.2559 | 0.4296 | 0.3645 |
| Euclidean nearest labeled neighbors | 0.0489 | 0.0219 | 0.0339 |
| Euclidean Gaussian kernel | 0.0433 | 0.0156 | 0.0284 |
| IAN graph-distance kernel | 0.0439 | 0.0205 | 0.0283 |
| IAN affinity smoother | 0.0462 | 0.1318 | 0.0342 |
| Oracle intrinsic-distance kernel | 0.0433 | 0.0133 | 0.0272 |

All tested smoothers improve on the constant training mean, but IAN does not consistently beat the simpler alternatives. The IAN graph-distance smoother is close to the Euclidean kernel on the square and sphere. Its helix error varies from 0.0126 to 0.0312 across the three datasets; it beats the nearest-labeled-neighbor method on two datasets and loses on one. The average alone should not be read as a stable superiority claim.

Direct affinity smoothing is markedly worse on every helix dataset. In 24.0% of its evaluation predictions there is no positive affinity to a training point, so it falls back to the training mean. The corresponding graph-distance-kernel fallback rate is 0.9%. This exposes a support limitation for this particular sparse-affinity consumer. It does not establish that every possible IAN-based estimator fails, nor quantify how much of the error comes from fallback versus other smoothing choices. The estimators are explicit consumers constructed for this benchmark, not part of IAN's graph algorithm.

## Checks, limitations and consequence

All **18 engine entries and 572 physical solver attempts** are accounted for. All nine paired trajectories complete, with identical LP coefficients and exactly matching primal and dual vectors; graph decisions and final outputs pass the unchanged comparison checks. All 572 saved payloads pass their applicable numerical/eligibility checks: 448 accepted returns and 124 rejected returns followed by successful retries. All 286 native settings snapshots match the accepted policy. No process or numerical refusal occurred; numerical children used 16.1 seconds in total, with a maximum process peak of 121.0 MiB. These costs are accounting evidence, not a new performance benchmark.

The declared coordinate, noise and split streams reconstruct exactly. Independent scalar formulas verify Euclidean and intrinsic distances within 1e-12 and known means within 1e-14. Arithmetic controls cover path and disconnected-graph losses, constant-response preservation, zero-weight fallback and invariance of tuning/predictions to changes in evaluation outcomes. All methods use the same splits and noise; outcome information remains outside graph construction. The [saved summary](figure-data.json) and [complete analysis](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage05-science/analysis-v1/summary.json) retain dataset-level ranges and paired differences. No vertex-level significance tests or population confidence intervals are asserted.

Three coordinate samples per geometry, one size, one signal function per geometry, one noise level and fixed tuning grids are narrow evidence. The examples cover intrinsic dimensions one and two, not the higher-dimensional quadforms previously used for engineering qualification. The observation hooks, known Python-library warnings and single-Mac numerical scope remain as documented. No R/grip embedding function is called in this study. These independent synthetic observations do not model repeated participants, assays, biological composition or real cohort sampling.

The justified next research step is to explain which pruning decisions disconnect these helices and whether a separately named connectivity-preserving alternative improves the declared task without merely adding shortcuts. That would be a new method study, keeping the faithful reference implementation unchanged. It is not an automatic patch or public-export decision. Biological application still needs its population, assay, visit, transformation and participant contracts. This bounded study can complete with a negative result while broad scientific usefulness remains unestablished.

## Reproduction

The [source scripts](../../stages/05-scientific-benchmark/prepare.py), [frozen fixture manifest](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage05-science/manifest.json), [process ledger](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage05-science/ledger.json), [final vector/settings census](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage05-science/final-checks.json) and [analysis script](../../stages/05-scientific-benchmark/analyze.py) bind the exact conditions. Saved replicate records contain every split, noise vector, candidate tuning loss, selected parameter, prediction and fallback count. The [Stage-4 audit](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/auditor/review-stage04-performance/audit.md) establishes the preceding engineering gate; it does not independently validate this new scientific interpretation.
