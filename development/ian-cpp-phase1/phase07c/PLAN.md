# Phase07C: one retry after numerical rejection

Authorized by Pawel following independent acceptance of Phase07B. Base is
61da3139e1cbecfa995ec061f2d926b6cc04bb4f. This plan precedes implementation and
new solves. Study completion, independent acceptance and adoption are separate.

## Experimental policy

The separate candidate is named `IAN evaluated-LP retry 0.1`. Its file interface
requires that explicit declaration; the accepted Phase06B runtime and policy
remain unchanged. Keep the same evaluated coefficients, objective, graph logic,
external validation thresholds and baseline solver settings. Attempt zero uses
all three tolerances at 1e-9. An otherwise optimal, finite solution with positive
active scales and a consistent objective may be retried only after a primal or
dual certificate rejection. Nonfinite diagnostics, nonoptimal status, invalid
active scales, inconsistent objective, input errors and observer failures do not
qualify. A retry creates one fresh solver on identical coefficients, with only
tol_feas, tol_gap_abs and tol_gap_rel changed to 1e-11. Maximum two attempts per
logical problem; a second rejection stops explicitly. No further settings search.

Every attempt is saved before acceptance or retry, including the rejected raw
vectors, coefficients, checks, attempt index, logical problem number, policy and
tolerance. The solve counter counts actual attempts. Only accepted scales enter
IAN decisions. Checkpoints occur at existing accepted boundaries, include policy,
source and configuration identities, and never resume a half-finished retry.
Update conservative checkpoint counter bounds for two attempts per solve.

## Frozen validation panel

1. Eight previously accepted complete inputs from the Phase06A regression list,
   in both native and evaluated Python candidates. Require exact same-path traces
   apart from timing and added retry metadata; retain unchanged cross-path limits.
2. All twelve Phase05 fixed boundary probes and the Phase05 stage probes, both
   candidates. Require the same previously accepted decisions and arrays.
3. Complete native/evaluated trajectories on the four saved Phase07 500-profile
   fixtures: helix, Gaussian cloud, separated disks and PreSSMat. Preserve and
   compare the original helix refusal prefix. Require all accepted payloads to
   pass independent numerical checks, every retry to use identical coefficients,
   and every decision, intermediate array and final affinity to agree under the
   existing limits. Passing trajectories with no retries must reproduce their
   accepted same-path traces exactly apart from timing and retry metadata.
4. Targeted operational checks: retry eligibility truth table, explicit policy
   refusals before solves, deliberately invalid active scales with no retry,
   deliberately damaged finite solutions exhausting exactly two attempts,
   observer failure on a rejected event preventing retry, and cancellation/resume
   after a real retry if an accepted pruning boundary is reached. Recombined
   continuation must match uninterrupted trace and result apart from timing.
   Mutated checkpoint policy must fail before another solve. Synthetic solver
   damage is explicitly marked and is not evidence about natural solver behavior.

Do not relax thresholds after a failure. A shared exhausted retry is an informative
negative result. Stop dependent expansion on unexplained cross-path differences
or resource limits, recording unexecuted cases and reasons. No 1,000-profile runs,
historical-expression repair, deployment, package qualification or default adoption.

## Resources and evidence

Serial one-thread runs; at most 8,000 actual solver calls, 3,600 aggregate child
seconds, 4 GiB sampled process-tree RSS, 900 seconds and 2 GiB output per run,
16 GiB study output. Poll at 50 ms; sampled limits can overshoot. Terminate then
kill after five seconds if needed. Build and pure checks do not consume solver
budget. Performance telemetry is provenance, not a speed benchmark.

Sources live here; evidence in worker/phase07c, factual handoff alongside it.
Commit source before measured executions. Keep failed attempts immutable under
versioned names. Inventory all runs, tests, binaries and configuration; recheck
prior implementation/audit manifests read-only. The bounded report states what
the retry resolves, any later failure, all deviations and untested generality.
