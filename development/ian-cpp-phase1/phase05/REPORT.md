# Phase 05: numerical reference and decision sensitivity

The native engine agrees with the evaluated-LP Python reference on every frozen
comparison in this bounded study. The original-expression control still fails
intermediate-array limits in eight of twelve fixed-state cases and three of four
complete examples. All three implementations make the same discrete choices
within each case, and final affinities pass the unchanged limits on all four
complete examples. These findings support the chosen numerical reference on the
tested inputs; they do not establish a drop-in historical replacement.

Status: completed by the coordinator/implementer and submitted for independent
audit. This phase has not been independently accepted. The user authorized Phase
05, including adoption of [IAN evaluated-LP 1.0](CONTRACT.md) as the working
implementation reference. Earlier accepted phases and their failed historical
comparisons remain unchanged.

## What was tested

The question was whether known formulation differences, or small changes near
decisions, propagate into different retuning or pruning behavior. We compared
original-expression Python, explicitly evaluated-LP Python and native C++ using
Clarabel 0.11.1 and the same pinned settings. The accepted engine, algorithm,
solver configuration and numerical tolerances were not changed.

The [plan](PLAN.md) was committed before generation and execution. Four fixed
graph states came exclusively from earlier original-expression traces: the two
known differing states, the smallest positive pruning-threshold margin, and the
smallest positive unweighted retuning margin. Fresh parameterized problems were
constructed at those states; this was not a resumption of historical solver
caches. Bounded original-only calibration used 28 solves before freezing twelve
comparison inputs. Their three-condition comparisons used 48 solves in 36
executions: nine single-solve cases and three calls to the actual retuning routine
per condition. Six additional threshold/tie vectors used no optimization.

Four complete inputs were fixed without a search or replacement: predefined
small composition perturbations of the earlier 256- and 300-profile PreSSMat
Hellinger subsets, a nonuniformly sampled 120-point helix, and a jittered
144-point saddle. Each ran once under all three conditions, for twelve complete
runs and 1,254 solves. The Hellinger inputs overlap and share a biological source.
The synthetic geometries were held out from the earlier trajectory search.

All runs were serial with the existing one-thread child-process policy. Resource
logs are execution diagnostics, not a repeated performance benchmark. No new
engine timing or memory advantage is claimed.

## Complete trajectories

Counts below are per condition; all three conditions agree on each row. Extra
pruning solves are solves beyond the first within a post-pruning outer iteration.

| Input | Solves | Pruning iterations | Edges removed | Extra pruning solves | Final affinity retuning solves | Final isolates |
|---|---:|---:|---:|---:|---:|---:|
| Perturbed 256-profile Hellinger subset | 195 | 182 | 238 | 11 | 1 | 3 |
| Perturbed 300-profile Hellinger subset | 189 | 176 | 228 | 8 | 4 | 2 |
| Nonuniform 120-point helix | 31 | 15 | 39 | 0 | 1 | 0 |
| Jittered 144-point saddle | 3 | 0 | 0 | 0 | 1 | 0 |

Native/evaluated comparisons pass at every recorded event, including numerical
arrays, graph changes, retuning brackets, stopping decisions and zero support of
affinities. Their final affinities are bitwise equal on both Hellinger examples;
maximum absolute differences on the helix and saddle are respectively
`1.21181e-13` and `2.70894e-14`. All complete examples retain one component
containing edges; the Hellinger examples also create isolates.

Original/evaluated intermediate comparisons remain failed on the two Hellinger
examples and the helix, with respectively 3, 9 and 27 failing events. The first
differences are the internal scales at pruning iteration 3, initial volume
ratios, and initial internal scales. The saddle passes. Every discrete field
agrees, including all edge removals. Original/evaluated final affinities are
bitwise equal except on the 300-profile input, where the maximum absolute
difference is `2.86299e-10`, within the unchanged `1e-7 + 1e-7*max(abs(a),abs(b))`
limit. Endpoint agreement does not erase the intermediate failures.

## Boundary behavior

All twelve native/evaluated fixed-state comparisons pass. Eight original/
evaluated comparisons fail intermediate arrays, while their discrete decisions
agree. The saved 256-profile center case reproduces the previously observed
`3.374015563e-6` maximum internal-scale discrepancy. Identical projected LP
coefficients and valid primal/dual solutions support representation sensitivity;
they do not establish a unique optimum or identify a particular conditioning
mechanism.

