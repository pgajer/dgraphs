# How strongly does the objective determine the disputed scale?

**Two exactly feasible witnesses differ by at least 0.33435 within a very narrow objective allowance.**

IAN-EXP-017 · Historical phase 07I · Aims IA1, IA4.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

Measure the permitted variation of the disputed scale under an explicit, strictly checked objective allowance. The [project aims](../../docs/project-aims.md) explain its role; this question-based grouping is retrospective.

## Analysis and data contract

On the Python-generated terminal LP, six min/max calls target coordinate 717 at three frozen objective bands above a rational upper bound. Exact arithmetic checks raw endpoints, repairs and augmented dual bounds; saved HiGHS/Clarabel witnesses are separately labeled.

[Shared methods](../shared-methods.md) define the reference conditions, tolerances and observation units; [dataset orientation](../dataset-orientation.md) identifies the examples and sampling limits. These computational checks do not estimate biological effects.

## Observed results

None of the six fresh raw endpoints is exactly feasible; three exceed their bands. Separately repaired historical witnesses establish span at least 0.33435 within 1.10503e-8 of the optimum. Fresh dual bounds place the narrowest-band full span at most 0.438902.

{{figure:ranges}}

## Interpretation and limitations

The full extrema remain unresolved. A near-optimal range is not proof of multiple exact optima. Repairs of fresh endpoints collapse almost to the baseline; the historical-witness result must not be attributed to successful raw endpoint solves.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Issue dispositions and later closure evidence are linked above. Study acceptance does not clear a failed compatibility gate.

## Recommendations and dependencies

Consider an explicit secondary scale-selection policy as a new bounded proposal.

- [IAN-EXP-016: Does dual simplex produce stable and compatible scales on these problems?](../016-dual-simplex/report.md) — consumed output.
- [IAN-EXP-014: Does the tested retry policy remain compatible at 1,000 profiles?](../014-scale-1000/report.md) — shared input.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07i/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07i/PLAN.md)
- [Evidence identities and historical provenance](evidence-manifest.json).
- [Catalogue build instructions](../README.md): run from the implementation worktree. Numerical reproduction uses the separately frozen historical plan and environment.

Current hashes identify available files, not historical execution. External backup coverage is unknown.
