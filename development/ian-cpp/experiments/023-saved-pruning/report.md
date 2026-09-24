# Do the certified scale differences change pruning at the saved graph?

IAN-EXP-023 · Phase 07J · Aims IA1 and IA4 · Executed 23 September 2026.

**The two vectors produce identical ordered candidates, selected nodes, removed edges and remaining graph in this fixed-state comparison. Both require further retuning.** This is a completed diagnostic with author checks; independent review is pending.

## What was compared

The earlier objective-band study certified two exactly feasible scale vectors for a saved optimization problem from the 1,000-profile helix. Both lie within the narrowest prescribed objective band, whose guaranteed allowance above the optimum is about 1.10503 × 10^-8. Their largest scale difference is 0.33435 in internal distance units. One vector derives from HiGHS and the other from Clarabel; their names indicate provenance, not fresh solver executions.

We evaluated both at the same saved initial graph: 1,000 profiles and 1,733 edges, with unchanged distances, degrees, tuning state, volume calculation and pruning rules. The original Python calculation and the native implementation each evaluated ten cases: these two vectors, two saved controls, and six existing threshold/tie controls. **No optimizer was called.** Continuous agreement required absolute error at most 10^-12 plus 10^-12 times the reference magnitude; discrete decisions and their order had to match exactly.

The saved problem is from an intermediate retuning calculation, before the reference reaches its first pruning step. We therefore checked the actual next retuning action and separately asked what pruning would do if these scales were used at this fixed graph. This conditional comparison is not a resumed trajectory.

## Results

| Quantity | HiGHS-derived vector | Clarabel-derived vector |
|---|---:|---:|
| Next action | Continue retuning | Continue retuning |
| Median neighborhood volume ratio | 16.13781820045 | 16.13781820043 |
| Conditional pruning threshold | 58.86720093708 | 58.86720093694 |
| Nodes exceeding that threshold | 23 | 23 |
| Candidates after median-based expansion | 840 | 840 |
| Selected nodes | 84 | 84 |
| Edges removed | 52 | 52 |
| Edges remaining | 1,681 | 1,681 |

A neighborhood volume ratio compares Gaussian neighborhood mass with the expected mass used by IAN. The median remains far above the retuning target of 1 (tolerance 0.1). Under the unchanged pruning rule, that high median expands the candidate list beyond nodes exceeding the threshold; the highest-ranked 10% are selected. Some selected nodes share affected edges or endpoints, so 84 selections remove only 52 edges.

The largest volume-ratio change is 0.0033375; the threshold changes by only 1.44 × 10^-10. The nearest threshold margin is about 0.48538, and the ratio gap across the selection boundary is about 0.07570. The entire candidate order, selection order, removal order and resulting edge set agree between vectors. The three coordinates highlighted by the earlier range study remain unselected.

Python and native decisions agree for all ten cases within the declared numerical tolerance and exactly for discrete results. The raw saved-volume control reproduces exactly. The later, actual first-pruning control also reproduces its recorded threshold, candidates, selections and 47 removed edges exactly. Those 47 historical removals follow additional retuning and must not be confused with the 52 conditional removals above.

## Certification and limits

Exact arithmetic rechecked both source vectors against the original inequalities and frozen objective cutoff. Decision routines require binary64 numbers, so each rational coordinate was rounded once without repair. Maximum coordinate rounding errors were below 4.4 × 10^-13. The rounded HiGHS-derived point remains exactly feasible; the rounded Clarabel-derived point has a positive row violation of about 5.92 × 10^-14. Both remain below the objective cutoff. The conditional numerical comparison uses these disclosed rounded inputs; it does not assert exact feasibility for the rounded Clarabel point.

This result establishes agreement for two endpoints at one graph. It does not prove that every point in the objective band has the same decisions, that later retuning agrees, or that a complete helix trajectory is compatible. It supplies no reason to adopt either solver, introduce a secondary scale rule, relax checks, or reopen the scale ladder. Interface engineering can proceed separately.

## Evidence and next step

The [prescribed plan](PLAN.md), [maintained result snapshot](results-summary.json), [complete numerical evidence](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/pruning/replay-v1/results.json), [exact witness checks](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/pruning/replay-v1/exact-witness-checks.json), [run provenance](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/pruning/replay-v1/run.json) and [file manifest](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/pruning/replay-v1/manifest.json) retain the inputs, comparisons and commands. The committed pre-run source is 7d34d7570ad119bb6898c66ca966979ba064cac7. Historical inputs were unchanged after execution.

Independent review of this bounded comparison is the immediate next step. Any wider sensitivity or full-trajectory study needs a separate bounded design. This study does not execute the [proposed secondary-selection study](../018-scale-selection/report.md).
