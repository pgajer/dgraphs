# Do formulation differences change decisions near numerical thresholds?

**Native/evaluated comparisons pass; historical array differences and incomplete pruning calibration remain.**

IAN-EXP-006 · Historical phase 05 · Aims IA1, IA4.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

Test whether small formulation differences matter when a graph decision is close to its threshold. The [project aims](../../docs/project-aims.md) explain its role; this question-based grouping is retrospective.

## Analysis and data contract

Twelve frozen fixed-state cases, six no-solve threshold/tie examples and four full inputs compare original-expression Python, evaluated Python and native code. The full inputs are two perturbed PreSSMat subsets, a 120-profile helix and a 144-profile saddle.

[Shared methods](../shared-methods.md) define the reference conditions, tolerances and observation units; [dataset orientation](../dataset-orientation.md) identifies the examples and sampling limits. These computational checks do not estimate biological effects.

## Observed results

The audit verifies 1,330 submitted payloads and 51 fresh executions containing 1,302 solves. Native/evaluated decisions and arrays pass. Historical intermediate arrays fail in eight fixed-state cases and three full examples; tested discrete choices and final affinities agree.

This record summarizes fixed decision-boundary and full-trajectory checks. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

The pruning calibration did not bracket a boundary. Library warnings remain unresolved at their source. IAN evaluated-LP 1.0 is a working implementation reference, not general historical equivalence.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Issue dispositions and later closure evidence are linked above. Study acceptance does not clear a failed compatibility gate.

## Recommendations and dependencies

Retain boundary cases as regressions and keep policy changes separately named.

- [IAN-EXP-005: Does agreement persist through longer pruning and retuning histories?](../005-long-histories/report.md) — consumed output.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase05/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase05/PLAN.md)
- [Evidence identities and historical provenance](evidence-manifest.json).
- [Catalogue build instructions](../README.md): run from the implementation worktree. Numerical reproduction uses the separately frozen historical plan and environment.

Current hashes identify available files, not historical execution. External backup coverage is unknown.
