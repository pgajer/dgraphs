# Direction and Neighborhood Sensitivity Tests

## Questions

This study asks whether reversing the endpoints changes the distribution of
final path lengths, and whether the local-network method's additional path
points make subsequent improvements too local. A single randomized run cannot
answer the first question. For each example, method, neighborhood rule, and
stopping condition, the default plan therefore contains 100 complete forward
runs and 100 complete reverse runs. A run is a complete search, not one local
replacement or one round of visits.

The primary example is the steep bowl, `z = 8(u^2 + v^2)`, over the unit disk,
with domain endpoints `(-0.45, -0.20)` and `(0.40, -0.10)`. Optional controls
are a flat square with endpoints `(0, 0)` and `(0.8, 0.4)`, and a saddle,
`z = 1.2(u^2 - v^2)`, over the unit disk with the bowl's endpoints. These are
unchanged examples from the frozen collection. Only the flat example has an
exact shortest-path answer used here. Shortening a bowl or saddle path does
not establish its distance from the true shortest path.

## Methods and Neighborhoods

Single-point refinement keeps the old route or replaces the selected section
by a direct connection or a route through one sampled point. Local-network
refinement searches connections among the sampled points and the section's
existing points; its replacement may contain several intermediate points.
Both methods start from the same 16 equal-surface-length segments, visit
interior points in a fresh random order each round, and draw 32 accepted
candidate points per visit. Duplicate coordinates are not replenished. Both
retain the existing rule requiring shortening beyond numerical uncertainty.

The **immediate-neighbor baseline** (`neighbors`) uses exactly the original
three-point rule. Its disk radius is the larger distance from the center point
to its two immediate neighbors. The instrumentation does not change its
candidate stream or decisions.

The **fixed-disk comparison** (`fixed_disk`) retains immediate neighbors as the
ends of each replacement but fixes the sampling radius before refinement starts.
The radius is the largest domain-space segment length in the shared initial
path. It is identical for both methods and both endpoint directions and never
changes as points are inserted or removed. The disk stays centered at the point
being visited and is clipped to the sampling domain. This comparison isolates
the sampling-radius rule, but does not fix the spatial extent of the section
being replaced.

The **fixed-disk and distance-based section comparison** (`fixed_span`) also
walks outward from the visited point along the current domain polygonal path
until it has covered that fixed radius on each side, or reaches an endpoint.
Those existing points delimit the replacement. This permits a section to
contain more than three points, so it is an explicit experimental extension,
not a silent revision of Appendix A. It prevents denser spacing alone from
arbitrarily shrinking the section. Discrete endpoints can overshoot the target
distance by one segment, and proximity to a path endpoint can truncate it.
Actual section lengths are recorded rather than described as exactly equal.

The fixed radius is a declared diagnostic choice, not an optimized parameter.
Differences between these settings test specific mechanisms; they cannot prove
that the chosen radius is best or eliminate every source of path dependence.
The local network still contains all of the single-point alternatives on
identical sections and identical candidates. That is a local property, not a
guarantee about the eventual results of two diverging searches.

## Stopping Conditions

Three separate comparisons distinguish round count from computational effort.
The **round-limited comparison** (`epochs`) retains the original maximum of
eight rounds and stops early after two successive rounds with relative
improvement below `1e-5`. Its protective limits are 120 seconds and 200,000
segment-length calculations. Eight rounds do not represent equal work.

The **calculation-limited comparison** (`edges`) allows 10,000 new numerical
segment-length calculations, including initialization and tighter recalculations;
cache hits do not consume this allowance. The **time-limited comparison**
(`seconds`) allows 10 seconds of search time, including preparation, Python
initialization, and progress saving, but excluding the independent path audit.
These two comparisons disable the early plateau stop and use a protective
1,000-round ceiling. Their other safeguards remain 120 seconds or 200,000
calculations respectively. These are two measures of effort, not a claim that
all numerical calculations cost the same amount of time.

All new study runs allow 1,024 MiB of sampled process-tree memory and at most
257 path points. The higher memory allowance is a declared change from the
earlier 512-MiB verification, not a reinterpretation of its failures. The audit
has a separate ten-second allowance. A five-second outer grace period allows
the worker to return its result after the search deadline; the numerical
control still prohibits new search publications after ten seconds in timed
runs. Memory is sampled, not enforced by an operating-system allocation quota.

A result enters a comparison only when the requested stopping condition was
reached, its initial and final paths passed the shared independent checks, and
the fixture checks and initial-path agreement passed. A competing memory or
time limit, an unavailable audit, or a worker error remains visible and does
not supply a length to that comparison. An independently checked retained path
can still be recorded separately. There are no automatic retries of failures.

