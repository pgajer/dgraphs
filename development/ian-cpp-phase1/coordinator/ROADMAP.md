# IAN implementation and improvement: proposed project roadmap

Status: proposed for discussion, not approval of later experiments or deployment.
Prepared after the phase 04 submission, 17 September 2026.
Scientific owner: Pawel Gajer. Coordinator and implementer: this task.
Independent audit remains a separate role.

## Objective and end products

Build a reproducible, maintainable IAN implementation that exposes its decisions,
survives interruption, works from R, and supports controlled method research.
Its scientific purpose is to support outcome-independent community organization
and within-/between-cohort comparisons in ZAPPS and PreSSMat, following the
[approved project aims](/Users/pgajer/current_projects/ZB/docs/project_aims.md).
Successful execution, reference agreement and attractive embeddings do not
establish biological geometry, cohort comparability or predictive validity.

Proposed end products:

1. A versioned native library and CLI with explicit algorithm/numerical policy,
   input and duplicate mappings, native graph, components, isolates, local scales,
   affinity matrix or kernel application, numerical diagnostics and provenance.
2. An automated regression and operational test suite with frozen small examples,
   longer adaptive histories, numerical boundary cases and independently reviewed
   evidence. The executable Python reference remains available.
3. A portable build and thin R interface, provisionally a companion package with
   an optional dgraphs adapter. Final packaging depends on build/distribution
   evidence, not the current worktree's location.
4. Auditable, resource-bounded cohort applications with durable scientific outputs
   saved before optional graph repair, shortest paths or layouts.
5. A separate evaluation framework and named experimental variants. An improvement
   is adopted only when it addresses a specified failure or user need and survives
   comparisons against the frozen reference and suitable simpler alternatives.

## Evidence so far

| Phase | Status in this conversation | What it establishes |
|---|---|---|
| 01: fixed optimization replay | Independently accepted | Native LP feasibility and small replay timing/memory evidence. |
| 02: historical discrepancy and persistent sequences | Independently accepted | Representation/backend settings explain the large historical timing discrepancy; persistent Python/native timings were near equal; native benchmark-client peak memory was 52–61% lower. These are not complete-engine claims. |
| 03: small complete engine | Independently accepted | Three-condition agreement on four small fixtures and tested checkpoint failures; only four pruning iterations on one ordinary input. |
| 04: longer trajectories and readable native stages | Submitted; independent audit pending | Implementer evidence: native/evaluated-Python agreement through 182 and 176 pruning iterations, retuning and isolate creation. Original-expression/evaluated-Python intermediate-array limits fail on both selected inputs despite equal discrete decisions. |

The accepted phase 03 baseline is `7d030ff669be9e4a090ec75829c6477c25a7091c`.
The submitted phase 04 candidate is `df4dcb271369d65302fdf62ce6b7e6c4a13fbb32`.
This roadmap does not alter either submission. See the
[phase 04 report](../phase04/REPORT.md) and
[handoff](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase04-implementer-handoff.md).

## Phase 05 — Audit closure and numerical contract

Close phase 04 audit findings before treating its evidence as accepted. Then
write a short, versioned compatibility specification distinguishing:

- The mathematical LP and algorithm policy.
- The chosen numerical execution baseline.
- Observed agreement of intermediate arrays and discrete decisions.
- Historical-expression comparisons that remain failed or untested.

Recommendation: use explicitly evaluated LP coefficients as the candidate native
baseline, with the evaluated Python engine as its implementation reference. Keep
the original-expression control as a historical compatibility diagnostic. This
requires an explicit owner decision after audit; it does not retroactively make
the failed phase 04 array tests pass or prove that future decisions cannot differ.
Keep the frozen baseline tolerances. Any future revised criterion needs its own
justification and prospective tests.

A bounded follow-up should concentrate on recorded near-boundary decisions and
the differing LP states, plus a small independent holdout fixture set. More
accuracy in separately labeled diagnostic solves may help distinguish residual
solver error from ill-conditioning or alternate optima; changing all baseline
settings is not a substitute for that diagnosis. Do not require reproducing every
incidental legacy conic solver vector unless that becomes an explicit project
requirement.

Deliverable: audited disposition, numerical contract and named reference version.
Exit: no unexplained implementation discrepancy; every remaining historical
compatibility limitation is stated and its consequence accepted by the owner.

## Phase 06 — Reusable core and reliable execution

Turn the current prototype into a library with a thin CLI and typed boundaries
for input, graph state, LP/backend, retuning, pruning, affinity and diagnostics.
Separate algorithm policy from file formats and language interfaces. Preserve
numeric operation ordering where it affects the accepted reference contract.

