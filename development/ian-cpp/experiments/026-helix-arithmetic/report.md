# Why did native IAN stop on the helix while Python completed?

IAN-EXP-026 · Phase 07K · Aims IA1 and IA4 · Executed 23 September 2026.

**Matching the arithmetic resolves this particular discrepancy.** With Python's
power convention used in both implementations, both complete the 1,000-profile
helix. Their local scales, all pruning decisions and final affinities are identical.
The solver settings and acceptance checks were not relaxed. These are author
checks of a bounded experiment; independent review is pending.

## What was tested

We used the same frozen helix distances and profile identities as the failed
scale-ladder experiment. First we reconstructed saved constraints without solving,
and examined the eight previously audited fixed-problem solver histories. Then we
ran six fresh helix trajectories: the preserved native and Python versions, both
using multiplication to square constraint values, and both using the system power
function. Four smaller examples were also run in both implementations under the
power convention: a nonuniform curve (64 profiles), variable-density patch (80),
nearby curved arms (96), and the PreSSMat Hellinger subset (64).

These runs use the historical experimental retry policy from Phase 07E. After an
eligible rejected return, it permits one new solve in normalized units, with
tighter solver tolerances. The original return is never accepted merely because
a retry succeeds. This is **not the strict policy currently used by the internal
dgraphs adapter**. No adapter or typed-core implementation was changed here.

## 1. The difference begins when a distance is squared

For one edge, the stored distance is 3726.1453183235058 in the engine's internal
units. C++ previously evaluated its square by multiplication; Python used a power
operation. On this machine they produce adjacent representable numbers:

| Operation | Squared distance |
|---|---:|
| Multiplication, `d*d` | 13884158.933264181 |
| System power function, `pow(d,2)` | 13884158.933264180 |

This propagates to one constraint's right-hand side. In the terminal saved problem
the difference is only **4.55 × 10⁻¹³**, or one last-place rounding step. The affected
constraint is zero-based row 882, for profiles 258 and 732. The difference already
appears in the first optimization problem; it is not introduced during pruning.
The two runs nevertheless make the same acceptance decisions through their first
12 accepted scale calculations. The acceptance switch occurs on physical attempt
26, the retry for logical problem 13.

Reconstruction matches every matrix entry and right-hand side in all 26 saved
native attempts using multiplication, and all 112 saved Python attempts using the
power rule. Thus the terminal difference has a measured arithmetic origin.
Exact rational arithmetic also confirms that **multiplication gives the correctly
rounded square of this stored distance**. The successful power convention matches
the reference; this is not evidence that it is inherently more accurate.

## 2. The solver follows different numerical paths

For the two fixed terminal problems, the audited convergence histories begin to
differ at solver iteration 5. With multiplication's input, the solver ends at
iteration 18 with a zero final step and `AlmostSolved`. One internal error measure,
the dual residual, remains about **9.8 × 10⁻¹⁰**, above the requested **10⁻¹¹**.
With the power input, it reaches `Solved` at iteration 27, with that residual about
**6.47 × 10⁻¹³**. Each input produces the same history in both interfaces.

The first return passes the separate original-unit certificate inequalities, but
its status still fails the unchanged requirement that a retry return `Solved`.
The recorded history does not expose the precise internal branch that caused the
zero step, so we do not attribute it to a particular factorization or line-search
failure. The measured cause of the interface discrepancy is the different rounded
input, not a demonstrated C++ interface defect.

![Solver convergence and complete helix pruning trajectories](build/helix-arithmetic.png)

*Left: audited saved-problem convergence; the dashed line is the solver's internal
requirement. Right: fresh native and Python trajectories using the shared power
convention overlap. The original native calculation stops before any pruning.*

## 3. A consistent construction rule changes the outcome

The candidate changes the squaring operation for every constraint distance,
scaled distance and tuning constant, not just the troublesome entry. It preserves
the surrounding operation order. C++ is compiled without fused contraction; a
runtime exponent prevents the compiler from replacing the power call with a
multiplication. Python explicitly calls the same system power operation.

| Helix construction | Native outcome | Python outcome |
|---|---|---|
| Preserved implementations | Refuses after 26 attempts | Completes after 112 attempts |
| Both use multiplication | Refuses after 26 attempts | Refuses after 26 attempts |
| Both use system power | Completes after 112 attempts | Completes after 112 attempts |

The fresh preserved runs reproduce their saved traces exactly apart from timing.
The multiplication candidate reproduces the native refusal; the power candidate
reproduces the historical Python completion. This includes the negative control:
matching the arithmetic can also make both implementations fail together.

## 4. The complete trajectories agree

Under the shared power convention, the two implementations have **490 matching
event positions**, including 112 optimization attempts. Every optimization matrix,
constraint bound, primal scale vector and dual vector is exactly equal. All 66
accepted scale calculations, 46 rejected attempts and their retries agree.
Retuning decisions agree, all **47 pruning steps** remove the same edges in the
same order, and the final graph has **999 edges and no isolated profiles**.
Final scales and affinity matrices are exactly equal, including against the
historical Python result. Small differences in independently calculated diagnostic
residuals mean that not every diagnostic field is bit-for-bit identical.

The four smaller examples also pass all native/Python comparisons. Compared with
their historical Phase 07E runs, numerical changes are at most about 6.04 × 10⁻¹⁴
in internal scales and 1.48 × 10⁻¹⁵ in affinities, far below the existing comparison
limits; graph decisions are unchanged. These examples add limited pruning coverage:
only PreSSMat prunes, four times.

Across the study, **14 engine executions made 446 physical optimization attempts**.
All 266 accepted returns pass the unchanged numerical checks; the 180 rejected
returns remain rejected and are accounted for. Every process has a complete
accounting record. Six additional synthetic supervisor tests and an exhausted-budget
test pass without invoking a numerical solver.

## Interpretation and next step

The original helix difference is explained and a narrowly defined compatibility
candidate completes its full trajectory. This does not eliminate the underlying
sensitivity: the largest accepted normalized constraint violation is 9.64 × 10⁻⁸
against the unchanged 10⁻⁷ limit. Nor does it establish that all nearly optimal
scale vectors produce the same graph. The earlier certified scale-range result
still stands: the objective minimizes the **sum of local scales**, so nearly equal
totals can coexist with different individual scales.

I recommend independent review of this candidate, followed by the permanent
difficult-problem/boundary regression collection and a declared portability test
of the arithmetic convention. A system power function is not yet a cross-platform
bitwise contract. Any promotion into the typed core and internal R adapter must
also explicitly choose the retry policy. The larger scale ladder and public export
remain gated; no general equivalence or production-readiness claim follows here.

## Evidence and reproduction

- [Prospective plan](../../../ian-cpp-phase1/phase07k/PLAN.md) and
  [reproduction instructions](../../../ian-cpp-phase1/phase07k/README.md).
- [Complete validation summary](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/helix-arithmetic/study-v1/analysis-v1/summary.json),
  [matching-policy small controls](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/helix-arithmetic/study-v1/baseline-supplement/summary.json),
  and [arithmetic reconstruction](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/helix-arithmetic/study-v1/arithmetic.json).
- [Auditor handoff](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/helix-arithmetic/implementer-handoff.md).

The first small-baseline comparison used older pre-retry traces named by the
fixture manifest. Their numerical comparisons pass, but full-contract comparison
correctly flags missing retry metadata. Those outputs are preserved; the separate
matching-policy comparison uses the actual Phase 07E traces and passes all eight
checks. This was a read-only analysis correction, with no additional solves.
