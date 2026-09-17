# IAN implementation and improvement: project roadmap

Status: phases 01–05 independently accepted for their bounded scopes. Authorized
Phase06A's numerical extraction is supported by audit; its requested CLI schema
correction is implemented and awaiting re-audit. Phase 05
requires no corrective patch. Milestones after 06A
remain proposals requiring their own authorization. Updated 17 September 2026
following the [auditor's roadmap review](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/auditor/roadmap-review-20260917/review.md)
and [Phase 05 independent audit](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/auditor/review-5/audit.md).
Scientific owner: Pawel Gajer. Coordinator and implementer: this task.
Independent audit remains a separate role.

This coordination update follows the frozen Phase 05 submission at
`b2e132562ae61a8849d2c1b8bca317fb805f76b1`. That submission's manifest identifies
the roadmap bytes at that commit. Its evidence, manifest, report, contract and
handoff are not rewritten by this later planning revision.

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
| 04: longer trajectories and readable native stages | Independently accepted as a bounded deliverable; no corrective patch required | Audit reproduced native/evaluated-Python agreement through 182 and 176 pruning iterations, retuning and isolate creation. Original-expression/evaluated-Python intermediate-array limits remain failed on both selected inputs despite equal discrete decisions. |
| 05: numerical contract and decision sensitivity | Independently accepted as a bounded deliverable; no corrective patch required | Audit verified all 1,330 submitted payloads and reproduced 51 executions containing 1,302 fresh solves exactly apart from timing. Native/evaluated agreement passes under IAN evaluated-LP 1.0. Historical intermediate-array failures, incomplete pruning calibration and unresolved diagnostic warnings remain limitations. |
| 06A: reusable core and early interface feasibility | Implementer-complete; independent acceptance pending | Typed in-memory core, optional observation and file/R adapters. Eight complete native traces and twelve boundary probes reproduce accepted traces apart from timing. A fresh dependency build, installed-header C++ client and minimal R call pass. No resume or cross-platform claim. |

The accepted phase 03 baseline is `7d030ff669be9e4a090ec75829c6477c25a7091c`.
The submitted phase 04 candidate is `df4dcb271369d65302fdf62ce6b7e6c4a13fbb32`.
This roadmap does not alter either submission. The
[phase 04 independent audit](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/auditor/review-4/audit.md)
accepts the bounded deliverable while preserving the failed historical-expression
compatibility results. See the
[phase 04 report](../phase04/REPORT.md) and
[handoff](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase04-implementer-handoff.md).

## Phase 05 — Audit closure and numerical contract

The phase 04 audit is accepted as a bounded deliverable and requires no corrective
patch. The user subsequently authorized Phase 05 and its proposed numerical
reference. The [contract](../phase05/CONTRACT.md) now distinguishes:

- The mathematical LP and algorithm policy.
- The chosen numerical execution baseline.
- Observed agreement of intermediate arrays and discrete decisions.
- Historical-expression comparisons that remain failed or untested.

Working decision for this authorized phase: use explicitly evaluated LP coefficients
as the native baseline, with the evaluated Python engine as its implementation reference. Keep
the original-expression control as a historical compatibility diagnostic. This
was authorized with Phase 05; it does not retroactively make
the failed phase 04 array tests pass or prove that future decisions cannot differ.
Keep the frozen baseline tolerances. Any future revised criterion needs its own
justification and prospective tests.

The bounded study is complete and described in the [Phase 05 report](../phase05/REPORT.md).
The [independent audit](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/auditor/review-5/audit.md)
accepts candidate `b2e132562ae61a8849d2c1b8bca317fb805f76b1` for the bounded
numerical-contract and decision-sensitivity scope. It independently verified all
1,330 submitted optimization payloads and reproduced 51 executions with another
1,302 solves, matching submitted traces apart from timing. Calibration results
were reconstructed from saved evidence, not rerun. No corrective patch is needed.
This disposition does not establish general historical equivalence or production
readiness; the frozen submission retains its original pre-audit status wording.

Near-boundary retuning probes change from one solve and three edge deletions to
three solves and two deletions across a tiny change in the supplied multiplier;
all implementations agree within each case. The pruning endpoint calibration did
not bracket a boundary, and its three frozen probes show a nonmonotone margin.
Those limitations remain explicit. The complete holdout helix prunes fifteen
times; the saddle does not prune. No solver settings or tolerances changed.
Python diagnostic dot-product warnings remain unexplained at the library level,
although saved finite values and independent summations agree. This submission
does not claim warning-free execution or arbitrary-input robustness.

Deliverable: completed study, numerical contract and named reference version;
independent disposition is recorded separately. Study completion means all frozen
attempts and failures are accounted for. Implementation acceptance requires the
named numerical/fidelity criteria to pass within the stated scope. Advancement
requires an owner decision accepting remaining limitations for the next use.

## Phase 06A — Reusable core with unchanged numerical behavior

The user authorized this milestone after Phase05 acceptance. The bounded work is
complete; see the [Phase06A report](../phase06a/REPORT.md),
[consumer contract](../phase06a/SCHEMAS.md), and
[factual handoff](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase06a-implementer-handoff.md).
All 560 solver calls are accounted for: 491 saved payloads, including one
intentional invalid-vector rejection, and 69 solver calls in observer-free interface executions checked
through outputs/invariants. The build/R evidence is one-host feasibility only.
The [Phase06A audit](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/auditor/review-6a/audit.md)
requested one parser correction. The [F1 addendum](../phase06a/AUDIT-F1.md)
records 18 passing CLI cases and four additional valid solves with exact
reference traces apart from timing. Independent acceptance is pending re-audit;
the following requirements describe the
submitted milestone, not authorization for additional experiments.

Turn the current prototype into a library with a thin CLI and typed boundaries
for input, graph state, LP/backend, retuning, pruning, affinity and diagnostics.
Separate algorithm policy from file formats and language interfaces. Preserve
numeric operation ordering where it affects the accepted reference contract.

Retain the accepted Phase 05 fixed-state retuning boundary, strict-threshold and
tie cases as regression tests, alongside complete trajectories. The extraction
must meet the existing discrete and numerical comparison rules. Preserve the
warning diagnostic fixtures and track their underlying library cause as a
separate unresolved investigation before qualifying unattended broader use;
suppressing warnings is not a resolution.

Add versioned input/result schemas and structured errors. Collect a named
scientific consumer contract for EXP-038 and EXP-039: discrete adjacency, metric
edge lengths, affinities with support and diagonal conventions, local scales and
units, specimen/profile duplicate mappings, and supplied participant mappings.
If an operator replaces a stored affinity matrix, specify exactly which matrix
it applies and how zeros/support are represented. Participant identities must
come from declared input metadata, never be inferred from profile equality.

After the interface stabilizes, include one clean build in a fresh environment
that does not rely on the development environment's installed dependencies, and
one minimal R call using a public synthetic example. Record dependency setup,
indexing, ownership and data-copy behavior. This small feasibility check does not
qualify a release or authorize installation into a shared production library.
Comprehensive portability and package qualification remain in Phase 09.

Deliverable: reusable core, thin CLI, schemas/consumer contract and a bounded
build/R feasibility record, including any failures. Acceptance for advancement:
the unchanged trajectory suite meets the existing discrete and numerical limits;
interface/build limitations are recorded and adjudicated for the next milestone.
No resumability claim follows from this refactor.

## Phase 06B — Durable checkpoints and resumability

Build on the reviewed core. Add versioned checkpoint schemas, cancellation at
safe boundaries, progress records and resource accounting. Add periodic accepted
iteration checkpoints before implementing resumability. A resumable state must
include the graph, bounds, multiplier/bracket phase, mapping, numerical policy
and required solver bookkeeping; it must reject mismatched input/configuration
or incompatible schema versions.

Declare supported restart boundaries and equivalence before execution. The initial
proposal is restart from a completed accepted iteration, preserving identical
subsequent discrete choices and the frozen numerical comparison limits. A fresh
solver is allowed only if it satisfies that promise. Preserve graph/bounds,
ordering, multiplier and relevant retuning phase, mappings, numerical policy and
all solver bookkeeping needed for it. Do not promise mid-solve restart or exact
byte equality without separate implementation and evidence. Distinguish complete,
partial, failed and resumable states explicitly.

Test uninterrupted versus interrupted/resumed trajectories, intentional process
termination around checkpoint commits, incomplete writes and storage failures.
Never infer restart safety from the existing controlled-exception tests. Keep
optional diagnostics separate from native graph acceptance. Record time/memory
for distinct phases with matching boundaries across implementations.

Deliverable: checkpoint/restart implementation, schema documentation and all
prespecified operational-test outcomes. Acceptance for advancement: truthful
failure states, demonstrated resume equivalence under the declared policy, and
independently reviewed checkpoints. A completed negative test study can require
a correction phase without becoming an unfinished study.

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
Acceptance for expansion: no unexplained implementation differences within the
named fidelity scope, known failure behavior and a
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
Acceptance for adopting a change: measured benefit under the intended workload
without unexplained correctness loss. A completed study may instead retain the
existing implementation and report that no tested change earned adoption.
Approximate initialization, stronger affinity truncation, changed tie rules and
modified pruning belong to the experimental-method phase instead.

## Phase 09 — Portable R-facing release

Choose and explicitly name supported targets from macOS, Linux and Windows;
test installation and execution on those targets. Record compiler/solver combinations and the dependency distribution
strategy. Complete attribution and redistribution inventories. Choose the final
companion-package versus direct-integration design from this evidence. A thin
companion package is the current preference, keeping native solver dependencies
out of dgraphs until the maintenance consequences are understood.

Separate three reproducibility promises: reproduction in the pinned reference
environment; discrete/numerical agreement across each supported environment
under prospectively declared criteria; and byte-for-byte agreement only where
explicitly promised and tested. Do not loosen current limits retrospectively
to hide platform differences. A restricted internal release may support one
validated platform without claiming the others. The early Phase 06A feasibility
check is evidence about interface/build assumptions, not release qualification.

The R interface should return stable specimen/profile maps, graph edges,
components, isolates, scales in input units, affinity or an explicitly defined
kernel operator, numerical reports and provenance. Specify indexing, ownership,
copying, sparse-zero meaning, cancellation and error handling. Verify CLI/R
agreement and account for conversion/peak-memory costs. Build small user examples
that do not depend on private cohort data.

Deliverable: versioned internal release with supported-platform tests and docs.
Acceptance for a named release: reproducible installation, API/output parity, resource-aware cancellation
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

Record two distinct decisions: acceptance of engine graph/scales/affinity
artifacts for a numerical and data scope, and acceptance of the estimator that
uses them for molecular means, associations or biomarkers. Apply the Phase 06A
consumer contract at that boundary. The [EXP-039 revision-2 response](/Users/pgajer/current_projects/ZB/experiments/039-crispatus-neighborhood-multiomics/reports/audit-response-v2.md)
reports refused observed-response fits under its conditioning checks and repeated
immunomics records requiring adjudication. These remain downstream numerical/data
issues; this roadmap neither re-audits them nor treats IAN acceptance as their
resolution. They do not block unrelated core-library engineering. That record is
implementer evidence with independent re-review pending, not an IAN finding.

Deliverable: audited cohort artifacts and a precise statement of the supported
scientific use. Acceptance for deployment: reproducible execution within resources
and separately accepted engine artifacts and analysis-specific validation for the
requested use. Historical interrupted-run recovery, new full fits
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

Add a small known-conditional-mean benchmark when the consuming estimator is
ready. On a declared latent geometry, prescribe a smooth scalar function m(z),
a sampling distribution and a noise model, for example Y=m(z)+epsilon with
E[epsilon|z]=0. Evaluate recovery of that known mean alongside neighborhood and
geodesic recovery. Fix the smoother and its tuning rule in advance so graph
comparisons do not simultaneously change the estimator. Declare evaluation
populations, held-out observations and error measures before execution. Later
clustered-sampling or missing-response variants must specify participant dependence
and the missingness mechanism rather than assume away assay-selection effects.

If latent points are mapped into compositions, distinguish truth in the latent
metric, the induced observation metric and the conditional mean being estimated.
A conditional mean given latent state need not equal a mean given observations
if the mapping loses information. This is a controlled estimator benchmark, not
a realistic synthetic vaginal microbiome claim or a new Phase 05 requirement.
An all-visits descriptive graph also does not establish enrollment-time prediction
performance; those populations and validation designs remain separate.

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
log and open limitations. Each phase records three separate states:

| State | Meaning |
|---|---|
| Study complete | Every frozen attempt, including failures, is accounted for and evidence is handed off. An informative negative result can complete a study. |
| Implementation accepted for a named scope | Independent disposition and the numerical/fidelity requirements support the stated claim. Completion alone does not establish this. |
| Advance or deploy authorized | The owner accepts remaining limitations for a specified next activity or use. Audit acceptance alone does not authorize it. |

The evidence table above records bounded study/disposition status; it grants no
deployment permission. All later acceptance and promotion criteria are separate
from the common study-completion criterion. A negative finding may block a claim
or adoption while leaving the completed study available for review.
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

Default dependency order is 05 → 06A → 06B → 07. The small clean-build/R check
follows interface stabilization in 06A. Then measured optimization (08) and
packaging (09) can be prioritized from the scale findings, while research (11)
uses the frozen baseline. Deployment (10) follows the relevant correctness,
operational and interface gates. A build feasibility check or synthetic research
design can run earlier as a bounded subtask; changing the numerical baseline and
algorithm at the same time should be avoided.

Immediate status: Phase05's numerical contract and bounded sensitivity deliverable
are independently accepted without a corrective patch; authorized Phase06A is
complete with the requested schema-parser correction awaiting re-audit. Native/evaluated
implementation checks remain separate from original/evaluated representation
checks; failed historical arrays remain failed. The study found no discrete
representation divergence, without proving it impossible. Phase06A's extracted
core preserves the tested reference behavior and includes the early clean-build/R
checks. Phase06B checkpoint and resume work has not started; it follows separate
review and authorization. Carry the accepted boundary cases and unresolved diagnostic warnings
forward. Do not reopen an unrestricted
solver competition, port the legacy conic expression solely to chase matching
vectors, or start a full cohort run based on small-example agreement.

Calendar estimates and a target speedup would be speculative at this point. Each
next phase should have a bounded run plan, resource estimate and explicit exit
condition before authorization; early results determine whether the subsequent
work is needed. The research programme succeeds by resolving its hypotheses,
including a well-supported decision to retain reference IAN.
