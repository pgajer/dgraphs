# Why does solver success coexist with IAN rejection?

**Global solver stopping criteria differ from the external row-wise acceptance checks.**

IAN-EXP-010 · Historical phase 07B · Aims IA1, IA4.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

Explain a shared refusal by examining the saved rejected optimization problem. The [project aims](../../docs/project-aims.md) explain its role; this question-based grouping is retrospective.

## Analysis and data contract

Five fixed problems include evaluated helix/control LPs, a selected PreSSMat stress problem and the original-expression helix cone formulation. Thirty-three prespecified direct Python Clarabel solves vary stopping settings and normalization.

[Shared methods](../shared-methods.md) define the reference conditions, tolerances and observation units; [dataset orientation](../dataset-orientation.md) identifies the examples and sampling limits. These computational checks do not estimate biological effects.

## Observed results

All five baseline cases reproduce exactly. Tighter settings can repair rejected problems, but also move previously accepted vectors beyond the old scale allowance. The historical formulation has additional numerical amplification.

This record summarizes fixed-problem or trajectory diagnostic checks. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

The selected cases are stress diagnostics. A tighter solve that passes a certificate is not automatically a compatible full-engine policy. No graph trajectory or native rebuild occurs here.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Issue dispositions and later closure evidence are linked above. Study acceptance does not clear a failed compatibility gate.

## Recommendations and dependencies

Test a limited retry policy on full trajectories with unchanged external acceptance.

- [IAN-EXP-009: Does implementation agreement persist at 500 profiles?](../009-scale-500/report.md) — consumed output.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07b/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07b/PLAN.md)
- [Evidence identities and historical provenance](evidence-manifest.json).
- [Catalogue build instructions](../README.md): run from the implementation worktree. Numerical reproduction uses the separately frozen historical plan and environment.

Current hashes identify available files, not historical execution. External backup coverage is unknown.
