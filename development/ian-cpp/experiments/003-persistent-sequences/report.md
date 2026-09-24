# Does native execution improve repeated-solve costs?

**Persistent runtimes are nearly equal; native benchmark-client memory is lower.**

IAN-EXP-003 · Historical phase 02 · Aims IA3.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

Test repeated optimization costs with processes kept alive, as they would be inside an adaptive engine. The [project aims](../../docs/project-aims.md) explain its role; this question-based grouping is retrospective.

## Analysis and data contract

The last eight saved post-pruning problems and four specified final-retuning problems are executed as short persistent sequences. Eighteen serial process jobs test three repetitions of applicable fresh-construction and data-update conditions.

[Shared methods](../shared-methods.md) define the reference conditions, tolerances and observation units; [dataset orientation](../dataset-orientation.md) identifies the examples and sampling limits. These computational checks do not estimate biological effects.

## Observed results

All 96 measured sequence solutions pass the recorded numerical checks. Native and Python runtimes are nearly equal; native peak memory is 52-61% lower for these clients. Supported solver updates reduce setup work without establishing a useful total-time gain.

This record summarizes persistent-sequence agreement and client resource comparisons. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

The input sequence is reused from one interrupted run. Fresh-process, persistent-client and full-engine memory are different quantities. Updating fixed structure does not qualify dimension-changing reuse.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Issue dispositions and later closure evidence are linked above. Study acceptance does not clear a failed compatibility gate.

## Recommendations and dependencies

Investigate complete-engine correctness before broad performance optimization.

- [IAN-EXP-001: Can native replay reproduce saved scale optimizations?](../001-fixed-lp-replay/report.md) — shared input.
- [IAN-EXP-002: What explains the historical versus replay runtime discrepancy?](../002-historical-runtime/report.md) — motivation.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase02/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase02/PLAN.md)
- [Evidence identities and historical provenance](evidence-manifest.json).
- [Catalogue build instructions](../README.md): run from the implementation worktree. Numerical reproduction uses the separately frozen historical plan and environment.

Current hashes identify available files, not historical execution. External backup coverage is unknown.
