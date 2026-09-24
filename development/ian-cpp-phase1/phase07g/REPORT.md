# Phase 07G: the terminal outcome follows the input

The isolated replay reproduces the Phase07F discrepancy and attributes its
observed switch to the one-step constraint perturbation on the pinned builds.
With identical input, native and Python return identical numerical results,
including solver histories. This completes the bounded diagnostic; independent
acceptance is pending and the 1,000-profile compatibility gate remains closed.

## Question and experiment

Phase07F stopped the native helix fit before pruning, while Python completed.
Their terminal linear programs differed in one right-hand-side entry by one
adjacent binary64 step. This study crossed the two saved problems with the two
interfaces, then repeated every cell in a fresh process: eight physical solves.
Each solver used the saved normalized formulation, three requested tolerances
of 1e-11, QDLDL, one thread, 300 maximum iterations and disabled presolve. Each
invocation constructed one solver and made one solve, without a further retry.
The original acceptance requirement remains Solved plus the unchanged original-
unit numerical and positivity checks, with certificate errors at most 1e-7.

The right-hand-side entry at zero-based row 882 is -2794.6999596425544 for the
native-generated problem and -2794.699959642554 for the Python-generated problem.
Their difference is 4.547473508864641e-13 in stored units, or
5.551115123125783e-17 after division by 10132.359853740509. All other LP coefficients,
objective, matrix structure, bounds and activity declarations are unchanged.
The saved coefficient difference remains within the earlier comparison allowance.

Actual backend input arrays were dumped before solver construction and compared
byte for byte, including CSC column pointers and row order, binary64 values,
normalized RHS, objective and empty quadratic objective. There is one nonnegative
cone and no explicit matrix zeros. Both sets also match CVXPY's canonical arrays
without solving. The no-solve controls detect coefficient and index perturbations
and distinguish numeric certificate success from status rejection.

## Results

Each row below occurred twice, with exact repeat agreement except elapsed time.

| Exact input | Interface | Status | Internal iterations | Original-unit numeric checks | Acceptance |
|---|---|---|---:|---|---|
| Native-generated LP | Native | AlmostSolved | 18 | Pass | Rejected |
| Native-generated LP | Python | AlmostSolved | 18 | Pass | Rejected |
| Python-generated LP | Native | Solved | 27 | Pass | Accepted |
| Python-generated LP | Python | Solved | 27 | Pass | Accepted |

Both interfaces reproduce their own Phase07F terminal status, iteration count,
primal/dual/slack vectors, objective and backend residuals exactly. The baseline
reproduction gate therefore passes. For each exact input, the interfaces agree
in all saved numerical fields and callback histories after excluding timing.
There are four accepted and four rejected returns, and all eight pass numerical
certificate inequalities when the separate status requirement is set aside for
reporting purposes. No rejected return is accepted by the engine policy.

For the native-generated input, maximum normalized primal violation is
1.4088333415994699e-8 and stationarity error is 1.524056325585832e-8. For the
Python-generated input they are 6.50854443076334e-16 and 1.0304757047663315e-11.
The limit is 1e-7 in each case. The maximum difference between returned scale
vectors across the two inputs is 246.35166607978886 in stored LP units. It fails
the frozen elementwise allowance of 1e-7 plus 1e-7 times the larger absolute scale.
Thus accepting AlmostSolved directly would still leave the scale mismatch.

The eight supervised processes total 2.287 seconds of wall time; maximum sampled
process-tree resident memory is 57.91 MiB. No resource bound was reached. These
figures describe small isolated replays, exclude preparation/build/postprocessing,
and do not estimate full-engine performance. There are no new graph trajectories,
quadform solves or ladder executions in this phase.

## Settings and build evidence

The native client links the unchanged accepted Clarabel library; Python uses the
unchanged Clarabel 0.11.1 wheel. Native Rust was built with 1.85.1 and release
optimization from the frozen offline dependency tree; the Python wheel reports
Rust 1.87.0, release optimization and additional optional features. Both use QDLDL
for this LP. Library hashes, full native source inventory/build receipts, Python
wheel/build metadata and client compilation flags are retained. The native client
uses Release C++17 and -ffp-contract=off, matching the accepted engine convention.

There was an instrumentation omission: a code-generation expression failed to
capture all native settings fields. The eight original runs record only method,
time-limit and ABI metadata; these files and the executed source are preserved.
A separate no-solve probe reconstructs all 38 exposed fields using the same pinned
default function and identical explicit assignments. Every field matches Python's
recorded effective settings. This is a post-run reconstruction, not a complete
in-process native settings snapshot. No optimization was repeated to fill it.
The first probe failed to load the dynamic library; a second probe with an explicit
library search path succeeded. Both probe artifacts are preserved. The initial
client build also failed on a JSON header include path, corrected before any solve.

The pinned C header omits Rust's input_sparse_dropzeros field. It occupies tail
padding in this non-SDP layout: the four native calls recorded its byte as zero,
consistent with Python's false setting. No explicit zeros occur in either matrix.
This observation is not general ABI qualification; the header discrepancy should
be addressed separately before portability work. Native/Python build differences
exist but did not produce numerical differences on identical data in this study.

Two dependency-head fields in the initial environment record resolve the enclosing
repository because the copied dependency tree contains no .git directories. They
are not dependency revisions. The supplement explicitly corrects this attribution
and records the exact source hashes, original build receipts and shared-library
identity instead. Original records remain available.

## Interpretation and next step

The controlled input swap is sufficient to reproduce the observed outcome switch
in both interfaces. This supports solver sensitivity to this particular one-step
perturbation on these builds. It does not prove multiple mathematical optima,
characterize general conditioning, or explain every earlier trajectory difference.
An almost identical objective and small residuals do not establish matching scales
or later pruning decisions. The original failed native trajectory remains failed.

Before another full trajectory, the next proposed bounded study should compare
these two fixed problems using a different LP algorithm, such as HiGHS dual simplex,
and examine the differing scales and near-optimal directions. Its tolerances,
physical solve budget and interpretation limits should be fixed in advance. This
would test whether the instability is specific to the current solve path before
further tolerance changes. A subsequent compatibility change could specify shared
coefficient arithmetic, but choosing the successful rounded RHS alone is not a
validated remedy. Any changed coefficient or solver policy needs fresh full native/
Python trajectories and the existing regression panel before reopening the ladder.
The six frozen unexecuted inputs, including quadforms, remain preserved.

## Evidence

Worker evidence: ../worker/phase07g relative to the implementation worktree.
`results-v2.json` contains the eight certificates, exact comparisons and explicit
settings supplement; `results.json` preserves the original analysis.
`fixtures/manifest.json`, `runs/*/child`, `ledger.json`, `preflight.json`,
`settings-supplement-v2/record.json`, `preservation-v1.json` and `manifest-v1.json`
provide inputs, raw outputs/histories, process accounting and provenance.
See README.md for reproduction and the adjacent factual implementer handoff.
