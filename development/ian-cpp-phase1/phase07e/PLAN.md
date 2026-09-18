# Phase 07E: bounded AlmostSolved retry eligibility

Pawel authorized Phase 07E after independent acceptance of Phase 07D without
corrective findings. Base: d30573a32b64fc184493192d4657ad924a464a0b.
This plan precedes implementation and new solves. Completion, independent
acceptance, adoption and scale expansion remain separate decisions.

## Policy and unchanged checks

Declare `IAN evaluated-LP retry units11 almost 0.1` as a separate experimental
policy. Ordinary attempts and accepted ordinary returns retain Phase 07D settings.
Permit at most one fresh normalized retry after a rejected first return whose
raw status is exactly Solved or AlmostSolved. Require correct vector dimensions,
finite coefficients and returned values, positive active scales, consistent
objective and finite recomputed diagnostics. An AlmostSolved return with otherwise
passing certificates is still rejected and retried. No infeasibility, iteration
limit, numerical-error, callback-cancellation or other status is eligible.

The retry uses identical original coefficients, alpha=max(upper), x=alpha*y,
A*y<=b/alpha, unchanged dual, original objective=alpha*backend objective, and
unchanged 1e-11 settings. Only Solved returns passing all original-unit checks
may be accepted. External limits remain 1e-7. A failed second attempt stops the
logical problem. Preserve both attempts, raw statuses and actual attempt counts.
No settings search, relaxed acceptance, always-normalized first attempt or
alternative engine backend is included.

## Tests and conditional execution

Before trajectories, test both language eligibility functions on ordinary valid
returns; AlmostSolved with valid and invalid certificates; malformed dimensions,
nonfinite values, nonpositive active scales, inconsistent objectives; every other
backend status; finite diagnostic limits; and second-attempt exhaustion.
Retain declaration refusal, invalid-return, observer-failure and trace-falsification
controls. Checkpoints bind policy, source, configuration and actual attempt counts.

Run fresh native and evaluated-Python helix-500 trajectories from the same original
input. Require the Phase 07D 76-event prefix to remain unchanged except timing,
policy declaration and the explicitly changed eligibility of the last rejection.
Compare every subsequent event under the frozen numerical/discrete rules;
independently check all certificates, retry transformations, topology and final
affinities. A numerical failure is a preserved negative result, not a reason to
change policy during this study. A cross-implementation mismatch stops dependent
runs. If the helix completes in agreement, run the remaining 24 specifications:
eight full regressions, three other 500-profile inputs, twelve boundary probes and
one six-case stage input, in both paths. Previously successful same-path results
must match their saved traces except time and declared retry metadata. Preserve
all frozen cross-path comparison thresholds.

Exercise natural cancellation after the first pruning step containing successful
retries, then resume to the same endpoint as the uninterrupted native run. Compare
the joined full trace and result, not merely counts. Refuse rehashed policy,
source, configuration and attempt-counter mutations before new optimization.

## Durable difficult-problem collection

Freeze the five Phase 07D fixed LPs and its new terminal LP, including exact
coefficients, returned vectors, provenance and expected acceptance outcomes.
Retain the earlier strict retries and auditor's separately labeled terminal probe
as reused evidence, not fresh execution. Run the six problems once under ordinary
and normalized-retry settings (12 fresh fixed solves) and reconstruct acceptance
independently. These are development regression cases, not unseen validation.
Add any new natural failure without silently rerunning it under new settings.

## Bounds, evidence and stopping

Serial one-thread solver runs; fresh QDLDL instances. At most 8,000 actual solves,
3,600 aggregate guarded child seconds, 900 seconds / 2 GiB output per child,
4 GiB sampled process-tree resident memory and 16 GiB study output. Build and pure
postprocessing are separately identified. Guard overshoot, failures and reruns
remain in the census. No 1,000-profile/cohort expansion, dependency installation,
production change, package qualification, deployment, merge or policy adoption.

Source changes stay under phase07e and coordinator/ROADMAP.md. Generated evidence
stays under worker/phase07e, factual handoff alongside. Commit executable source
before measured execution. Preserve prior source/evidence and audit artifacts
read-only and freeze an inventory after all work. If normalized retries still
fail, recommend a separately specified different-LP-algorithm diagnostic before
further tolerance changes; do not execute that alternative in this phase.
