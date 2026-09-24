# Small complete IAN engine: implementation comparison

The native engine completed all four frozen examples and matched every compared
discrete decision in both Python conditions. Floating arrays passed the limits
committed before execution. The failure tests preserved completed checkpoints and
reported later stages as incomplete. These are implementer validation results;
independent audit of this phase is pending.

The strongest limitation is the short pruning history. The three geometric
examples removed no edges; the Hellinger example removed four edges in four
iterations. The nearby-arms fixture therefore did not provide the consequential
pruning originally intended. It was retained without replacement. These results
establish agreement on these inputs, not general IAN equivalence or readiness for
a cohort run.

## Purpose, methods and examples

The accepted phase 02 evidence made complete algorithm comparisons more useful
than another fixed-problem timing exercise. I agreed with the next-step proposal
and implemented its bounded milestone. The standalone C++17 engine processes
supplied distances and specimen feature rows through exact-duplicate mapping,
Gabriel initialization, scale optimization, retuning, volume statistics, pruning,
stopping, final scales and the full small affinity matrix. It does not invoke
Python or consume reference decisions. Optional repair, geodesics and layouts
are outside the construction.

The [committed plan](PLAN.md) froze the executed-source contract, fixtures and
comparison limits. Actual coordinates/compositions, distance matrices and stable
identities were saved before solving. The examples comprise a nonuniform smooth
curve, a warped and jittered two-dimensional patch, two nearby curved arms, and
64 profiles selected by `floor(linspace(0,499,64))` from the existing authorized
PreSSMat 500-profile test input. Neither outcomes nor community state types were
used in selection. These are implementation tests, not biological validation.

Three conditions used each frozen input. The **original-expression Python
control** executed the pinned IAN algorithm and adapter with its parameterized
constraint expression. The **evaluated-LP Python reference** executed the same
loop with explicitly evaluated linear-program coefficients. The **native
engine** implemented that evaluated formulation. The first comparison measures
effects of reformulation; the second measures effects of implementation.

The Python conditions execute the retained IAN source with observation hooks and
its compiled Cython Gabriel function. Inactive plotting/approximate-path imports
are removed to load it in the isolated environment. All conditions use Clarabel
0.11.1, explicit QDLDL with one thread, fresh solver construction, binary64,
1e-9 feasibility and gap tolerances, and disabled presolve, chordal processing and
sparse zero dropping. These controlled settings do not recreate all historical
defaults. Algorithm settings include the C3 spread estimate, 4.5 standard
deviations, the existing threshold floor and conditional cap, and 2,000 outer
iterations. No solver update, alternative backend or modified pruning rule was
introduced.

Exact comparisons cover maps, ordering, graph structure, degrees, active sets,
LP structure, retuning values/brackets, candidate order, removals, isolates,
components and stopping decisions. For each floating entry, the limit is
`atol + rtol * max(abs(left), abs(right))`. Distance and LP-coefficient limits
are 1e-12 absolute and 2e-14 relative. Scale limits are 1e-7 absolute in internal
distance units and 1e-7 relative; the absolute allowance is divided by the
distance rescaling for original-unit outputs. Ratios, thresholds and affinities
use 1e-7 absolute and relative limits. Affinity support, diagonals and isolate
masking must match exactly. No limit was relaxed after execution.

## Complete trajectories and numerical results

All three conditions produced the following results. A pruning iteration means
an iteration that actually removed edges; solve counts include initial and final
retuning attempts.

| Example | Profiles | Initial → final edges | Pruning iterations | Solves per condition |
|---|---:|---:|---:|---:|
| Nonuniform smooth curve | 64 | 63 → 63 | 0 | 2 |
| Variable-density patch | 80 | 170 → 170 | 0 | 2 |
| Nearby curved arms | 96 | 142 → 142 | 0 | 3 |
| PreSSMat Hellinger subset | 64 | 278 → 274 | 4 | 9 |

Each condition has 112 trace events across the four examples. All eight paired
trajectory comparisons passed: four original-expression versus evaluated Python,
and four evaluated Python versus final native. All ordinary final graphs have
one component and no isolates. Final graph equality was accompanied by checks
of every recorded intermediate event, including unsuccessful retuning attempts.

Between evaluated Python and native, the largest scale difference was
6.04e-14 in internal distance units, the largest ratio difference was 1.24e-14,
and the largest final affinity difference was 1.47e-15. Distances, upper bounds
and sparse matrix entries matched exactly; the largest right-hand-side
coefficient difference was 8.88e-16. Effective threshold differences were at most 1.78e-15.
All discrete choices matched exactly.

Changing the Python constraint representation produced a larger intermediate
scale difference: at most 4.82e-7 in internal units on the patch. This passed the
combined absolute-plus-relative scale limit; it is not below an absolute-only
1e-7 limit. Ratio differences were at most 2.83e-8 and threshold differences at
most 7.34e-8. Discrete choices still matched, and the final affinity matrices
were identical. Those final solves use the shared recycled-LP expression.

