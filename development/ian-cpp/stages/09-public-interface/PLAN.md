# Public dgraphs IAN interface

23 September 2026. IAN-EXP-035. Owner-authorized milestone 1, following accepted IAN-EXP-034. Base commit 1e769e1. Implementer/coordinator: IAN implementer. Independent review: the existing IAN auditor. Work remains in the assigned implementation worktree; no merge, remote publication, CRAN submission or shared-library installation is included.

## Public contract and adoption

Export `create.ian.graph()` with its existing dotted formal arguments and positional order. Adopt `preserve.connectivity=TRUE` and `numerical.policy="IAN evaluated-LP retry-power 0.1"` as public defaults, as proposed to and authorized by the owner. Keep explicit FALSE/reference pruning and `IAN evaluated-LP 1.0` strict baseline. This is policy selection, not a numerical/core change. Preserve the existing list return schema: complete/error, initial/final/last-valid graphs, mapping, scales, affinity, diagnostics and backend identity. Existing result field names are a separate serialized-data contract; do not rename them merely to match function/formal naming.

Document all stable top-level objects, index bases, original specimen/unique-profile distinction, metric lengths versus affinities, expected refusal/interrupt behavior, and the obligation to check complete before using final_graph. Preserve no fixed row cap, summary diagnostics, current solve budget, argument checks and event-boundary interrupts. No R restart is added. Historical experiment programs and accepted evidence retain their earlier scope and defaults; newly maintained examples use explicit public behavior.

Export `build.ian.backend(build.dir, ...)` as an explicit setup command. It builds the installed pinned sources in a new caller-selected directory, returns the module path for `backend=`, uses the calling R runtime and preserves logs. Existing directories are refused rather than overwritten. Ordinary package installation and graph execution do not start compilation or download tools. The setup helper does not install system tools or alter shared libraries. Its supported initial build target is macOS arm64. Select native Cargo/Rust explicitly when the host default toolchain differs. Existing Python builder remains the installed compilation mechanism; improve command-failure accounting and validate selected R/Rscript consistency if needed for a reliable public setup contract.

Update roxygen/help, backend guide, README, function catalogue and package website configuration. Add runnable installed-package examples and backend-independent argument/default/naming tests. R-package-owned function/formal names remain dotted, with X as the mathematical matrix-name exception. No renamed return columns or unrelated public API changes.

## Prospective qualification

Use fresh private source-archive installations and fresh installed-source backend builds on the available Mac arm64 R-devel and correctly linked R 4.5.2 environments. Preserve the known R 4.5.2 launcher/linker workaround as explicit environmental provenance. Native Rust 1.85.1 and the pinned lockfile are used; compile fresh from cached vendored dependencies, with at most two build jobs. This is an offline build test, not a test of downloading dependencies from the internet. Runtime support is bounded to those named installations.

For each runtime, execute 28 reserved entries, serially:

1. Four saved small strict/reference R cases, full diagnostics, matching accepted outputs.
2. Three saved 200-point connected cases (square, helix, sphere; seed 6101), public defaults/full diagnostics, matching accepted outputs.
3. Seven frozen 1,000-profile geometries, public defaults/summary diagnostics, matching accepted connected R results and projected solve histories.
4. One explicit retry-power/connected 1,000-profile helix with full diagnostics, equal to saved full output and default summary output after declared diagnostic exclusions.
5. Two frozen 2,000-profile connected cases, public defaults/summary, matching accepted R outputs.
6. Ten operational entries: computed/supplied/dist/full duplicate-profile variants; solve budget, invalid-solver injection, event interruption, post-graph failure; all-duplicate and inconsistent-duplicate refusals. Fault hooks stay private. Check partial graphs, mapping, diagnostics and no final result on refusal.
7. One installed public help example with the prepared backend, checked for completion and connectedness.

This is at most 56 planned engine entries. Input bytes and baseline paths come from accepted studies; do not regenerate or replace difficult inputs. Compare actual R objects, omitting timing/source identities and full trace only when comparing summary observation. Preserve exact numerical and graph values. Full accepted and rejected returns get existing certificate checks; summaries are not counted as independent full certificates. Core/backend source equality to the accepted base and an unchanged pinned dependency tree complement the R interface regression.

Builder/argument controls use zero IAN solves: missing tools, existing build directory, missing/obsolete backend, spaces in paths, public exports/defaults, and failure accounting. Run targeted R tests, regenerated guide checks and full archive checks in both runtimes. Record inherited package warnings/notes separately from new regressions. No 5,000-profile run, new geometry, speed claim or scientific comparison belongs to this milestone.

## Bounds and completion

Maximum 80 engine entries including failed/repeated attempts; 8,000 physical solver attempts; 1,500/process; 900 seconds/process; 6,000 aggregate numerical child seconds; 4 GiB sampled tree memory; 2 GiB process output; 20 GiB numerical evidence. Serial numerical launches, one numerical thread, reserve before execution, reap every child and retain failures. Build/package processes have separate command records and timeouts (up to 1,800 seconds per command); compile at most two jobs. Require 20 GiB available disk before numerical launches. A resource stop or unexplained discrepancy closes further numerical launches pending diagnosis and a versioned correction.

The deliverable is committed, audited export-ready source in this worktree, with an installed-package setup/example path, declared supported environment, preserved reference choices and concise report. Public API adoption is not a scientific superiority claim. Correct audit findings and obtain independent closure before final completion. Keep original accepted report/PDF pairs and all prior numerical evidence unchanged.

The next research milestone is the scientific comparison of connectivity-preserving IAN with reference IAN and simpler graph methods, using neighborhood recovery, global paths and known-function estimation. It will receive its own prospective design and audit; this milestone records it as next research work and does not execute it.
