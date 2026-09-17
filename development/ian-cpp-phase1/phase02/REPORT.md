# IAN execution fidelity and persistent-sequence results

The large historical/replay discrepancy is reproducible in Python and is explained
by constraint representation and solver backend/thread selection. With Python
startup paid once per sequence, native Clarabel has essentially the same running
time as Python/CVXPY/Clarabel on these examples, while using substantially less
resident memory. Solver-object updates save setup work but do not establish a
useful total-time advantage here. All 96 measured solutions and six diagnostic
solutions pass external primal and dual checks. Full IAN equivalence remains
untested; this is an implementer result awaiting independent review.

## What was tested

This follows the accepted fixed-LP replay and its
[bounded next-step proposal](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/auditor/review-1/next-steps.md).
The question is whether a native implementation saves meaningful repeated-solve
cost after resolving a large mismatch between historical execution and replay.
The examples are saved optimization subproblems from the interrupted combined
Hellinger run, not new cohort fits or independent biological observations.

Selection was committed before timing: the last eight consecutive post-pruning
solves, at pruning iterations 1846–1853 (saved events 1860–1867), and the four
parameterized final-retuning solves (events 1869–1872). The full final phase has
five solves: event 1868 is an initial recycled check, preserved as context but
excluded from the specified four-step sequence. All problems contain 4,841 scale
variables. The pruning window loses two inequality rows and four coefficients
per step, from 262,922 rows/516,162 coefficients to 262,908/516,134. Retuning keeps
the latter structure and changes coefficients. Exported coefficients and metadata
round-trip exactly; the [fixture manifest](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase02/fixtures-v2/manifest.json)
records all identities and hashes.

Six separately labeled, single-solve diagnostics reconstruct the historical final
state and vary parameter evaluation, backend and thread policy. Then eighteen
serial persistent-process jobs cover three repetitions of each applicable
sequence/path/mode combination, totaling 96 measured solves. Fresh construction
is tested for both sequences; supported data updates are tested only for final
retuning. Changed dimensions are explicitly refused, with no silent fallback.
Ten small setup optimizations and four no-solve adversarial checks are separate.

## The historical discrepancy

The original CVXPY expression contains a squared retuning parameter. Its default
conversion adds a variable and a three-dimensional second-order cone to the
otherwise linear problem. Evaluating that parameter first yields exactly the
saved LP coefficients. The [execution-fidelity note](FIDELITY.md) gives the
projection proof, original-source details, six conditions and all assumptions.

| Same final state, different execution condition | Solver seconds | Iterations |
|---|---:|---:|
| Historical observation; actual backend/threads unrecorded | 415.053 | 133 |
| Reconstructed original expression, automatic faer / 16 threads | 372.090 | 133 |
| Same original expression, faer / one thread | 30.606 | 133 |
| Same original expression, QDLDL / one thread | 17.118 | 133 |
| Evaluated saved LP, QDLDL / one thread | 5.739 | 45 |

The automatic reconstruction reproduces the historical scale vector **exactly**.
A separate control evaluates parameters before converting the original expression;
it matches the saved-LP canonical data hash and restores 45 iterations. Both this
control and the saved-LP automatic-backend condition select one-thread faer and
take about 9.08 seconds. Thus representation, linear-system backend and threading
all contribute; translation to C++ does not explain the historical/replay gain.
The source creates a fresh CVXPY problem for each retuning value, so it does not
support a historical solver-cache reuse explanation.

These are controlled single observations. The actual historical canonical
matrices/backend/thread state were not saved, and historical contention remains
unknown. The reconstruction's exact numerical agreement is strong corroboration,
but it does not recover or replace the original execution record.

## Persistent-process results

Both clients use the same recorded LPs, Clarabel 0.11.1, binary64, explicit QDLDL,
one solver thread, 300 iterations and the three original 1e-9 tolerances. Presolve
and chordal processing are disabled in **both** fresh and update modes, with sparse
dropzeros false, to guarantee supported updates. This differs from historical
preprocessing defaults and is reported as a controlled benchmark condition.
Python builds and canonicalizes a new CVXPY model at every step, then invokes
Clarabel's public constructor or update API. A fully cached CVXPY model and direct
Python Clarabel without CVXPY are not benchmarked.

Sequence time includes loading, assembly, solver construction/update, solving,
vector output and between-step cleanup. Imports are excluded; the separate
launch-to-exit process measurement includes startup and shutdown. Each cell below
is the median of three jobs, with the observed sequence-time range in brackets.
Peak memory is OS root-process high-water resident memory, in MiB (2^20 bytes).
All jobs had one observed process and one observed thread.

| Sequence and mode | Python sequence seconds | Native sequence seconds | Python peak MiB | Native peak MiB |
|---|---:|---:|---:|---:|
| Eight late-pruning solves, fresh | 44.702 [42.653, 45.286] | 44.178 [42.580, 44.287] | 431.6 | 205.6 |
| Four final-retuning solves, fresh | 23.407 [23.283, 24.376] | 22.991 [22.493, 23.566] | 416.0 | 180.8 |
| Four final-retuning solves, updates | 22.836 [22.829, 22.978] | 23.057 [22.606, 23.152] | 466.0 | 183.5 |

Python/native median time ratios are 1.012, 1.018 and 0.990, respectively: a near
tie with overlapping observed ranges, not a demonstrated substantial native speed
advantage. Native median peak memory is 52.4%, 56.5% and 60.6% lower. The common
20 ms process-tree sampler gives corresponding reductions of 52.1%, 55.1% and
60.3%; its lower peaks illustrate sampling limitations. These are memory costs of
these clients, not intrinsic lower bounds for either language or full IAN.

