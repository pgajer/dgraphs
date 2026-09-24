# Phase 07I: a small objective allowance permits the observed scale difference

Two exactly feasible points differ by **0.33435 scale units** at coordinate 717
while both lie within **1.10503e-8 original objective units of the optimum** of the
same stored problem. This supports weak determination of that scale within a
very narrow near-optimal band. It does not prove multiple exact optima.

The six new range solves completed, but none returned a point satisfying every
constraint in exact arithmetic. Three also exceeded their objective band. Those
raw endpoints remain unresolved. The attained span above comes from separately
labeled exact repairs of saved HiGHS/Clarabel points; fresh endpoint duals bound
the narrowest band's full span above by 0.438902. The study is complete, pending
independent review; no numerical policy or scale gate has changed.

## Question, fixed problem and objective bands

Phase07H showed stable HiGHS results but three differences from successful Clarabel.
This study asks how far the 718th scale (zero-based coordinate 717) can move while
remaining feasible and nearly optimal. It uses only the Python-generated terminal
LP: 1,000 variables, 5,466 original rows and 8,932 nonzeros. The earlier native-
generated problem is not pooled with it. Coordinates 229 and 230 are recorded at
the endpoints without additional optimization.

Saved HiGHS multipliers yield an exact, box-corrected objective lower bound L.
An exactly feasible point q obtained by a tiny adjustment of the saved scales yields
upper bound U. This implementation reconstructs the auditor's fractions exactly:
U-L is approximately 9.044598297592895e-10, around objective 1,802,193.3506149.
The lower bound accounts for exact stationarity residuals; it is not the rounded
solver gap. q differs from the saved HiGHS scales by less than 2.36e-12 per coordinate.
No baseline solve was performed.

For each nominal allowance, the cutoff T is the smallest binary64 number at least
U plus that exact decimal allowance. Cutoffs, hexadecimal encodings and rational
values were frozen before solving. The relevant guarantee is T-L, including the
uncertainty in the optimum, not just T-U.

| Nominal allowance above U | Frozen cutoff T | Guaranteed allowance T-L, approximately |
|---|---:|---:|
| 1e-8 | 1802193.3506149107 | 1.10502254e-8 |
| 1e-6 | 1802193.3506159007 | 1.00104612e-6 |
| 1e-4 | 1802193.3507149008 | 1.00001101e-4 |

The original-variable formulation retains A and b exactly and appends cᵀx≤T.
Unlike Phase07H, it does not normalize variables; this avoids another conversion
of the narrow cutoff. That formulation choice was prescribed before execution.
Each band receives one minimization and one maximization of coordinate 717, six
calls total, with no retries or parameter search. Maximization minimizes -x717.

SciPy 1.15.3/HiGHS 1.8.0 uses the accepted diagnostic settings: explicit dual simplex,
presolve/scaling disabled, one thread, seed zero, steepest-devex weighting, primal/
dual tolerances 1e-10, small-entry threshold 1e-12, 100,000 iterations and 60 solver
seconds. All bound rows stay present and extra variable bounds remain free. Full
in-process options and loaded arrays match the frozen models. The accepted one-shot
supervisor records six reservations, six start events and six reaped exit-zero runs.

## Strict checks and what the new solves establish

Objective-band membership admits **zero** exact violation. Every binary64 return is
converted to a rational point and tested against each original row and the band.
A no-solve falsification control constructs an originally feasible point outside
the narrow band that would pass the ordinary normalized-row test; the strict check
correctly rejects it. Sign, maximization-direction, cutoff-rounding and exact-repair
controls also pass.

All six solver statuses are Optimal, but all six raw points have exact original
constraint violations. The three minimization returns also exceed their bands by
approximately 1.34e-11, 2.20e-10 and 5.06e-10 objective units. All pass the existing
original-LP numerical checks using the saved original-objective dual. Two of the
augmented maximization certificates fail the unchanged 1e-7 numerical tests.
Solver status and general numerical checks therefore do not certify these endpoints.
The violated bands were not enlarged after execution.

Each raw point is separately clipped to the box and mixed toward q by the smallest
exact weight that makes all original constraints and its band feasible. The resulting
rational witnesses pass every row exactly. However, the weights exceed 0.9999988:
repair pulls almost entirely back to q. At the widest band the largest coordinate
change from a raw point is about 1,863 scale units. These are explicit fallback
witnesses, not small harmless corrections or validated raw extrema. Fresh repairs
alone attain spans of only about 3.77e-8, 4.51e-5 and 3.29e-4.

