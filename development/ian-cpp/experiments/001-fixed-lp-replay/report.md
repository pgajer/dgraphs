# Can native replay reproduce saved scale optimizations?

**Saved scale optimizations reproduce; the measured benefit is chiefly lower client memory.**

IAN-EXP-001 · Historical phase 01 · Aims IA1, IA3.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

Compare solver interfaces on fixed saved coefficients before attributing any benefit to a full native engine. The [project aims](../../docs/project-aims.md) explain its role; this question-based grouping is retrospective.

## Analysis and data contract

Six saved events cover five unique LPs: three small synthetic events and three events from the historical combined Hellinger run (4,841 unique profiles). Native and Python/CVXPY solve the same stored coefficients in fresh processes.

[Shared methods](../shared-methods.md) define the reference conditions, tolerances and observation units; [dataset orientation](../dataset-orientation.md) identifies the examples and sampling limits. These computational checks do not estimate biological effects.

## Observed results

All 36 measured solves pass. Native fresh-process wall time is 1.08-1.15 times faster on the three combined-cohort cases; peak process memory is about 53-55% lower. Solver-reported time is essentially unchanged.

This record summarizes saved-solve agreement and client resource comparisons. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

The two gap-observation events are byte-identical. These are fixed-LP client measurements, not full-engine performance, independent biological replicates or a cohort fit.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Issue dispositions and later closure evidence are linked above. Study acceptance does not clear a failed compatibility gate.

## Recommendations and dependencies

Build and compare complete adaptive trajectories; keep process and solver time distinct.

No predecessor is declared.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/PLAN.md)
- [Evidence identities and historical provenance](evidence-manifest.json).
- [Catalogue build instructions](../README.md): run from the implementation worktree. Numerical reproduction uses the separately frozen historical plan and environment.

Current hashes identify available files, not historical execution. External backup coverage is unknown.
