# Connectivity-preserving pruning with useful R diagnostics

**Question.** Can IAN retain a connected graph by checking each proposed edge deletion first, while preserving the existing numerical checks and reference behavior?

**Finding.** The new explicit option keeps all twelve tested graphs connected and completes through both native and R interfaces with exactly matching traces and outputs. All six 200-point helices finish with 199 edges. The three previously studied helices had split into six, three and three components under reference pruning. This is an engineering result; prediction and biological usefulness of retained connections have not been tested.

## Method and examples

The owner requested a bridge check before each proposal's pruning-condition test. A bridge is an edge whose removal increases the number of connected components. The implementation first consults the bridge list, then checks current connectivity when the edge is not cached. Bridges are retained and cached permanently because later edge deletions cannot make them cease to be bridges. Nonbridge status is checked afresh after preceding deletions.

The global statistics and threshold still use the entire graph. Proposals follow the existing statistical ordering and use each point's longest incident edge. Protected proposals are skipped; later proposals remain eligible. Skips do not consume the deletion allowance. The original allowance and restriction against deleting two edges sharing an endpoint in one batch remain. A full pass without deletion ends pruning, followed by the usual final scale and affinity calculation. All unique-profile vertices remain.

The [prospective contract](../../stages/07-connected-pruning/PLAN.md) fixes these details and the resource limits. The new pruning policy is `IAN bridge-protected 0.1`; the tests explicitly use numerical policy `IAN evaluated-LP retry-power 0.1`. Reference pruning and the strict numerical policy remain the R defaults. No thresholds or solver acceptance limits changed.

The comparison panel comprises the nine existing square, helix and sphere datasets (200 points each; seeds 6101–6103) and three additional helices drawn by the same declared generator using seeds 6201–6203. The new draws provide engineering confirmation, not a held-out scientific comparison. Each connected run was executed once natively and once through the freshly installed R package. Four established small examples, the nine existing datasets and the 1,000-profile helix were rerun in reference pruning mode; the four small examples were also rerun under the strict numerical policy.

## Results

| Geometry and samples | Connected-mode final edges | Final components | Pruning stopping reason |
| --- | --- | --- | --- |
| Square, seeds 6101–6103 | 350, 359, 355 | 1 each | No pruning candidates |
| Previously studied helices, seeds 6101–6103 | 199 each | 1 each | No connectivity-preserving removal |
| Sphere, seeds 6101–6103 | 412, 395, 383 | 1 each | No pruning candidates |
| Additional helices, seeds 6201–6203 | 199 each | 1 each | No connectivity-preserving removal |

The author independently reconstructed all **3,081 edge proposals** using component counting rather than the implementation's endpoint-reachability routine. Every actual deletion preserved connectivity. The reconstruction also verifies proposal order, sequential bridge updates, condition-test ordering, allowance accounting, cache encounters and final diagnostics. All twelve native/R traces match apart from timing; exact R objects have matching scales, affinities, final edges and protected-edge information. All 1,560 optimization payloads in the main comparison panel pass the existing numerical certificate checks.

All fourteen reference-mode runs and four strict-policy runs reproduce saved traces apart from timing. The graph-level controls passed 5,325 exhaustive bridge comparisons over small graphs. Additional controls cover a cycle where two deletions would jointly disconnect the graph, skipping a high-ranked bridge before removing a lower-ranked edge, caching and termination. Disconnectedness is tested on a supplied graph at the graph-helper level; no naturally disconnected Gabriel input was produced to execute the full engine's defensive initial-connectivity refusal branch.

Native interruption and resumption at a pruning boundary reproduce the uninterrupted trace and result. Resuming the terminal graph checkpoint reproduces its bridge list and final result. Five altered checkpoint declarations are rejected before a solve. None of the panel's nonterminal pruning checkpoints contained an encountered bridge: cache-bearing recovery is therefore tested at the terminal graph boundary, not during a later pruning pass. The original supplemental harness assumption to the contrary failed before launching that test and is retained in the evidence.

R controls pass for summary/full agreement, duplicate-profile mapping, partial diagnostics after an injected graph-stage failure, solve-budget refusal, early interruption, the previous native entry-point compatibility and an actionable error for an old optional module. The initial Gabriel graph, last valid graph and final graph remain distinct return objects; no final graph is claimed on numerical refusal.

## R use and interpretation

The function remains internal. After building the updated optional backend and making it discoverable, request the variant explicitly:

```r
fit <- dgraphs:::create.ian.graph(
    X, distances = D,
    numerical.policy = "IAN evaluated-LP retry-power 0.1",
    preserve.connectivity = TRUE,
    diagnostics = "summary")
fit$initial_graph
fit$final_graph
fit$diagnostics$connectivity$protected.edges
fit$diagnostics$connectivity$history
fit$diagnostics$connectivity$stop.reason
```

The protected-edge table gives one-based profile indices and IDs, first/last encounter iterations, encounter counts and the first statistic, threshold and difference. It records **encountered bridges**, not every bridge and not only edges that would have passed pruning conditions: those conditions are deliberately not tested for protected proposals. The per-iteration history counts examined proposals, bridge checks, cached skips, condition rejections, endpoint conflicts and deletions. `diagnostics="full"` additionally returns each proposal and whether conditions were tested; those core trace indices remain explicitly zero-based. See the [backend guide](../../../../../inst/ian/README.md).

## Qualification and limits

The author attempted 56 engine entries in 51 supervised numerical processes, accounting for 1,717 physical solver attempts. All processes were reaped; the aggregate child elapsed time was 39.5 seconds and maximum sampled process-tree memory was 312.8 MiB. These are accounting observations, not comparative performance measurements. Bounds were 80 entries, 10,000 attempts, 900 seconds per process, 7,200 aggregate seconds and 4 GiB sampled memory. Graph-only and package commands are separate.

A fresh native/module build and private package installation passed on the available Mac arm64 R-devel runtime. The accepted Rust archive was reused and identified by hash; Rust and other platforms were not rebuilt. The first build's obsolete test asserting fourteen event types failed after adding the fifteenth typed event; the corrected test and complete second build passed. Documentation regeneration, source archive build, targeted R tests and full archive checks passed. The full check retained two notes: development-version/non-mainstream suggested-package metadata, and the optional dynamically loaded native symbol. There were no errors or warnings. No shared installation changed.

This delivers an explicit internal option. It does not establish biological validity of protected edges, improve conditional-mean estimation by itself, qualify R above 500 rows, expose R restart, qualify other platforms or authorize export. The connected variant has native/R agreement and an independent graph reconstruction, not a separate complete Python engine implementation. The [project status](../analysis-queue.md) records independent review and advancement separately.

## Evidence

Canonical code is in [the typed core](../../../../../inst/ian/backend/core/include/ian/core.hpp), [the bridge guard](../../../../../inst/ian/backend/core/src/connected.hpp), [the native R bridge](../../../../../inst/ian/backend/bridge.cpp) and [the R adapter](../../../../../R/ian_graph.R). Reproduction programs and the committed contract are in [the stage directory](../../stages/07-connected-pruning/PLAN.md). The [private evidence](</Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/connected-pruning>) retains input identities, source snapshots, commands, complete traces, results, checkpoints, certificates, failed attempts and package logs. This report contains author findings; independent disposition is maintained in [the audit record](audit-summary.json).