Raw numerical checks recomputed objective, primal feasibility, bounds, projected
LP dual stationarity, nonnegativity and relative gap outside solver status.
The complete phase contains 81 optimization payloads: 48 initial ordinary
solves, six targeted-stage solves including the supplement, eight operational
injection solves, 16 final native verification solves, and three forced-cap
solves. One payload was deliberately corrupted before acceptance. All other 80
passed both primal and dual checks. Maximum normalized primal violation was
1.30e-9, objective discrepancy 1.88e-15, dual stationarity residual 5.04e-9 and
relative dual gap 9.02e-10, against 1e-7 check limits. Maximum absolute primal
violation was 9.54e-8. The invalid payload was rejected before volume evaluation
or pruning.

The [generated tables](</Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase03/analysis-v1/tables.md>)
give each condition's results. The accompanying
[raw analysis](</Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase03/analysis-v1/results.json>)
contains every payload check and comparison maximum.

## Boundary cases and durable failure states

Stage tests cover exact duplicates including signed zero, distances immediately
below/at/above the float32 Gabriel boundary, ordinary and median-override ties,
threshold flooring and conditional capping, tied neighbor removal, and explicit
disconnected adjacency with an isolate. They also compare the numerical affinity
cutoffs, underflow zeros, diagonal, symmetry, range and isolate rows. The Python
tests execute the original relevant functions, including the extracted nested
pruning function. The initial stage bundle passed 29 checks. A separately
committed supplemental case increased this to 31 checks and demonstrated that
a threshold above 5 remains uncapped when its conditional guard is false.

Malformed, negative, asymmetric, nonfinite, single-profile, all-duplicate,
near-distinct and empty-input guards were exercised through 14 Python/native
refusal processes across seven cases. Fewer than two unique profiles are unsupported upstream; the
raw single-profile reference failure is retained. Initial isolated vertices are
also explicitly unsupported for complete runs because the original initial state
is undefined there. The disconnected downstream-stage test does not establish
full-run support for that initial state.

Native graph, final scales and affinities are separate atomic stages, each with
input/configuration/source hashes and stable identities. The implementation
flushes the temporary file, renames it and flushes the containing directory.
The tests produced these expected nonzero exits:

| Injected failure | Graph durable | Scales durable | Affinity durable | Overall complete |
|---|---|---|---|---|
| Invalid solver vector before downstream use | No | No | No | No |
| After graph checkpoint | Yes | No | No | No |
| After scale checkpoint | Yes | Yes | No | No |
| After affinity checkpoint | Yes | Yes | Yes | No |

Earlier artifact hashes remained identical across the applicable failure tests,
and no temporary stage files remained. These are controlled exception tests;
they do not simulate power loss or disk exhaustion. A separate cap diagnostic
forced the outer limit to one on the unchanged Hellinger fixture. All three
conditions made the same first-iteration decisions and refused completion
without publishing a converged graph.

No ordinary trajectory divergence occurred. Two no-solve adversaries altered
copied traces, one removal and one scale array. The comparator detected each
first affected event and saved the preceding complete state and decision margins.

## Corrections, diagnostics and limits

The first native build failed because `<set>` was missing; the log remains in
`build-v1`. The include was committed before the successful `build-v2` and every
numerical run. Later code inspection found that native cap refusal reported the
incremented loop counter instead of the last visited iteration. That label was
corrected without changing ordinary numerical behavior. The final `build-v3`
reproduced all four earlier native primal vectors, dual vectors and affinities
exactly and passed the forced-cap test. Initial runs and both additions remain
separately identified. The finalizer, report and adversarial comparison checks
were added after numerical execution; the final executed engine/reference source
is unchanged.

Resource records are diagnostic. On this Apple M4 Max/macOS host, canonical
Python process times were 0.67–0.82 seconds with 111–113 MiB peak resident memory;
native times were 0.028–0.277 seconds with 4.0–5.4 MiB. Internal engine elapsed
times and optimization-path times are also retained. Fine-grained preprocessing,
pruning and affinity phase timings are unavailable. Native optimization timing
includes coefficient assembly that precedes the corresponding Python timer.
Process startup, loading and instrumentation matter greatly at this size; memory
sampling can miss short native processes, so the table uses the OS root-process
peak rather than the sampled process-tree peak. No repeated timing was run and
no speed or memory-benefit estimate for larger complete engines is inferred.
The phase 02 persistent-client conclusions remain a separate experiment.

The implementation retains dense distances and affinities and has only a macOS
build. Full initial-isolate behavior, long pruning histories, arbitrary tie
configurations, other platforms, solver updates and cohort-scale resource use
remain unverified. The original-expression traces retain projected LP vectors
and conic dimensions, but not auxiliary conic-coordinate vectors. The loaded
retained Cython binary is hashed rather than rebuilt here. Reference and native
paths can share a mistaken interpretation despite these checks. No R/package
integration, production modification, cohort recovery or larger run was made.

The [build and reproduction guide](README.md), private
[command record](</Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase03/commands.md>)
and final evidence manifest accompany the factual handoff. Work stops at this
bounded submission for independent audit.
