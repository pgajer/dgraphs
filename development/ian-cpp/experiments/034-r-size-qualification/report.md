# Removing the R interface’s fixed row limit

**Finding.** The internal IAN function now accepts inputs above 500 specimen rows, subject to actual representation and resource limits. All seven tested 1,000-profile geometries pass through R in both pruning modes. A 2,000-profile helix and four-dimensional quadform also complete with exactly matching native/R results in connectivity-preserving mode. This establishes bounded interface behavior, not unlimited capacity or scientific usefulness.

## What changed and what was tested

The artificial 500-row rejection is removed. Checks now cover matrix dimensions, native vertex-index arithmetic and exact conversion into R objects. Inputs still require at least two finite specimen rows. The solve budget, event-boundary interruptions, numerical acceptance rules, reference pruning default and strict numerical default remain unchanged. The function is still unexported. Updated R code requires a rebuilt optional module with the checked-size entry point; old call signatures remain forwarding aliases in the new module.

The [prospective plan](../../stages/08-r-size-qualification/PLAN.md) and two amendments declare the panel and resource gates. Seven previously frozen 1,000-profile datasets comprise a helix, cloud, separated lobes and quadforms of intrinsic dimensions two through five. Each was run natively and through R with full diagnostics, under both reference and connectivity-preserving pruning: 28 runs. All explicitly select `IAN evaluated-LP retry-power 0.1`. Reference traces match accepted earlier runs; paired native/R traces match exactly apart from timing.

An author check then found that the first version’s integer projection converted the minimum signed integer to R’s missing-value sentinel. The corrected conversion preserves it as an exact double. The complete 28-run panel was repeated successfully with the correction. The final module-version change adds no numerical changes; it has fresh build/package checks, old-module refusal and both forwarding-interface controls, plus another connected 1,000-profile helix pair. Its native trace matches the corrected panel exactly.

Two larger engineering samples were frozen before execution: a 2,000-point helix and a 2,000-point quadform with four intrinsic coordinates and five embedding coordinates. Their declared generators and seeds are in the plan. Both use connectivity-preserving pruning. Native runs retain full certificates; R uses summary diagnostics. Their scales, affinity matrices, final graphs, profile mappings, bridge tables and solve histories agree exactly.

| Completed comparison | Coverage | Result |
| --- | --- | --- |
| Seven 1,000-profile geometries | Both pruning modes; native/R full diagnostics; original and corrected panels | All complete; exact paired traces and outputs |
| Final module dispatch | Connected 1,000-profile helix; native full/R summary | Exact results and projected history; unchanged native trace |
| Two 2,000-profile examples | Connected helix and intrinsic-dimension-four quadform; native full/R summary | Both complete; exact results and projected histories |

## Checks and resource observations

Each 28-run panel contains 1,248 solver returns: 1,026 accepted and 222 rejected. Certificate reconstruction verifies both decisions under the unchanged rules; rejected returns remain rejected, and eligible retries are separate solves. Full certificates are also checked for the final native helix pair, both larger native examples and three saved connected R regressions. Four strict-policy R examples and three saved 200-point connected examples preserve their earlier R outputs. Dimension-only checks, actual typed-to-R conversion probes and 501-row duplicate-profile controls pass, including summary/full agreement, budget refusal, interruption and partial diagnostics after failure. Independent author component counting reconstructs 13,363 edge proposals across the seven corrected 1,000-profile connected runs and both 2,000-profile runs. Every deletion preserves connectivity. This checks current bridges and graph updates, not a new derivation of the statistical ranking. The numerical core is unchanged.

The following sampled process-tree memory and elapsed times include different diagnostic workloads. They are resource accounting, **not a performance comparison** between R and native execution.

| 2,000-profile input | Native full: seconds / MiB | R summary: seconds / MiB |
| --- | --- | --- |
| Helix | 16.93 / 1,097.7 | 9.16 / 574.2 |
| Four-dimensional quadform | 44.83 / 1,130.4 | 33.54 / 627.6 |

The optional 5,000-profile pair was **not run**: both native full-diagnostic runs exceeded the predeclared 1 GiB advancement gate. No process reached the separate 4 GiB stop limit. Across preserved original and corrected evidence, 76 engine entries in 70 numerical processes account for 3,234 physical solver attempts and 824.2 child seconds. All processes were reaped; maximum sampled memory was 1,827.1 MiB. The final package passes 40 targeted assertions and its full archive check with no errors or warnings and two existing notes (development-version/suggested-package metadata and the optional native symbol).

## Practical meaning and limitations

There is no replacement experimental row cap. One dense n-by-n double matrix uses `8*n*n` bytes: 8 MB at 1,000 rows, 200 MB at 5,000 and 800 MB at 10,000, before overhead. Several matrices and conversion copies coexist; these figures are not peak-memory estimates. Distances are allocated before duplicate profiles are collapsed. Full diagnostics retain additional dense data; summary remains the default. Gabriel construction has cubic worst-case work. Removing a guard cannot guarantee that an arbitrary larger dataset fits or completes.

Qualification here uses the available Mac arm64 R-devel environment and an identified, previously accepted Rust archive. Other platforms and R versions were not newly tested. The larger comparisons establish internal interface agreement; there is no new Python trajectory at 2,000, biological validation, R restart or public export. The 5,000-profile input is frozen but unexecuted. Original projection/probe failures and earlier evidence remain preserved.

The [backend guide](../../../../inst/ian/README.md) describes use and resource behavior. [Private evidence](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/r-size-qualification) includes commands, source snapshots, inputs, traces, R objects, certificates, accounting and failures. Independent disposition is maintained separately in the [audit record](audit-summary.json); current project decisions are in [Project status and next steps](../analysis-queue.md).
