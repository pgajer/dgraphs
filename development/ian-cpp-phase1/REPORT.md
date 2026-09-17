# Fixed IAN optimization replay: results and feasibility

The C++ path reproduced the Python/CVXPY solutions on all six selected saved
problems, with all 36 measured solves passing the recorded numerical acceptance
policy. For the three combined-cohort cases, median fresh-process wall time was
**1.08–1.15 times faster** through the native interface, and peak resident memory
was about **53–55% lower**. Solver-reported time was essentially unchanged
(native medians were approximately 0.4–1.1% longer). This supports a narrower
conclusion than a fast full IAN port: avoiding Python/CVXPY reduces overhead and
memory, but does not substantially accelerate these unchanged solver tasks.

This is implementer validation, not independent audit or acceptance. No full IAN
fit, cohort recovery, scientific comparison, package integration or method change
was performed. The [architecture proposal](ARCHITECTURE.md) defines the next
correctness stages and the separate scientific questions.

## What was tested

The experiment replayed stored linear optimization subproblems, not the full
algorithm. Three saved control events came from synthetic uniform-arc and
gap-observation examples; three came from the interrupted combined Hellinger
run. That run contains 4,849 specimens represented by 4,841 unique profiles.
Repetitions measure computational variability, not independent biological
observations. Case selection was committed in [PLAN.md](PLAN.md) before candidate
timing: first uniform-arc initial solve, first gap-observation post-pruning solve,
last gap-observation final-retuning solve, and first/last combined post-pruning
solves plus its last final-retuning solve. All source runs used multiplier 4.5.
Within each phase, ordering is by `(iteration, solve number)`.

| Saved case | Solve | Iteration | Variables | Rows, including bounds | Nonzeros | Isolates |
|---|---:|---:|---:|---:|---:|---:|
| Uniform arc, initialization | 000000 | 0 | 128 | 510 | 764 | 0 |
| Gap observations, after pruning | 000001 | 1 | 128 | 508 | 760 | 0 |
| Gap observations, final retuning | 000002 | 1 | 128 | 508 | 760 | 0 |
| Combined cohort, early pruning | 000015 | 1 | 4,841 | 331,020 | 652,358 | 0 |
| Combined cohort, late pruning | 001867 | 1,853 | 4,841 | 262,908 | 516,134 | 28 |
| Combined cohort, final retuning | 001872 | 1,853 | 4,841 | 262,908 | 516,134 | 28 |

The two gap-observation artifacts are byte-identical: final retuning reused the
same coefficients and solution. Thus the six saved-event cases cover **five
unique numerical problems**, a coverage limitation. They were retained under
the frozen phase-based rule, not replaced after seeing speed measurements.
All identities, source paths, full SHA-256 hashes, dimensions and array dtypes are
in the [fixture manifest](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/fixtures-v1/manifest.json).
Each original NPZ is retained next to its exported binary and trace event.

## The precise reference problem

For a fixed graph and retuning parameter C, the executed `obj='l1'` problem is

\[
\min_{s\in\mathbb R^n} c^Ts,\qquad As\le b,\qquad c_i=1.
\]

Here s contains nonnegative local Gaussian scales in the routine's rescaled
distance units. Let d be the current edge length between i and j, let
`w=C*d`, and let u_i and u_j be furthest-neighbor distances. In stored edge
orientation, the two secant rows are

\[
-(w/u_i)s_i-s_j\le -w^2/u_i-w,\qquad
-(u_j/w)s_i-s_j\le -u_j-w.
\]

The saved A then appends `+I` and `-I`, with corresponding right-hand side u
and zero: `0 <= s <= u`. There are `2*edges+2*n` rows. The objective is the
sum, not the mean, of all scales. No auxiliary absolute-value variables are
needed because of nonnegativity. C is an outer retuning parameter; it is fixed
inside a saved LP. The two source construction paths (parameterized and recycled)
produce these inequalities through their recorded coefficients. Replays consume
those coefficients without reconstructing C, changing edge orientation or adding
bounds a second time.

Distances were preconditioned by dividing by the minimum nonzero distance; the
original IAN routine converts final returned scales back to metric units. These
LPs and objectives remain in saved preconditioned units. An active vertex has
positive graph degree; an isolate has degree zero and upper bound zero. Active
scales must be strictly positive after validation. Tiny signed isolate values
can remain in raw solver output within the residual tolerance; the executed
adapter excludes isolates from affinity divisions. The last scale optimizer
state is not a saved final affinity matrix.