Updates reduce four-step setup/update wall time from 0.738 to 0.291 seconds in
Python and from 0.605 to 0.158 seconds natively. Total sequence time improves only
about 2.4% in Python and is about 0.3% worse natively, within observed variability.
The summed iteration count changes from 181 (43,45,48,45) to 182 (43,44,49,46).
Clarabel preserves initial equilibration and solver structure during updates but
starts each solve through its default starting-point procedure; this is **not**
reuse of the previous primal/dual solution as a warm start. Late pruning changes
shape, so this update mechanism is not used there.

The [generated tables](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase02/analysis-v1/tables.md)
contain all 18 jobs, process times and phase breakdowns. The
[full results](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase02/analysis-v1/results.json)
retain every step, comparison and resource record. Phase medians need not sum to
the median total. Per-step vector-output timing excludes writing its JSON metadata;
sequence time includes it. Backend-reported times overlap wall phases and retain
initial setup during updates; they are not added to derive sequence totals.
External validation takes another 0.14–0.47 seconds per job in the parent and is
reported separately, outside child time and memory.

## Numerical checks and failures

The external checker reads original saved NPZ coefficients, not just exported
fixtures or solver summaries. It requires optimal status, correctly shaped finite
scales/objective, positive active scales, maximum normalized inequality violation
at most 1e-7, and relative objective recomputation error at most 1e-7. Bound rows
are included in the inequalities. Additional LP dual checks require stationarity
and nonnegativity errors at most 1e-7 and relative primal/dual gap at most 1e-7.
These are numerical certificates at stated tolerances, not an exact-arithmetic
proof of optimality.

All 96 measured and six diagnostic raw solutions pass. Across measured solutions,
the largest normalized primal violation is 4.97e-9, objective recomputation error
3.32e-15, relative primal/dual gap 9.61e-10 and stationarity error 7.35e-9. No
negative dual value was observed. Python/native scale vectors are bitwise equal
in all 48 matched comparisons within the same mode; all 64 comparisons of later
repetitions against the first repetition are also bitwise equal.

Fresh construction and updates differ by up to 1.295e-5 in recorded scale units
(relative vector difference at most 1.03e-9). Against historical scales, the
largest measured difference is 2.753e-5 (relative vector difference at most
4.21e-9). Small fixed-LP differences can still affect later threshold or tie
choices; no pruning trajectory or final affinity comparison has been performed.

There were no diagnostic or measured-solve failures. The eight analytic small-LP
checks passed, both changed-shape update attempts were refused after their first
valid solve, and missing, nonfinite, infeasible and reduced-status outputs were
rejected. The initial preparation attempt did fail when it assumed matching
canonical dimensions. Its partial exports and traceback remain under
`fixtures-v1` and `setup/prepare.log`; a committed correction produced canonical
`fixtures-v2` without executing an optimization. Nothing overwrote that failure.

## Interpretation, limitations and next milestone

Use explicitly evaluated LP coefficients, QDLDL and one solver thread as the
candidate optimization baseline for the next small engine, with fresh solver
construction first. Keep the original-expression reference available for
iteration-by-iteration comparison. The evidence does not justify making data
updates the default, nor does it establish a drop-in replacement for the existing
IAN trajectory. HiGHS/basis reuse was optional and was not implemented or tested.

The next milestone remains a small complete reference-compatible loop: duplicate
maps, distance preprocessing, float32 Gabriel boundaries, retuning, volume ratios,
thresholds/ties, pruning, isolates/components, stopping reasons and final
affinities. Durable graph and final-scale/affinity checkpoints must precede
optional diagnostics, with injected downstream failures demonstrating survival
and truthful completion fields. None of that engine, a larger cohort comparison,
R/Rcpp integration or recovery of the interrupted fit is included in this phase.

Measurements used one Apple M4 Max host (16 cores, 64 GiB), macOS 26.6.1,
Python 3.12.10, CVXPY 1.6.7, NumPy 2.2.6, SciPy 1.15.3 and Clarabel 0.11.1.
Native code uses Apple Clang 21, CMake 4.1.1, C++17 Release/-O3 and the unchanged
phase 1 pinned Rust-backed C ABI library. Configure/build took 1.46/4.84 seconds,
separate from measurements. Official headers emitted extension warnings and the
linker emitted the retained libunwind warning; build and execution succeeded.
Portability outside this ARM64 environment is untested.

The host was not reserved: measured whole-system CPU use ranged from 15.4% to
41.3%, and one-minute load from 2.43 to 5.76. The monitoring parent also consumes
CPU. Three repeats describe local variation; they do not support strong timing
inference. The memory comparison excludes distance reconstruction, full graph
initialization, affinity construction and the diagnostic that exhausted the
historical run's 4 GiB allowance. No biological validity, cohort comparison or
outcome-prediction claim follows from these checks.

## Evidence and audit response

Audit finding N1 is addressed by accurately labeling the phase 1 helper's
36 **summary-row checks**; raw validation remains separate. The
[audit response](AUDIT-RESPONSE.md) and new setup record preserve that distinction.
Original phase 1 generated evidence and the auditor's directory remain unchanged.

[Build and reproduction instructions](README.md), [frozen plan](PLAN.md),
[exact execution commands](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase02/commands.md)
and the [phase 2 handoff](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase02-implementer-handoff.md)
identify revisions, raw bundles, hashes and omitted validation. Sources are
isolated under the assigned prototype directory. No production environment,
shared checkout, scientific rule or historical result was changed.
