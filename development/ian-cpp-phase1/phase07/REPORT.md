# Phase 07: agreement at 500 profiles, with a shared numerical limit

The bounded study is complete. Three of four prescribed 500-profile inputs
produce valid graphs and affinities in both native and evaluated Python, with
matching decisions throughout. The fourth, a density-varying helix, fails the
same numerical check in both implementations before a graph is saved. All
1,000-profile executions remain gated. This supports implementation agreement
on the tested attempts; it does not qualify arbitrary 500-profile inputs or
establish production readiness. Independent acceptance of this phase is pending.

The Phase06B auditor's nonblocking N1 comment is addressed: the coordinator
roadmap now consistently records Phase06A as independently accepted with F1
closed. It also records Phase06B acceptance. No frozen Phase06B source, report,
handoff or evidence was rewritten.

## What was tested

The [prospective plan](PLAN.md) specifies a density-varying three-dimensional
helix, a noisy six-dimensional cloud, two separated planar disks, and the existing
500-profile PreSSMat pilot composition/Hellinger input. All seven prospective
500/1,000-profile fixtures were generated before execution, without outcomes or
selection based on graph behavior. Only the four at 500 were executed. The
PreSSMat pilot overlaps earlier studies and is not an independent biological
replicate. No new cohort source or full-cohort fit was introduced.

Both principal paths use the accepted IAN evaluated-LP 1.0 policy and pinned
Clarabel 0.11.1 on this macOS ARM64 host. The native executable and dependency
were reused from accepted Phase06B; neither was rebuilt or modified. Original-
expression Python was run only on the helix and disks as a separate historical
compatibility control. Each condition/input has one fresh-process execution.
All are serial with one-thread settings. Native checkpoint cadence is 100 accepted
pruning iterations plus the forced graph checkpoint; Python retains its stage
files. A 120-profile helix regression precedes the larger inputs in both paths.

The new checker reads one trace event at a time and applies the frozen Phase03
discrete fields, coefficient/array limits and external primal/dual checks. It
also reconstructs topology, stage hashes and final affinities. Saved rejected
solutions remain rejected; solver status alone never constitutes acceptance.

## Results and coverage

| Input | Native/evaluated outcome | Solves per implementation | Pruning iterations | Final graph |
|---|---|---:|---:|---|
| 120-profile helix regression | Complete; each reproduces its accepted trace exactly except timing | 31 | 15 | 169 edges, no isolates |
| 500-profile helix | Both reject solve 2; complete traces up to refusal agree | 2 | 0 | No accepted final graph |
| 500-profile noisy cloud | Complete; full comparison passes | 50 | 46 | 2,428 edges, two isolates |
| 500-profile separated disks | Complete; full comparison passes | 17 | 15 | 927 edges, two components containing edges, no isolates |
| 500-profile PreSSMat pilot | Complete; full comparison passes | 405 | 396 | 4,051 edges, two isolates |

The cloud and PreSSMat graphs each have one component containing edges plus two
isolates. The disks provide the intended distinct coverage of two nontrivial
components, without graph repair or invented links. The PreSSMat example extends
the previously tested pruning history to 396 iterations. Final retuning and all
intermediate decisions are included in the comparisons, not just endpoints.

Across 12 engine executions there are **1,028 saved optimization payloads**:
1,025 pass the unchanged external checks and three fail. The failures are the
native and evaluated helix's second solve and the original-expression helix's
first solve. They are observed numerical failures, not injected tests.

For passing payloads, maximum normalized constraint error is 3.8733e-8,
dual stationarity error 1.1315e-8 and relative primal/dual gap 9.9630e-10, below
the respective 1e-7 external limits. All 24 recorded kernel checks pass. All nine
completed executions have independently reconstructed final affinities, with
maximum absolute entry difference 2.23e-16 and identical zero support. All 27
stage-file hashes and seven native checkpoint payload/prefix identities pass.
These checkpoint checks establish integrity of this evidence, not a fresh
large-input interruption/resume experiment.

Cross-language arrays satisfy the frozen tolerances but are not generally
bitwise identical. For example, PreSSMat right-hand sides differ by at most
2.85e-14 and internal scales by 6.02e-11. Its dual vectors differ by up to
1.082e-6; the policy checks each dual certificate's residuals and gap, and does
not impose a pointwise cross-language dual-vector tolerance. The rejected helix
payloads are exactly equal across the two evaluated paths, including both
primal and dual vectors. Bitwise equality is an additional observation, not a
replacement acceptance rule.

The original-expression disks finish in 17 solves and pass the complete frozen
comparison with evaluated Python. The original-expression helix rejects the
first solve while evaluated Python accepts that solve and rejects the next.
Their scale/acceptance comparisons first differ at trace event 4, so later
unmatched events are not compared as if they represented the same state. This
is an observed difference in numerical acceptance, not a demonstrated difference
between completed pruned graphs. General historical equivalence remains false
as a claim and unestablished as a project objective.

## What the helix failure means

