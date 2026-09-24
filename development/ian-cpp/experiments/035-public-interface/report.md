# Making IAN available through the public R interface

**Finding.** The candidate source exports `create.ian.graph()` with connectivity preservation and the qualified retry policy as defaults. Fresh private installations in two Mac arm64 R environments reproduce the saved results exactly under the selected policies. The initial Gabriel graph, final graph, profile mapping, local scales, affinities and diagnostics remain available. Independent review is pending. This work qualifies an interface; it does not establish scientific superiority or unlimited input size.

## Public behavior and setup

The public function now defaults to `preserve.connectivity=TRUE` and `numerical.policy="IAN evaluated-LP retry-power 0.1"`. The first protects an edge when removing it would split the graph. The second permits a separately checked retry of an eligible unsuccessful optimization. Every accepted solution must still pass the existing numerical checks. Users can explicitly choose reference pruning with FALSE and the strict `IAN evaluated-LP 1.0` policy. The C++ core, R bridge and pinned solver source tree are unchanged from the accepted preceding milestone.

The exported `build.ian.backend()` builds the optional module from the installed pinned sources in a new caller-selected directory and returns its path. It uses the calling R runtime, retains build logs and refuses existing directories. Tool installation remains the user's responsibility. Package installation and graph construction do not silently start compilation. The initial supported target is macOS arm64; builds here used native Rust 1.85.1 and cached dependencies offline.

Help and the new IAN vignette explain duplicate-profile mappings, specimen and participant identities, edge lengths versus affinities, index conventions, resource limits and failure handling. A returned `complete=FALSE` result has no final graph; available initial or last-valid graphs and diagnostics are retained. Argument and unavailable-backend errors are ordinary R errors. Summary diagnostics remain the default, and the existing solve budget and event-boundary interruptions remain. There is no R resume interface or fixed row cap.

## Comparisons and results

The [prospective plan](../../stages/09-public-interface/PLAN.md) specifies two fresh private archive installations: R-devel and correctly linked R 4.5.2, both Mac arm64. Each optional backend was freshly compiled using the new public setup helper, including a directory name containing spaces. All numerical inputs and expected results came from accepted earlier studies; no new geometry or performance comparison was introduced.

| Test in each R environment | Comparison | Result |
| --- | --- | --- |
| Four small reference examples | Explicit strict policy and reference pruning; saved full R objects | Exact agreement |
| Square, helix and sphere, 200 points each | Public defaults; saved connected results | Exact agreement |
| Seven frozen 1,000-profile geometries | Public defaults and summary diagnostics; saved connected results | Exact agreement |
| Additional 1,000-profile helix | Explicit public policy choices and full diagnostics | Exact agreement with saved results and default summary output |
| Helix and intrinsic-dimension-four quadform, 2,000 profiles each | Public defaults and summary diagnostics | Exact agreement |
| Duplicate representations and installed help example | Computed/supplied/dist distances, summary/full views | Complete, connected and consistent |
| Six refusal/failure controls | Budget, invalid solver return, interruption, post-graph failure, duplicate degeneracy/inconsistency | Expected refusal and retained partial information |

Object comparisons exclude timing and declared source/configuration identities; full trace is omitted only when comparing summary observation. Requested solve-budget metadata is also excluded: the four strict saved examples used a budget of 1,000, whereas this qualification used 1,500; neither budget was reached. Across both environments, 34 saved-case comparisons and 22 operational entries account for **56 engine entries, 36 processes and 1,594 physical solver attempts**. Forty-four entries complete; twelve deliberately exercise refusal or injected failure. The full records contain 504 optimization payloads: 370 accepted and 134 rejected, with both decisions independently recalculated by the author's existing numerical checker. Another 1,090 summary returns are counted and compared to saved histories, not claimed as independently reconstructed full certificates.

All processes were reaped. Total numerical child time was 228.2 seconds; the largest sampled process-tree memory was 2,888.4 MiB, below the declared 4 GiB stop bound. These observations account for this mixed diagnostic workload and are not a performance comparison. The 5,000-profile examples remain unexecuted under the preceding study's gate.

Both fresh installations pass 54 targeted interface assertions, six zero-engine setup/backend controls and installed-guide checks covering 114 exports, 44 S3 methods and four vignettes. Both full source-archive checks finish with no errors. R-devel retains two notes. R 4.5.2 retains one compiler warning and three notes: the R header warning option, development-version/suggested-package and URL metadata, an existing unused import, and dynamic optional-symbol registration. These are recorded limitations, not a clean CRAN result.

## Preserved failures and limits

The first archive attempt failed because the isolated dependency path hid RcppEigen; adding the existing read-only dependency library repaired the environment. The first numerical harness stopped after a successful strict-policy case because its checker expected retry-only metadata. The corrected checker reused that saved output without rerunning the engine. Both failed attempts and their complete accounting remain preserved. Neither correction changed the numerical implementation.

Independent review then found a process-cleanup race in the public build helper: a child could exit just before a signal, leaving an incorrect claim that it had been reaped. The helper and qualification supervisor now tolerate that race, use bounded cleanup waits, and record unconfirmed termination truthfully. A related supervisor correction treats crossing the time limit as failure even when the child subsequently exits zero. Twenty-two deterministic controls exercise the actual functions without launching children. The original defective source and submitted report/PDF are preserved.

The corrected helper has a separate fresh archive, private installations and backend builds in both R environments. Its source change is limited to process cleanup; the R graph function, core, solver and numerical inputs are unchanged. The 56 numerical calls above belong to the original qualification and were not repeated by the author after this setup-only repair. Independent replay and the final disposition are recorded in the audit record.

Qualification uses these two installations, the R 4.5.2 launcher/linker workaround and cached offline dependencies. Other operating systems, online dependency acquisition, arbitrary larger inputs, general original-expression equivalence and perturbation robustness remain unqualified. The source is exported in this worktree but has not been merged, remotely published, submitted to CRAN or installed into a shared library. No biological data or new scientific outcomes were evaluated.

The next research study will compare connectivity-preserving IAN with reference IAN and simpler graph methods, using local-neighbor recovery, global paths and held-out recovery of known smooth functions. Its prospective design must address graph density and genuinely separated populations. Engineering acceptance alone cannot establish the benefit of retaining a connection.

[Private evidence](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/public-interface) contains frozen inputs, commands, full and summary traces, R objects, certificate checks, provenance and failed attempts. [Project status and next steps](../analysis-queue.md) records the current decision; the [audit record](audit-summary.json) binds any later independent disposition to exact submitted bytes.
