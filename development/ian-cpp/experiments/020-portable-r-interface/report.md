# Which platforms and R interfaces can be qualified?

**Broader platform study: proposed, not executed. Bounded macOS evidence is available from the separate independent adapter audit.**

IAN-EXP-020 · Historical phase 09 · Aim IA2 · Updated 23 September 2026.

## Purpose and existing evidence

The intended study extends build and R-interface qualification beyond one host. The owner authorized independent review of the repaired adapter and feasible broader qualification. That review tested two R environments on the same Mac; it does not complete the proposed Linux, Windows or other-architecture study.

The [independent adapter audit](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/auditor/review-adapter-layout/audit.md) accepts the repaired 39-field C/Rust settings interface, rejection of incompatible layouts and complete settings capture for the executed builds. The earlier statement that this repair remains unreviewed no longer describes the new adapter. Historical binaries remain unchanged.

| Environment | Evidence available | What remains untested |
| --- | --- | --- |
| macOS 26.6.1 arm64, R-devel r90190, Rcpp 1.1.2 | Fresh original and typed installed builds; full bounded interface schedules and four small complete traces | Larger trajectories and full package qualification |
| Same Mac, R 4.5.2, Rcpp 1.1.1 | Fresh typed installation/backend; four complete traces and three interface controls agree with R-devel | Original adapter and full interrupt/interface schedule on this R version |
| macOS x86_64 | C header compilation checks size, alignment and field offsets | Rust, linking, R and runtime behavior |
| Linux and Windows | Tool inventory and build-helper inspection | Actual builds and runtime tests; the helper currently supports macOS arm64 only |

The audit used 46 engine calls and 237 solver attempts across both adapter candidates and the additional R-version subset. These are audit executions for [the adapter](../024-internal-dgraphs-adapter/report.md) and [typed core](../025-typed-core-messages/report.md), not a newly executed broad-platform experiment. Only 96 attempts had complete payloads for independent numerical-certificate recalculation; all 237 had their settings records checked.

The audit preserves initial R 4.5.2 environment failures. A private launcher and isolated dependencies enabled testing without changing ordinary R libraries.

## Proposed next qualification

Select supported targets and dependency distribution. Linux, Windows and Intel Mac qualification require actual R runners, an appropriate module build path and pinned Rust/C++ toolchains.

For each environment, the auditor recommends 13 interface cases, four complete traces and five native checkpoint/observer controls: 22 engine calls and an expected 111 attempts. Predeclare hard limits of 24 calls, 200 attempts, 80 attempts per call and at most 96 profiles, plus zero-optimization layout/capture probes and six fixed decision controls. Treat a second R version as a separate environment. Compare unchanged settings, numerical checks and failure behavior with the frozen references; investigate deviations before changing policy or tolerances.

## Interpretation and limits

Compilation alone does not qualify runtime behavior. Existing long-path source-package warnings remain; full R CMD check and CRAN qualification were not performed. Single-precision, semidefinite and alternative solver backends remain outside this scope. This audit does not adopt the experimental retry or helix arithmetic policies, authorize public export, or reopen the scale ladder.

[Standing audit authorization](../../docs/audit-coordination.md) applies. This catalogue presentation remains unreviewed; its [audit summary](audit-summary.json) separates the broader proposal from bounded Mac evidence.

## Sources and reproduction

- [Independent audit](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/auditor/review-adapter-layout/audit.md) and its [pre-execution plan](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/auditor/review-adapter-layout/PLAN.md).
- [Reusable core](../007-reusable-core/report.md), [internal adapter](../024-internal-dgraphs-adapter/report.md) and [typed core](../025-typed-core-messages/report.md).
- [Historical roadmap](../../../ian-cpp-phase1/coordinator/ROADMAP.md).
- [Evidence identities](evidence-manifest.json) and [catalogue build instructions](../README.md).
