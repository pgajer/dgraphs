# Phase 02: execution fidelity and persistent sequences

Authorized by the user's request to follow the phase 1 audit and bounded
next-step proposal. Independent audit of new work remains pending. The small
reference-compatible engine is the following milestone; this phase stops with
its own report and factual handoff. No cohort restart/recovery, full IAN fit,
production mutation, solver sweep, HiGHS implementation or integration.

## Selection fixed before candidate measurements

Use the last eight `post_prune` solve events ordered by (iteration, number), and
the complete final `parameterized` retuning block. Raw trace inspection gives
late-pruning solves 1860–1867 (iterations 1846–1853), and final parameterized
solves 1869–1872 (iteration 1853). The full final phase contains FIVE solves:
1868 is the initial recycled check; the next four are the requested retuning
sequence. Save its metadata and relationship but do not silently call the full
phase four solves. Never select by measured speed or numerical success.

## Discrepancy diagnostics

Reconstruct the final graph's original parameterized CVXPY expression from the
pinned executed-source functions, original Hellinger distances, recorded distance
rescaling, graph edges, saved upper bounds and final C. Compare actual CVXPY
canonical A,b,c, order, shape, structural zeros, numeric differences, solver
settings and cache behavior against the saved-matrix expression before solving.
Hash all controlling source and data. State assumptions about recovered state;
this is one subproblem, not replay of the full historical fit.

Up to five single-solve diagnostic conditions, run serially and separately from
the benchmark: reconstructed/auto/automatic threads (historical explicit options),
reconstructed/auto/one thread, reconstructed/QDLDL/one thread,
saved-matrix/auto/one thread, saved-matrix/QDLDL/one thread. These form controlled
one-factor comparisons of expression, backend and thread policy. Retain failures.
Record actual selected linear solver and thread count, not just requested `auto`.
No changed tolerances. Input reconstruction/canonicalization without solving
is setup. Any further diagnostic condition requires a separately committed,
reasoned plan amendment rather than an undocumented sweep.

## Persistent benchmark

For each recorded sequence, run Python/CVXPY/Clarabel and C++/native Clarabel in
one persistent process with fresh solver construction at each step. Run a second
mode with data updates for final retuning only, where dimensions and sparsity
match. Late-pruning deletes rows, so native update is explicitly unsupported;
no padding or silent fallback is used. Clarabel data updates are not primal/dual
warm starts; the core still invokes its default starting-point procedure.

Use Clarabel core 0.11.1, binary64, QDLDL, one solver thread, max_iter=300 and
all three historical main tolerances 1e-9. Disable presolve and chordal processing
for ALL sequence modes to guarantee the update contract (no SDP cones used).
Keep sparse dropzeros false. Match coefficients, ordering and residual acceptance.
Do not substitute a different solver or relax numerical acceptance for speed.

Three repetitions per sequence/path/mode: two sequences x two cold paths x three
repetitions = 12 jobs / 72 scale solves, plus final sequence x two update paths x
three repetitions = 6 jobs / 24 solves. Total mandatory measured workload is
18 persistent-process jobs, 96 scale solves. Balanced deterministic job ordering
rotates the six configurations by two positions per block, reverses on odd blocks.
Step order always follows the recorded sequence. Smoke tests use small constructed
LPs and are separately labeled. No overlapping measured jobs or compile work.

Persist actual solver-cache/reuse decisions, per-step input, assembly,
construction/update, solve and output times; primal/dual vectors; solver
iterations/timing; load; process-tree samples and root OS peak RSS. Report
sequence-internal time (imports excluded), sums by phase and launch-to-exit time.
No repeated Python import charge within a sequence. Independently recompute
all numerical outputs from original source NPZ coefficients, outside both solvers,
and compare scale vectors, objectives and iteration counts, including failures.
Three repeats are descriptive compute variation, not biological observations.

Commit source before all solve runs. Keep raw artifacts under worker/phase02 in
new namespaces; phase 1 and auditor evidence remain immutable. Label summary-only
checks accurately, carrying audit N1. Final handoff includes limitations, exact
commands, hashes, source revisions and any unresolved discrepancy.
