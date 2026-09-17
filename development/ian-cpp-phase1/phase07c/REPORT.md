# Phase07C: a limited retry helps, but does not complete the helix

The bounded experiment is complete. One stricter retry repairs the original
500-point helix failure and six subsequent constraint failures. A later problem
still fails its optimality-certificate check after retry, so neither Python nor
native IAN reaches the first pruning step. The retry is therefore insufficient
as a general repair. It remains a separate experimental policy; the accepted
engine is unchanged, and the 1,000-profile expansion remains closed.

## What was tested

Both implementations first used the accepted Clarabel settings, including
feasibility and gap tolerances of 1e-9. An optimal, finite result with positive
active scales and a consistent objective could receive one fresh retry only if
its constraint or dual-certificate checks failed. That retry used 1e-11 for all
three solver tolerances, on identical coefficients. The external acceptance
limits stayed at 1e-7. The graph algorithm, pruning decisions and affinity
calculation were unchanged. Each rejected attempt was saved before retry;
its scales never entered an outer decision.

The complete-run panel contained the eight accepted small/regression inputs and
four saved 500-profile examples: a helix, Gaussian cloud, separated disks and
PreSSMat Hellinger profiles. Native and evaluated-LP Python ran on every input.
Twelve saved decision-boundary probes and six non-solving threshold/tie cases
were also tested in both paths. Comparisons retained the accepted exact discrete
decisions and numerical array tolerances; accepted same-path traces were also
compared exactly after removing timing and the new retry metadata.

The [frozen plan](PLAN.md) and [amendment](AMENDMENT-1.md) preceded their respective
executions. All optimization runs were serial and used one solver thread.

## Complete-run results

| 500-profile example | Attempts per implementation | Retry attempts | Pruning steps | Outcome |
|---|---:|---:|---:|---|
| Helix | 19 | 8 | 0 | Seven retries pass; the eighth is rejected. No completed graph, scales or affinity checkpoint. |
| Gaussian cloud | 50 | 0 | 46 | Complete; exactly preserves its accepted same-path trace. |
| Separated disks | 17 | 0 | 15 | Complete; exactly preserves its accepted same-path trace. |
| PreSSMat profiles | 405 | 0 | 396 | Complete; exactly preserves its accepted same-path trace. |

All eight accepted regression inputs complete unchanged without retries. All
12 fixed boundary probes and six stage cases preserve their accepted results.
Native/evaluated comparisons pass throughout every attempted trajectory,
including both helix refusals. The original helix failure prefix is preserved
exactly in each path. For the 11 inputs that complete, final affinities also pass
independent reconstruction from the supplied distances and returned scales,
including exact agreement of which affinities are zero.

The primary panel contains **1,882 optimization attempts**: **1,864 accepted
returns and 18 preserved rejected returns**. Each implementation contributes nine
helix rejections: eight first attempts and the final failed retry. All accepted
returns pass independent scalar constraint, objective and dual checks. Both
rejected and accepted attempts are checked against their recorded acceptance
and retry decisions; every retry uses identical coefficients.

## Where the helix stops

The original rejection at tuning multiplier C=0.525 has normalized constraint
violation 2.688e-7. Its retry reduces that to 3.188e-9 and passes. Six more
constraint rejections are subsequently repaired.

At C=0.500048828125, the eleventh logical problem fails a different check:
**dual stationarity**, the consistency condition between the objective and the
returned dual weights used to support optimality. The first attempt has residual
7.900e-7. Its stricter retry has residual **1.0532813e-7**, about 5.3% above the
unchanged 1e-7 limit. Constraint violation is zero on that retry and the objective
gap is tiny, but those checks do not replace stationarity. Both attempts are
reported optimal by the solver. They take 19 and 57 iterations, respectively;
the retry is a whole fresh solve.

The worst stationarity component is column 364 with zero-based indexing. Scalar
summation and 80-digit Decimal reconstruction from the exact binary64 inputs
confirm that it exceeds the threshold. Thus, rounding in the reporting sum does
not explain away the rejection. The unresolved first attempt and retry are
saved as standalone fixed-problem payloads for subsequent work. No further
solver settings were tested here.

The run stops during initial tuning. Its trace retains the accepted intermediate
solutions and every refusal, but no completed graph, scale or affinity artifact
exists. This is not a partially accepted scientific fit.

## Operational checks and evidence quality