On the evaluated paths, Clarabel labels the second solve optimal at multiplier
0.525. Direct reconstruction finds normalized constraint error
2.6877102747778647e-7, approximately 2.7 times the fixed 1e-7 allowance.
An independent `math.fsum` calculation of the worst row reproduces this error.
The historical-expression control's first solve has error 1.5750401345031977e-7.
It also reports optimal but fails the external requirement.

Both evaluated implementations therefore stop truthfully before graph convergence.
There is no final graph, affinity or accepted checkpoint boundary to resume.
Agreement through refusal argues against a native-only defect on this input.
It does not identify the underlying numerical cause: conditioning, equilibration
and stopping criteria are candidates for a later controlled diagnosis. No settings,
acceptance tolerances, coefficients or point selections were changed here.

The first driver conservatively gated every later input. The [recorded amendment](AMENDMENT-1.md)
then authorized completing only the other three already frozen 500-profile
examples after this shared refusal. It did not rerun the helix, add candidates or
reopen the 1,000-profile gate. The original attempt and its original ledger remain
available beside the continuation.

## Resource observations

The following are single complete-client observations, including startup,
trace serialization and the prescribed persistence. RSS is resident memory,
sampled over each process tree every 50 ms; MiB means 2^20 bytes.

| 500-profile input | Native wall seconds | Evaluated Python wall seconds | Native peak RSS, MiB | Evaluated Python peak RSS, MiB |
|---|---:|---:|---:|---:|
| Helix, partial failed attempt | 0.18 | 1.04 | 50.3 | 157.0 |
| Noisy cloud, complete | 1.45 | 3.11 | 70.9 | 178.5 |
| Separated disks, complete | 0.43 | 1.36 | 63.7 | 170.6 |
| PreSSMat pilot, complete | 14.30 | 25.59 | 92.3 | 204.9 |

Short-process sampled peaks can miss transients: the separate Darwin `wait4`
maximum for the failed native helix is 63.2 MiB. Both peak conventions are retained
in the evidence. No child hits the 4 GiB RSS, 900-second wall or 2 GiB output
threshold. The workload uses 86.59 supervised seconds including 35.42 seconds
of per-run checking/comparison. Separate fixture generation, harness tests and
the two final census attempts have their own resource records. The largest
principal run output is evaluated PreSSMat at about 456 MB, dominated by tracing.
The outer continuation supervisor samples a combined peak of about 662.5 MiB.

Native PreSSMat observer intervals record 0.077 seconds in initialization,
13.541 in pruning, 0.230 in final retuning, 0.056 in checkpoint I/O and 0.014 in
output, with another 0.049 seconds for input loading. These labels describe
observer intervals and include mixed computation/output costs. In particular,
the inherited solve timer combines LP assembly, backend work and validation.
Isolated solver, assembly and affinity costs, matched Python phase timings and
per-phase peak RSS are unavailable. They have not been filled with estimates.

These client observations are not a controlled language-speed comparison or a
production memory bound. Startup, tracing, checkpoint policies, measurement
overhead and concurrent system load matter. Persistent solver timing was already
nearly equal in Phase02. Matching fine-grained instrumentation is still needed
before attributing an optimization benefit in Phase08.

## Failures retained and limitations

The first checker falsification attempt failed while writing a NaN diagnostic
as strict JSON. A corrected diagnostic representation preserves the original
malformed trace and labels nonfinite values as strings in diagnostic output.
The second attempt passes ten checker/supervisor checks, without solving.
The first final census incorrectly asserted optional bitwise equality across
all solver fields. The corrected census reports those differences separately
from the frozen acceptance criteria. Both failed attempts and their source
revisions remain saved; neither required an engine rerun.

Python matrix-product warnings recur in six run logs. External `math.fsum`
objective checks and saved finite values pass where acceptance is reported;
the underlying library warning remains unresolved. No warning suppression is
treated as a fix. Existing initial-isolate refusal, numerical-policy limits,
same-host restart scope and lack of production/package qualification remain.

No 1,000-profile input was executed; no original-expression cloud or PreSSMat
control was prescribed; no new native build, R/package check, portability test,
large-input interruption test, graph repair, embedding or scientific estimator
validation was performed. There are no repetitions or statistical uncertainty
claims for runtime, memory or biological generalization.

## Coordinator interpretation

This is a completed bounded study with useful positive fidelity evidence and an
informative negative robustness result. The next proposed milestone is a small
numerical diagnosis of the frozen helix subproblems: explain why the backend's
optimal status does not satisfy the external row criterion, using named diagnostic
conditions while retaining the current baseline and all refusals. Any candidate
settings or scaling change must then be checked against the accepted trajectories
and boundary cases before adoption. This is a proposal, not an implemented or
authorized policy change. Do not proceed to larger cohorts or silently relax the
validation threshold.

Detailed evidence is in [the census](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07/analysis-v2/results.json),
[the two-batch ledger](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07/ladder-v2/ledger.json),
and the [reproduction record](README.md). The final manifest and factual handoff
identify the candidate separately from independent acceptance.
