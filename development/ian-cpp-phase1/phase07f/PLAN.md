# Phase 07F: bounded 1,000-profile scale and quadform coverage

Pawel authorized the proposed Phase07F after independent acceptance of Phase07E
without findings, and suggested including dgraphs quadforms of dimensions 2–5.
Base: eac10a31a66da10daedf175093a8b6d2e7202cd1. This plan precedes new fixture
construction and execution. Study completion, independent acceptance, policy
adoption and further expansion remain separate decisions.

## Fixed numerical implementation

Reuse the accepted Phase07E native executable, Python reference and configuration
without rebuilding or changing their sources. Policy:
`IAN evaluated-LP retry units11 almost 0.1`. Ordinary settings, one fresh normalized
retry, status/finite/dimension/positivity checks and original-unit 1e-7 acceptance
limits remain unchanged. Verify binary/source/configuration/dependency identity.
The independently audited Phase07E 500-profile panel is a reused prerequisite,
not a new execution. No repetition of its full 50-execution schedule is planned.

## Prespecified input schedule

Generate and freeze all seven 1,000-profile inputs before running any engine.
Execute them in the following order, native then evaluated Python for each:

1. Density-varying two-turn helix: reuse the exact unexecuted Phase07 fixture.
2. Noisy six-dimensional cloud: reuse its exact unexecuted Phase07 fixture.
3. Separated planar lobes: reuse its exact unexecuted Phase07 fixture.
4–7. Quadforms with intrinsic dimensions d=2,3,4,5, in ambient dimension d+1.

Only the new numerical-policy declaration is added to the three original fixtures;
features, distances, identifiers and provenance stay unchanged. Their original
formulas/seeds are specified in phase07/PLAN.md and phase07/fixtures.py.

The quadforms use the existing dgraphs `synthetic.quadform` and
`sample.synthetic.geometry` functions sourced read-only from this pinned worktree.
For dimension d, take one symmetric form
A=diag((-1)^(j-1) * 0.5/sqrt(d), j=1..d), canonical frame, zero offset and
independent uniform latent coordinates in [-1,1]^d. Seed=2026091700+d using the
API's recorded L'Ecuyer-CMRG/Inversion/Rejection RNG plan. Embed as (u,u^T A u).
This fixes the form's Frobenius norm at 0.5 across dimensions; it does not hold
all geometric or sampling characteristics constant. Sampling is uniform in
latent coordinates, not in surface area. No added observation noise, selection
by observed pruning, seed search, curvature sweep or random rotation is included.
The user is asked to clarify intrinsic versus ambient dimension before generation;
in absence of a correction, the stated intrinsic interpretation is used.

Preserve R source hashes, full sample/specification/RNG RDS, session information,
and lossless binary64 latent/embedded coordinates. Independently reconstruct the
quadratic coordinates, check bounds/dimensions/uniqueness and compute symmetric
Euclidean distances in ambient space for IAN. These are engineering coverage
inputs; no geodesic oracle, graph-quality claim or conditional-mean benchmark is
part of this phase.

## Comparisons, failures and restart

At most fourteen principal runs. Advance to the next input only after both paths
complete, original-unit certificates and topology/affinity reconstruction pass,
and full traces match under the frozen numerical/discrete allowances. A shared
numerical refusal is a preserved negative result; after completing its paired
comparison, gate remaining inputs. A resource failure gates remaining execution
immediately, including an unstarted counterpart. An unexplained implementation
difference also closes the gate. Do not add settings or statuses, loosen a
threshold, change inputs or silently repeat a failed run.

Record ordinary/retry counts and raw statuses, minimum acceptance margins and
original-unit residuals, all pruning decisions, graph components/isolates, final
scales and affinities. Preserve every rejection. Retain a new terminal LP in the
difficult-problem collection as a new versioned entry if encountered; no extra
remedy solve is authorized. Inspect native checkpoints and trace-prefix hashes.

After the principal schedule, if a completed native run has at least one pruning
step, select the first such input in the prescribed order. Cancel a fresh run
after its first pruning step and resume. Require the concatenated trace and final
result to match its uninterrupted counterpart exactly apart from timing. This is
at most two additional native executions; if no suitable complete fit exists,
record the restart test as unavailable. A later panel failure does not invalidate
an earlier completed case's bounded restart test, subject to remaining resources.

Run no-solve falsification checks of the reused numerical/trace validators and
fixture checks before principal execution. Preserve original failures and partial
artifacts with truthful completion flags. A bounded negative study may complete
without satisfying expansion criteria.

## Resource and scope bounds

Serial fresh-process, one-thread solver runs. Per child: sampled process-tree RSS
4 GiB, wall 900 seconds, output 2 GiB; total: 10,000 actual attempts, 3,600 guarded
child seconds, 16 GiB output. Require 20 GiB free before execution. Use the accepted
50 ms supervisor, one-second output/solve scans and five-second kill escalation;
report any overshoot. Keep checkpoint interval 100 and preserve graph/scales/
affinity before optional diagnostics. Measure child wall/RSS/output and inherited
native phase intervals and solve-wrapper time; do not call them isolated solver
cost or comparable language speedups. Fine-grained instrumentation belongs to
Phase08. Fixture preparation and pure postprocessing are separately identified.

No source/dependency installation, production adoption, 1,000-profile real cohort,
larger synthetic size, original-expression port, alternative backend, always-
normalized first attempt, package/R qualification, graph repair, layout, deployment
or merge. New source only in phase07f and coordinator/ROADMAP.md; evidence under
worker/phase07f, handoff alongside. Existing sources, historical evidence and all
auditor directories remain read-only. Commit executable source before running,
freeze evidence after validation and stop with the factual report/handoff.
