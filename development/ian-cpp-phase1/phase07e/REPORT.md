# Phase 07E: the helix completes with unchanged acceptance checks

The bounded study is complete. Allowing one fresh normalized retry after an
otherwise usable `AlmostSolved` return lets both the native and evaluated-Python
engines complete the 500-profile helix. They perform **42 pruning steps**, reach
matching graph decisions and final affinities, and pass every frozen comparison.
The remaining regression panel also passes. Independent review of this phase is
pending; the experimental policy is not adopted and larger runs remain gated.

## What changed and what was tested

Phase 07D stopped because its retry rule excluded `AlmostSolved`, even though a
separately labeled auditor solve later repaired that fixed problem. Phase 07E
changes eligibility for another calculation. It does not accept the original
reduced-accuracy return or relax the required accuracy of a replacement.

The new declared policy is `IAN evaluated-LP retry units11 almost 0.1`. An ordinary
attempt retains 1e-9 solver stopping settings. A rejected first return with raw
status exactly `Solved` or `AlmostSolved` may receive one fresh normalized solve
at 1e-11, provided dimensions and finite-value checks pass, active scales are
positive, the objective is consistent and recomputed diagnostics are finite.
An `AlmostSolved` return with otherwise passing certificates still receives a
fresh solve. Every accepted return must be `Solved` and pass the unchanged
original-unit primal, objective and dual checks at 1e-7. Other backend statuses
are ineligible. A failed replacement ends the logical problem.

Normalization and recovery are unchanged from Phase 07D: alpha=max(upper),
A*y<=b/alpha, x=alpha*y, unchanged dual and objective multiplied by alpha.
Graph construction, tuning, pruning, affinity truncation and ordinary accepted
solutions are unchanged. Both implementations retain fresh Clarabel 0.11.1
QDLDL instances, one thread and the 300-iteration limit.

The [plan](PLAN.md) was committed before coding or new optimization. It specifies
six fixed development problems, the complete helix, conditional execution of the
remaining 24 specifications, and operational controls. Those remaining inputs
comprise eight full regressions, three other 500-profile examples, twelve
pruning/retuning boundary probes and one six-case stage input. All were executed
in both implementations; the stage cases require no optimization.

## Complete trajectories and compatibility

Each helix execution performs **61 logical LPs and 81 actual solver attempts**:
61 accepted returns and 20 rejected ordinary returns followed by 20 successful
normalized retries. Nineteen retries follow `Solved` returns that fail external
checks; one follows the formerly terminal `AlmostSolved` return. No replacement
fails. Both 424-event traces pass the frozen native/Python comparisons.

The 76-event Phase 07D prefix is unchanged except timing, the declared policy name
and the intended change to the last rejection's eligibility. That last ordinary
return remains rejected. Its replacement returns `Solved` in 19 iterations, with
original-unit stationarity error **1.318e-12**, below the unchanged **1e-7** limit.
This was a fresh engine execution. The earlier auditor probe is separately
preserved as reused diagnostic evidence.

The full-fit panel gives the following counts per implementation:

| Input | Pruning steps | Solver attempts | Successful retries |
|---|---:|---:|---:|
| 500-profile helix | 42 | 81 | 20 |
| Nonuniform curve | 0 | 2 | 0 |
| Variable-density patch | 0 | 2 | 0 |
| Nearby curved arms | 0 | 3 | 0 |
| Small PreSSMat Hellinger subset | 4 | 9 | 0 |
| Perturbed 256-profile Hellinger example | 182 | 195 | 0 |
| Perturbed 300-profile Hellinger example | 176 | 189 | 0 |
| 120-profile helix | 15 | 31 | 0 |
| 144-profile saddle | 0 | 3 | 0 |
| 500-profile cloud | 46 | 50 | 0 |
| 500-profile separated lobes | 15 | 17 | 0 |
| 500-profile PreSSMat subset | 396 | 405 | 0 |

All **50 scheduled executions** complete and all **25 native/Python comparisons**
pass: 24 complete fits, 24 boundary-probe executions, and two executions of the
six-case stage input. Previously successful same-path traces remain exact after
removing timing and declared retry metadata; the stage outputs match exactly.
No previously successful case acquires a retry.

