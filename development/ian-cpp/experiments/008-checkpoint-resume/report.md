# Can interrupted runs resume without changing their results?

**Tested checkpoints preserve completed work and reproduce continuation on the pinned host.**

IAN-EXP-008 · Historical phase 06B · Aims IA2.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

The question is: can interrupted runs resume without changing their results? This record places the documented comparison in the [project aims](../../docs/project-aims.md); the question-based grouping is a retrospective documentation choice. Its predecessor relationships are stated below and do not imply independent replication.

## Analysis and data contract

Owned snapshots bind input, configuration, numerical policy and trace prefix at supported pruning/graph boundaries. Eight prior complete examples and fixed probes support regression; recovery controls include cancellation, process death and simulated storage failures.

A solve, a full trajectory and a pruning decision are different observation units. Reference conditions, tolerance meanings and input reuse are defined in [shared methods](../shared-methods.md); example identities and sampling limitations are in [dataset orientation](../dataset-orientation.md). No biological estimand or population-level uncertainty is inferred from these computational checks.

## Observed results

The main recovery workload has 73 executions and 19 full continuation comparisons. Successful recoveries match uninterrupted traces and final results, excluding time. A separate three-run interval check adds one resumed comparison.

This record summarizes restart and checkpoint-failure checks. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

Initial resource problems and their versioned correction remain preserved. No mid-retuning restart, power-loss durability or cross-build/platform migration is established. A roadmap documentation comment was closed in the next milestone.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Current issue dispositions and later closure evidence are linked above. A completed negative study remains useful evidence; acceptance of its scope does not authorize progression through a failed compatibility gate.

## Recommendations and dependencies

Apply bounded scale tests with truthful failure and checkpoint accounting.

- [IAN-EXP-007: Can the engine become a reusable core without changing behavior?](../007-reusable-core/report.md) — shared infrastructure.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase06b/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase06b/PLAN.md)
- [Evidence identities](evidence-manifest.json) identify declared/resolved locations, available source hashes and known historical provenance.
- [Catalogue build instructions](../README.md) distinguish figure reconstruction and rendering from numerical execution. Run them from the implementation worktree; numerical reproduction, if separately requested, uses the frozen historical plan and environment.

Current file hashes establish what is available now, not proof of which source produced an old execution. Generated catalogue outputs have no confirmed external backup.