Add versioned input/result/checkpoint schemas, structured errors, cancellation at
safe boundaries, progress records and resource accounting. Add periodic accepted
iteration checkpoints before implementing resumability. A resumable state must
include the graph, bounds, multiplier/bracket phase, mapping, numerical policy
and required solver bookkeeping; it must reject mismatched input/configuration
or incompatible schema versions.

Test uninterrupted versus interrupted/resumed trajectories, intentional process
termination around checkpoint commits, incomplete writes and storage failures.
Never infer restart safety from the existing controlled-exception tests. Keep
optional diagnostics separate from native graph acceptance. Record time/memory
for distinct phases with matching boundaries across implementations.

Deliverable: reusable core and CLI, schema documentation and operational tests.
Exit: unchanged regression behavior, truthful failure states, demonstrated resume
equivalence under the specified policy, and independently reviewed checkpoints.

## Phase 07 — Bounded scale and generalization validation

Use a small predeclared size ladder, initially around 500 then 1,000 unique
profiles, rather than jumping to full cohorts. Exact sizes, candidate counts,
memory allowance, expected workload and stopping rules belong in the phase plan
before runs. Expansion to another size is conditional on the previous evidence.

Include more than overlapping PreSSMat subsets: geometries with different density,
dimension and noise, a supported separation into multiple components containing
edges, and an additional cohort source only under its separately recorded data
scope. Selection remains outcome-independent. Preserve initial-isolate refusal
until a distinct behavior is specified and tested.

Compare complete native/evaluated-Python trajectories. Use the original-expression
control on a bounded declared set that is computationally feasible, reporting
exactly where it was and was not run. Keep stage diagnostics and final affinity
checks; large final graph agreement alone is insufficient. Measure initialization,
assembly, solver, pruning, affinity, checkpoint and diagnostic resource costs.

Deliverable: scale/coverage report and measured resource envelope.
Exit: no unexplained implementation differences, known failure behavior and a
defensible budget for the next size. A resource failure is reported and redirects
engineering work; it does not trigger automatic expansion or a silent algorithm
change.

## Phase 08 — Evidence-led performance and memory work

Choose work from measured bottlenecks, one change at a time. Candidate work is
buffer reuse and sparse assembly, avoiding duplicate storage, blockwise affinity
construction or kernel application under the same numerical cutoff, and exact
initialization improvements. Mathematical equality alone does not guarantee
unchanged floating-point reductions or pruning decisions; rerun the trajectory
suite and investigate discrepancies.

Keep solver experiments separately labeled. A bounded HiGHS/basis-reuse test is
worth considering only when solver cost dominates and after verifying the API
and applicable reuse conditions. Clarabel data updates should not be assumed to
provide a useful warm start or total-time improvement; phase 02 found no clear
total-time gain. Alternative LP backends may return different optimal scales and
must be assessed through the outer algorithm, not only objective values.

Benchmark equivalent long-lived pipelines with consistent phase boundaries,
outputs, settings and repetitions. If attributing gains to language overhead,
include a direct Python-to-solver condition so CVXPY overhead is distinguishable.
Retain the accepted backend as a fallback/reference. Do not promise a speedup
because the implementation is native.

Deliverable: measured improvement with costs and limitations, or a supported
decision to retain the simpler implementation.
Exit: benefit under the intended workload without unexplained correctness loss.
Approximate initialization, stronger affinity truncation, changed tie rules and
modified pruning belong to the experimental-method phase instead.

## Phase 09 — Portable R-facing release

Test installation and execution on declared supported macOS, Linux and Windows
targets; record compiler/solver combinations and the dependency distribution
strategy. Complete attribution and redistribution inventories. Choose the final
companion-package versus direct-integration design from this evidence. A thin
companion package is the current preference, keeping native solver dependencies
out of dgraphs until the maintenance consequences are understood.

The R interface should return stable specimen/profile maps, graph edges,
components, isolates, scales in input units, affinity or an explicitly defined
kernel operator, numerical reports and provenance. Specify indexing, ownership,
copying, sparse-zero meaning, cancellation and error handling. Verify CLI/R
agreement and account for conversion/peak-memory costs. Build small user examples
that do not depend on private cohort data.

Deliverable: versioned internal release with supported-platform tests and docs.
Exit: reproducible installation, API/output parity, resource-aware cancellation
and independent package review. Public/CRAN release is a separate choice, not a
necessary dependency for internal scientific use.

