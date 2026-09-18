# Does dual simplex produce stable and compatible scales on these problems?

**HiGHS is stable across the input perturbation but differs from successful Clarabel in three coordinates.**

IAN-EXP-016 · Historical phase 07H · Aims IA1, IA4.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

The question is: does dual simplex produce stable and compatible scales on these problems? This record places the documented comparison in the [project aims](../../docs/project-aims.md); the question-based grouping is a retrospective documentation choice. Its predecessor relationships are stated below and do not imply independent replication.

## Analysis and data contract

The two saved LPs each receive one HiGHS dual-simplex solve and one fresh-process repeat. Presolve/scaling are disabled; original bound rows remain and extra bounds are free. Full backend settings and models are captured. No-solve guard controls are separate.

A solve, a full trajectory and a pruning decision are different observation units. Reference conditions, tolerance meanings and input reuse are defined in [shared methods](../shared-methods.md); example identities and sampling limitations are in [dataset orientation](../dataset-orientation.md). No biological estimand or population-level uncertainty is inferred from these computational checks.

## Observed results

All four calls return Optimal in 2,175 iterations and pass original-unit checks. Scale and dual vectors match exactly across inputs and repeats. Coordinates 229, 230 and 717 differ from successful Clarabel, with maximum scale difference 0.3343531.

This record summarizes fixed-problem or trajectory diagnostic checks. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

Four deterministic calls are not population replicates. The unchanged external tests do not prove exact optimality or a uniquely selected vector. The one-shot supervisor correction is independently accepted; no solver is adopted.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Current issue dispositions and later closure evidence are linked above. A completed negative study remains useful evidence; acceptance of its scope does not authorize progression through a failed compatibility gate.

## Recommendations and dependencies

Bound near-optimal scale ranges on one common fixed LP.

- [IAN-EXP-015: Does the terminal outcome follow the input or the interface?](../015-input-interface/report.md) — shared input.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07h/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07h/PLAN.md)
- [Evidence identities](evidence-manifest.json) identify declared/resolved locations, available source hashes and known historical provenance.
- [Catalogue build instructions](../README.md) distinguish figure reconstruction and rendering from numerical execution. Run them from the implementation worktree; numerical reproduction, if separately requested, uses the frozen historical plan and environment.

Current file hashes establish what is available now, not proof of which source produced an old execution. Generated catalogue outputs have no confirmed external backup.
