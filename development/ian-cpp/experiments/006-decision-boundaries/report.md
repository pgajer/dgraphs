# Do formulation differences change decisions near numerical thresholds?

**Native/evaluated comparisons pass; historical array differences and incomplete pruning calibration remain.**

IAN-EXP-006 · Historical phase 05 · Aims IA1, IA4.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

The question is: do formulation differences change decisions near numerical thresholds? This record places the documented comparison in the [project aims](../../docs/project-aims.md); the question-based grouping is a retrospective documentation choice. Its predecessor relationships are stated below and do not imply independent replication.

## Analysis and data contract

Twelve frozen fixed-state cases, six no-solve threshold/tie examples and four full inputs compare original-expression Python, evaluated Python and native code. The full inputs are two perturbed PreSSMat subsets, a 120-profile helix and a 144-profile saddle.

A solve, a full trajectory and a pruning decision are different observation units. Reference conditions, tolerance meanings and input reuse are defined in [shared methods](../shared-methods.md); example identities and sampling limitations are in [dataset orientation](../dataset-orientation.md). No biological estimand or population-level uncertainty is inferred from these computational checks.

## Observed results

The audit verifies 1,330 submitted payloads and 51 fresh executions containing 1,302 solves. Native/evaluated decisions and arrays pass. Historical intermediate arrays fail in eight fixed-state cases and three full examples; tested discrete choices and final affinities agree.

This record summarizes fixed decision-boundary and full-trajectory checks. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

The pruning calibration did not bracket a boundary. Library warnings remain unresolved at their source. IAN evaluated-LP 1.0 is a working implementation reference, not general historical equivalence.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Current issue dispositions and later closure evidence are linked above. A completed negative study remains useful evidence; acceptance of its scope does not authorize progression through a failed compatibility gate.

## Recommendations and dependencies

Retain boundary cases as regressions and keep policy changes separately named.

- [IAN-EXP-005: Does agreement persist through longer pruning and retuning histories?](../005-long-histories/report.md) — consumed output.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase05/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase05/PLAN.md)
- [Evidence identities](evidence-manifest.json) identify declared/resolved locations, available source hashes and known historical provenance.
- [Catalogue build instructions](../README.md) distinguish figure reconstruction and rendering from numerical execution. Run them from the implementation worktree; numerical reproduction, if separately requested, uses the frozen historical plan and environment.

Current file hashes establish what is available now, not proof of which source produced an old execution. Generated catalogue outputs have no confirmed external backup.
