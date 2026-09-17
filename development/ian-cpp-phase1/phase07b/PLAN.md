# Phase07B: fixed-problem diagnosis of the shared numerical refusal

Authorized by Pawel after independent Phase07 acceptance. Base candidate is
`c2330c8ed1e9b307700b51dc919391090f4f0ec6`. This plan precedes new optimization
executions. IAN evaluated-LP 1.0 and the Phase07 refusals remain unchanged.
All 1,000-profile work, policy adoption, full-engine experimental reruns and
Phase08 optimization remain outside this diagnostic scope.

## Questions and fixed cases

Explain why Clarabel reports optimal when the saved helix solution exceeds IAN's
per-row normalized constraint tolerance. Separate a mismatch in stopping tests
from data/assembly differences, infeasibility, and effects of equilibration or
the historical lifted expression. A low objective gap alone is not feasibility.

Extract four evaluated LPs from accepted Phase07 traces, before any replay:

1. The 120-profile helix's first solve (small passing control).
2. The 500-profile helix's first solve at C=0.55 (passing immediate predecessor).
3. The same helix's second solve at C=0.525 (shared rejection).
4. The accepted 500-profile PreSSMat solve with the largest external normalized
   primal residual; choose by that saved residual, breaking ties by solve number.
   This is a deliberate stress control, not an independent population sample.

Also capture the actual canonical first problem of the original-expression
500-profile helix through the frozen Phase03 adapter. Intercept construction
before solving, save the full cone data, and stop explicitly; zero solver calls.
Verify its projected coefficients against the saved original LP. This fifth
case includes the historical auxiliary variable/cone rather than pretending
that its saved projected LP is the canonical problem actually solved.

## Frozen diagnostic conditions

Fresh direct Python Clarabel 0.11.1 solves, serial, one thread, QDLDL, max_iter=300,
with the accepted options. Bypass CVXPY for saved evaluated matrices. The unchanged
baseline must reproduce saved primal/dual vectors and iterations exactly before
interpreting its interventions. On baseline mismatch, retain evidence and stop
the affected case; do not silently tune until reproduction succeeds.

Apply these seven conditions to each of the four evaluated cases (28 solves):

- Baseline: all three accepted tolerances remain 1e-9.
- Feasibility only: tol_feas=1e-11; gap tolerances unchanged.
- Gap only: tol_gap_abs=tol_gap_rel=1e-11; feasibility unchanged.
- All three tolerances 1e-11.
- All three tolerances 1e-12.
- Disable equilibration only; retain baseline tolerances.
- Row normalization only: divide each inequality by
  max(1,abs(b_i),max_j abs(A_ij)); retain baseline tolerances and equilibration.
  Recover original duals by the same positive row multiplier and validate against
  the original coefficients. Mathematical equivalence does not imply identical
  floating-point execution or outer IAN decisions.

For the historical canonical case apply baseline, feasibility-only, gap-only,
all-three 1e-11, and all-three 1e-12 (five solves). Do not apply scalar row scaling
to the second-order cone as if it were independent scalar inequalities.
The prescribed total is 33 solver calls; hard study ceiling is 40 including any
explicitly recorded corrective harness reruns. No open-ended setting search.
Every negative result, AlmostSolved status or residual failure remains a result.

## Checks and evidence

Read and hash the pinned native Clarabel 0.11.1 source implementing residuals,
norms, equilibration and termination. Record the installed Python wheel identity
and full settings. Official settings documentation is background; the pinned
source and measured telemetry govern version-specific claims.

Save original and transformed A,b,c, cones, all primal/dual/slack vectors, status,
iteration telemetry, costs, gap, residuals and elapsed time. Reconstruct the
backend residual formula from unscaled returned vectors and compare it with
reported residuals, allowing small floating-point effects from unscaling.
Distinguish its global denominator from the row-specific external denominator.
Recompute every external constraint, objective and dual certificate with scalar
math.fsum; cross-check the worst rejected row with Decimal arithmetic on the
exact binary64 inputs. Preserve each worst row and its terms.

For the lifted historical case, separately check canonical equality/slack/cone
residuals, auxiliary-variable departure from C^2, its induced projected-constraint
effect, and the original LP certificate. Do not identify a returned cone slack
with a feasible original LP without checking the projection.

Record changes in scales and objectives relative to the baseline. Passing a
fixed LP under experimental settings identifies a candidate, not an adopted
repair. No complete experimental IAN trajectory or boundary regression is run
in this phase; those would be necessary before accepting a changed policy.

Run all cases through a bounded supervisor: 120 seconds and 1 GiB sampled child
RSS per replay, 20 minutes and 4 GiB output for the study. Poll at 50 ms, with
possible recorded overshoot. Send SIGTERM then SIGKILL after five seconds if
needed. Stop the diagnostic schedule on an actual resource limit. Resource
measurements are guard/provenance evidence, not performance benchmarks.

New authored sources/docs live under phase07b; generated evidence and handoff
under worker/phase07b and worker/phase07b-implementer-handoff.md. Freeze source
before runs, preserve failures in new namespaces, verify prior manifests including
review-7 read-only, and distinguish study completion from independent acceptance
and any later authorization. No modification of old sources, runtime, audits,
shared packages, scientific data or production artifacts is included.
