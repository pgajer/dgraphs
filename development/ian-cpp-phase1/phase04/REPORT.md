# Longer IAN histories: native agreement and representation sensitivity

The native implementation agrees with evaluated-LP Python through two much longer
histories: 182 and 176 pruning iterations, including retuning and newly isolated
vertices. Both implementation comparisons passed the unchanged limits. The
original-expression Python control made the same discrete decisions, but its
intermediate scale and volume arrays exceeded the prespecified limits on both
inputs. Strict three-condition numerical compatibility was therefore **not**
established. This is a substantive result of the additional coverage, not a
passed comparison with a revised tolerance.

The bounded work is complete and submitted for independent audit. The four
accepted examples retain exactly the same native numerical outputs. Graph
checkpoints now contain their unit conversion directly. No cohort restart,
production change, new solver or algorithm modification was made.

## Purpose, selection and controlled conditions

Phase 03 established a functioning small engine but exercised only four pruning
iterations on one ordinary input. This extension asked whether agreement persists
through repeated graph changes and retuning. The [plan](PLAN.md) froze six actual
inputs and an original-expression-only selection rule before execution. All
candidate bytes, identities, reference failures and complete traces were to be
retained; no search extension or selection by native agreement was allowed.

The two geometric candidates were a warped 200-point grid with fixed jitter and
240 points on nearby arcs with opposing density gradients. Four Hellinger inputs
used 128, 192, 256 and 300 profiles selected deterministically from the already
authorized PreSSMat 500-profile test input by evenly spaced profile indices.
Compositions, supplied distances and identities were saved and checked. No
outcomes or community state types entered selection.

The target was at least ten pruning iterations and at least one additional solve
for retuning during pruning. An additional solve means a solve beyond the first
within an outer iteration after initial graph construction; initial and final
weighted retuning are counted separately. Successful candidates were ranked by
target reached, pruning iterations, additional retuning solves and then frozen
input order. The top two were selected before inspecting native agreement.

All six original-expression controls completed and passed external primal/dual
checks. The search produced:

| Reference candidate | Profiles | Pruning iterations | Edges removed | Additional retuning solves during pruning | Selected |
|---|---:|---:|---:|---:|---|
| Variable-density patch | 200 | 1 | 1 | 0 | No |
| Nearby arms with density gradients | 240 | 9 | 9 | 0 | No |
| PreSSMat Hellinger subset | 128 | 36 | 36 | 0 | No |
| PreSSMat Hellinger subset | 192 | 100 | 100 | 3 | No |
| PreSSMat Hellinger subset | 256 | 182 | 238 | 11 | Yes |
| PreSSMat Hellinger subset | 300 | 176 | 228 | 8 | Yes |

This selection deliberately favors coverage. The two selected inputs overlap and
come from one source; they are not independent biological replicates or a
representative performance sample. The unselected attempts remain evidence of
the search, including geometric examples with less adaptive behavior.

Each selected input was compared under the original-expression Python control,
evaluated-LP Python reference and evaluated-LP native engine. The search control
traces were reused, so selection did not cause a repeated original solve. The
Python references, compiled Cython Gabriel function and comparison limits are
unchanged from phase 03. Every condition uses fresh Clarabel 0.11.1, QDLDL with
one thread, 1e-9 solver feasibility/gap tolerances, disabled presolve/chordal
processing and disabled sparse zero dropping. The algorithm settings and
2,000-iteration cap are unchanged. These are controlled comparisons, not a
recreation of all historical defaults.

## Full implementation and topology comparisons

The 256-profile input required 195 solves per condition and produced 1,506 trace
events; the 300-profile input required 189 solves and produced 1,461 events.
Evaluated Python and native agreed on every discrete comparison: graph edges,
degrees, active sets, candidate order, edge removals, retuning multipliers and
brackets, topology and stopping decisions. All intermediate floating arrays
passed the frozen limits.

Maximum internal-scale differences were 1.78e-8 and 4.12e-9 respectively. Maximum
volume-ratio differences were 7.58e-9 and 3.12e-10. Distance matrices, upper
bounds and sparse matrix entries were identical; the maximum LP right-hand-side
difference was 1.42e-14. Every final affinity entry was identical between
evaluated Python and native for both inputs. Across intermediate weighted
retuning attempts, the largest affinity difference was 9.44e-16.

The 256-profile graph developed isolates after pruning iterations 57, 61 and
167, ending with three isolates and one component containing edges. The
300-profile graph developed isolates after iterations 78 and 145, ending with
two isolates and one component containing edges. Iteration indices here are
zero-based. These transitions occurred in the reference and matched in all three
conditions. Component labels, degrees and isolate identities were reconstructed
from every saved transition. No disconnectedness was forced or repaired.

This extends coverage to isolates created during supported construction. It does
not remove the existing limitation on complete runs beginning with isolates,
and it does not test a transition into two separate components both containing
edges. The retained explicit disconnected-stage fixture covers downstream
calculations for that separate case.

## The original-expression comparisons remain failed

The first comparison stopped at the 256-profile input before selected native
execution. The first failed entry occurred at pruning iteration 3, in a
parameterized solve. At profile index 246, the original and evaluated scales
were 2.7067762095 and 2.7067728355 in internal units. Their difference,
3.374e-6, exceeded the combined allowance of 3.707e-7 by a factor of 9.10.
The subsequent volume ratio exceeded its allowance by a factor of 15.87.