The augmented multipliers remain useful for rigorous outer bounds. For range
objective g, the exact lower bound is -b_augᵀz + Σ min(0,g+A_augᵀz)ⱼuⱼ, with z
nonnegative and the objective-row multiplier included. Negating the bound for
minimizing -x717 supplies an upper bound on the maximum scale. Exact residual
corrections remain valid even when a rounded numerical certificate fails. The
saved certificates retain rational bounds and feasible points, not just decimals.

## Separate saved-point evidence and combined range bounds

Before the new solves, the prescribed saved-data analysis checked the HiGHS and
successful Clarabel vectors. Neither raw binary64 vector is exactly feasible.
Mixing the Clarabel point toward the known feasible upper-bound vector repairs it
with a maximum coordinate change below 3.20e-12. This is separate from the much
larger repairs of the fresh range endpoints. The repaired Clarabel point lies in
all three frozen bands; its objective is at most 1.01805957e-8 above L.

The repaired HiGHS and Clarabel points differ by 0.33435312469517964 at coordinate
717. They are both exactly feasible in the narrowest band, so every point on the
segment between them is feasible there. The roughly opposite changes at coordinates
229 and 230 explain much of the cancellation in the objective; their exact changes
and affected constraint rows are preserved. This statement uses the repaired
witnesses, not an assumption that the historical raw points were exactly feasible.

Combining these saved witnesses, the fresh repaired points and exact dual bounds:

| Nominal band above U | Certified attainable span, at least | Full span bounded above by |
|---|---:|---:|
| 1e-8 | 0.33435 | 0.438902 |
| 1e-6 | 0.33435 | 38.316962 |
| 1e-4 | 0.33435 | 1863.055153 |

The displayed span limits are rounded outward; exact fractions are authoritative.
The wide outer bounds for larger bands are not claims that those widths are attained.
For the narrowest band, the minimum lies approximately between 1863.1460577574
and 1863.1460578317; the maximum lies between 1863.4804109562 and 1863.5849596884.
The uncertainty in the maximum prevents reporting a fully resolved min/max pair.
Original-objective allowances and endpoint optimality gaps in coordinate units
are separate quantities in the evidence.

Thus the previously observed 0.33435 discrepancy can occur between exactly feasible
points inside the declared narrow objective allowance. It is not explained solely
by treating slightly infeasible historical outputs as feasible. This does not show
zero objective change along a nonzero feasible direction, or multiple exact optima.

## Completion, limitations and next step

Six fresh optimization calls and zero additional baseline/range calls were made.
They consumed 3.788178 supervised child seconds, with maximum sampled process-tree
RSS 85.53125 MiB. No supervisory/resource failure occurred. Pure rational arithmetic,
preparation and evidence checking are outside those totals; these are not full-engine
performance figures. Every raw endpoint, refusal by a strict check, repaired point,
multiplier, option record and original source remains preserved.

The completed study is informative despite unresolved raw endpoints and imprecise
outer extrema. It supports defining scale selection explicitly rather than assuming
that near-optimal LP returns must match. A next bounded proposal should compare a
prespecified secondary scale-selection rule on the saved difficult problems, with
an explicit primary-objective allowance. Any such rule changes numerical policy
and needs subsequent native/Python trajectory and pruning comparisons. It has not
been implemented here. The ladder, quadforms and larger runs remain gated.

Native header-layout qualification and complete native settings capture remain
separate work. This study establishes neither historical-expression equivalence,
biological validity nor general solver stability or uniqueness.

## Evidence and reproducibility

Evidence root: /Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07i.
`bounds.json` reconstructs the exact optimum bracket; `schedule.json` freezes bands;
`fixtures-manifest.json` identifies actual inputs; `preflight.json` records no-solve
controls. `ledger.json`, `reservations.json` and `runs/*` account for all six calls.
`results.json` reports the fresh endpoints without importing historical witnesses;
`certificates/*` retains exact repairs and dual bounds. `saved-direction.json` records
pre-run saved-data arithmetic; `saved-span.json` separately combines those certified
witnesses with fresh bounds, adding zero solves. `manifest-v1.json` and
`preservation-v1.json` freeze this submission and verify historical evidence.
