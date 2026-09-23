# Can the internal R adapter be built and used from a fresh package installation?

IAN-EXP-029 · Continuation stage 3 · Aims IA1 and IA2 · 23 September 2026.

**Fresh installations preserve the tested IAN results, but full package checking exposed mixed R-version linkage in the R 4.5.2 environment. A declared correction is in progress; independent audit is pending.** This qualifies a bounded internal interface, subject to review; it does not make IAN an exported function or establish public-release readiness.

## Methods and examples

The [prospective plan](../../stages/03-package-qualification/PLAN.md) used macOS arm64 with actual R-devel (24 June 2026, revision 90190) and R 4.5.2. Each runtime received a fresh private dgraphs installation and a fresh optional Rust/C++ backend built from the installed source distribution. Existing dependencies were reused with their origins recorded. Native-arm Rust 1.85.1, locked cached crates, Apple clang 21 and one numerical thread were used. Shared installations were untouched.

The initial panel in each runtime comprised the established 13 adapter cases; complete traces for four small strict-policy examples and five explicit retry-policy examples, including the 500-profile helix; three refusal controls; and a relocated-module example. The small examples are a nonuniform curve, a variable-density patch, nearby curved arms and the small PreSSMat Hellinger-distance engineering fixture. Controls cover duplicate profiles, supplied versus calculated distances, diagnostic levels, invalid solver output, solve budgets, interruption and unavailable backends.

After packaging corrections, both runtimes were freshly installed and rebuilt again. The remaining twelve authorized calls repeated the strict PreSSMat trace, retry-policy helix, three refusal controls and relocated-module example in each runtime. They were compared with the initial installed results and accepted native references. No new Python solves were needed. The strict default remains `IAN evaluated-LP 1.0`; the explicitly selected internal option is `IAN evaluated-LP retry-power 0.1`.

## Results

| Evidence | Initial package | Corrected package | Total |
| --- | ---: | ---: | ---: |
| R engine entries | 52 | 12 | 64 |
| Physical solver attempts | 414 | 214 | 628 |
| Fresh backend builds | 2 | 2 | 4 |

All declared numerical, output and failure-behavior comparisons pass. Initial and final graphs, local scales, affinities, retained diagnostics and structured incomplete results preserve the accepted behavior. All 628 settings snapshots match the declared policy. Read-only scalar calculations check 504 complete optimization payloads: 420 accepted and 84 rejected, with 80 retry attempts. These include repeated helix problems and deliberate refusal controls, not 504 independent examples. The remaining 124 attempts have preserved R results and solver summaries rather than complete optimization payloads; no full-payload certificate claim is made for them.

The 64 calls ran in 32 supervised processes, using 58.6 seconds of aggregate child time and a maximum sampled process-tree memory of 1,069.6 MiB. No numerical resource limit was reached. These are correctness measurements, not matched performance results. The declared limits were 64 entries, 2,000 solver attempts, one hour of numerical child time and 4 GiB per process tree. The original entry allowance is exhausted. A prospective amendment adds 26 calls to replace the mixed-runtime R 4.5.2 evidence, with a new cumulative ceiling of 90 and unchanged other numerical limits.

The optional module registers one native call with eight arguments, disables dynamic symbol lookup and uses a registered native address. Runtime registration checks pass in both installations. Relocated module calls pass, and linkage inspection finds no private build-library dependency. Ordinary installation without the optional backend gives the intended error. The function remains unexported and retains the 500-row limit. A deliberately wrong Rust architecture and a deliberately corrupted source bundle are both refused before compilation.

## Packaging and package checks

The first package check exposed upstream source metadata and long paths in the R archive. The [declared correction](../../stages/03-package-qualification/AMENDMENT-1.md) ships the unchanged editable backend sources as a deterministic ZIP plus an identity manifest. The installed helper verifies and expands that archive before building. All 264 backend source files match the accepted source bytes, including license notices. The repository retains the editable tree at `inst/ian/backend`; the installed package provides the archive and build helper under `ian`. This changes distribution, not numerical code.

The initial R-devel check completed with zero errors, zero warnings and six notes. The corrected R-devel check has zero errors, zero warnings and two notes. The first full R 4.5.2 check reached examples, tests and vignettes but crashed in ordinary graph functions. Linkage inspection found that both the main package library and reused RcppEigen linked to R-devel despite compilation and execution under R 4.5.2. The [second amendment](../../stages/03-package-qualification/AMENDMENT-2.md) isolates the versioned linker path and repeats the affected installation, backend and complete R panel. Earlier R 4.5.2 evidence is retained but does not qualify a consistently linked installation. Recent HTML Tidy is used for final checks; examples, tests, vignettes and manuals are included.

One remaining note concerns the development version and the suggested private package `ivue`. The other arises because R's static foreign-call checker cannot resolve the optional module's locally held address. Assigning the address to a local variable did not eliminate that note, contrary to the correction plan's expectation. Actual registration is verified at runtime; the note is retained rather than suppressed. This remains a package-check limitation and is not described as CRAN readiness.

The first R 4.5.2 check stopped because `ivue` was unavailable in its isolated library. A private source snapshot was installed, then the same dgraphs archive was rechecked. Copying that suggested dependency reported dangling links in unrelated visualization artifacts; the retained available package sources installed successfully. An intermediate recheck failed before checking because its output directory was absent. Both failures are retained. A first read-only payload census also stopped after detecting repeated entries in an aggregate control trace; the corrected census uses the individual call traces. None of these operations reran IAN.

## Interpretation and remaining boundaries

At this draft, the R-devel target has completed checking and the corrected R 4.5.2 target remains in progress. Linux, Windows, Intel Mac, larger R inputs, an R restart interface and public package release remain unqualified. Native checkpoint evidence comes from prior accepted work; this stage does not add R resumability. The Stage-2 NumPy warning cause remains unresolved and unchanged. No scientific usefulness or full-engine speed advantage follows from these package tests.

After independent review and closure of findings, the next stage measures matched complete pipelines, including initialization, solver, pruning, affinity, checkpoint and R-conversion costs. No optimization should be selected before that measurement.

## Evidence and reproduction

- [Read-only census and checks](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage03-package/summary.json), [initial accounting](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage03-package/numerical-v1/ledger.json) and [corrected-package accounting](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage03-package/numerical-v2/ledger.json).
- [Initial execution](../../stages/03-package-qualification/run.py), [final execution](../../stages/03-package-qualification/run_final.py), [R result and registration checks](../../stages/03-package-qualification/check_final.R), [scalar checks and artifact verification](../../stages/03-package-qualification/finalize.py).
- [Build environment](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage03-package/environment.json), [corrected source inventory](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage03-package/archive-v2.json) and [Project status and next steps](../analysis-queue.md).
