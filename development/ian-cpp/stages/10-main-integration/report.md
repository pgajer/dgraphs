# Main integration qualification

The merged candidate preserves the accepted IAN results, main's current embedding defaults, and the six pending sKNN distance-input files. Worker qualification is complete; independent review is pending. Main has not yet been committed, merged or pushed.

## What was combined and tested

The candidate combines accepted IAN revision `644ed2a`, main `b879b33`, and the exact pending distance-input files preserved in `d0401a6`. Merge `55a0d4f` retains main's default SGD metric MDS behavior and explicit SMACOF option in the embedding explorer, together with IAN's current/older public GRIP compatibility adapter in the graph explorer. The IAN core and numerical policy are unchanged.

Tests used private macOS arm64 installations of R-devel and R 4.5.2, with GRIP built from committed revision `a66f3e75`. Shared package libraries were not changed. Documentation regenerated without source drift. Both package and optional IAN native module were built afresh for each runtime.

## Results

- All 56 IAN calls in 36 processes completed with the expected outcomes: 44 complete calls and 12 deliberate refusals. All 34 comparisons with saved baseline R objects passed, including the 1,000-profile panel and two 2,000-profile examples in each runtime.
- All 1,594 optimizer attempts were accounted for. The checker recalculated 504 full certificates (370 accepted and 134 rejected returns); 1,090 summary returns were checked through saved diagnostic histories. Summaries are not independent full certificates.
- Comparisons exclude timings, source/configuration identities and requested solve-budget metadata. Older baseline full traces are excluded only when comparing a summary diagnostic result. Numerical values, graph structure, scales, affinities and mappings match exactly under these declared comparisons. Child execution totaled 230.05 seconds; this mixed regression schedule is not a performance benchmark.
- Each runtime passed 54 IAN interface assertions, 50 distance-input assertions, 79 graph-explorer assertions, 446 embedding-explorer assertions, six zero-engine setup/refusal controls, and installed-guide provenance/link checks. Optional UMAP and saved-study tests in the embedding suite were not enabled by this invocation.
- Full package checks had zero errors. R-devel passed 3,668 assertions, with two Shiny-dependent tests skipped, and reported zero warnings/two notes. R 4.5.2 passed 3,677 assertions with no skips and reported one warning/three notes. Its warning is an unsupported warning-group pragma in the installed R header. The notes cover development metadata/non-mainstream suggestion, dynamic optional native-symbol registration, and the R 4.5.2 unused import. These categories match the accepted prior qualification and do not establish CRAN readiness.

The first targeted test command failed after its 50 distance-input assertions because the graph-explorer test was invoked outside the package namespace. The corrected invocation passed. Both records remain preserved; no package change was needed. No numerical process hit a resource limit or required a rerun.

## Evidence and limits

Private evidence is in `/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/main-integration-qualification`: `environment.json`, per-runtime `commands.json` and logs, fresh libraries/backend build records, `numerical-v1/ledger.json`, individual results/traces/certificates, and `integration-summary.json`. The original main snapshot, patch, exact pending files, orchestration scripts and factual handoff are in the sibling `main-integration` directory. The package archive SHA256 is `864c23870646d201d8071482eff042048a41c04d3df7fb7ed5143ca2fe33383a`.

The six pending files' original authorship and validation history are unknown; this qualification supplies fresh tests. Other platforms, online backend dependency acquisition, 5,000-profile runs, R resume and scientific superiority remain unverified. No shared installation, release or CRAN submission is included. Independent review and final repository/remote reconciliation remain necessary before the authorized merge and push.
