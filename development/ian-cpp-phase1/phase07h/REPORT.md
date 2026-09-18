# Phase 07H: stable dual-simplex results, with scale agreement still unresolved

HiGHS dual simplex returns identical, numerically certified scale and dual vectors
for the two saved terminal problems and their fresh repeats. The one-step input
change that switched Clarabel's outcome does not switch this algorithm's result
under the tested settings. However, HiGHS still disagrees with three coordinates
of Clarabel's successful scale vector. This bounded diagnostic is complete;
independent acceptance is pending and the scale ladder remains gated.

The auditor's N1 supervisor finding is addressed in a versioned one-shot harness.
Its no-optimizer controls and all four measured process records complete. The
historical multi-solve engine guard and the original Phase07G records are preserved.

## Purpose and methods

The two saved 1,000-variable, 5,466-row, 8,932-nonzero LPs differ by one adjacent
binary64 RHS value at row 882. Native and Python names identify the generating
path, not a language comparison in this phase. Both are solved here through the
same installed SciPy 1.15.3 interface and its bundled HiGHS 1.8.0 backend. The
schedule is native-generated input, Python-generated input, then one fresh-process
repeat of each. Saved Phase07G Clarabel outputs are reused comparisons; there are
no fresh Clarabel calls or complete IAN trajectories.

