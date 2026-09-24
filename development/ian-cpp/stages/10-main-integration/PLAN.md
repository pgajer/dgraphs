# Main integration qualification

The owner authorized committing and pushing all pending dgraphs changes and merging the IAN branch into main on 2026-09-23. This integration preserves history and requires independent audit before the final merge.

The inputs are accepted IAN revision 644ed2a4d4965831240ee2e88265dabef3447b40, main b879b33ebc3cb3782f37df32477bef11b6e6575a, and the six pending sKNN distance-input files saved byte-for-byte under `/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/main-integration`. The latter were preserved in d0401a6; their authorship and prior validation are unknown. Main has not been edited.

Merge 55a0d4f preserves main's embedding-explorer SGD defaults and documentation, and IAN's graph-explorer compatibility adapter and tests. The numerical IAN core is unchanged.

Qualification uses private installations of committed GRIP a66f3e75 and dgraphs, on the previously qualified macOS arm64 R-devel and R 4.5.2 runtimes. Run documentation regeneration, source archive creation, full package checks, sKNN distance-input tests, graph-explorer compatibility tests, and embedding-explorer tests. Reuse the accepted public-interface harness for all 56 calls in 36 processes, comparing saved R results and full traces against accepted evidence. Its existing resource limits remain: 80 entries, 8,000 optimizer attempts, 1,500 attempts per process, 900 seconds per process, 6,000 total child seconds, 4 GiB process-tree memory, and 20 GiB study output. Build/check commands retain their separate recorded limits. No new scientific comparison is proposed.

After worker validation, provide factual evidence to the existing independent IAN auditor. Resolve findings before integration. Recheck the main checkout against its snapshot, preserve its pending files in a separate commit, simulate the final merge and compare its tree with the audited candidate. Perform a normal history-preserving merge, push explicit branch refs without force, and verify remote heads. New concurrent changes require reconciliation rather than replacement.

This establishes integration behavior on the named runtimes only. It does not establish broader portability, CRAN acceptance, performance at larger sizes, or scientific superiority.