Both controls solved identical projected LP coefficients with accepted primal
and dual residuals. The original canonical problem had 257 coordinates and a
three-dimensional second-order cone; the evaluated LP had 256 coordinates and
no such cone. Clarabel took 42 versus 20 iterations at this solve. The controls
differ only in representation, so this numerical difference is observed entirely
within Python. It is not evidence of an error introduced by C++ or proof of
exact LP nonuniqueness.

The next median-ratio retuning evaluation was 0.824 outside the target tolerance,
and both controls followed the same retuning sequence. At that outer iteration's
pruning decision, the closest volume ratio was about 0.02098 from the threshold;
both selected and removed the same edges. Five trace events exceeded array
limits across the full 256-profile history. All discrete decisions and its final
affinity matrix agreed exactly.

After retaining that first failure and a committed no-solve diagnosis, the
remaining fixed comparisons continued in a new namespace. No source arithmetic,
input, solver setting or tolerance changed, and the completed evaluated-Python
run was reused. On the 300-profile input, the first failure was already in the
initial volume calculation: a ratio difference of 1.279e-6 against a 4.651e-7
allowance. The closest initial ratio to the pruning threshold remained about
0.008679 away, and the candidates agreed. Nine trace events exceeded limits.
The largest internal-scale difference anywhere was 2.482e-5; the largest volume
ratio difference was 2.771e-6. All projected LP data and discrete decisions again
agreed. The final affinity difference was 2.67e-10, within the affinity limit and
with exactly matching zero support.

The [retained first diagnosis](</Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase04/representation-diagnosis-v1.json>)
and per-input continuation diagnoses contain first differing events, complete
preceding states through the comparator, coordinate-wise allowances and decision
margins. The final report preserves both failed representation outcomes. Matching
graphs and small final differences do not erase intermediate incompatibility.

## Numerical checks, regression and durable output

The complete bounded workload contains 1,343 optimization payloads: 549 from the
six original-expression search runs, 768 from the four remaining selected
condition runs, and 26 from native regression/stage/failure tests. Of these,
1,342 pass external primal and projected-LP dual checks. The other payload was
deliberately corrupted and was rejected before volume evaluation or pruning.
All 14 ordinary complete runs finished successfully; the failed array
comparisons are distinct from solver or engine failure.

Across valid payloads, maximum normalized primal violation was 1.21e-8, objective
discrepancy 1.69e-15, dual stationarity residual 2.35e-8 and relative dual gap
1.06e-9, each below its external 1e-7 limit. Maximum **absolute** primal violation
was 4.57e-6; that quantity is not the normalized acceptance criterion. Raw
vectors, coefficients, solver statuses and all check results are retained.

The C++ code is now formatted and separated into input, numerical functions,
solver, durable I/O, engine and targeted-stage files. A token comparison verifies
unchanged algorithm expressions/control flow, allowing only the declared graph
metadata addition and equivalent split help literals. All four phase 03 native
examples reproduced every trace value exactly except elapsed seconds, and every
checkpoint value except source hashes and added metadata. The supplemented
targeted-stage values also reproduced exactly. No original phase 03 file changed.

The graph checkpoint now includes its distance rescaling, explicit upper-bound
units and conversion to supplied input units. Tests interpreted graph-only
checkpoints without the trace, including failures immediately after graph
commit. All four operational injections retained the correct completed stages
and overall failure flag; the forced outer-cap diagnostic retained its previous
behavior. Seventeen graph checkpoints were reconstructed, including nine native
checkpoints carrying the new metadata, and completed affinities were recomputed
from saved distances/scales. Controlled exceptions still do not establish
power-loss recovery, arbitrary termination safety or resumability.

## Resources, provenance and remaining limits

Selected-run Python process times were 5.58–6.76 seconds with 136–148 MiB OS peak
resident memory; native times were 2.42–2.99 seconds with 25.6–37.9 MiB. These are
single-run diagnostics on deliberately selected inputs. Timing boundaries,
startup and instrumentation differ; no general performance ratio is estimated.
Dense distance and affinity storage, the pinned macOS environment and the shared
solver core remain limitations. No dependency was installed or upgraded.

One no-solve token-check failure arose because formatting split a long help
literal; its log is preserved and the checker now recognizes equivalent adjacent
C++ literals. The first selected-comparison driver stopped on the genuine
representation difference, which remains failed. During reporting, the initial
table's final-affinity column was found to contain the maximum over *all* weighted
retuning attempts. The preserved `analysis-v1` is superseded by `analysis-v2`,
which reads final checkpoint matrices directly. Raw numerical results and
comparison outcomes did not change, and no optimization was repeated.

The [canonical generated tables](</Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase04/analysis-v2/tables.md>),
[reproduction guide](README.md), exact private command record and final manifest
accompany the factual handoff. Longer evaluated-Python/native agreement is now
supported on these two inputs; strict original-expression array compatibility,
cohort-scale behavior, broader geometries, other platforms, biological validity
and production readiness remain unestablished. Work stops at this bounded
submission for independent audit.
