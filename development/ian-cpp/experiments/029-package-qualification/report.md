# Can the internal R adapter be built and used from a fresh package installation?

IAN-EXP-029 · Continuation stage 3 · Aims IA1 and IA2 · 23 September 2026.

**Fresh installations and native backend builds preserve the tested IAN results. A mixed R-version build problem was corrected in a separate private installation. Independent audit is pending.** This qualifies a bounded internal interface, subject to review; it does not make IAN an exported function or establish public-release readiness.

## Methods and examples

The [prospective plan](../../stages/03-package-qualification/PLAN.md) used macOS arm64 with actual R-devel (24 June 2026, revision 90190) and R 4.5.2. Each runtime received a fresh private dgraphs installation and a fresh optional Rust/C++ backend built from the installed source distribution. Existing dependencies were reused with their origins recorded. Native-arm Rust 1.85.1, locked cached crates, Apple clang 21 and one numerical thread were used. Shared installations were untouched.

The initial panel in each runtime comprised the established 13 adapter cases; complete traces for four small strict-policy examples and five explicit retry-policy examples, including the 500-profile helix; three refusal controls; and a relocated-module example. The small examples are a nonuniform curve, a variable-density patch, nearby curved arms and the small PreSSMat Hellinger-distance engineering fixture. Controls cover duplicate profiles, supplied versus calculated distances, diagnostic levels, invalid solver output, solve budgets, interruption and unavailable backends.

After packaging corrections, both runtimes were freshly installed and rebuilt again. The remaining twelve authorized calls repeated the strict PreSSMat trace, retry-policy helix, three refusal controls and relocated-module example in each runtime. They were compared with the initial installed results and accepted native references. A later full package check exposed mixed R-version linkage, so the entire 26-call R 4.5.2 panel was repeated after correcting that private build environment. No new Python solves were needed. The strict default remains `IAN evaluated-LP 1.0`; the explicitly selected internal option is `IAN evaluated-LP retry-power 0.1`.

## Results

| Evidence | Initial package | Corrected packaging | Corrected R 4.5.2 linkage | Total |
| --- | ---: | ---: | ---: | ---: |
| R engine entries | 52 | 12 | 26 | 90 |
| Physical solver attempts | 414 | 214 | 207 | 835 |
| Fresh backend builds | 2 | 2 | 1 | 5 |

All declared numerical, output and failure-behavior comparisons pass. Initial and final graphs, local scales, affinities, retained diagnostics and structured incomplete results preserve the accepted behavior. All 835 settings snapshots match the declared policy. Read-only scalar calculations check 649 complete optimization payloads: 544 accepted and 105 rejected, with 100 retry attempts. These include repeated helix problems and deliberate refusal controls, not 649 independent examples. The remaining 186 attempts have preserved R results and solver summaries rather than complete optimization payloads; no full-payload certificate claim is made for them.

The 90 calls ran in 44 supervised processes, using 79.1 seconds of aggregate child time and a maximum sampled process-tree memory of 1,100.1 MiB. No numerical resource limit was reached. These are correctness measurements, not matched performance results. The declared limits were 64 entries, 2,000 solver attempts, one hour of numerical child time and 4 GiB per process tree. The original entry allowance is exhausted. A prospective amendment added 26 calls to replace the mixed-runtime R 4.5.2 evidence, with a cumulative ceiling of 90 and unchanged other numerical limits.

The optional module registers one native call with eight arguments, disables dynamic symbol lookup and uses a registered native address. Runtime registration checks pass in the final R-devel and corrected R 4.5.2 installations. Relocated module calls pass, and linkage inspection finds no private build-library dependency. Ordinary installation without the optional backend gives the intended error. The function remains unexported and retains the 500-row limit. A deliberately wrong Rust architecture and a deliberately corrupted source bundle are both refused before compilation.

## Packaging and package checks

The first package check exposed upstream source metadata and long paths in the R archive. The [declared correction](../../stages/03-package-qualification/AMENDMENT-1.md) ships the unchanged editable backend sources as a deterministic ZIP plus an identity manifest. The installed helper verifies and expands that archive before building. All 264 backend source files match the accepted source bytes, including license notices. The repository retains the editable tree at `inst/ian/backend`; the installed package provides the archive and build helper under `ian`. This changes distribution, not numerical code.

