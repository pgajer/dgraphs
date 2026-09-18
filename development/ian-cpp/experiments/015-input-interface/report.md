# Does the terminal outcome follow the input or the interface?

**Identical inputs yield identical results across interfaces; the perturbation switches the outcome.**

IAN-EXP-015 · Historical phase 07G · Aims IA1, IA4.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

Cross exact saved inputs with both interfaces to separate input sensitivity from implementation differences. The [project aims](../../docs/project-aims.md) explain its role; this question-based grouping is retrospective.

## Analysis and data contract

Two exact terminal LPs are each replayed through native and Python Clarabel, with one fresh-process repeat per cell: eight solves. Actual binary64 CSC arrays and normalization are checked, not just fixture descriptions.

[Shared methods](../shared-methods.md) define the reference conditions, tolerances and observation units; [dataset orientation](../dataset-orientation.md) identifies the examples and sampling limits. These computational checks do not estimate biological effects.

## Observed results

The native-generated input returns AlmostSolved in 18 iterations through both paths. The Python-generated input returns Solved in 27 through both. Across inputs, scales differ by up to 246.35. Own-input baselines and repeats reproduce.

{{figure:interface}}

## Interpretation and limitations

Native settings capture was incomplete and later reconstructed without solving. Audit N1 found a final-process supervisor race; eight numerical audit outputs exist but only seven complete process records. Phase07H closes N1 prospectively.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Issue dispositions and later closure evidence are linked above. Study acceptance does not clear a failed compatibility gate.

## Recommendations and dependencies

Use the corrected one-shot guard to compare an alternative LP algorithm.

- [IAN-EXP-014: Does the tested retry policy remain compatible at 1,000 profiles?](../014-scale-1000/report.md) — consumed output.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07g/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07g/PLAN.md)
- [Evidence identities and historical provenance](evidence-manifest.json).
- [Catalogue build instructions](../README.md): run from the implementation worktree. Numerical reproduction uses the separately frozen historical plan and environment.

Current hashes identify available files, not historical execution. External backup coverage is unknown.