Every accepted payload is checked from saved original coefficients outside the
solver. Checks also cover rejected returns, unchanged original problems within
retries, the actual transformed backend data, recovery to original units, graph
topology and reconstruction of final affinities from distances and local scales.
The largest paired absolute affinity difference is **1.212e-13**; the largest
recorded scale difference across compared events is **1.279e-10**. All satisfy
the existing comparison limits. The largest accepted helix stationarity error
is 9.984e-8 against the 1e-7 limit: some ordinary accepted returns remain close
to the boundary. This establishes compatibility on this panel,
not general mathematical or historical-expression equivalence.

## Fixed-problem collection and operational controls

The permanent [regression collection](REGRESSION_COLLECTION.md) contains the five
Phase 07D fixed problems plus its new post-pruning terminal problem, retaining
exact coefficients, returned vectors, provenance and expected acceptance results.
All six fresh ordinary solves reproduce saved primal/dual vectors, objectives
and iteration counts exactly. Three pass and three correctly fail. All six fresh
normalized solves pass. These twelve executions are development regressions on
known problems; they are not an independent estimate of numerical reliability.

**86 classification cases** pass in both languages using the helpers called by
the runtime. They distinguish eligibility from acceptance for both relevant
statuses, every other backend status, malformed vector lengths, nonfinite values,
nonpositive active scales, objective mismatches and boundary diagnostics. These
are no-solve tests of classification, not simulated full backend malfunctions.

All **19 operational checks** pass. They cover declaration refusal before solving,
invalid active scales without retry, deliberate two-attempt exhaustion, observer
failure before retry, natural cancellation/resume, and refusal of rehashed
checkpoint policy/source/configuration and four attempt-counter mutations.

Cancellation after the first helix pruning step saves a checkpoint after
**27 attempts**, including 12 successful retries. Resume performs **54 further
attempts**, completes the fit at cumulative count 81, and reproduces the
uninterrupted result exactly. Joining the interrupted and resumed traces gives
the same 424 events, including metadata except timing. This demonstrates the
tested continuation to completion, not recovery from arbitrary interruption,
power loss or across platforms.

All **42 transformation controls**, **13 trace-verifier falsification controls**,
and regeneration of all **29 candidate files** pass. The native library and
clients were built in a new private build directory against the existing pinned
backend. No dependencies were installed or rebuilt.

## Accounting and limitations

There are **2,104 physical solver attempts**: 12 fixed diagnostics, 2,006 across
the trajectory/probe panel, and 86 in operational tests. Of these, **2,037 returns
pass and 67 are rejected**, including intentionally damaged operational returns.
All rejections are preserved. Copied diagnostics, concatenated restart traces and
historical auditor evidence do not add to the execution count.

The 199 guarded processes, including validation processes, total **255.6 seconds**
with maximum sampled process-tree memory **241.3 MiB**. No sampled resource limit
was reached. These quantities exclude builds and unguarded postprocessing; this
study does not estimate a performance advantage. Existing Python numerical and
native dependency/compiler warnings remain in the retained logs.

The first final-census pass stopped because it expected optimization-check fields
on the stage-only cases. Its failed output is retained. The corrected census
handles those cases separately; no engine, solver setting, trajectory or solver
execution changed for that correction.

This phase is implementer validation awaiting independent review. It does not
adopt a default policy, qualify production use, establish historical-expression
array equivalence, resolve pruning calibration, validate biological graph
geometry or conditional-expectation estimators, or qualify R packaging and
portability. No 1,000-profile/full-cohort run, different-LP-algorithm comparison,
always-normalized first-attempt study, deployment or merge occurred. The tested
geometries include reused difficult cases and controls, not an unseen sampling
study. Further failures remain possible.

The immediate next step is independent review of this bounded candidate. After
acceptance, a separately authorized extension can revisit the original scale
ladder. A different LP algorithm remains a diagnostic option if new failures
appear; always-normalized solves remain a separate compatibility question.

## Durable evidence

- [Fixed collection manifest](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07e/fixtures-v1/manifest.json)
- [Fixed replay ledger](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07e/diagnostic-v1/ledger.json)
- [Complete panel and comparisons](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07e/trajectory-v1/ledger.json)
- [Operational controls](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07e/operational-v1/checks.json)
- [Numerical reconstruction and physical census](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07e/analysis-v2/results.json)
- [Reproduction instructions](README.md)
