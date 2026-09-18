# Can interrupted runs resume without changing their results?

**Tested checkpoints preserve completed work and reproduce continuation on the pinned host.**

IAN-EXP-008 · Historical phase 06B · Aims IA2.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

Preserve completed progress across interruptions without silently changing the resumed trajectory. The [project aims](../../docs/project-aims.md) explain its role; this question-based grouping is retrospective.

## Analysis and data contract

Owned snapshots bind input, configuration, numerical policy and trace prefix at supported pruning/graph boundaries. Eight prior complete examples and fixed probes support regression; recovery controls include cancellation, process death and simulated storage failures.

[Shared methods](../shared-methods.md) define the reference conditions, tolerances and observation units; [dataset orientation](../dataset-orientation.md) identifies the examples and sampling limits. These computational checks do not estimate biological effects.

## Observed results

The main recovery workload has 73 executions and 19 full continuation comparisons. Successful recoveries match uninterrupted traces and final results, excluding time. A separate three-run interval check adds one resumed comparison.

This record summarizes restart and checkpoint-failure checks. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

Initial resource problems and their versioned correction remain preserved. No mid-retuning restart, power-loss durability or cross-build/platform migration is established. A roadmap documentation comment was closed in the next milestone.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Issue dispositions and later closure evidence are linked above. Study acceptance does not clear a failed compatibility gate.

## Recommendations and dependencies

Apply bounded scale tests with truthful failure and checkpoint accounting.

- [IAN-EXP-007: Can the engine become a reusable core without changing behavior?](../007-reusable-core/report.md) — shared infrastructure.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase06b/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase06b/PLAN.md)
- [Evidence identities and historical provenance](evidence-manifest.json).
- [Catalogue build instructions](../README.md): run from the implementation worktree. Numerical reproduction uses the separately frozen historical plan and environment.

Current hashes identify available files, not historical execution. External backup coverage is unknown.
