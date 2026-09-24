# Phase07D: dual-certificate diagnosis and bounded remedies

Pawel authorized this phase after accepting the Phase07C independent audit,
which has no findings. Base: 9f82d83ace376a3c2c8996a16c5ab53e81a6d82b.
This plan precedes new solves and implementation. Study completion, independent
acceptance, policy adoption and scale expansion remain separate decisions.

## Diagnosis and fixed problems

Read the pinned Clarabel 0.11.1 source and reconstruct its stopping residuals
from returned primal, dual and slack vectors. The source divides dual residual
L2 norm by max(1, norm(c,inf)+norm(x,2)+norm(z,2)); IAN checks maximum absolute
stationarity against 1e-7. Measure the contributions, termination history and
whether unit normalization addresses this mismatch. Internal refinement solves
linear systems with separate tolerances; tighter refinement is a hypothesis,
not an attribution of the current failure to failed refinement.

Freeze five evaluated LPs, without solving:
1. The Phase07C helix's unresolved problem (ordinary attempt 17, retry 18).
2. Its accepted immediate predecessor (attempt 16).
3. The original repaired helix problem (attempts 1 and 2).
4. The small helix's first passing problem saved in Phase07B.
5. The deterministically selected PreSSMat stress problem saved in Phase07B.

Run every problem under five conditions, exactly 25 diagnostic solves:
- Ordinary accepted settings, all three stopping tolerances 1e-9.
- Phase07C strict retry, all three 1e-11.
- All three 1e-12, all other settings unchanged.
- All three 1e-11 plus iterative-refinement absolute/relative tolerances 1e-14
  and maximum 30 refinement iterations; other settings unchanged.
- All three 1e-11 with uniform variable units: alpha=max(upper)>0, x=alpha*y,
  solve min c'y subject to A*y<=b/alpha. Recover x=alpha*y, original dual z=z',
  original slack=alpha*s', original objective=alpha*objective'. No row-dependent
  transformation, distance recomputation or external-tolerance change.

Retain complete raw vectors, settings, actual solver coefficients, iteration
telemetry and original-unit certificates. Exact reproduction of saved ordinary
returns and both saved strict retries is a gate before interpreting remedies.
Check transformed values and objective/dual recovery independently. Repeat no
setting search if a result fails. A remedy qualifies for a trajectory attempt
only if all five original-unit certificates pass.

## Conditional complete trajectories

Test qualified remedies in fixed order: tighter stopping, tighter refinement,
then uniform variable units. Each is a separately declared experimental policy
with an ordinary 1e-9 first attempt and at most one fresh retry under that remedy.
All eligibility rules and external limits from Phase07C remain unchanged.
Build a separate candidate for each qualified remedy; preserve both attempts,
actual attempt counters and policy/source/configuration-bound checkpoints.

For each qualified remedy, attempt the complete 500-profile helix in native and
Python. Compare every event under frozen limits, including rejection behavior.
A shared numerical refusal is an accounted negative result and permits the next
already specified qualified remedy. An unexplained implementation discrepancy
or resource limit stops dependent execution. The first remedy completing this
helix in agreement advances to the full regression panel; do not test additional
full-helix remedies after that success. If none completes, report that outcome
without further settings, relaxations or variants.

For the selected completing remedy, run both implementations on the remaining
Phase07C panel: eight accepted full inputs, the three other 500-profile inputs,
12 fixed boundary probes and six stage-only cases. Previously successful
same-path traces must remain exact apart from elapsed time and new metadata;
retain all frozen cross-path limits and independently reconstruct final affinities.
Carry the tested helix executions into the final ledger as explicitly reused
executions, not fresh repeats. Require independent certificates for all attempts
and identical original problems within each retry. The transformed backend
problem, if used, must also match the declared transformation.

Run eligibility/failure controls, exhaustion after two attempts, observer failure
before a retry, declaration refusals, and cancellation/resume after an actual
successful retry if a pruning boundary exists. Joined continuation must match
uninterrupted trace and result. Rehashed policy/source/configuration and counter
mutations must refuse before solving. If no remedy completes, test the changed
fixed-problem machinery with no-solve controls and record unavailable full-engine
operational claims; do not fabricate a successful natural checkpoint.

## Bounds and provenance

Serial, one solver thread, fresh Clarabel QDLDL instances. No more than 8,000
actual solves (including 25 diagnostics), 3,600 aggregate guarded child seconds,
900 seconds and 2 GiB output per child, 4 GiB sampled process-tree RSS, 16 GiB
study output. These are sampled safeguards, with a five-second kill escalation;
overshoot is recorded. Pure checks/builds are separate from solver counts.
No 1,000-profile runs, production changes, package qualification, historical
expression port, default adoption or deployment. No new dependencies are planned.

Commit sources before measured executions. Source changes stay under phase07d
and the coordinator roadmap; evidence stays under worker/phase07d, with factual
handoff alongside. Preserve failed attempts in separate namespaces. Verify old
manifests, including review-7c, read-only; freeze the new inventory after all work.
