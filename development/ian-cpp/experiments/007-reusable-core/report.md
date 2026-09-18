# Can the engine become a reusable core without changing behavior?

**The core preserves tested numerical behavior; malformed schema declarations are now refused before execution.**

IAN-EXP-007 · Historical phase 06A · Aims IA1, IA2.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

Create a callable engine while preserving numerical behavior and reference comparisons. The [project aims](../../docs/project-aims.md) explain its role; this question-based grouping is retrospective.

## Analysis and data contract

A typed C++ core, CLI and file/R adapters are tested against eight full native traces, twelve boundary probes and prior operational cases. A clean dependency build, external C++ consumer and minimal R example test one-host feasibility.

[Shared methods](../shared-methods.md) define the reference conditions, tolerances and observation units; [dataset orientation](../dataset-orientation.md) identifies the examples and sampling limits. These computational checks do not estimate biological effects.

## Observed results

Accepted trajectories reproduce except timing. Audit finding F1 identified fractional/out-of-range schema conversion; the corrected parser passes 18 submitted tests and 28 additional audit checks, preserving valid-run results.

This record summarizes core-interface and input-declaration checks. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

The first candidate was not accepted until F1 was independently closed. This is single-platform interface feasibility, not portable release qualification, resumability or demonstrated memory improvement.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Issue dispositions and later closure evidence are linked above. Study acceptance does not clear a failed compatibility gate.

## Recommendations and dependencies

Add checkpoint/resume as a separate behavior-preserving milestone.

- [IAN-EXP-006: Do formulation differences change decisions near numerical thresholds?](../006-decision-boundaries/report.md) — consumed output.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase06a/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase06a/PLAN.md)
- [Evidence identities and historical provenance](evidence-manifest.json).
- [Catalogue build instructions](../README.md): run from the implementation worktree. Numerical reproduction uses the separately frozen historical plan and environment.

Current hashes identify available files, not historical execution. External backup coverage is unknown.
