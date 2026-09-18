# Does one stricter retry repair complete trajectories?

**Seven helix failures are repaired, but the next retry fails its optimality certificate.**

IAN-EXP-011 · Historical phase 07C · Aims IA1, IA4.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

The question is: does one stricter retry repair complete trajectories? This record places the documented comparison in the [project aims](../../docs/project-aims.md); the question-based grouping is a retrospective documentation choice. Its predecessor relationships are stated below and do not imply independent replication.

## Analysis and data contract

Ordinary solves retain accepted settings. Eligible rejected returns may receive one fresh solve on identical coefficients at 1e-11 internal tolerances. The external 1e-7 checks and full regression panel remain unchanged.

A solve, a full trajectory and a pruning decision are different observation units. Reference conditions, tolerance meanings and input reuse are defined in [shared methods](../shared-methods.md); example identities and sampling limitations are in [dataset orientation](../dataset-orientation.md). No biological estimand or population-level uncertainty is inferred from these computational checks.

## Observed results

The main panel records 1,882 attempts, 1,864 accepted and 18 rejected. Both helix paths stop before pruning. Eleven other full inputs complete and preserve accepted behavior; a separate preliminary panel and operational attempts are retained in the historical ledger.

This record summarizes fixed-problem or trajectory diagnostic checks. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

The last strict retry has stationarity error about 1.053e-7, exceeding 1e-7. Counts from preliminary, primary and operational runs must not be pooled without their labels. The retry policy is experimental.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Current issue dispositions and later closure evidence are linked above. A completed negative study remains useful evidence; acceptance of its scope does not authorize progression through a failed compatibility gate.

## Recommendations and dependencies

Diagnose the remaining fixed dual-certificate failure.

- [IAN-EXP-010: Why does solver success coexist with IAN rejection?](../010-stopping-tests/report.md) — motivation.
- [IAN-EXP-008: Can interrupted runs resume without changing their results?](../008-checkpoint-resume/report.md) — shared infrastructure.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07c/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07c/PLAN.md)
- [Evidence identities](evidence-manifest.json) identify declared/resolved locations, available source hashes and known historical provenance.
- [Catalogue build instructions](../README.md) distinguish figure reconstruction and rendering from numerical execution. Run them from the implementation worktree; numerical reproduction, if separately requested, uses the frozen historical plan and environment.

Current file hashes establish what is available now, not proof of which source produced an old execution. Generated catalogue outputs have no confirmed external backup.
