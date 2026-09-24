# What explains the historical versus replay runtime discrepancy?

**Representation, linear-system backend and threads explain the large timing difference; C++ does not.**

IAN-EXP-002 · Historical phase 02 · Aims IA1, IA3.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

Identify which execution conditions explain the large historical timing difference before attributing it to language. The [project aims](../../docs/project-aims.md) explain its role; this question-based grouping is retrospective.

## Analysis and data contract

Six controlled diagnostics use the saved final-retuning state of the historical 4,841-profile combined-cohort run. They vary original-expression versus evaluated-LP representation, backend and threading in Python.

[Shared methods](../shared-methods.md) define the reference conditions, tolerances and observation units; [dataset orientation](../dataset-orientation.md) identifies the examples and sampling limits. These computational checks do not estimate biological effects.

## Observed results

The historical observation was 415.053 seconds and 133 iterations. Reconstructed original-expression automatic faer/16-thread execution took 372.090 seconds and reproduced its vector exactly. Original expression with QDLDL/one thread took 17.118 seconds; evaluated LP with QDLDL/one thread took 5.739 seconds and 45 iterations.

{{figure:runtime}}

## Interpretation and limitations

These are single controlled observations. The actual historical backend/thread state and contention were not saved. A reconstruction cannot replace the original execution record.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Issue dispositions and later closure evidence are linked above. Study acceptance does not clear a failed compatibility gate.

## Recommendations and dependencies

Compare persistent processes before attributing gains to language or startup.

- [IAN-EXP-001: Can native replay reproduce saved scale optimizations?](../001-fixed-lp-replay/report.md) — motivation.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase02/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase02/PLAN.md)
- [Evidence identities and historical provenance](evidence-manifest.json).
- [Catalogue build instructions](../README.md): run from the implementation worktree. Numerical reproduction uses the separately frozen historical plan and environment.

Current hashes identify available files, not historical execution. External backup coverage is unknown.
