# Phase07D: the earlier certificate failure is repaired, but the helix still stops

The bounded study is complete. We explained why the earlier helix solution could
satisfy Clarabel's stopping test while failing IAN's certificate, and found a
change of optimization-variable units that repairs that fixed problem. In the
complete-engine attempt, the same retry repairs 13 rejections and permits two
pruning steps. The next ordinary solve returns **AlmostSolved**, with an invalid
dual certificate; the unchanged retry-eligibility rule stops there.

This is progress beyond the Phase07C failure, not a completed helix fit. No policy
has been adopted, no acceptance limit has been relaxed, and the 1,000-profile
gate remains closed. The accepted engine and earlier evidence are unchanged.

## What was tested

The [frozen plan](PLAN.md) specifies five original evaluated linear programs:
the unresolved Phase07C helix problem, its accepted immediate predecessor, the
first helix problem repaired in Phase07C, a small-helix passing control, and the
previously selected PreSSMat stress control. Each was solved under five conditions,
for exactly 25 diagnostic solves. All used fresh Clarabel 0.11.1 QDLDL instances,
float64 arithmetic, one thread and the existing 300-iteration limit.

The two reference conditions use stopping tolerances of 1e-9 and 1e-11. The three
prespecified remedies are tighter stopping at 1e-12; tighter internal linear-system
refinement at 1e-14 with at most 30 refinement iterations, retaining 1e-11 stopping;
and uniform variable normalization with 1e-11 stopping. External primal,
objective and dual-certificate limits remain 1e-7.

Every ordinary saved solution and both available saved strict retries reproduce
exactly in primal/dual vectors, objective and iteration count. All raw solutions,
actual solver matrices, settings, iteration telemetry and recovered original-unit
certificates are retained. Exact rational checks also establish feasible witnesses
for all five LPs: their upper-bound vectors satisfy the stored inequalities.
These failures therefore do not establish mathematical infeasibility.

## Why the original dual failure passed the solver's test

For these linear programs, the pinned solver source computes the dual residual as

`||c + Aᵀz||₂ / max(1, ||c||∞ + ||x||₂ + ||z||₂)`.