## Randomness and Analysis

Repeat labels start at `50001`. Seeds are derived from the unchanged fixture
identity, example, endpoints, direction, and repeat label. Forward and reverse
use independent seeded streams. Matching methods and neighborhood settings use
the same repeat seed, allowing paired comparisons across those settings; their
later draws need not represent the same physical candidates once paths diverge.
Candidate locations and visit orders use separate PCG64 streams. Execution order
is deterministically shuffled to reduce systematic effects of changing machine
load. The number 100 is a starting sample size, not a guarantee of adequate
precision for every effect.

The direction table compares the two independent distributions, not pairs of
individual forward/reverse outcomes. It reports differences in means and
medians, pointwise 95% percentile bootstrap intervals from 2,000 resamples,
and the largest gap between their cumulative distributions. Positive length
differences mean forward paths are longer. The distribution table also gives
the 5th, 25th, 50th, 75th, and 95th percentiles, standard deviations, and explicit
planned, recorded, available, and stopped-run counts.

Method comparisons pair runs by example, direction, repeat, neighborhood, and
stopping condition. Positive differences mean local-network paths are longer.
The neighborhood-effect table compares this method difference under a changed
neighborhood with the same repeat's baseline difference. Negative values mean
the changed rule reduces the network-minus-single length gap. Paired bootstrap
resampling keeps each repeat's observations together. Mean and median contrasts
are differences of group means and medians, not a median of individual gaps.

All length summaries are conditional on available runs. Missing runs cannot be
silently treated as long paths, wins, or ties; incomplete coverage limits any
performance conclusion. The intervals are exploratory, without a multiple-test
correction, and an interval containing zero does not establish equivalence.
No confidence interval is produced with fewer than two available observations
per required group. A one-repeat check tests the machinery, not sensitivity.

## Running the Tests

Use the same R dependencies as the shared harness plus `reticulate` and a Python
interpreter with NumPy. Set `RETICULATE_PYTHON` to that interpreter. `testthat`
is needed for the focused checks. The package does not need to be installed:
the study reads frozen geometry and uses the shared numerical integration code.

From the repository root:

```sh
Rscript dev/shared/benchmarks/quadform_geodesics/tests/test_sensitivity.R

# Inspect the 3,600-run primary plan without performing any searches.
Rscript dev/shared/benchmarks/quadform_geodesics/run_sensitivity.R \
  --output "$HOME/.codex/private/geosmooth/quadform-geodesics/sensitivity-study" \
  --plan-only

# Execute that exact saved plan. The directory must match its source and settings.
Rscript dev/shared/benchmarks/quadform_geodesics/run_sensitivity.R \
  --output "$HOME/.codex/private/geosmooth/quadform-geodesics/sensitivity-study" \
  --resume

# A separate 36-run implementation check, not the statistical study.
Rscript dev/shared/benchmarks/quadform_geodesics/run_sensitivity.R \
  --output "$HOME/.codex/private/geosmooth/quadform-geodesics/sensitivity-check" \
  --repeats 1
```

The output parent must exist and the output must be outside the package checkout.
The default is the steep bowl. Select comma-separated examples with `--cases`
and stopping conditions with `--cohorts`; for example `--cohorts epochs` creates
a 1,200-run primary study. Adding all three examples and all conditions creates
10,800 runs. Full studies can take hours and retain substantial checkpoint data;
start with the small check and inspect its time and disk usage first.

`--resume` verifies the saved plan, source hashes, fixture identity, and recorded
environment before reusing completed records. It does not rerun recorded failures
or resume an interrupted solver. A started directory without a completed record
stops the runner for explicit review. Original attempts are never overwritten.

## Reading the Output

`plan.csv` and `manifest.json` specify every planned run, limits, source hashes,
and environment; `sources/` preserves copies of the executed code. `runs.csv`
keeps every planned row, including work not yet run. `distributions.csv` and
`direction-comparison.csv` answer the direction question. `matched-method-runs.csv`,
`method-comparison.csv`, and `neighborhood-effects.csv` answer the method and
neighborhood questions. `summary.json` gives coverage and explains difference
signs and limitations.

`rounds.csv` records each completed round's estimated path length, point count,
median sampling radius, median replaced-section length in domain coordinates,
visits, accepted changes, calculations, and time. These lengths are search
estimates, not separately audited at every round. The numbered directories
retain requests, acknowledged publications, algorithm states, resource records,
logs, and independent audits. The shared runtime and historical adapters are
unchanged, no registry entry is activated, and no C++ implementation is included.
