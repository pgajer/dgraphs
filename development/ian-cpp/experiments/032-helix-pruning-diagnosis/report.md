# Why does pruning disconnect the helices?

IAN removes a useful connection after it has already recovered the correct chain of sampled points. In all three helices, the first disconnection is caused by the ordinary local pruning rule: a point exceeds the cutoff, so its longest remaining incident edge is deleted. That edge is a **bridge**, the only graph connection between two substantial groups. Native and Python make the same decision. This diagnoses behavior of the accepted reference method on these samples, rather than a new implementation discrepancy.

## What was examined

We reconstructed both saved trajectories for each of the three Stage 5 two-turn helices: 200 independently sampled points per dataset, with seeds 6101, 6102 and 6103. Points are uniform along the helix parameter, so their realized spacings are uneven. All graphs use Euclidean edge lengths; exact distances along the helix provide the geometric reference. No optimizer was rerun, no scale was changed and no new method or dataset was tested. This is a descriptive diagnosis of the previously observed failures, not an independent confirmatory sample.

Every recorded decision and ordered edge removal was replayed. We recalculated local statistics from saved distances and scales, reconstructed the threshold and candidate order, and checked graph components after each removal. Both interfaces agree. Component checks also use a separate union-find calculation, with path, cycle and sequential-cut controls.

## The first cuts

Pruning-step numbers below start at one; raw trace iterations start at zero. Row indices in the evidence start at zero and retain stable input IDs.

| Helix sample | First split at step | Removed rows | Selected statistic / cutoff | New component sizes | Pairs still connected |
| --- | --- | --- | --- | --- | --- |
| Seed 6101 | 41 | 62–195 | 3.101 / 2.750 | 125 and 75 | 52.9% |
| Seed 6102 | 45 | 96–146 | 3.109 / 2.750 | 172 and 28 | 75.8% |
| Seed 6103 | 30 | 86–183 | 2.850 / 2.750 | 174 and 26 | 77.3% |

Immediately before each cut, the graph is exactly the 199-edge chain joining consecutive sampled points along the helix. Every pair is connected, and average relative path-length error is only 0.086%, 0.087% and 0.091%, respectively. Earlier pruning removed the extra connections; it had already achieved a very accurate graph for this particular distance-recovery task.

Each first-split batch removes just one edge. Both endpoints have degree two beforehand and degree one afterward, so no isolated point is created. The cut separates consecutive parameter ranks 125–126, 28–29 and 26–27, respectively. These are along-helix links, not shortcuts across different turns. Each edge is already a bridge before the batch; simultaneous deletions are not responsible for the first split.

![First deleted bridge and component history in all three helices](build/pruning.png)

*Top: the exact pre-cut chain projected from its 3D coordinates. Blue and orange identify the two groups created by removing the red edge; colors do not denote biological classes. Red rings mark its endpoints. Bottom: component count after each saved pruning step, with the first split marked. Subsequent pruning increases the final counts to 6, 3 and 3. Projection overlap is not a graph connection.*

## Why the local rule selects these edges

The pruning statistic compares the Gaussian-weighted mass near a point, using its fitted scale, with a degree-based normalization. It includes the point itself and nearby points whether or not they are directly connected by graph edges. At each first cut, degree two makes the denominator sqrt(pi), about 1.772. The selected points have weighted masses 5.497, 5.510 and 5.052, giving the statistics in the table.

The sampling is locally uneven. At the triggering point, the deleted edge is about 77, 37 and 48 times longer than its other incident edge. Its scale is approximately half the deleted-edge length. Four or five other sampled points lie within one scale on the crowded side. Most of the weighted mass is there: 4.475, 4.492 and 4.032, plus self-weight 1; mass on the side across the gap is only 0.021, 0.018 and 0.020. This explains the measured high statistic despite degree two. The gaps rank fifth, second and sixteenth largest among the 199 consecutive parameter gaps; choosing only the globally largest gap would not describe these decisions.

The ordinary cutoff calculation gives 2.467, 2.484 and 2.589 before applying the minimum cutoff of 2.75. Each triggering point is the highest-ranked candidate. The per-step ten-percent limit, with a minimum of one, selects one point; the rule removes its longest edge. There is no bridge-protection check. The other endpoint need not exceed the cutoff and does not in these three cuts.

The special conditional threshold cap and the extra candidate rule for an uncentered median are inactive at all three first cuts. The median statistics are 0.911, 0.945 and 1.034, within the accepted 0.9–1.1 interval. Retuning stops because that target is met, not because a boundary or iteration limit is reached. Each immediately preceding solve is an accepted ordinary `Solved` return without retry. Earlier retries remain part of the saved histories.

These are clear threshold exceedances: margins are 0.351, 0.359 and 0.100. Recalculated statistics differ from the saved values by at most 3.6e-15 over all six histories. That supports the decision reconstruction; it does not prove insensitivity to arbitrary changes in data, scale solutions or settings.

## Consequences and next decision

The first cut disconnects 47.1%, 24.2% and 22.7% of all point pairs. Local ten-neighbor recall nevertheless remains 98.6%, 99.3% and 98.1%. Across the complete trajectories, nine component-increasing deletions all cut consecutive along-helix neighbors. This explains how good local-neighborhood scores can coexist with poor global paths.

The diagnosis does not justify raising the cutoff until these samples pass. Nor does it establish that connected output is always appropriate: genuine gaps or separate populations may warrant disconnection. It identifies a specific methodological tradeoff: local pruning can sacrifice a globally necessary link after useful shortcut removal has finished.

A next method study could compare the unchanged reference with an explicitly named rule that checks proposed bridge removals. Its target task, treatment of genuinely disconnected data, stopping behavior and success criteria must be specified first. Retaining bridges could preserve bad connections as well as useful ones. These three helices may inform design; additional prespecified samples and both local and global metrics are needed for confirmation. No variant was implemented here.

## Evidence and limits

The analysis covers 125 decisions, 122 pruning batches and 303 individual removals per interface. Every candidate and removal identity matches exactly. The private bundle retains both analysis versions: the second adds chain-identity and weighted-mass details without changing the first-cut or graph results. Source hashes bind all six traces and three input/truth pairs to the accepted Stage 5 inventory. Analysis takes about 1.5 seconds; no performance claim follows.

Source and regeneration instructions are in the [prospective plan](../../stages/06-pruning-diagnosis/PLAN.md) and [analysis script](../../stages/06-pruning-diagnosis/analyze.py). The [saved analysis](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/pruning-diagnosis/analysis-v2/summary.json) and [handoff](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/pruning-diagnosis/implementer-handoff.md) retain detailed edge tables, threshold statistics, checks and provenance. Review status is recorded separately in audit-summary.json. This diagnostic does not repeat optimizer certification, qualify another platform, establish general historical-expression equivalence or measure a changed method's predictive performance.
