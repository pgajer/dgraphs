# Can the engine become a reusable core without changing behavior?

**The core preserves tested numerical behavior; malformed schema declarations are now refused before execution.**

IAN-EXP-007 · Historical phase 06A · Aims IA1, IA2.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

The question is: can the engine become a reusable core without changing behavior? This record places the documented comparison in the [project aims](../../docs/project-aims.md); the question-based grouping is a retrospective documentation choice. Its predecessor relationships are stated below and do not imply independent replication.

## Analysis and data contract

A typed C++ core, CLI and file/R adapters are tested against eight full native traces, twelve boundary probes and prior operational cases. A clean dependency build, external C++ consumer and minimal R example test one-host feasibility.

A solve, a full trajectory and a pruning decision are different observation units. Reference conditions, tolerance meanings and input reuse are defined in [shared methods](../shared-methods.md); example identities and sampling limitations are in [dataset orientation](../dataset-orientation.md). No biological estimand or population-level uncertainty is inferred from these computational checks.

## Observed results

Accepted trajectories reproduce except timing. Audit finding F1 identified fractional/out-of-range schema conversion; the corrected parser passes 18 submitted tests and 28 additional audit checks, preserving valid-run results.

This record summarizes core-interface and input-declaration checks. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

The first candidate was not accepted until F1 was independently closed. This is single-platform interface feasibility, not portable release qualification, resumability or demonstrated memory improvement.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Current issue dispositions and later closure evidence are linked above. A completed negative study remains useful evidence; acceptance of its scope does not authorize progression through a failed compatibility gate.

## Recommendations and dependencies

Add checkpoint/resume as a separate behavior-preserving milestone.

- [IAN-EXP-006: Do formulation differences change decisions near numerical thresholds?](../006-decision-boundaries/report.md) — consumed output.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase06a/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase06a/PLAN.md)
- [Evidence identities](evidence-manifest.json) identify declared/resolved locations, available source hashes and known historical provenance.
- [Catalogue build instructions](../README.md) distinguish figure reconstruction and rendering from numerical execution. Run them from the implementation worktree; numerical reproduction, if separately requested, uses the frozen historical plan and environment.

Current file hashes establish what is available now, not proof of which source produced an old execution. Generated catalogue outputs have no confirmed external backup.
