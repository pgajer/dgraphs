# Phase 07: bounded scale and coverage study

Authorized by Pawel after the Phase06B audit. This plan is frozen before fixture
generation and new solver executions. The accepted engine at
`e31f3f20692e738c6c4ca9c56f8a9f26518c4216` and IAN evaluated-LP 1.0 remain unchanged.
Phase06B audit comment N1 is corrected in the coordinator roadmap only; no old
report or evidence is rewritten. Study completion, independent acceptance and
authorization for subsequent work remain separate decisions.

## Question and prescribed examples

Do complete native and evaluated-Python trajectories still agree at larger sizes
and on different geometries, and what resources do these instrumented clients
require? This is an engineering coverage study, not a scientific validation of
the inferred neighborhoods or a performance competition.

Generate every fixture before running either implementation. There is no search
or selection based on solver performance, pruning or outcomes.

At 500 unique profiles, use four inputs in this order:

1. Density-varying two-turn helix: t=4*pi*linspace(0,1,n)^1.6 and coordinates
   (cos(t),sin(t),0.12*t). This extends the accepted public helix construction.
2. Noisy six-dimensional cloud: independent standard normal coordinates, with
   coordinate scales (1,1,1,0.1,0.1,0.1), seed 2026091707+n. This changes dimension
   and noise structure; it is not an assertion of known recovered geometry.
3. Separated planar lobes: equal-sized uniform disks of radius 0.25, centers
   (-2,0) and (2,0), seed 2026091807+n. Radius is 0.25*sqrt(U), angle is 2*pi*U.
   This challenges removal of between-lobe connections. If multiple components
   containing edges never appear, record a coverage shortfall; do not alter gaps
   or prune manually to manufacture success.
4. All 500 already-declared PreSSMat pilot profiles, supplied compositions and
   Hellinger distances from the same private NPZ used in Phase04. Verify the
   distances from square-root compositions. No additional cohort source, outcomes,
   participant inference or full-cohort fit is introduced.

Only after ALL four 500-profile native/evaluated comparisons complete and pass
the existing numerical/discrete rules within resources, run the three synthetic
families at 1,000 profiles in the same order. A failure at 1,000 stops further
1,000-profile runs. Remaining planned attempts are recorded as gated, not passed.
No size beyond 1,000 is authorized. The ladder has seven fixed inputs and at most
14 principal runs. Run original-expression Python only on the 500-profile helix
and separated lobes (two additional controls); historical array disagreement is
reported separately and is not a native/evaluated implementation failure.

Before the ladder, execute the accepted 120-profile helix in both native and
evaluated Python (two runs) and compare each to its saved accepted trace as well
as each other. This validates the new streaming checker and harness. Run checker
falsification tests on altered saved payloads without invoking the solver.

## Budgets and gates

All engine runs are serial, fresh-process, one thread, one execution per condition
and input, using the existing pinned environment and accepted native executable.
Native checkpoint interval is 100 accepted pruning iterations, with the existing
forced graph checkpoint. Python retains its existing stage-file behavior; these
different persistence costs forbid a language-speedup claim.

Per child: sampled process-tree RSS ceiling 4 GiB; wall ceiling 900 seconds;
output ceiling 2 GiB. Poll RSS/wall at 50 ms and output size/trace accounting at
one second. These are supervisory thresholds, not hard instantaneous OS limits;
overshoot is recorded. At a threshold send SIGTERM, allow at most 5 seconds for
cooperative cancellation, then SIGKILL. Keep all partial evidence. Require 20 GiB
free disk before each run. Whole-study ceilings: 10,000 observed solves, 3,600
seconds of supervised run wall time, 16 GiB output. Reserve each remaining run
under these limits; stop at the boundary. Existing algorithm cap 2,000 pruning
iterations and all retuning/solver limits remain unchanged.

Expected workload is hundreds to a few thousand solves, but this is a planning
estimate, not a measured result. A resource failure or unexplained native/reference
discrepancy closes the expansion gate and leads to a completed negative study.
Do not retune, relax tolerances, change the accepted engine or silently rerun a
failed input. Harness corrections may use a new namespace with explicit accounting.

## Evidence and measurements

Stream full traces rather than retaining all iterations in memory. Reuse frozen
Phase03 field lists, absolute/relative limits and external primal/dual checks.
Check every saved solve, graph degree/component/isolate declarations, final
affinity symmetry, support, diagonals and isolate zeros. Reconstruct final
affinities independently from supplied distances and final scales. Check stage
hashes and native checkpoint payload/trace-prefix hashes after execution.
Retain first discrepancy and preceding state. Stop paired comparisons at a
discrete branching divergence; report subsequent endpoints separately.

Measure identical external wall/process-tree RSS boundaries for both clients,
system load, thread counts and output sizes. Preserve native phase telemetry
and every solve's inherited aggregate `seconds` field. The latter includes LP
assembly, backend execution and validation and is NOT pure solver time. Native
phase labels are observer intervals, not isolated computational kernels.
Initialization, pruning/final-retuning, checkpoint I/O and output intervals are
available only in the native client. Isolated assembly/backend/affinity timings
and per-stage RSS are unavailable in the accepted clients. Explicitly record
this measurement shortfall instead of changing numerical sources to add timers
during a scale-fidelity test. Matching fine-grained instrumentation is a Phase08
prerequisite. Time the separate streaming validation/diagnostic process; diagnostics
occur after preserved native/Python stages. No graph repair or layout is run.

Sources live in phase07 and the coordinator roadmap; generated inputs, raw traces,
failures, commands, resources, checks, report data and a manifest live in
worker/phase07. Freeze source before every new run. Verify prior accepted evidence
read-only, including review-6b, before final handoff. No release, shared installation,
R qualification, recovery of historical cohorts or Phase08 work is included.
