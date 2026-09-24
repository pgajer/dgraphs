# Phase 07H: supervisor repair and alternative LP diagnostic

Authorized by Pawel after accepted Phase07G with nonblocking N1.
Base d124f56a4c99580da6f2bafe4cabcac33fed8112. Plan precedes implementation/solves.
Study completion, audit acceptance, numerical policy adoption and expansion differ.

First add a versioned one-shot supervisor under phase07h, leaving historical
multi-solve guards and evidence unchanged. Reserve one invocation durably before
launch; refuse another when the study budget is exhausted. A completed solve event
at the exact quota must not interrupt child finalization. More than one event is
a contract violation; retain independent wall/RSS/output limits. Handle signaling
errors and exit races with durable process records, explicit incomplete/running
states and no further launch on failure. No-optimizer controls cover exact quota
with slow finalization, exhausted-budget refusal, excess events, time termination,
PermissionError and ProcessLookupError races, and missing completion accounting.
Synthetic events are separately labeled and never counted as optimization calls.

Then run exactly four fresh-process HiGHS dual-simplex solves: native-generated
terminal LP, Python-generated terminal LP, repeat native, repeat Python. Reuse the
unchanged Phase07G binary64 inputs, normalized by the same alpha. Compare against
saved Clarabel returns as reused evidence, not fresh solves. Use installed SciPy
1.15.3's explicit method highs-ds and bundled HiGHS (version checked before runs).
No install or backend rebuild. Presolve disabled, simplex scaling disabled (0),
serial dual simplex strategy 1, threads 1, parallel false, random_seed 0,
steepest-devex edge weights, primal/dual feasibility tolerances 1e-10,
small_matrix_value 1e-12, 100000 simplex iterations, 60 solver seconds.
Verify these values are accepted by this backend before any optimization and
that all matrix magnitudes exceed the discard threshold. Different internal
tolerances from Clarabel do not alter the external certificate limits.

Keep all upper/lower-bound rows. Additional variable bounds are (None,None).
Capture actual backend model and full effective options in process immediately
before run(), with hashes and version. A read-only proxy may observe the pinned
SciPy backend object but must forward unchanged operations and allow only one
run(). Save raw solution, inequality marginals, slack, basis, solver info and logs.
Recover original scales x=alpha*y, objective=alpha*fun, and z=-ineqlin.marginals;
validate sign convention with hand-calculated no-solve examples and check the
actual stationarity c+A^T z. Independently reconstruct all original-unit finite,
positive-active, primal, stationarity, objective, gap and dual-sign conditions
at unchanged 1e-7 limits. Report HiGHS status, numerical checks and scale comparisons
separately; successful HiGHS termination is not an engine-policy status mapping.
Use the existing scale allowance 1e-7+1e-7*max(abs(x),abs(y)), and exact repeat checks.

Per invocation: 120 wall seconds, sampled 4 GiB process-tree RSS, 2 GiB output;
study: four optimization invocations, 600 child seconds, 16 GiB output, 20 GiB free.
Run serially with thread environment limits. Stop on supervisory or resource failure;
a numerical refusal may complete its prescribed paired/repeat comparisons. Preserve
all outcomes. No tolerance search, hidden retries, near-optimal range optimizations,
basis reuse, new Clarabel solves, full trajectories, quadforms or scale ladder.

Stable certified vectors support this alternative algorithm on these fixtures.
Different certified vectors do not prove exact nonuniqueness. Neither outcome
adopts a backend or reopens the ladder. Range optimizations require a later declared
objective band and separate solve budget. Coefficient-policy changes and complete
trajectories are later work. The C/Rust header mismatch remains a separate interface
qualification issue; any future native replay must capture complete settings.

New tracked source only phase07h and coordinator/ROADMAP.md. Evidence worker/phase07h,
factual handoff adjacent. Commit executable sources before measured execution;
freeze checksums and verify earlier inventories. Auditor directories read-only.
