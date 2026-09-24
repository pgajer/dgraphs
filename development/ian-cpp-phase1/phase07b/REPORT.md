# Phase07B: why the helix was rejected, and what a repair would need to preserve

The shared helix failure is explained by different numerical stopping requirements.
Clarabel's global feasibility measure passes while IAN's individual-constraint
measure fails. The replayed baseline exactly reproduces the rejected vectors.
Tighter diagnostic settings produce solutions that pass the original IAN checks,
but they also change some already accepted control vectors beyond the old
comparison limits. A repair candidate is available; no replacement policy has
been adopted and no larger IAN run is authorized by these results.

The bounded diagnosis is complete: 33 prescribed fixed-problem solves, with all
five baseline reproductions exact in primal vectors, dual vectors, objective and
iteration count. Independent acceptance of Phase07B remains pending. Phase07 is
already independently accepted; its original refusals and closed 1,000-profile
gate remain unchanged.

## What was tested

The [frozen plan](PLAN.md) selected four evaluated linear programs from accepted
Phase07 evidence: the first solve of the small 120-profile helix; the passing
first solve and rejected second solve of the 500-profile helix; and the saved
PreSSMat solve with the largest normalized constraint violation among its accepted
solutions. The last rule selects solve number 150, using zero-based numbering,
and is deliberately a stress selection, not a random sample.

The fifth case is the historical-expression helix's first problem. The frozen
adapter was intercepted before constructing a solver, saving its actual 501-variable,
2,737-row canonical problem with one three-dimensional second-order cone. Its
projection agrees with the saved 500-variable, 2,734-row LP within the existing
coefficient limits. This capture performs zero solves; its intentional exception
and partial initialization files are retained. The historical cone was not
discarded and mislabeled as a replay of the projected LP.

All replays use the pinned Python Clarabel 0.11.1 binding directly, with fresh
solvers, one thread, QDLDL, max_iter=300 and the accepted options as baseline.
The evaluated matrices bypass CVXPY; the historical matrices come from the
frozen original expression. This isolates solver behavior on fixed problems.
There are no native rebuilds, new native executions or complete IAN trajectories.
Phase07 already established identical rejected native/evaluated vectors; direct
replay reproduces them without changing the outer graph algorithm.

Each evaluated case has seven conditions: baseline; feasibility tolerance alone
at 1e-11; absolute and relative gap tolerances alone at 1e-11; all three at 1e-11;
all three at 1e-12; equilibration disabled; and row normalization. The last divides
each inequality by max(1, absolute right-hand side, largest absolute row coefficient)
and maps duals back before checking the original LP. Historical canonical tests
use the first five conditions only. Every condition and input was fixed before
replay; no extra settings were searched after seeing the outcomes.

## The measured cause of the shared evaluated failure

For the represented LP, write the constraints as A x <= b. Clarabel introduces a
nonnegative slack vector s and measures the error in A x + s = b. Slack is the
unused margin in an inequality. The pinned 0.11.1 source calculates:

```
solver primal residual = ||A x + s - b||_2 /
                         max(1, ||b||_infinity + ||x||_2 + ||s||_2)
```

IAN instead requires every row's positive violation to be small relative to that
row's own magnitudes:

```
IAN row residual = max(A_i x - b_i, 0) /
                   max(1, |b_i|, sum_j |A_ij| |x_j|)
IAN requires max_i(row residual) <= 1e-7.
```

