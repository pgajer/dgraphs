# Phase 07F: the 1,000-profile helix exposes a native/Python discrepancy

**The bounded study is complete with a negative scale result.** Native IAN stops
during initial tuning of the 1,000-profile helix after exhausting its permitted
retry. Evaluated Python completes the same input with 47 pruning steps. The full
trajectory comparison therefore fails, closing the expansion gate. The cloud,
separated lobes and all four quadforms were generated and verified but not run.

The new finding differs from Phase07D: the terminal native return passes the
numerical certificate checks, but the solver reports `AlmostSolved`. The contract
requires `Solved`, including on the replacement attempt, so refusal is correct.
This result does not justify accepting that return directly or adding another
retry. The accepted Phase07E implementation and all limits remain unchanged.
Independent review of this phase is pending.

## Purpose and prescribed inputs

The [plan](PLAN.md) asks whether the accepted experimental implementation remains
compatible at 1,000 profiles, with bounded computation and storage. It reuses the
Phase07E binary, Python reference, configuration and existing dependencies without
rebuilding or changing numerical source. Its independently audited 500-profile
panel is explicitly reused prerequisite evidence, not a fresh execution.

Seven inputs were frozen before any new engine run. The first three are the
original unexecuted Phase07 1,000-profile fixtures: density-varying helix, noisy
six-dimensional cloud and separated planar lobes. Only their explicit numerical
policy declaration changed; coordinates, distances, identifiers and provenance
were preserved exactly.

Pawel confirmed that the additional quadforms should have **intrinsic dimensions
2, 3, 4 and 5**, embedded in ambient dimensions **3, 4, 5 and 6**. The existing
`dgraphs` geometry and sampling API generated one prescribed saddle-shaped
example per dimension. For intrinsic dimension d, latent coordinates are drawn
uniformly from [-1,1]^d and embedded as

`x = (u, uᵀ A u),  A = diag(0.5/sqrt(d), -0.5/sqrt(d), …)`.

The alternating-sign form has Frobenius norm 0.5 in every dimension. This controls
one aspect of curvature magnitude; it does not make the sampling or geometry
identical across dimensions. Sampling is uniform in latent coordinates, not in
surface area. The canonical frame, zero offset, no observation noise and one
fixed seed per dimension were declared before generation. There was no seed,
curvature or solver-performance search.

The four R source files are pinned from this worktree, and were sourced without
installing or rebuilding `dgraphs`. Full sample/specification/RNG RDS objects,
lossless binary64 latent and embedded coordinates, form matrices, source hashes
and R session information are preserved. Independent checks reconstruct every
quadratic height, verify uniqueness and bounds, and reconstruct all pairwise
Euclidean distances for all seven inputs. These checks pass. They establish the
intended input construction, not IAN accuracy on the unexecuted quadforms.

## What happened on the helix

Both paths used fresh Clarabel 0.11.1 QDLDL instances, one thread, unchanged
ordinary and normalized-retry settings, and at most one retry per logical LP.
The original-unit external accuracy limits remain 1e-7, and accepted solutions
must have raw solver status `Solved`.

| Result | Native | Evaluated Python |
|---|---:|---:|
| Physical solver attempts | 26 | 112 |
| Logical optimization problems | 13 | 66 |
| Accepted returns | 12 | 66 |
| Rejected returns | 14 | 46 |
| Normalized retries attempted | 13 | 46 |
| Successful retries | 12 | 46 |
| Pruning steps | 0 | 47 |
| Completed graph, scales and affinities | No | Yes |

Native stops at zero-based attempt 25, the normalized replacement for the
thirteenth logical problem, at tuning C=0.50001220703125. The ordinary attempt
failed stationarity and correctly triggered a retry. The replacement returns
`AlmostSolved` in 18 solver iterations. Python's corresponding normalized solve
returns `Solved` in 27 iterations and passes all checks, so Python continues.

Independent reconstruction of the two corresponding returns gives:

| Original-unit check | Native retry | Python retry | Limit |
|---|---:|---:|---:|
| Normalized primal violation | 1.409e-8 | 6.509e-16 | 1e-7 |
| Maximum dual-stationarity error | 1.524e-8 | 1.030e-11 | 1e-7 |
| Relative objective inconsistency | 5.168e-16 | 1.421e-15 | 1e-7 |
| Relative primal–dual gap | 4.910e-12 | 2.455e-15 | 1e-7 |
| Dual nonnegativity violation | 0 | 0 | 1e-7 |

Both also have finite, positive active scales. Thus the native terminal return
fails the required **solver-status condition**, not these numerical inequalities.
It is the second attempt, so no further retry is allowed. The trace records its
status-based eligibility separately from the already exhausted attempt allowance.
No native graph decision or pruning step uses this rejected result.

