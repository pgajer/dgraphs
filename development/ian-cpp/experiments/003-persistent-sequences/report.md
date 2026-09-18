# Does native execution improve repeated-solve costs?

**Persistent runtimes are nearly equal; native benchmark-client memory is lower.**

IAN-EXP-003 · Historical phase 02 · Aims IA3.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

The question is: does native execution improve repeated-solve costs? This record places the documented comparison in the [project aims](../../docs/project-aims.md); the question-based grouping is a retrospective documentation choice. Its predecessor relationships are stated below and do not imply independent replication.

## Analysis and data contract

The last eight saved post-pruning problems and four specified final-retuning problems are executed as short persistent sequences. Eighteen serial process jobs test three repetitions of applicable fresh-construction and data-update conditions.

A solve, a full trajectory and a pruning decision are different observation units. Reference conditions, tolerance meanings and input reuse are defined in [shared methods](../shared-methods.md); example identities and sampling limitations are in [dataset orientation](../dataset-orientation.md). No biological estimand or population-level uncertainty is inferred from these computational checks.

## Observed results

All 96 measured sequence solutions pass the recorded numerical checks. Native and Python runtimes are nearly equal; native peak memory is 52-61% lower for these clients. Supported solver updates reduce setup work without establishing a useful total-time gain.

This record summarizes persistent-sequence agreement and client resource comparisons. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

The input sequence is reused from one interrupted run. Fresh-process, persistent-client and full-engine memory are different quantities. Updating fixed structure does not qualify dimension-changing reuse.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Current issue dispositions and later closure evidence are linked above. A completed negative study remains useful evidence; acceptance of its scope does not authorize progression through a failed compatibility gate.

## Recommendations and dependencies

Investigate complete-engine correctness before broad performance optimization.

- [IAN-EXP-001: Can native replay reproduce saved scale optimizations?](../001-fixed-lp-replay/report.md) — shared input.
- [IAN-EXP-002: What explains the historical versus replay runtime discrepancy?](../002-historical-runtime/report.md) — motivation.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase02/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase02/PLAN.md)
- [Evidence identities](evidence-manifest.json) identify declared/resolved locations, available source hashes and known historical provenance.
- [Catalogue build instructions](../README.md) distinguish figure reconstruction and rendering from numerical execution. Run them from the implementation worktree; numerical reproduction, if separately requested, uses the frozen historical plan and environment.

Current file hashes establish what is available now, not proof of which source produced an old execution. Generated catalogue outputs have no confirmed external backup.
