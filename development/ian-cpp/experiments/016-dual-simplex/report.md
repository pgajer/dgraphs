# Does dual simplex produce stable and compatible scales on these problems?

**HiGHS is stable across the input perturbation but differs from successful Clarabel in three coordinates.**

IAN-EXP-016 · Historical phase 07H · Aims IA1, IA4.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

Use a different LP algorithm diagnostically before considering further tolerance changes. The [project aims](../../docs/project-aims.md) explain its role; this question-based grouping is retrospective.

## Analysis and data contract

The two saved LPs each receive one HiGHS dual-simplex solve and one fresh-process repeat. Presolve/scaling are disabled; original bound rows remain and extra bounds are free. Full backend settings and models are captured. No-solve guard controls are separate.

[Shared methods](../shared-methods.md) define the reference conditions, tolerances and observation units; [dataset orientation](../dataset-orientation.md) identifies the examples and sampling limits. These computational checks do not estimate biological effects.

## Observed results

All four calls return Optimal in 2,175 iterations and pass original-unit checks. Scale and dual vectors match exactly across inputs and repeats. Coordinates 229, 230 and 717 differ from successful Clarabel, with maximum scale difference 0.3343531.

This record summarizes fixed-problem or trajectory diagnostic checks. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

Four deterministic calls are not population replicates. The unchanged external tests do not prove exact optimality or a uniquely selected vector. The one-shot supervisor correction is independently accepted; no solver is adopted.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Issue dispositions and later closure evidence are linked above. Study acceptance does not clear a failed compatibility gate.

## Recommendations and dependencies

Bound near-optimal scale ranges on one common fixed LP.

- [IAN-EXP-015: Does the terminal outcome follow the input or the interface?](../015-input-interface/report.md) — shared input.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07h/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07h/PLAN.md)
- [Evidence identities and historical provenance](evidence-manifest.json).
- [Catalogue build instructions](../README.md): run from the implementation worktree. Numerical reproduction uses the separately frozen historical plan and environment.

Current hashes identify available files, not historical execution. External backup coverage is unknown.