IAN instead requires `max(abs(c + Aᵀz)) <= 1e-7`. The source formula is recorded in
[Clarabel's info.rs](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase06a/clean-v2/dependencies/Clarabel.cpp/Clarabel.rs/src/solver/implementations/default/info.rs:164).

On the failed Phase07C strict retry, the denominator is **15,211.79**, of which
**15,200.30** comes from the primal vector's norm. The dual residual numerator
has L2 norm 1.368e-7. Dividing it by that large denominator produces **8.991e-12**,
which is below the solver's 1e-11 limit. Meanwhile, its largest individual
stationarity error is **1.053e-7**, above IAN's unchanged 1e-7 limit. Reconstruction
from returned vectors agrees with the backend telemetry. This explains the
apparent disagreement without treating the external rejection as rounding noise.

Internal iterative refinement has its own linear-system stopping test; it is not
the external optimality certificate. Changing its controls does not establish
that inadequate refinement caused the original failure. Actual inner refinement
iteration counts were not instrumented in this study.

## Fixed-problem remedies

Results on the unresolved helix LP are:

| Condition | Backend status | Internal iterations | Original-unit stationarity error | External result |
|---|---|---:|---:|---|
| Ordinary 1e-9 stopping | Solved | 19 | 7.900e-7 | Reject |
| Phase07C retry at 1e-11 | Solved | 57 | 1.053e-7 | Reject |
| Tighter stopping at 1e-12 | AlmostSolved | 123 | 2.526e-6 | Reject |
| Tighter refinement, 1e-11 stopping | AlmostSolved | 38 | 7.891e-7 | Reject |
| Uniform variable units, 1e-11 stopping | Solved | 17 | 7.792e-12 | Accept |

Only uniform variable normalization passes all five fixed problems. Across all
25 diagnostics, 20 returns pass and five fail. These are dependent conditions
and selected examples, not a population success-rate estimate.

The transformation uses `alpha = max(upper)` for the current LP, writes
`x = alpha*y`, and solves `min cᵀy` subject to `A*y <= b/alpha`. A positive constant
objective multiplier does not change the mathematical minimizers. Recovery uses
`x = alpha*y`, the same dual vector `z`, and objective multiplied by alpha. Both
the transformed data and recovered original-unit solution are checked; the
underlying specimen distances and graph construction are not changed.

For the unresolved LP, alpha is 3,337.08. The transformed primal norm is 4.555,
and the dual normalizer becomes **16.05**, rather than 15,211.79. The recovered
solution passes both primal and dual checks. This removes the large primal-scale
contribution to the stopping denominator in this example. The transformation also
changes the floating-point solution path; the entire improvement cannot be
attributed uniquely to the denominator change, and success is not guaranteed
for other problems. Original-unit external checks remain necessary.

## Complete-trajectory attempt and the new stopping point

The qualifying remedy was implemented as the separately declared policy
`IAN evaluated-LP retry units11 0.1`. Ordinary attempts retain the accepted 1e-9
settings. Only an eligible rejection receives one fresh normalized 1e-11 retry.
The graph, tuning and pruning policy and retry eligibility remain unchanged.

Native and evaluated Python each execute **17 logical problems and 30 actual
attempts**: 16 accepted returns and 14 preserved rejections. All **13 retries**
pass their original-unit certificates. Initial tuning finishes at
C=0.5000030517578125, and both implementations perform the same two pruning steps.
Their 76-event traces pass every frozen comparison, including retry decisions,
intermediate arrays and graph topology. The original accepted ordinary-solve
prefix is preserved.

The next ordinary solve, at pruning iteration 2 and attempt number 29 (zero-based),
returns **AlmostSolved**, the backend's reduced-accuracy status. Its stationarity
error is **6.830e-6**, approximately 68 times the 1e-7 limit. Thus the returned
solution is not acceptable even apart from its status. The policy requires a
Solved status before permitting a retry, so this attempt is not retried.
No statement is made about whether a normalized retry would repair this new LP.
An exact upper-bound witness confirms that the stored new LP is feasible.

The first trajectory recorded only the inherited coarse label `not_optimal`.
The [amendment](AMENDMENT-1.md) added raw backend-status metadata and repeated the
same native/Python attempts with a fresh build. Every existing event field matches
its first execution exactly apart from timing; the only new field is raw status.
Both versions are preserved and counted as physical executions. Numerical policy,
coefficient assembly and eligibility did not change during this repetition.

No completed graph-stage artifact, scale-stage artifact or final affinity exists.
The plan's complete-helix gate fails, so the other **24 input specifications**
(48 native/Python executions) remain unexecuted: eight full regression inputs,
three other 500-profile inputs, 12 boundary probes and the six-case stage input.
Their earlier acceptance does not substitute for validation under this new policy.

## Checkpoint and adversarial results

All **19 operational checks** pass, including 20 eligibility truth-table
assertions, declaration refusals before solving, invalid active scales without
retry, deliberate exhaustion after exactly two damaged solutions and observer
failure before retry. Policy/source/configuration and four invalid attempt-counter
checkpoint mutations are refused before another solve.

A natural accepted pruning boundary is now available. Cancellation immediately
after the first pruning step saves a checkpoint containing **27 actual attempts**,
including 12 successful normalized retries. Resume executes three further attempts
and reaches the same AlmostSolved refusal at cumulative count 30. Joining the
interrupted and resumed traces exactly reproduces the uninterrupted 76 events,
including metadata except timing, and the same partial result. This demonstrates
continuation to the tested failure; it does not demonstrate a completed fit or
recovery from arbitrary interruption or power loss.

All **35 no-solve transformation checks** and **13 trace-verifier falsification
controls** pass. They include incorrect variable units, right-hand sides,
primal/dual/objective recovery, missing slack, missing or extra attempts, invalid
vectors and inconsistent raw solver status. All 28 candidate files match mechanical
regeneration. These controls do not qualify arbitrary malformed solver returns.

## Evidence accounting and limitations

There are **180 actual optimization attempts**: 25 fixed diagnostics, 60 in the
first native/Python trajectory pair, 60 in the status-enriched pair and 35 in
operational tests. Of these returns, 101 pass and 79 are rejected, including
intentionally damaged operational returns. Diagnostic copies and concatenated
traces are excluded from the execution count. Every accepted solution is
independently checked outside the solver, and all 13 natural retries per helix
execution use identical original problems with the declared backend transform.

Guarded execution and diagnostic processes total **30.3 seconds**, with maximum
sampled process-tree RSS **170.7 MiB**; no sampled limit was hit. These totals
exclude builds and unguarded pure postprocessing and are not performance estimates.
Existing Python numerical warnings and native dependency/compiler warnings remain
in the logs. No new dependency was installed.

One census attempt is retained as failed: it expected the native literal error
string while Python wraps the same error inside `InvalidSolve(...)`. The corrected
census recognizes that wrapper while preserving all status flags and numerical
checks. No solver was rerun because of this postprocessing correction.

The remaining full panel and final-affinity validation are gated, so this phase
does not establish full-engine compatibility for the new policy, general helix
recovery, historical-expression equivalence or production readiness. There is
no condition-number analysis, arbitrary-precision optimum, portability or R/package
qualification, scientific neighborhood validation, cohort-scale run, or downstream
conditional-expectation validation. Feasible witnesses and certificates concern
these stored LPs, not biological validity.

The next bounded question is whether a fresh normalized retry of the newly saved
finite AlmostSolved problem can pass the unchanged acceptance criteria. Allowing
that retry would change eligibility, not acceptance of the original return, and
requires a separately specified policy plus complete-trajectory and regression
tests. Simply accepting AlmostSolved or lowering the external limit is not
supported. This study neither performs nor authorizes that next intervention.

## Durable evidence

- [Fixed diagnostic ledger](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07d/diagnostic-v1/ledger.json)
- [Primary trajectory ledger, including gated cases](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07d/trajectory-v2/ledger.json)
- [Operational checks](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07d/operational-v1/checks.json)
- [Reconstruction, exact feasible witnesses and census](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07d/analysis-v2/results.json)
- [New terminal problem and returned solution](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07d/analysis-v2/native-terminal-problem.json)
- [Reproduction instructions](README.md)
