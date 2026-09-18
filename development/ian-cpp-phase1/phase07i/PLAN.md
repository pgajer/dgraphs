# Phase 07I: exact-certified near-optimal coordinate ranges

Pawel authorized this study after Phase07H acceptance and N1 closure. Base:
c777ca5c2e275a68aae4c87a3034799952d7c525. This plan precedes implementation and solves.
Completion, audit acceptance, policy adoption and ladder advancement are separate.

Use only the Python-generated terminal LP, in its original coordinate order and
original units. Reconstruct the audit's exact rational lower bound L and feasible
point q with upper bound U from saved Phase07H outputs, independently implementing
the formulas and checking agreement. Verify the explicit bound rows and 0<=x<=u.
No baseline solve. Save exact fractions, source identities and all bound checks.

Six fresh calls in ascending band order, min then max coordinate 717, for nominal
absolute allowances delta=1e-8,1e-6,1e-4 above U. Interpret these decimals exactly.
For each, set T to the smallest binary64 value at least U+delta. Freeze the exact
fraction and hexadecimal representation of T before calls; report T-U and T-L.
The original-variable formulation Ax<=b, c^T x<=T avoids further normalization or
rounding of the objective-row cutoff. This differs explicitly from Phase07H's
global variable normalization; the original constraint coefficients/RHS are
unchanged. Additional variable bounds stay free; original bound rows stay present.
Range objective is +e717 for min and -e717 for max. No coordinate/seed selection.

Use installed SciPy highs-ds and HiGHS 1.8.0 with the accepted Phase07H settings:
no presolve or simplex scaling, serial dual simplex, one thread, seed zero,
steepest-devex, primal/dual tolerance 1e-10, small_matrix_value 1e-12, 100000
iterations and 60 solver seconds. Record complete in-process settings/model,
actual arrays, raw results, augmented duals, basis and logs. No retries/settings
search. Reuse the accepted one-shot reservation supervisor. Six calls maximum,
120 child seconds each, 720 total, sampled 4 GiB RSS, 2 GiB per-child/16 GiB study
output and 20 GiB free. Stop dispatch on supervisor/resource failure. Numerical
failures remain results and do not automatically stop later prescribed cells.

## Exact feasibility and extremum bounds

Check raw original-unit feasibility and the objective band with exact rational
arithmetic on every stored binary64 value. Admitted objective-band violation is
ZERO. A raw point outside the band is unresolved as an endpoint even if the solver
reports Optimal. Keep unchanged 1e-7 numerical checks separately: original LP
checks use the saved original-objective dual; augmented checks use range objective
and its correctly signed full multipliers. Neither replaces the strict band test.

For a finite return, clip its coordinates to [0,u]. Repair by the smallest exact
convex-mixture weight toward q that makes every original row AND the objective
row feasible. Check the resulting rational point against every row and record
the weight, clipping/change, objective and coordinates 229,230,717. q itself is
feasible in every band, so this is an explicit fallback witness, never a hidden
optimizer or a claim that the raw return passed. A collapse to q is informative.

For each augmented minimization g, take nonnegative multipliers z=-marginals;
if any are negative, clip them to zero and record that change. In exact arithmetic
compute d=g+A_aug^T z and B=-b_aug^T z+sum(min(0,d_j)*u_j). This bounds its true
minimum from below regardless of the solver's rounded stationarity residual.
For max, g=-e717, so -B is an upper bound on the true maximum coordinate. Combine
these bounds with repaired feasible coordinates and the box bounds to report
intervals for both extrema, an attained feasible span and an outer bound on the
full span. Do not call a pair of feasible points the full min/max without these
bounds. Record endpoint optimality gaps in coordinate units and original-objective
allowances relative to L. Preserve exact witnesses and dual-correction arithmetic.

No-solve controls cover too-wide acceptance by a normalized objective-row check,
strict objective-band rejection, exact repair, dual signs, max-direction conversion,
and binary64 upward cutoff rounding. Inspect saved HiGHS/Clarabel direction and
feasibility with exact arithmetic, preserving historical returns and distinguishing
any derived feasible witnesses. No additional optimizer calls for these diagnostics.

A wide certified span supports weak determination within this declared allowance,
not multiple exact optima. A narrow or unresolved span does not establish engine
compatibility. No secondary criterion, regularization, backend adoption, native ABI
repair, trajectory, quadform or ladder run. New tracked files only phase07i and
coordinator/ROADMAP.md; evidence worker/phase07i, factual handoff adjacent. Commit
executable source before measured calls and preserve previous/auditor evidence.
