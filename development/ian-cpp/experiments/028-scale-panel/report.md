# Does the qualified engine agree across the remaining 1,000-profile geometries?

IAN-EXP-028 · Continuation stage 2 · Aims IA1 and IA2 · 23 September 2026.

**All six frozen examples complete in native code and Python with matching trajectories and final outputs. Independent audit is pending.** This broadens implementation coverage to the noisy cloud, separated lobes and quadforms of intrinsic dimension two through five. It does not establish scientific usefulness or unrestricted scale.

## Methods

The [prospective plan](../../stages/02-scale-panel/PLAN.md) resumed the six inputs left unexecuted in the earlier scale study. Each contains 1,000 profiles. The quadforms retain the audited dgraphs construction: coordinates sampled uniformly in a latent box, embedded on a fixed quadratic surface in one additional coordinate. They are not sampled uniformly by surface area, and the dimensions are not otherwise matched scientific scenarios.

Both implementations use the Stage-1 accepted explicit policy, `IAN evaluated-LP retry-power 0.1`: common power-function constraint arithmetic, at most one eligible normalized retry and unchanged final numerical checks. The accepted native executable and corrected Python reference were hash-verified and reused. Only the input policy declaration changed; geometry, identifiers, distances and provenance are unchanged. Native then Python ran serially for each case. The already accepted 1,000-profile helix and 500-profile regression panel are earlier evidence, not fresh executions here.

## Results

| Example | Solver attempts per implementation | Pruning steps | Final graph edges |
| --- | ---: | ---: | ---: |
| Noisy six-dimensional cloud | 46 | 42 | 5,947 |
| Separated planar lobes | 36 | 34 | 1,855 |
| Quadform, intrinsic dimension 2 | 19 | 17 | 1,902 |
| Quadform, intrinsic dimension 3 | 22 | 20 | 3,499 |
| Quadform, intrinsic dimension 4 | 45 | 41 | 5,794 |
| Quadform, intrinsic dimension 5 | 26 | 23 | 9,387 |

Every optimization return passes; no retries are needed in these six cases. Native and Python optimization coefficients are exactly equal. Complete event comparisons, scale and dual-vector comparisons, graph structure and final affinity reconstruction pass the existing limits. All six native checkpoint envelopes pass payload, input, source, configuration and trace-prefix binding checks. Cancellation/resume evidence is reused from Stage 1, not repeated.

The complete accounting contains **12 engine launches and 388 solver attempts**. Guarded child time totals 80.5 seconds, and the highest sampled process-tree memory is 454.4 MiB. No resource limit is reached. These are supervised correctness runs, not a language performance comparison. The declared ceilings were 12 launches, 10,000 attempts, one hour of aggregate child time, 4 GiB per process tree and 24 GiB of study output. No input was skipped or replaced.

## Python warnings and their numerical consequence

All six Python logs report division-by-zero, overflow and invalid-value warnings in the calculation used to verify optimality. A [declared read-only diagnostic](../../stages/02-scale-panel/WARNING-STUDY.md) recalculated the certificate products from all 194 saved Python solutions, without running the optimizer.

The warnings reproduce specifically for NumPy's dense vector `@` operation. Sparse matrix products, NumPy `dot`, and elementwise multiplication followed by summation produce no arithmetic warnings in this replay. All inputs and results are finite, and every product agrees with an independent scalar sum within the declared relative check of one part in a trillion. The largest absolute difference is about 1.46×10⁻¹¹. The original-unit solution certificates also pass independently.

Thus the observed warnings do not correspond to incorrect certificate values on these saved problems. Their low-level library cause remains unestablished. The original reference and warnings are preserved; no warning filter or arithmetic replacement was applied. The first read-only diagnostic misread the saved sparse format and failed before calculating any products. That failure is retained, followed by the corrected diagnostic. A separate configuration-printing message suggests an optional formatting package; it is unrelated to the arithmetic warnings.

## Interpretation and limits

Together with the earlier accepted helix, the result covers all seven originally frozen 1,000-profile geometries on this macOS arm64 runtime. It does not test larger inputs, general resistance to perturbations, other operating systems, R calls above 500 rows, a fresh package installation or scientific graph quality. The absence of retries here does not establish that they are unnecessary elsewhere: the prior helix needed them.

After independent review and resolution of any findings, this bounded scale milestone can advance to supported-platform and package qualification. Any larger-size experiment needs a separately declared budget based on measured costs. The strict R default remains unchanged, and nothing is exported publicly.

## Evidence

- [Summary and warning diagnostic](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage02-scale/summary.json), [complete accounting](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage02-scale/panel-v1/ledger.json) and [evidence identities](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage02-scale/manifest.json).
- [Fixture freezing](../../stages/02-scale-panel/prepare.py), [serial execution](../../stages/02-scale-panel/run.py), [checkpoint and census checks](../../stages/02-scale-panel/finalize.py), [saved-product diagnostic](../../stages/02-scale-panel/check_warnings.py).
- [Stage-1 integration](../027-numerical-policy-integration/report.md) and [Project status and next steps](../analysis-queue.md).