## Phase 10 — Controlled scientific deployment

Freeze the scientific input contract before application: population, cohort,
visit/window, features/transform, metric, duplicate handling and participant
mapping. Begin with cohort-specific, outcome-independent reference graphs in line
with the approved aims. A pooled fit is an additional specified analysis, not a
default replacement for separate cohort descriptions.

Use the accepted engine, versioned policies and budgets for a bounded application.
Persist accepted native graph/scales/affinities before separate optional
diagnostics. Do not silently bridge components, assign finite intercomponent
geodesics or treat successful layout computation as construction success.
Validate consuming analyses such as graph-conditioned molecular means and
within-context residual covariance separately; an IAN engine is infrastructure,
not validation of those estimators. Participant dependence and assay/visit
selection belong in the scientific analysis specification.

Deliverable: audited cohort artifacts and a precise statement of the supported
scientific use. Exit: reproducible execution within resources and accepted
analysis-specific validation. Historical interrupted-run recovery, new full fits
and production replacement each require their own named scope.

## Phase 11 — Algorithm improvement as a separate research programme

This programme can begin after phases 05–06 provide a stable baseline; it need
not wait for final packaging or deployment. It runs on named experimental policies
and cannot silently change the validated reference mode.

First establish where IAN succeeds or fails against suitable simple graph
baselines under density variation, noise, bottlenecks, nearby branches,
disconnected populations, duplicates and varying intrinsic dimension. Evaluate
neighborhood fidelity, shortcut retention, fragmentation, local-scale behavior,
geodesic distortion where true distances are known, and stability under sampling
or perturbation. Resampling for cohort questions should respect participants;
outcome labels must not tune an allegedly outcome-independent reference graph.
Connectivity, a pleasing embedding or CST concordance is not a universal score.

Select one documented failure mechanism and one change at a time. Potential
families are pruning/calibration rules, explicit degeneracy/isolate behavior,
decision sensitivity/uncertainty diagnostics, and approximate initialization or
kernel computation for otherwise infeasible inputs. Define each hypothesis,
baseline, held-out challenge set, acceptance criterion and computational budget
before comparison. A change that improves speed but changes geometry must report
both. A change that fixes one case but harms another is not an automatic default.

Deliverable: a reproducible comparison and named variant, including negative
results. Exit for promotion: demonstrated benefit relevant to intended use,
acceptable tradeoffs, held-out evidence and independent scientific review.
Keep downstream estimators or biomarker models as separately scoped consumers;
prediction and longitudinal modeling follow the approved project priorities and
later decisions, not the existence of an IAN implementation.

## Coordination, authority and sequencing

The coordinator/implementer maintains a single project status ledger, the next
bounded phase specification, dependencies, source/evidence inventory, decision
log and open limitations. Each phase distinguishes proposed, running, submitted,
accepted and superseded work. Completion of code or tests is not audit acceptance.
Reports use the same short format: question, scope, conditions, results/failures,
interpretation, limitations and durable handoff.

Pawel decides scientific policy, acceptable compatibility tradeoffs, method
promotion, cohort scope and deployment. Within an explicitly authorized phase,
routine implementation, validation and reversible corrections proceed without
repeated permission. New scope, substantially larger compute, production changes
or algorithm-policy changes are separately identified decisions.

An independent auditor reviews evidence and sets the audit scope/verdict. My
coordinator role includes preparing factual handoffs and tracking dispositions;
it does not authorize me to independently audit my own work or restrict an audit
to my preferred questions. No new agent/task, messaging or automation is implied
by this roadmap.

Default dependency order is 05 → 06 → 07. Then measured optimization (08) and
packaging (09) can be prioritized from the scale findings, while research (11)
uses the frozen baseline. Deployment (10) follows the relevant correctness,
operational and interface gates. A build feasibility check or synthetic research
design can run earlier as a bounded subtask; changing the numerical baseline and
algorithm at the same time should be avoided.

Immediate recommendation: obtain the phase 04 independent disposition, settle
the numerical contract in phase 05, and implement the reusable/interruptible core
before escalating input size. Do not reopen an unrestricted solver competition,
port the legacy conic expression solely to chase matching vectors, or start a
full cohort run merely because the small native timings look favorable.

Calendar estimates and a target speedup would be speculative at this point. Each
next phase should have a bounded run plan, resource estimate and explicit exit
condition before authorization; early results determine whether the subsequent
work is needed. The research programme succeeds by resolving its hypotheses,
including a well-supported decision to retain reference IAN.
