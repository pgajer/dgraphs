# IAN numerical reference contract 1.0

Status: adopted as the working specification for user-authorized Phase 05;
validation and independent audit of this phase are pending. This specification
does not assert general equivalence or authorize deployment.

The implementation reference is **IAN evaluated-LP 1.0**: the pinned executed
IAN/EXP-038 adapter policy with explicitly evaluated linear-program coefficients,
as implemented by the unchanged phase03 evaluated Python control and accepted
phase04 native engine. The user authorized the proposed Phase 05, including this
reference choice. The original-expression Python control remains a historical
compatibility diagnostic. This adopts a controlled numerical formulation change;
it is not a promise to reproduce historical conic-solver vectors.

## Identity and supported scope

- Accepted engine source: phase04 at `df4dcb271369d65302fdf62ce6b7e6c4a13fbb32`;
  compiled files unchanged since `fc8d94330a4876777e7299b82d52ee296cc53de3`.
- Executed Python reference: phase03 `reference.py` and its frozen IAN/adapter
  dependencies; hashes are recorded with every reference execution.
- Algorithm/configuration: phase04 `config.json`, byte-identical to phase03.
  Exact precomputed distances, l1 objective, C3 spread, 4.5 standard deviations,
  existing median/cap/ordering rules, final weighted retuning and numerical
  affinity cutoff. All arithmetic, float32 Gabriel decisions, duplicate mapping
  and isolate treatment remain unchanged.
- Clarabel 0.11.1, binary64, QDLDL, one thread, fresh solver construction,
  max_iter 300, feasibility/absolute-gap/relative-gap tolerances 1e-9, disabled
  presolve/chordal processing/sparse-zero dropping. No solver update/warm start.
- Supported mode: validated symmetric finite nonnegative supplied distances with
  stable first-occurrence exact feature duplicates, at least two unique profiles
  and no nearly coincident distinct profiles. Full runs beginning with isolates
  remain explicitly refused; isolates arising during pruning are supported.
- Platform qualification remains the tested pinned macOS ARM64 environment.

## Three separate judgments

1. **Optimization validity.** Optimal status, correct shapes, finite vectors and
   objective, positive active scales, normalized primal violation <=1e-7 and
   relative objective recomputation discrepancy <=1e-7. Bounds are LP rows.
   Projected-LP dual stationarity, nonnegativity violation and relative gap must
   each be <=1e-7. Record absolute residuals too. These are numerical checks, not
   a rigorous exact-arithmetic certificate or proof of a unique optimum.
2. **Implementation fidelity.** Native versus evaluated Python: exact discrete
   state/choices, with the phase03 frozen field lists and floating-array limits.
   Distances/upper bounds/LP coefficients: atol 1e-12, rtol 2e-14. Internal scales:
   atol 1e-7, rtol 1e-7; divide absolute allowance by distance rescaling for final
   original-unit scales. Ratios/statistics/thresholds/affinities: atol=rtol=1e-7.
   Entrywise limit is atol + rtol*max(abs(left),abs(right)). Affinity zero support,
   diagonal/isolate convention and discrete graph operations are exact. Timing
   and solver iteration counts are descriptive, not equality requirements.
3. **Historical compatibility.** Original-expression versus evaluated Python uses
   those same recorded comparisons, reported separately. The failed phase04
   intermediate-array comparisons remain failed. Agreement of decisions or final
   graphs/affinities never retroactively changes that result. A new discrete
   representation difference requires an explicit description of its propagation
   and consequences before any claim of drop-in behavioral replacement.

The reference is an executable, versioned numerical policy. Feasible/near-optimal
LP solutions need not determine identical downstream decisions. Near a boundary,
even native/evaluated agreement must be tested rather than assumed. A numerical
implementation mismatch blocks a claim of fidelity for that case; it must not be
hidden by a wider tolerance or a silent change to the tie/pruning rule.

## Outputs and failure semantics

Graph, final scales and affinity are independently validated durable stages.
Record stable specimen/profile identities, original/internal units, input/source/
configuration hashes, explicit stage completion and errors. A saved graph does
not imply completed affinity retuning. Optional diagnostics cannot invalidate or
silently modify the accepted native graph. Cap rejection, invalid vectors,
unsupported initial isolates and component separation retain existing semantics.
Crash recovery, resumability, R integration, other platforms and cohort-scale
performance are outside this contract's present validation claims.

## Change control

Future solver/settings changes, different formulations, revised tolerances,
tie/pruning/isolate policies, approximations or stronger truncation require a
named version or experimental variant and prospective tests. This contract
preserves the original-expression control and failed evidence. Independent audit
assesses Phase 05 against the scientific and implementation evidence; the
implementer does not set its verdict. No claim of biological geometry or
predictive validity follows from numerical agreement.