The explicit method is highs-ds. Presolve and simplex scaling are disabled;
serial dual simplex, one thread, random seed 0 and steepest-devex edge weights are
fixed. Primal/dual feasibility tolerances are 1e-10, with 100,000 simplex iterations
and 60 solver seconds allowed. A no-solve backend option check accepts these
values and rejects 1e-11. The current HiGHS documentation is supporting context;
the installed backend's accepted settings and version are recorded directly.
See the [SciPy 1.15.3 method documentation](https://docs.scipy.org/doc/scipy-1.15.3/reference/optimize.linprog-highs-ds.html)
and [official HiGHS option definitions](https://ergo-code.github.io/HiGHS/dev/options/definitions/).

Every original upper/lower-bound row is retained. Additional variable bounds are
free, avoiding duplicate nonnegativity constraints. The RHS is normalized by the
same alpha, 10132.359853740509. Scales and objective are restored to original units;
inequality multipliers are minus SciPy's marginals. A hand-calculated example tests
this sign convention without solving. The wrong sign gives stationarity error 2
on each measured result, versus about 2.22e-16 with the correct sign.

A read-only proxy observes SciPy's actual backend object immediately before its
single run() call. It saves all effective options and the loaded model, verifies
exact CSC order, matrix/RHS/objective bytes, free variable bounds and lower row
bounds, and forwards the solve unchanged. All backend arrays match the frozen
inputs. The smallest matrix magnitude, about 1.34e-4, exceeds the configured
1e-12 discard threshold; no coefficient is dropped. This pinned private interface
is an experimental instrumentation dependency, not a public integration API.
Raw vectors, marginals, slack, basis, solver information and console logs are saved.
The expected SciPy warning about forwarded extra HiGHS options is preserved; their
actual effective values are checked, rather than assuming the warning means success.

## Results

All four calls terminate successfully with HiGHS model status Optimal and 2,175
simplex iterations. Simplex iteration counts are not equivalent to Clarabel's
interior-point iteration counts. All numerical return fields repeat exactly,
excluding time. Across the two inputs, both primal scales and dual vectors are
exactly equal. Certificates are recomputed from each original, unnormalized LP.

| Check in original units | Worst across four runs | Required limit |
|---|---:|---:|
| Normalized primal violation | 4.8815e-16 | 1e-7 |
| Maximum stationarity error | 2.2204e-16 | 1e-7 |
| Relative objective inconsistency | 3.8758e-16 | 1e-7 |
| Relative primal–dual gap | 0 at displayed arithmetic precision | 1e-7 |
| Dual nonnegativity violation | 0 | 1e-7 |

All vectors are finite and all active scales positive. Zero displayed gap means
the two recomputed floating-point objective values agree; it is not an exact
arithmetic proof of optimality. The checker reuses its Solved argument only to
assess the existing numerical predicates; HiGHS status is separately recorded.
No HiGHS status is mapped into or adopted by the IAN engine policy.

The HiGHS scale vector is compared with both saved Clarabel returns:

| Saved Clarabel comparison | Coordinates outside frozen allowance | Maximum scale difference |
|---|---:|---:|
| Native-generated input, AlmostSolved | 382 of 1,000 | 246.6860192 |
| Python-generated input, Solved | 3 of 1,000 | 0.3343531 |

The frozen allowance is 1e-7 + 1e-7 times the larger absolute coordinate. The
three differences from successful Clarabel occur at zero-based coordinates 229,
230 and 717, with magnitudes about 0.16718, 0.16717 and 0.33435. The objectives are
extremely close: HiGHS's recomputed objective is 1,802,193.3506148998, about 6.29e-9
below the saved successful Clarabel objective. This supports examining how strongly
the objective determines these coordinates, not declaring a unique correct vector.

The four guarded processes total 2.134962 seconds of wall time and reach 79.59375
MiB maximum sampled process-tree RSS. All four reservations, start events, raw
returns and reaped exit-zero process records reconcile. No resource limit or
supervisor error occurred. These process figures include startup/instrumentation
and exclude preparation and checking; they do not establish engine performance.

## N1 correction and its scope

The new one-shot guard reserves each invocation before launch and refuses a fifth
reservation in a four-call budget. A single completed event at the exact allowance
no longer triggers termination. The replay client separately prohibits a second
backend run() call. Excess events are a contract violation, while independent wall,
RSS and output controls remain active. The old multi-solve engine protection is
unchanged; the new guard is not a general multi-solve budget implementation.

Six real child-process tests contain only synthetic events: slow finalization after
one allowed event, excess events, wall termination, simulated PermissionError,
simulated ProcessLookupError, and missing solve accounting. A seventh check refuses
an exhausted reservation without launching a child. The slow-finalization child
waits 1.3 seconds and writes its completion marker; it exits normally with a complete
record. Both signal-error controls finish and retain error details plus reaped exit
status. The time-limit control is terminated and recorded as such. Six synthetic
events across these controls are explicitly excluded from the four optimizer calls.

Signaling failures are captured instead of escaping before accounting. The guard
writes a running record immediately after launch and a final record in all handled
paths. If escalation cannot reap a process, it records an unreaped state and PID;
the driver stops further dispatch. Sampled limits are not hard OS quotas. These
controls test defined paths, not every operating-system failure. Historical
Phase07G numerical evidence remains accepted; its audit's missing eighth process
record has not been invented or repaired retrospectively. New one-shot experiments
must use this versioned guard, not Phase07G's historical inherited supervisor.

## Interpretation and next step

The alternative method is stable across this perturbation on these fixtures and
settings. It has stronger observed certificate margins, but still does not reproduce
all of Clarabel's successful scales under the frozen comparison. A change of solver
would therefore be a separately tested numerical-policy change. The study does
not prove nonuniqueness, establish a mathematically preferred vector, qualify
HiGHS for IAN trajectories, or authorize the ladder/quadform runs.

The next proposed bounded diagnostic is an objective-band range experiment on a
common fixed problem: minimize and maximize the already identified coordinate 717
while constraining the original objective to declared near-optimal bands. Derive
and state those bands from verified primal/dual information, prescribe a small
allowance ladder and physical solve count, and independently check every endpoint.
A wide range would show weak determination within a stated objective allowance;
it would not prove multiple exact optima. This extension was not run here.

Complete native settings capture and the C/Rust header-layout mismatch remain
separate instrumentation/interface work before broader native qualification.
Historical-expression equivalence, pruning calibration, biological validity and
conditional-expectation validity remain outside this diagnostic.

## Durable evidence

Evidence root: /Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07h.
PLAN.md and README.md specify scope and reproduction. preflight.json records
backend option acceptance and identities; guard-controls/results.json records N1
controls; reservations.json and ledger.json account for all invocations.
runs/*/child contains pre-run options/model/array dumps and raw outputs.
results.json contains original-unit certificates and comparisons; preservation-v1.json
and manifest-v1.json freeze historical preservation and this submission. The factual
implementer handoff is adjacent to the evidence root. No installs or policy edits.
