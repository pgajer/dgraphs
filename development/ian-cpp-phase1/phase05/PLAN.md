# Phase 05 frozen decision-sensitivity study

This plan and CONTRACT.md are committed before generation or new numerical runs.
Base: `9022e32` (coordinator roadmap following phase04 acceptance). User authorized
Phase 05. All phase01–04 and auditor evidence remain immutable. Native engine,
Python reference, solver settings and comparison tolerances are unchanged.

## A. Fixed states selected only from original-expression evidence

Read the six phase04 `search-v1` original traces. Retain the complete rescaled
distances, graph, bounds, degrees, profile identities, C and source event hashes
for four states, selected before new native/evaluated execution:

1. Hellinger 256, event 31, the known first discrepant parameterized solve.
2. Hellinger 300, event 4, the solve preceding its first discrepant volume event.
3. Across all six original traces, the decision with the smallest strictly
   positive absolute active ratio-to-effective-threshold margin. Break ties by
   frozen candidate order, event index, vertex index. Use the immediately
   preceding solve and graph; retain the chosen vertex.
4. Across all six original traces, the retuning evaluation with the smallest
   strictly positive abs(abs(median-1)-0.1), breaking ties by candidate order and
   event index. Use its preceding solve and graph.

Overlapping selected states are retained and labeled, not replaced. This is
purposeful sensitivity selection, not representative sampling. Rebuild fresh
parameterized problems at saved graph/C rather than pretending to resume the
historical solver cache or bracket.

For the first two states use C*(1-2^-24), C, C*(1+2^-24): six single-solve probes
per condition. Each evaluates ratios, the actual threshold/candidate block and
one actual pruning step; it reports whether median/boundary convergence would
hold at the initial bracket. These diagnostic decisions do not constitute a
complete IAN run at an arbitrary frozen C.

## B. Bounded reference-only boundary calibration

For the selected pruning state, vary only C within [0.98*C_saved,1.02*C_saved].
Solve both endpoints under original-expression Python, measuring the chosen
vertex's ratio minus the effective threshold at that C. If signs bracket zero,
perform exactly 24 midpoint evaluations and retain the final two endpoints and
their midpoint as three frozen C values. If there is no sign change, retain the
original two endpoints and midpoint, report the missing bracket and do not widen
the interval. The selection/candidate override may make this diagnostic margin
different from the final selected deletion; report both.

For the selected retuning state, use the same original-only procedure on [0.5,1]
with median ratio minus 1.1 as the target. Exactly 24 midpoint solves if bracketed;
otherwise the same explicit no-bracket rule. Do not change solver accuracy to
manufacture a root. At most 26 calibration solves per state, 52 total. Record
every solve, objective/residual, margin, C and bracket. Numerical sign changes
are observations, not an exact root certificate or proof of monotonicity.

Freeze calibrated fixture bytes before comparing formulations. Run three
single-solve probes for the pruning state under each condition. For the three
retuning C values, invoke the actual full retuning routine with fresh constraints
and the unchanged tolerance/cap, then the actual candidate/prune step. This
tests whether near-boundary numerical differences change the retuning path.
Retuning is capped by its existing 20-evaluation rule. Fixed-state comparison
workload: 27 single solves plus nine retuning calls (at most 180 solves).

## C. Four fixed complete inputs, with no search or replacement

1. The phase04 Hellinger-256 compositions, multiply column j of row i by
   exp(2^-24*sin(i+1)*cos(j+1)), renormalize each row, then recompute Hellinger
   distances. Keep identities and original-source provenance.
2. The same construction for phase04 Hellinger-300 with the exponent negated.
3. An unrelated 120-point 3D helix: t=4*pi*linspace(0,1,120)^1.6 and coordinates
   (cos(t),sin(t),0.12*t), Euclidean distances.
4. An unrelated 144-point saddle: a 12-by-12 grid on [-1,1]^2 with coordinates
   (u,v,0.6*(u^2-v^2)), plus iid normal coordinate jitter with sd .002 and
   default_rng seed 2026091705. Euclidean distances.

Freeze actual arrays and IDs. Execute once under original Python, evaluated
Python and the unchanged native engine: 12 complete runs. The small composition
perturbations are predefined sensitivity inputs, not calibrated to force a
trajectory difference. The synthetic inputs are held out from the phase04 search.
Compare all events, raw solves, graph transitions, retuning, final scales,
affinities and topology. Retain any reference failure; no replacement input.

## D. Exact-threshold and tie probes without optimization

Use the unchanged Python threshold/candidate/prune functions and native numerical
functions on explicit diagnostic vectors: 32 ones with two entries replaced by
(2.75+delta,1) for threshold tests and (4,4+delta) for candidate ties, where delta
is -1e-7,0,+1e-7. Use a 32-vertex unit-spaced cycle with supplied pairwise circular
distances for the one-edge selection test. Median=1; no retuning or geometric
initialization is claimed for these stage vectors. Require exact candidate and
removal agreement for identical inputs and report sensitivity across deltas.

## Comparison, failures and completion

Use the unchanged phase03 comparator and external primal/dual checks. Native/
evaluated fidelity, historical-array compatibility, discrete agreement and final
matrix agreement are distinct fields. Preserve the first differing state,
quantities and margins. For a discrete divergence report the event and graph-edge
symmetric differences and affinity differences at the endpoint. Trace index
alignment after an early branch difference is not a meaningful numerical pairing;
report common-prefix agreement and final outcomes separately.

Pause the driver at a new discrepancy for diagnosis before continuing frozen
independent cases. A documented continuation does not turn failure into success.
No tolerance change or new candidate/solver sweep is authorized. A native/evaluated
failure blocks a claim of implementation fidelity but does not require discarding
the remaining predetermined sensitivity evidence. Do not repair the engine in
this study without a separately documented correction and new run namespace.

The bounded study is complete when all frozen attempts are accounted for, the
contract is explicit, comparisons/negative results are explained, and the report
and factual handoff are frozen for independent audit. Passing all historical
compatibility comparisons is not a prerequisite for an honest completed study.
Success does not prove arbitrary-input robustness, cohort equivalence or biological
validity. No phase06 work, cohort run, R integration, optimization project, merge,
new agents/tasks or automation is included. Store all generated files privately
under worker/phase05, commit runtime sources before use, record commands/hashes,
preserve earlier evidence, and stop at independent-audit submission.