The retuning calibration straddles the median-ratio stopping boundary at 1.1.
Under the original control, the lower starting multiplier
`0.6297677159309387` yields median `1.0999999774542375` and stops after one solve.
Increasing that multiplier by only `1.4901161194e-8` to the frozen midpoint yields
median `1.1000000508293863`, triggering two more solves and a final multiplier
near `0.5973257981`. The subsequent candidate count changes from 30 to 29, and
the pruning quota from three edge removals to two. The upper endpoint follows
the same three-solve pattern. All three implementations reproduce these paths
and edge choices. This is sensitivity to different supplied starting multipliers,
not a demonstrated formulation-induced decision divergence.

The pruning calibration's endpoint margins are both negative: approximately
`-0.11094` and `-0.04889` at multipliers `0.5665625` and `0.5896875`. The specified
endpoint test therefore did not bracket a boundary and did not run bisection.
The subsequently frozen midpoint probe has a positive margin of approximately
`6.89876e-5`. Thus the three measured margins are not monotone, and same-sign
endpoints did not exclude an interior sign change. The study does not claim a
finely calibrated pruning root. The selected edge changes between the midpoint
and upper endpoint, identically in all conditions. No interval was widened or
input replaced after observing this result.

The six no-solve stage tests establish the specified strict comparison and tie
behavior on identical explicit inputs. A ratio equal to the threshold 2.75 does
not enter the candidate set; adding `1e-7` does. An exact two-candidate tie retains
index order; increasing the second ratio by `1e-7` reverses that order and changes
the selected edge. Python and native results agree. These supplied cycle-graph
tests do not establish geometric initialization or arbitrary tie behavior.

## Numerical checks, checkpoints and execution history

Saved-data checks accept all **1,330 optimization payloads**: 28 calibration, 48
fixed-state and 1,254 complete-run solves. Maximum normalized primal violation is
`1.28133e-8`, dual stationarity residual `1.13142e-8`, relative primal-dual gap
`1.05877e-9`, and objective recomputation discrepancy `1.45490e-15`. All are below
their external `1e-7` limits. Maximum absolute primal violation is `3.26299e-6`;
the acceptance quantity is normalized, not that absolute value.

All twelve complete runs saved graph, scales and affinity checkpoints: 36 stage
artifacts. Their hashes, graph states, identities and mappings agree with the
traces. Affinities were reconstructed from distances and internal scales and
pass numerical and zero-support checks. Native distance-unit metadata passes.
These are successful-path checkpoint checks. Phase 05 adds no new crash,
interruption, storage-failure or resume test; earlier controlled-exception
evidence remains limited to its original scope.

The first fixed-state driver stopped at the reproduced historical center-case
failure. That bundle remains intact. A committed diagnosis permits continuation
of the already documented historical array-only class when raw validity,
coefficients, discrete fields and endpoints still pass; new native, discrete,
coefficient, raw-validity or endpoint failures would stop again. The continuation
reused earlier child artifacts by checksum and ran only missing frozen cases.
All failures remain failures. No numerical execution was repeated to obtain a
passing result, and no tolerance was changed.

Python emitted divide-by-zero, overflow and invalid-value warnings in diagnostic
dot products, recorded in 31 stderr logs. A no-solve diagnostic recomputed all
saved dot products: all results were finite and agreed with `math.fsum` to at
most `4.32228e-16` relative difference. The dot products themselves reproduced
3,711 warnings. External primal/dual checks passed without relying on those
warnings or the solver's success label alone. Their low-level cause remains
unresolved; this is not a warning-free numerical environment. The native probe
also built with existing Clarabel C-interface extension and linker warnings.

## Interpretation and remaining scope

The evidence supports the evaluated LP as the working native reference on this
bounded set. It also shows why the reference contract must include the executed
numerical policy: tiny changes across a stopping boundary can alter later
pruning, even when all implementations agree. No formulation-induced discrete
divergence was observed here; absence in these selected cases is not a general
robustness guarantee.

The principal coverage limits are the missing endpoint pruning bracket, the
saddle's zero pruning iterations, overlapping biological subsets, no full run
splitting into multiple components containing edges, and a single pinned macOS
ARM64 environment. We did not test different solver accuracy, alternate optima,
other backends/platforms, full cohorts, production replacement, biological
validity, R integration or recovery after process death. Fixed-state probes are
diagnostics, not additional complete IAN fits.

The next planned engineering milestone remains the reusable core and reliable
execution work in the [coordinator roadmap](../coordinator/ROADMAP.md), after
independent review of this submission and separate authorization. Near-boundary
regression fixtures and the unresolved numerical-library warnings remain explicit
follow-up evidence. Phase 06 has not started.

Supporting evidence: [derived tables](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase05/analysis-v1/tables.md),
[raw checks and results](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase05/analysis-v1/results.json),
[dot-product diagnostic](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase05/analysis-v1/dense-dot-diagnostic.json),
[reproduction instructions](README.md), and
[factual handoff](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase05-implementer-handoff.md).
