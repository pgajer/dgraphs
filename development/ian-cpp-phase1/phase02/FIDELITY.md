# Why historical final retuning and saved-LP replay differed

The historical final-retuning solve and the phase 1 replay represented the same
fixed optimization problem differently. Reconstructing the original parameterized
expression reproduces all 133 historical iterations and the historical scale
vector exactly. Evaluating the parameter before canonicalization removes an
unnecessary auxiliary cone and restores the replay's 45 iterations. Backend and
thread selection explain a further large timing difference. These improvements
are available in Python; they cannot be credited to translation into C++.

## Reconstruction and its limits

The isolated diagnostic executes only `getParamConstraint` and
`buildOptimizationProblem` extracted from the frozen, executed IAN source
(SHA-256 `b27f05ad470f963dab8e2989fb1048577670da3daee5ad78d10e5947c931a603`).
It reconstructs the last saved graph, original Hellinger distances multiplied by
the recorded 1596.2419737619066 rescaling, and final parameter
C = 0.5312528610229492. Edge order is lexicographic, consistent with the original
upper-triangle extraction and preservation of insertion order during deletion.
Recomputed upper bounds and active-vertex indicators equal the saved arrays
bit for bit. No outer IAN iteration, retuning search or affinity calculation is run.

The retained historical Python environment and the private environment currently
have identical Clarabel extension binaries and identical CVXPY Clarabel adapter
files by SHA-256. The historical run did not save its actual canonical matrices,
selected linear-system backend, thread count or cache contents. Consequently,
this is a source-and-state reconstruction with particularly strong numerical
corroboration, not a recovered historical solver object. Historical host contention
and scheduling remain unknown, and the new 372-second result does not replace
the historical 415-second observation.

## The additional cone

The saved problem is a linear program with 4,841 scales, 262,908 inequalities and
516,134 stored coefficients, including upper and lower bounds. The original
CVXPY expression contains `C**2`, where C is a parameter. With the default
parameter-processing route in CVXPY 1.6.7, canonicalization introduces an extra
variable t and a three-dimensional second-order cone. The solver instead receives
4,842 variables, 262,911 rows and 642,749 coefficients.

The cone slack is `(1+t, t-1, 2C)`. Its condition
`1+t >= sqrt((t-1)^2 + (2C)^2)` is equivalent to `t >= C^2`.
The remaining constraints have the form `A s + gamma t <= b0`, where gamma is
nonnegative. The objective has zero coefficient on t. Substituting `t=C^2`
therefore gives exactly the projected feasible set for s: any lifted feasible
point satisfies the substituted inequalities, and any substituted feasible s has
a feasible lift at `t=C^2`.

The diagnostic verifies that substituted A, b and the scale objective equal the
saved LP bit for bit. This is mathematical equivalence of the fixed problem;
the different constraint representation changes the numerical path. A sixth
condition sets `ignore_dpp=True` on the *original expression*, evaluating
parameters before conversion. Its canonical data hash equals that of the saved
LP, and its scale vector equals the saved-LP/auto/one-thread diagnostic exactly.
This additional condition was committed as a plan amendment after observing the
matrix discrepancy and before executing any diagnostic solve.

## Controlled results

Each row is one isolated solve of the same final state, run serially. All use
Clarabel 0.11.1, binary64, the three original 1e-9 tolerances and 300-iteration
limit. Normal presolve defaults remain enabled here. Times are solver telemetry,
which includes setup, and must not be added to measured construction/solve wall
phases. QDLDL and faer are two numerical linear-system backends inside Clarabel.

| Construction | Actual backend | Threads | Solver seconds | Iterations | Largest scale difference from historical |
|---|---|---:|---:|---:|---:|
| Historical observation | Not recorded | Not recorded | 415.053 | 133 | Reference |
| Original expression, automatic settings | faer | 16 | 372.090 | 133 | 0 |
| Original expression, one thread | faer | 1 | 30.606 | 133 | 1.25e-7 |
| Original expression, QDLDL | QDLDL | 1 | 17.118 | 133 | 1.29e-6 |
| Saved LP, automatic backend | faer | 1 | 9.071 | 45 | 5.77e-6 |
| Saved LP, QDLDL | QDLDL | 1 | 5.739 | 45 | 5.77e-6 |
| Original expression, parameters evaluated first | faer | 1 | 9.083 | 45 | 5.77e-6 |

Scales are in the recorded, rescaled distance units. These six new solves all
pass the original primal acceptance policy and the additional external LP dual
checks. Full vectors and separate timing phases are retained. The original
133-iteration reconstruction has objective 999828.5320136291, exactly matching
the stored historical value. The saved-LP objective is 999828.5321106021, a small
numerical difference rather than proof of a different optimum.

The useful one-factor comparisons are original/auto/16 versus original/auto/1
(thread policy), original/auto/1 versus original/QDLDL/1 (backend), and
original/QDLDL/1 versus saved/QDLDL/1 (representation). The original/auto/1
versus evaluated/auto/1 comparison isolates parameter evaluation while retaining
the original expression and backend. The 16-thread timing is about twelve times
the one-thread timing in this diagnostic; the experiment does not identify which
internal scheduling or synchronization cost causes that slowdown. Single runs
establish this observed behavior, not portable speed ratios or uncertainty bounds.

## Cache and update behavior

The pinned original `getNewSigmas` creates a fresh `cp.Problem` for each value of
C. The pinned CVXPY adapter reuses Clarabel only when that problem has a cached
solver and permits data updates; it does not read an arbitrary prior `x.value`
as a Clarabel starting point. Each reconstructed problem's solver cache is empty.
Thus the source does not support attributing this discrepancy to a reused
historical factorization or warm-started solution.

The persistent benchmark separately tests Clarabel's supported coefficient
updates on fixed sparsity. These retain the original equilibration and reusable
solver structure, while the pinned core invokes `default_start()` for each solve.
They are not primal/dual warm starts. The public API also restricts dimensions,
sparsity and preprocessing. See the [official Clarabel update contract](https://clarabel.org/stable/user_guide_data_updating/)
and [CVXPY solver/cache documentation](https://www.cvxpy.org/tutorial/solvers/index.html).
Version-specific evidence is the pinned local core's `data_updating.rs`,
`core/solver.rs`, `info.rs`, and CVXPY's `clarabel_conif.py`, listed and hashed in
the phase 2 evidence package.

The justified next implementation baseline is an explicitly evaluated LP with
explicit QDLDL and one solver thread, alongside the original-expression reference
for trajectory checks. Matching the fixed feasible set does not establish equal
subsequent pruning, final graph or affinities. Those remain the following small
reference-compatible-engine milestone.