This derivation comes from the frozen executed `pilot_audit.py`, its instrumented
solve sites, and pinned `ian.py` (`getParamConstraint`,
`getParamConstraintFixedC`, `buildOptimizationProblem`). The
[paper's LP relaxation](https://arxiv.org/html/2208.09123v3) supplies methodological
context; this phase tests the actual stored LP rather than proving its
relationship to a continuous manifold.

## Execution and measurement

Python used CVXPY 1.6.7, NumPy 2.2.6, SciPy 1.15.3 and Clarabel 0.11.1 in a new
private Python 3.12.10 environment. The C++17 executable calls the supported
Clarabel C ABI from Clarabel.cpp revision
`0de6259a3edfd5cc041ec42b2148599ce63e73cb`, with Rust core tag `v0.11.1`
(`25540f559592068d0c8a80e46ded1b21760212a1`). The Rust core version matches
Python; compiler and wheel build provenance are not identical.

Both paths use binary64, the same A,b,c, the nonnegative cone for `A*s+slack=b`,
a zero quadratic term, QDLDL, one solver thread, `max_iter=300`, and
`tol_gap_abs=tol_gap_rel=tol_feas=1e-9`. Other common core settings retain their
0.11.1 defaults. The historic settings specified those three tolerances and
iteration cap but left linear-solver/thread choice implicit; this replay makes
QDLDL and one thread explicit on both sides. Python may include optional compiled
features absent from the native build; SDP/alternative factorization backends are
unused here. The [official settings guide](https://clarabel.org/stable/api_settings/)
and pinned core source document the options.

The export checks the full recorded schema: CSR `A_data`, `A_indices`,
`A_indptr`, `A_shape`, and `b`, `c`, `upper`, `active`, `scales`, `residual`,
`normalized`. It validates the bound rows and metadata, recomputes historical
residuals on the six cases, and verifies exact Python and native round trips.
CVXPY canonicalization is also asserted to preserve A,b,c exactly. The C++ client
converts CSR to CSC without changing row order or coefficients.

Each case/path received three fresh-process measured repetitions, serially.
Case order rotates by two positions in each block; backend order alternates by
block/position parity. The complete schedule was written before solving. No warm
start, factorization reuse, full fit or benchmark time limit was used. There were
no interrupted, failed or invalid measured solves. Separate smoke runs solved
only the first selected control once per path; they are excluded from summaries.

The machine was an Apple M4 Max MacBook Pro, 16 CPU cores (12 performance,
4 efficiency), 64 GiB RAM, macOS 26.6.1 ARM64. Native build used Apple Clang 21,
CMake 4.1.1 and private ARM64 Rust/Cargo 1.85.1. C++ flags include `-O3 -DNDEBUG`
with GNU C++17 and no fast-math; Rust uses Release opt-level 3, LTO, one codegen
unit and a committed dependency lockfile. The working build took 24.45 s, plus
0.80 s configuration, separate from all solve timings. The earlier stock build
failed after 72.42 s because Cargo 1.73 could not parse a Rust-2024 dependency of
its unpinned cbindgen installation. Its installed toolchain was also x86_64.
That failure is retained in `setup/build.log`. The working build uses the official
wrapper's shipped C headers without requiring regenerated bindings. Upstream
C-header extension warnings and a libunwind linker warning remain in the
successful build log; macOS runtime smoke and all measured solves succeeded.

Wall time is process launch through exit, excluding parent-side validation.
Child timings separately record imports/startup, input, setup, solve call and
solution output. Python setup includes model construction, canonicalization and
exact-matrix assertions; its solve call includes native solver construction.
C++ setup is native solver construction. They are not identical substage scopes.
Solver-reported time is a nested backend timer including setup work; do not add
it to the measured phases. Python backend setup cannot be extracted separately
from the saved CVXPY result. Parent residual/dual checks and loading for validation
are timed separately, about 0.03–0.04 s for cohort cases.

Memory uses the same parent sampler for both paths: summed resident set size of
the child and observed descendants every approximately 10 ms. It excludes the
parent validator. The table reports the operating system's root-process peak
RSS (`wait4`, bytes on macOS); no descendants were observed. Sampled tree values
are retained separately and can severely undercount submillisecond controls.
They are not exact allocation attribution. Observed solver thread telemetry is
one for native; Python's solver policy is one, with backend thread telemetry
unavailable through its returned object. Process sampling observed at most one
thread; zero in a brief sample means missed observation, not zero computation.
System one-minute load ranged 2.78–3.82; interval CPU samples ranged 0–43.9%.
Zero CPU on short controls is uninformative. Other work was not stopped, the host
was not reserved, and fresh processes do not imply cold operating-system caches.

## Timing and memory results

All cells have three valid repetitions. Values are medians; brackets give the
observed minimum–maximum wall time. Ratios are Python/native median wall times,
not an inferred full-fit speedup.

| Saved case | Python wall s [range] | Native wall s [range] | Wall ratio | Python / native peak RSS MiB |
|---|---:|---:|---:|---:|
| Uniform arc, initialization | 0.726 [0.706–0.731] | 0.0185 [0.0168–0.0188] | 39.25 | 100.4 / 2.34 |
| Gap observations, after pruning | 0.700 [0.675–0.715] | 0.0175 [0.0175–0.0278] | 39.98 | 100.2 / 2.36 |
| Gap observations, final retuning | 0.703 [0.700–0.707] | 0.0167 [0.0149–0.0168] | 42.13 | 100.3 / 2.36 |
| Combined cohort, early pruning | 10.915 [10.835–11.005] | 10.081 [9.884–10.105] | 1.083 | 482.2 / 226.6 |
| Combined cohort, late pruning | 6.120 [6.072–6.209] | 5.313 [5.274–5.325] | 1.152 | 397.0 / 179.2 |
| Combined cohort, final retuning | 6.769 [6.652–6.806] | 5.899 [5.884–5.916] | 1.148 | 397.6 / 179.2 |

| Saved case | Python solver s | Native solver s | Iterations in both paths |
|---|---:|---:|---:|
| Uniform arc, initialization | 0.000704 | 0.000711 | 9 |
| Gap observations, after pruning | 0.000638 | 0.000733 | 9 |
| Gap observations, final retuning | 0.000652 | 0.000634 | 9 |
| Combined cohort, early pruning | 10.0187 | 10.0631 | 48 |
| Combined cohort, late pruning | 5.2376 | 5.2974 | 41 |
| Combined cohort, final retuning | 5.8222 | 5.8786 | 45 |

The large control wall ratios are dominated by Python startup/imports
(approximately 0.63–0.65 s) around an optimization taking less than 1 ms.
This advantage would largely disappear for successive solves inside an already
running Python IAN process. For the cohort cases, Python startup was approximately
0.64–0.71 s, canonicalization/setup about 0.10–0.13 s, while solving took 5–10 s.
No statistical significance or population inference is claimed from three repeats.

[All 36 attempts](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/results-v1/all-attempts.md)
and the [full measurement table](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/results-v1/attempts.tsv)
include separate phases, load, iterations, memory, numerical results and failures.
The generated [case summary](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/results-v1/case-summary.json)
retains unrounded values and ranges.

## Numerical behavior

The independent validator recomputes `max(0,A*s-b)` rowwise, normalized by
`max(1,abs(b),abs(A)*abs(s))`, and recomputes `c^T*s` with compensated summation.
Both normalized constraint error and relative objective self-consistency must be
at most 1e-7. Bounds are rows in A; reported raw bound violations are additional
diagnostics. Status must be optimal, all scales/objective finite, and every
active scale strictly positive. Native `Solved` maps to optimal; reduced-accuracy
statuses are rejected. Finite feasibility and objective self-consistency alone
are not an independent optimality proof.

Across all 36 solves, the largest normalized violation was **4.70e-9**, below
1e-7; largest absolute row violation was 5.87e-9, largest lower-bound violation
4.70e-9, and largest upper-bound violation 3.61e-10. The largest relative
objective recomputation error was 3.08e-15. Both paths gave identical recorded
scale vectors and objectives for every matched repetition, an observed result,
not a demanded bitwise acceptance rule.

| Saved case | Recomputed objective | Maximum normalized violation | Max absolute scale change from historical saved vector |
|---|---:|---:|---:|
| Uniform arc, initialization | 121.6000000025 | 1.95e-11 | 8.97e-9 |
| Gap observations, after pruning | 121.6000000023 | 1.94e-11 | 0 |
| Gap observations, final retuning | 121.6000000023 | 1.94e-11 | 0 |
| Combined cohort, early pruning | 1,286,424.854978 | 1.14e-11 | 1.98e-10 |
| Combined cohort, late pruning | 946,772.839941 | 4.70e-9 | 2.73e-12 |
| Combined cohort, final retuning | 999,828.532111 | 2.03e-9 | 5.77e-6 |

Differences from the historical vector were not clipped or dismissed; values use
the saved preconditioned units. The largest scale relative L2 difference across
all cases was 2.52e-9. Historical execution/model assembly and the new direct
saved-matrix replay are not identical execution paths. No pruning decisions were
replayed to test the consequences of these differences. LP optima can be
nonunique, so matching objective alone would not imply matching scales or
subsequent graph topology.

Both paths saved dual vectors. Independent diagnostics compute stationarity
`c+A^T*z`, nonnegativity of z, dual objective `-b^T*z`, and primal/dual gap.
Largest relative gap was 9.09e-10, stationarity residual 6.96e-9, and dual
nonnegativity violation zero. These provide extra numerical evidence, not a
rigorous interval/exact-arithmetic certificate. Twelve adversarial validation
controls passed: a valid solution is retained, and missing/nonfinite vectors or
objectives, infeasible values, bound errors, nonpositive active values, wrong
shape, wrong objective and reduced-accuracy status are rejected. These tests
exercise the acceptance implementation, not a new set of benchmark optimizations.

## Historical reconstruction and implications

[Primary reconstruction](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/fixtures-v1/historical-reconstruction.json)
reproduces 1,873 solve records marked accepted, graph convergence at iteration
1,853, and successful final retuning (median 1.03336 within 0.1 of one; no cap).
The checkpoint has 126,613 edges, two components with edges (4,811 and 2 vertices)
and 28 isolates. Input array dimensions independently support 4,849 specimens
and 4,841 unique profiles. Neither `graph.npz` nor `affinity.npz` exists.

| Historical timing | Seconds | Meaning |
|---|---:|---|
| Sum of `solver_time` | 29,325.9011 | Backend-reported time across recorded solves |
| Sum of solve `wall_seconds` | 30,160.2784 | CVXPY solve, validation and per-solve export inside the timed wrapper |
| Nested optimization calls | 30,170.0704 | Outer wrapper, also including recorded-constraint construction |
| Worker supervisor duration | 30,650.3188 | Full attempted worker lifetime, including other stages |
| Controller elapsed time | 30,684.3077 | Controller scope including controls/preparation and supervision |

These clocks have different start/end boundaries and overlap; they must not be
added. The phase record places the interruption in connectivity repair after
IAN returned. Its existing 4 GiB safeguard observed about 4.224 GiB RSS and stopped
the worker with exit -9. The unfinished diagnostic explains why a converged graph
trace does not make this an accepted completed fit. The Python tuple-based repair
is a plausible source of the spike; allocations were not individually profiled.

Solver-reported time is about 95.6% of controller elapsed time. Under the strict
assumption that solver work/time remained unchanged, removing *all* other time
would imply only about a 1.046-fold historical speedup. This is an accounting
bound under that assumption, not a controlled benchmark estimate: historical
threading/contention, repeated-call behavior and candidate implementation may
change. The replay results reinforce the case for a later bounded sequence test
of LP-specific reoptimization. They do not justify extrapolating fresh-process
control ratios to a full IAN port.

## Provenance, limitations and unverified claims

The branch started clean at `e7cde950dd86a411f1d41e707392789d33f5617c`.
Fixture export used committed source `6bc73fd`; the successful native build used
`7ab4268`; measured runs used `cba3b90`. The native source and working CMake file
did not change between successful build and measured execution. Later commits
add reporting/summary sources, not changed measured algorithms. The handoff names
the final candidate commit and complete hashes. The final replay sources are
committed under this directory; builds, environments and numerical evidence are
private worker artifacts. [Build/replay instructions](README.md) regenerate them.

Limitations include five unique LPs represented by six saved events, one machine,
three repetitions, a nonreserved host, and no reference-compatible outer loop.
The six historical vectors were independently checked, but all 1,873 historical
solutions were not revalidated; their acceptance count is a raw-trace count.
No full affinity matrix, biological endpoint or independent population evidence
was produced. Binary64 agreement does not prove behavior across compilers or
degenerate optima. Solver settings share the same core defaults, but the Python
wheel's complete compiler/transitive-build provenance is unavailable. Numerical
dual diagnostics do not constitute a formal certificate. Process-tree sampling
can miss short-lived children/peaks, although no child processes were observed;
root high-water marks are the reported memory measure. Startup/disk cache and
uncontrolled concurrent work limit interpretation of small timing differences.

The prototype's trusted fixture parser is not hardened for arbitrary hostile
binary input. Nonoptimal/native malformed output is retained and rejected by the
parent; a production backend needs a stronger structured error interface.
Reference tie/rounding behavior, initial-isolate handling, all-stage checkpoints,
sequence reuse, R/Rcpp ownership and installation on Linux/Windows remain
untested proposals. Upstream license declarations were inspected, but a complete
transitive redistribution assessment was not performed. Earlier failed build and
smoke artifacts remain deliberately available; they are not measured successes.
No public API, production environment, shared-checkout change, cohort input,
auditor workspace or historical evidence was modified by this task.