The initial R-devel check completed with zero errors, zero warnings and six notes. The corrected R-devel check has zero errors, zero warnings and two notes. The first full R 4.5.2 check reached examples, tests and vignettes but crashed in ordinary graph functions. Linkage inspection found that both the main package library and reused RcppEigen linked to R-devel despite compilation and execution under R 4.5.2. The [second amendment](../../stages/03-package-qualification/AMENDMENT-2.md) isolates the versioned linker path and repeats the affected installation, backend and complete R panel. Earlier R 4.5.2 evidence is retained but does not qualify a consistently linked installation. The corrected R 4.5.2 check completes with zero errors, one compiler warning and four notes; examples, tests, vignettes and manuals now pass. The warning is an unrecognized warning-group pragma in the installed R 4.5.2 header under Apple clang 21. Its additional notes concern an unavailable current-time check and an unused declared nloptr import reported by that R checker. These are retained limitations, not hidden or suppressed. Recent HTML Tidy is used for final checks.

One remaining note concerns the development version and the suggested private package `ivue`. The other shared note arises because R's static foreign-call checker cannot resolve the optional module's locally held address. Assigning the address to a local variable did not eliminate that note, contrary to the correction plan's expectation. Actual registration is verified at runtime; the note is retained rather than suppressed. This remains a package-check limitation and is not described as CRAN readiness.

The first R 4.5.2 check stopped because `ivue` was unavailable in its isolated library. A private source snapshot was installed, then the same dgraphs archive was rechecked. Copying that suggested dependency reported dangling links in unrelated visualization artifacts; the retained available package sources installed successfully. An intermediate recheck failed before checking because its output directory was absent. Both failures are retained. A first read-only payload census also stopped after detecting repeated entries in an aggregate control trace; the corrected census uses the individual call traces. These preparatory failures did not execute IAN. Only the declared 26-call linkage-correction continuation added numerical runs. The original build environment also inherited a user Makevars file requesting sixteen jobs, so its declared two-job maximum was not established. The corrected R 4.5.2 environment isolates Makevars with two jobs and an explicit versioned R library; no shared configuration was changed.

## Audit correction: command accounting

Independent review found that overlapping build/check commands could overwrite completion records in the original nonnumerical logger. The corrected logger serializes commands across the evidence root, reserves time under the same lock, writes ledgers atomically and reaps each child before releasing the lock. A zero-optimizer regression starts three clients concurrently, including one deliberate nonzero exit; all three children run sequentially and retain their exit and timing records.

The original ledger is preserved. Its final R 4.5.2 backend completion and read-only result-check entry were lost; saved backend/result artifacts show completion, and contemporaneous task outputs reported zero exits, but their elapsed times cannot be recovered. A separate factual reconciliation leaves those durations unknown and conservatively charges each command its full two-hour allowance for future budget accounting. Numerical ledgers and the 90-call / 835-attempt census are unchanged. Independent closure of this correction is pending.

## Interpretation and remaining boundaries

The numerical evidence covers the final R-devel and corrected R 4.5.2 installations on this Mac only. Linux, Windows, Intel Mac, larger R inputs, an R restart interface and public package release remain unqualified. Native checkpoint evidence comes from prior accepted work; this stage does not add R resumability. The Stage-2 NumPy warning cause remains unresolved and unchanged. No scientific usefulness or full-engine speed advantage follows from these package tests.

After independent review and closure of findings, the next stage measures matched complete pipelines, including initialization, solver, pruning, affinity, checkpoint and R-conversion costs. No optimization should be selected before that measurement.

## Evidence and reproduction

- [Read-only census and checks](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage03-package/summary.json), [initial accounting](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage03-package/numerical-v1/ledger.json) and [corrected-package accounting](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage03-package/numerical-v2/ledger.json), and [corrected R linkage accounting](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage03-package/numerical-v3/ledger.json).
- [Initial execution](../../stages/03-package-qualification/run.py), [final execution](../../stages/03-package-qualification/run_final.py), [R result and registration checks](../../stages/03-package-qualification/check_final.R), [scalar checks and artifact verification](../../stages/03-package-qualification/finalize.py).
- [Build environment](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage03-package/environment.json), [corrected source inventory](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage03-package/archive-v2.json) and [Project status and next steps](../analysis-queue.md).