The complete Python output passes all accepted-payload checks, topology checks,
stage hashes, affinity support checks and independent affinity reconstruction.
The reconstruction differs by at most 2.220e-16, within the frozen limits. Those
Python artifacts remain available. Native retains its partial trace and raw
optimization returns, but has no valid pruning checkpoint or completed stage.
Consequently the proposed larger native cancellation/resume test is unavailable.

## Where the two paths diverge

Initialization distances, initial topology, bounds and constraint matrices match.
The first scale-vector comparison failure is at ordinary attempt 18, which both
paths reject; its replacement agrees under the frozen rules. All twelve returns
accepted by both paths before the terminal failure satisfy the scale comparison.
The decisive status/acceptance branch occurs at attempt 25. This distinction
separates earlier differences in discarded returns from a difference that prevents
one implementation from advancing.

At the terminal problem, all matrix coefficients, objective coefficients, bounds,
activity flags, tuning value and normalization factor match exactly. **One entry
of the right-hand-side vector differs by one binary64 floating-point step**:

- Native: -2794.6999596425544.
- Python: -2794.699959642554.
- Absolute difference: 4.547e-13, below the frozen coefficient comparison allowance
  of 5.689e-11 at that entry.

The normalization factor is 10132.359853740509 in both paths. After normalization,
the corresponding backend right-hand sides differ by 5.551e-17. The maximum
returned-scale difference is nevertheless 246.35 in stored LP units. Exact
rational checks confirm that the respective upper-bound vectors are feasible
for both represented LPs; this is not an optimality or uniqueness proof.

These measurements show sensitivity worth diagnosing, but do not establish that
the one-entry difference caused the status or solution difference. The native
and Python interfaces have not yet been cross-tested on identical saved data.
No condition-number analysis or proof of multiple exact optima is supplied.
Passing certificate inequalities alone also does not establish matching scale
vectors or subsequent graph decisions. Simply dropping the status requirement
would not settle the compatibility problem.

The rejected native LP and matched Python LP are retained as a versioned
[extension to the difficult-problem collection](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07f/analysis-v1/fixed-collection-extension.json).
All diagnosis in this phase used saved data; it introduced zero additional solves.

## Gates, resources and provenance

The prescribed paired comparison fails. The remaining **six inputs / twelve
principal executions** are explicitly gated, including all four quadforms. No
larger native restart run was attempted because no completed paired native case
with pruning exists. The quadform addition remains useful future dimensional
coverage, but this phase makes no claim about its IAN behavior.

There are **138 physical solver attempts**, with 78 accepted and 60 rejected
returns. All acceptance decisions were independently reconstructed from saved
coefficients and vectors. Copied diagnostics, trace-control fixtures and earlier
500-profile evidence are excluded from physical counts. Five guarded processes
(two engines, two validators and one comparison) total **18.70 seconds**. Maximum
sampled process-tree RSS is **1,750.03 MiB**, observed in the Python engine run;
no sampled resource limit was reached. The native run does less work because it
stops early, so these measurements cannot support a performance comparison.

Thirteen no-solve trace falsification controls pass. The first preflight used a
three-solve prefix ending immediately after a retry. Removing that last retry
left a legitimate interrupted trace, so the expected refusal did not occur.
The corrected fixture retains the actual following outer event, making the
missing retry an invalid transition. Both preflight versions and logs remain;
no solver had run before this harness correction and no solver was repeated.

The fixtures precede execution; source revisions and exact commands are recorded.
The accepted numerical runtime, configuration and dependencies are unchanged.
Historical source and evidence preservation is checked at final freeze. Existing
Python numerical-library warnings remain visible. No installation, build, package
qualification, production change, alternative solver, tolerance search, further
retry, always-normalized first attempt, real-cohort expansion, deployment or merge
occurred.

This is a completed bounded negative study awaiting independent review. It does
not establish 1,000-profile implementation compatibility, quadform trajectory
coverage, larger native restart behavior, geodesic/neighborhood recovery,
biological validity, general numerical reliability, historical-expression
agreement or production readiness. Fixture checks are not substitutes for gated
engine executions.

## Recommended next question

Before another scale run or policy change, freeze a small cross-interface replay:
run each of the two saved terminal LPs through both native and Python solver
interfaces with identical coefficients, settings and normalization. This would
separate sensitivity to input rounding from an interface or backend-execution
difference. A different LP algorithm can then provide a separately labeled fixed-
problem diagnostic if needed. Neither remedy nor direct acceptance of AlmostSolved
is authorized or implemented by this report. The existing quadform fixtures can
be used once the compatibility gate is resolved, without selecting new examples
based on subsequent results.

## Durable evidence

- [Seven inputs and generator provenance](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07f/fixtures-v1/manifest.json)
- [Execution ledger and gated cases](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07f/ladder-v1/ledger.json)
- [Independent reconstruction and census](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07f/analysis-v1/results.json)
- [Terminal coefficient difference](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07f/terminal-difference.json)
- [Python completed affinity](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07f/ladder-v1/helix_1000/evaluated/child/affinity.json)
- [Reproduction commands](README.md)
