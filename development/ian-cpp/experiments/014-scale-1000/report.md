# Does the tested retry policy remain compatible at 1,000 profiles?

**Native refuses before pruning while Python completes; six remaining inputs stay gated.**

IAN-EXP-014 · Historical phase 07F · Aims IA1, IA4.

Executed; original bounded evidence independently accepted. This catalogue summary and its newly drawn figures have not been independently reviewed. The authoritative [audit summary](audit-summary.json) and [issue register](../correction-dispositions.json) distinguish original evidence, corrections and current presentation.

## Goal and motivation

The question is: does the tested retry policy remain compatible at 1,000 profiles? This record places the documented comparison in the [project aims](../../docs/project-aims.md); the question-based grouping is a retrospective documentation choice. Its predecessor relationships are stated below and do not imply independent replication.

## Analysis and data contract

The first 1,000-profile input is the frozen density-varying helix. Cloud, lobes and four dgraphs quadforms are also prepared. Quadforms have intrinsic dimensions 2-5 and ambient dimensions 3-6; sampling is uniform in latent coordinates.

A solve, a full trajectory and a pruning decision are different observation units. Reference conditions, tolerance meanings and input reuse are defined in [shared methods](../shared-methods.md); example identities and sampling limitations are in [dataset orientation](../dataset-orientation.md). No biological estimand or population-level uncertainty is inferred from these computational checks.

## Observed results

Native performs 26 attempts and refuses; Python performs 112 attempts and completes 47 pruning steps. The terminal LPs differ by one RHS floating-point step. Both returns pass numerical inequalities, but status and scale comparisons disagree.

This record summarizes fixed-problem or trajectory diagnostic checks. The frozen report and evidence manifest retain the detailed tables/traces; no additional standalone plot is needed for this question.

## Interpretation and limitations

The native result is not a completed graph. The prepared quadforms have no IAN trajectory evidence. The larger native restart test is unavailable; preparation is not execution.

## Verification and audit findings

The numerical-check flag refers to the independent checks of the original bounded milestone, identified in the audit summary. It does not certify every sentence, figure or intended use of this newly authored record. No optimization was rerun for this catalogue.

Current issue dispositions and later closure evidence are linked above. A completed negative study remains useful evidence; acceptance of its scope does not authorize progression through a failed compatibility gate.

## Recommendations and dependencies

Cross the two exact saved inputs with both solver interfaces.

- [IAN-EXP-013: Can broader retry eligibility complete the helix without relaxing acceptance?](../013-retry-eligibility/report.md) — shared infrastructure.
- [IAN-EXP-009: Does implementation agreement persist at 500 profiles?](../009-scale-500/report.md) — shared input.

## Sources and reproduction

- [Historical report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07f/REPORT.md)
- [Historical plan / source](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree/development/ian-cpp-phase1/phase07f/PLAN.md)
- [Evidence identities](evidence-manifest.json) identify declared/resolved locations, available source hashes and known historical provenance.
- [Catalogue build instructions](../README.md) distinguish figure reconstruction and rendering from numerical execution. Run them from the implementation worktree; numerical reproduction, if separately requested, uses the frozen historical plan and environment.

Current file hashes establish what is available now, not proof of which source produced an old execution. Generated catalogue outputs have no confirmed external backup.