These use different numerators as well as different denominators. The versioned
[solver implementation](https://github.com/oxfordcontrol/Clarabel.rs/blob/v0.11.1/src/solver/implementations/default/info.rs)
defines its global residual and termination conditions. The pinned local sources,
including the vector norm and cached data norm implementations, are hashed in the
fixture manifest; live documentation defaults are not substituted for the actual
settings. The [official settings reference](https://clarabel.org/stable/api_settings/)
describes feasibility, gap and equilibration controls.

For the rejected evaluated helix solve at C=0.525:

| Measure | Numerator | Denominator | Result | Required maximum |
|---|---:|---:|---:|---:|
| Solver's global primal residual | 3.70313e-4 | 969,794.19 | 3.81847e-10 | 1e-9 |
| IAN's worst normalized row | 1.03063e-6 | 3.834615 | 2.68771e-7 | 1e-7 |

The solver's denominator is dominated by the slack-vector norm, 948,667.42.
The second family of edge inequalities contributes 99.9146% of the sum of
squared slacks. Several have slack exceeding 100,000. Such large unused margins
elsewhere in the LP make the global normalization permissive relative to a
constraint whose relevant magnitude is only about 3.83. Clarabel also passes its
dual and gap tests at that iteration. Its optimal status is consistent with its
documented implementation; it does not certify IAN's different row requirement.

This is reconstructed from returned vectors, not inferred from the status label.
For this case, the rebuilt global primal residual differs from reported telemetry
by only 1.20e-17. Across all 33 conditions, maximum absolute discrepancy in rebuilt
primal/dual residuals is 8.60e-16. Scalar compensated sums and 80-digit Decimal
evaluation agree that the offending row exceeds 1e-7. The Decimal calculation
uses the exact binary64 inputs, avoiding an explanation based on a misleading
matrix-product warning.

The represented LP is not infeasible. Setting scales equal to the saved upper
bounds provides a feasible point: exact rational arithmetic on every binary64
coefficient proves all inequalities for all five original LPs. This witness is
a feasibility proof for those represented matrices, not an optimal solution or
a proof about arbitrary IAN inputs.

## Diagnostic changes and their limits

The table gives the worst original-LP normalized constraint violation. Every
reported pass also satisfies finite-value, active-scale, objective and dual
certificate requirements. The unchanged external allowance is 1e-7.

| Fixed problem | Baseline | Feasibility only 1e-11 | Gap only 1e-11 | All three 1e-11 | All three 1e-12 | No equilibration | Row normalization |
|---|---:|---:|---:|---:|---:|---:|---:|
| Small helix, first solve | 7.34e-10 | 7.33e-12 | 7.33e-12 | 7.33e-12 | 7.33e-12 | 4.78e-9 | 8.97e-9 |
| 500-profile helix, passing predecessor | 3.87e-8 | 3.94e-10 | 3.94e-10 | 3.94e-10 | 5.09e-12 | 0 | **2.12e-7, fail** |
| 500-profile helix, rejected solve | **2.69e-7, fail** | 3.19e-9 | 3.19e-9 | 3.19e-9 | 3.10e-11 | 0 | **1.42e-7, fail** |
| PreSSMat stress control | 1.12e-8 | 1.12e-10 | 1.12e-10 | 1.12e-10 | 1.11e-12 | 4.13e-10 | 3.90e-10 |
| Historical-expression helix, first solve | **1.58e-7, fail** | 7.37e-10 | 7.37e-10 | 7.37e-10 | 7.37e-10 | Not prescribed | Not prescribed |

All 33 solver statuses are Solved. Twenty-nine returned payloads satisfy the
external checks; the four refusals remain explicit. These are purposively selected
fixed problems and conditions, not an empirical population success rate.

For the shared rejected LP, baseline stops after 14 iterations. The three 1e-11
conditions take 15 iterations and return exactly the same primal, dual and slack
vectors, reducing the row error to 3.1880e-9. The 1e-12 condition takes 16 iterations
and reaches 3.0979e-11. Either a tighter feasibility test or a tighter gap test
forces additional progress here; this experiment does not identify one as uniquely
responsible. The three 1e-11 conditions also return identical vectors within each
of the other four cases.

Turning off equilibration solves the rejected LP in 24 iterations, but it changes
the numerical path and is not necessary to obtain a valid result. Keeping the
existing equilibration and requesting tighter convergence also works. Simple
row normalization is not a satisfactory repair: it still fails the rejected LP
and introduces failure in its passing predecessor. Neither finding establishes
a general ranking of scaling methods.

Crucially, improved feasibility does not imply compatibility with already accepted
vectors. Under all-three 1e-11, seven scale entries in the passing 500-profile
helix predecessor and three in the PreSSMat stress control exceed the frozen
absolute-plus-relative scale-comparison allowance. Their largest differences are
7.70e-6 and 8.23e-6, respectively. No graph-decision effect is established because
the outer algorithm was not run. The small helix stays within that scale allowance.
This argues against silently tightening the default for every solve.

## Why the historical expression fails earlier

The original expression introduces an auxiliary variable representing C squared
through a second-order cone. At C=0.55 its baseline value is
0.3024998704859214, about 1.29514e-7 below C squared. The affected inequality has
an auxiliary coefficient about 3,337.08. Multiplication amplifies the small
auxiliary error into 0.000432199 of the worst projected-row violation of
0.000448077: **96.46% of that violation** is accounted for by the auxiliary term.
The remaining canonical inequality error is approximately 0.0000158781; the
projection identity reconstructs within 4.91e-13 across all rows.

The returned solver slack lies in its cone, but the slack reconstructed directly
as b-Ax violates that cone by approximately 1.99e-7. Their difference is permitted
by the globally normalized equality error. Thus a feasible returned cone slack
alone would be a misleading certificate for the projected LP.

Tighter conditions take 41 iterations instead of 39, reducing the auxiliary
error and making the original LP pass. This explains the additional error
amplification in this failed historical attempt. It does not establish historical
equivalence, nor attribute the entire historical/evaluated difference across IAN
to this single mechanism.

## What is ready, and what remains unverified

Seven no-solve falsification/dual-map checks pass. All baseline reproductions,
matrix-transform checks, scalar certificates, residual reconstructions and exact
feasibility witnesses pass as described. All prescribed conditions ran once;
there were no failed harness reruns, extra setting searches or resource stops.
The intentional canonical-capture exception is retained and labeled separately.
The replay schedule used about 15.46 seconds and a maximum sampled child peak of
67.83 MiB, below the declared bounds; these observations are not benchmarks.

No warning was emitted in the new direct-replay stderr logs. This does not resolve
the older Python matrix-product warning, whose source path was bypassed here.
No matrix condition number, arbitrary-precision optimal solution, different solver
backend, native setting change, full experimental IAN run, boundary regression,
R/package check or larger input has been tested in this diagnosis. The pinned
native source explains the formula, and Python telemetry verifies it numerically;
this is not a new native-build qualification.

The recommended next experiment is a separately named, limited retry policy:
keep the accepted first attempt unchanged, preserve its rejection, and try a fresh
solver with tighter settings only after external numerical rejection. A candidate
1e-11 condition is supported on these fixed problems; it is not guaranteed for
all future ones. A fresh retry would pay for a complete new solve—it cannot be
described as continuing for just one additional iteration. Every retry must pass
the unchanged external checks, and exhaustion must remain an explicit failure.

That candidate would need complete native/evaluated helix runs, accepted trajectory
and decision-boundary regressions, and checkpoint/provenance tests before adoption.
It is a proposal for a bounded Phase07C, not implemented work or permission to
reopen the 1,000-profile gate. The accepted IAN evaluated-LP 1.0 mode and all earlier
evidence remain unchanged.

Supporting evidence: [analysis](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07b/analysis-v1/results.json),
[replay ledger](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07b/replays-v1/ledger.json),
[exact witnesses](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07b/witness-v1/results.json),
and [commands/source boundaries](README.md).