All 16 operational checks pass, including a 20-assertion eligibility truth table,
missing/wrong policy declarations before solves, invalid active scales without
retry, exactly two rejected attempts under deliberate finite solution damage,
and an observer failure that prevents retry after the rejected event is emitted.
Changed checkpoint policy, source and configuration identities stop before
another solve. Twelve additional no-solve falsification controls show that the
trace checker detects missing or third attempts, altered problems/settings,
false acceptance/eligibility, invalid vectors and premature outer decisions.

Because the natural helix never reaches a pruning checkpoint, resume after a
natural retry remains untested. A separately labeled one-time damaged first
solution on the small PreSSMat example exercises that path operationally.
The fresh retry succeeds, a checkpoint records both attempts, and interruption
plus resumption reproduces the uninterrupted trace and final result exactly.
The two execution paths each consume ten actual attempts. Synthetic damage is
not counted as a natural solver failure.

The first panel is preliminary: a test-client edit after initial CMake
configuration left a stale source fingerprint embedded in the core. Its numerical
code was the intended candidate. The evidence is retained, the fingerprint
mismatch is reconstructed explicitly, and CMake now refreshes fingerprints when
identity-bearing sources or configuration change. The clean second build passes
an independent fingerprint check. Its entire panel reproduces the preliminary
same-path traces exactly apart from timing and metadata.

The preliminary runner also labeled the successful Python stage-only process
as incomplete because that adapter writes stages.json without status.json;
its exit status and stage comparisons were successful. This bookkeeping is
corrected in the primary panel. Two postprocessing census attempts are retained:
the first incorrectly imposed an additional bitwise cross-path requirement beyond
the frozen limits, and the second counted diagnostic input traces as fresh
executions. The corrected census uses the existing comparison rules and counts
only actual guarded solver executions. These corrections did not trigger new
solver runs or change numerical policy. Exact same-path reproduction should not
be confused with bitwise equality between implementations. As an additional
raw-data diagnostic, 424 of 941 paired solves have identical coefficients,
primal/dual vectors, objectives and iteration counts. Across all pairs, the
largest scale difference is 1.046e-9 and the largest dual-vector difference is
2.752e-6; dual equality is not a frozen cross-path requirement, and each returned
dual is checked independently. These differences also occur in the exactly
preserved accepted same-path histories. All 19 helix pairs are identical in
these raw fields.

There are **3,789 actual attempts across both panels and operational tests**,
within the frozen 8,000-attempt allowance. Of these, 1,882 belong to the preliminary
panel, 1,882 to the primary panel and 25 to operational tests. No sampled resource
limit was reached. Guarded execution and diagnostic processes total 490.3 seconds;
the largest sampled process-tree RSS is 231.6 MiB. These figures exclude build
and unguarded pure postprocessing costs. Resource telemetry is guard evidence, not a performance
benchmark. Older Python numerical warnings and native dependency/compiler
warnings remain in the logs; this study does not claim to resolve them.

## Interpretation and next step

The limited retry preserves the accepted cases and repairs several local
failures, but it fails the intended complete-helix recovery test. Implementation
agreement is supported on the tested trajectories; successful recovery is not.
Study completion does not establish independent acceptance, default-policy
adoption or readiness for larger cohorts.

The next bounded numerical study should start from the newly saved failed LP
and explain the dual-stationarity rejection against the solver's stopping and
scaling calculations. Any further change should remain a named experimental
policy and repeat the boundary and complete-trajectory comparisons. Increasing
the retry count or relaxing the external threshold is not justified by this
experiment alone. Phase08 optimization and the 1,000-profile expansion should
wait for that unresolved numerical question.

Full-cohort behavior, general historical-expression equivalence, pruning
calibration, scientific neighborhood validity, downstream conditional-expectation
estimators, portability and production readiness remain unestablished. The
checkpoint test is a bounded single-host operational result; it does not establish
recovery from arbitrary failures or a successful natural helix checkpoint.

## Durable records

- [Primary execution ledger](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07c/panel-v2/ledger.json)
- [Operational checks](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07c/operational-v1/checks.json)
- [Corrected census and numerical findings](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07c/analysis-v3/results.json)
- [Unresolved retry payload](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07c/analysis-v3/unresolved-retry.json)
- [Trace-checker controls](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07c/checks-v1/results.json)
- [Reproduction instructions](README.md)
