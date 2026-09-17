# Phase 03: small complete IAN engine — frozen comparison contract

The user accepted phase 02 (candidate 322595c) and authorized proceeding after
review of the review-2 proposal. I agree with that proposal. This phase implements
a standalone small engine and stops with an independent-audit handoff. No cohort
restart/recovery, production change, merge, R interface, new solver, data updates,
method variant or repeated performance benchmark is included.

## Reference and controlled conditions

The reference is IAN 1.1.2, upstream commit
06606ab27b52a1ea60daebae082a0e6752625521, as frozen under
`/Users/pgajer/.codex/private/ZB/exp038-full-cohorts/20260916-175755/source/`.
The controlling files are `build/source-evidence/ian/ian/ian.py` (SHA-256
b27f05ad470f963dab8e2989fb1048577670da3daee5ad78d10e5947c931a603),
`ian/cutils.pyx`, and `scripts/prepare_ian_adapter.py`, `pilot_audit.py`,
`run_ian_pilot.py`, `run_full_cohort_background.py`. Hash the actual files and the
compiled retained Cython extension. Apply the existing adapter generator to a
private copy, retain its diff, and add observation hooks without changing branch
conditions. Inactive plotting/approximate imports may be removed for the private
exact-path loader; active IAN functions and compiled Gabriel remain the reference.

Three conditions use the SAME frozen specimen features and distances:

1. Original-expression Python control: executed pinned algorithm and adapter,
   original parameterized CVXPY constraints.
2. Evaluated-LP Python reference: same executed algorithm, replacing only the
   solve expression with the adapter's explicitly evaluated A,b,c.
3. Evaluated-LP native engine: independently ported C++ loop and evaluated assembly.

Clarabel core 0.11.1, binary64, fresh construction, explicit QDLDL and one thread
in all three. Tolerances tol_feas/tol_gap_abs/tol_gap_rel = 1e-9, max_iter=300.
Presolve and chordal processing disabled; sparse zero dropping disabled. These
are controlled settings, not recreation of historical runtime defaults. Preserve
adapter acceptance: optimal status, finite correctly shaped solution/objective,
normalized row residual and relative objective consistency <=1e-7, positive active
scales, bounds represented by rows. Also record dual vectors and checks; do not
let an invalid primal drive ratios or pruning. Retuning cap 20 and pruning cap
2000 are explicit failures. No changed tolerance after a divergence.

## Inputs and exact-path policy

Four complete-run fixtures, constructed once and saved with hashes before any
comparative solve: 64 points on a nonuniform smooth curve; 80 points on a warped,
variable-density 2D patch; 96 points on two nearby curved arms; 64 composition
profiles at indices floor(linspace(0,499,64)) from the existing authorized
`build/pilot-20260916-v1/pressmat_500_input.npz`. The last uses stored compositions,
Hellinger distances and representative IDs, without CST/outcome selection. Save
coordinates/compositions and complete distance arrays, not only seeds. No fixture
is replaced because it produces difficult pruning or reference failure.

Exact duplicate feature rows use first-occurrence representatives, matching the
frozen cohort preparation's tuple(row) lookup; signed zeros compare equal. Preserve
specimen order, representative IDs and member-to-profile map. Distances for unique
profiles are selected from supplied specimen distances; duplicate rows must have
consistent distances. Near-duplicate distinct profiles are not merged. Require
finite nonnegative symmetric square distances with zero diagonal. Distinct minimum
distance satisfying np.isclose(d,0) is refused. Fewer than two unique profiles are
explicit degenerate refusals before invoking the upstream empty-array path. These
outer input guards are a stated standalone contract, not new successful upstream
results. A targeted raw reference probe preserves its own degenerate limitations.

Exact precomputed distances: D2=(D*D), scl=1/min distance, D1*=scl and D2*=scl*scl
in that order (not square already rescaled D1). Gabriel casts D2 to float32; its
two float32 distances are added in float32, then promoted to double and compared
with float32 edge distance plus double(10*float32 epsilon), using <=. Traverse
(i,j,k) in ascending order. Initial edges lexicographic; furthest-neighbor order
is descending (distance,index). Initial-isolate data are uninitialized upstream:
ordinary engine refuses this unsupported full-run condition explicitly; the
provided disconnected adjacency/isolated vertex is tested at downstream stages,
not made to succeed by silently patching the initial state.

Only obj=l1, exact-precomputed, sig2scl=1, n_stds=4.5, C3 threshold dispersion,
max_prune=.1, fixedC=None, allowMSconvergence=False, final tuning='median',
interactive=False, plots disabled. Initial C = clip(median(median-neighbor /
furthest-neighbor distance), .55, .95), with the source's degree-index formula.
Retuning follows the exact recycled first solve, bracket updates, np.isclose
boundary predicate and last-solved-C bookkeeping. Native assembly preserves
parameterized versus recycled arithmetic and row order; algebraically equivalent
reassociation is not assumed bitwise equal.

C3 location .333*(q1+median+q3), linear percentiles; dispersion uses the source's
normal quantile. Threshold floor 2.75 and conditional cap 5-(median-1), with the
median override and max(1,int(.1*candidate_count)). Ordinary candidates use stable
descending statistic from ascending indices; override reproduces NumPy 2.2.6 ARM64
indexed quicksort/reverse tie behavior. Preserve one-edge-per-node skipping.
Native normal quantile implementation may differ within the limits below; no
alternate discrete tie rule is introduced.

Volume sums use the pinned dense float64 distance path, cutoff <= -log(2*eps64),
with degree=max(2,degree), log2 correction, and zero ratios for isolates. Final
multiscale affinity uses reciprocal scales in the source multiplication order,
strict exponent cutoff < -log(2*eps64), 1e-8 numerical truncation, maximum with
transpose, unit diagonal for active vertices, zero rows/columns for
adjacency-confirmed isolates. Save scales in internal and original distance units;
compare the full small affinity matrix, including zeros, symmetry and diagonal.

## Frozen comparison limits and divergence records

Require EXACT discrete agreement for evaluated Python/native: duplicate mapping,
initial/iteration/final edges, degrees, candidate order, removals, isolates,
component membership, solve phase/site/order, evaluated C sequence, bracket/stop
flags, cap decisions and completed stages. Original/evaluated comparisons are
reported separately, under the same criteria, not relabeled native defects.

Float arrays: elementwise abs(a-b) <= atol + rtol*max(abs(a),abs(b)). D1/D2 and
upper bounds: atol=1e-12, rtol=2e-14 in internal distance / squared-distance units;
LP coefficients/bounds: atol=1e-12, rtol=2e-14 in recorded coefficient units.
Scales: atol=1e-7, rtol=1e-7 in internal distance units (divide absolute limit by
scl for original-unit scales). Ratios, location/dispersion and effective
thresholds: atol=1e-7, rtol=1e-7, dimensionless. Affinities: atol=1e-7, rtol=1e-7
on [0,1], with exact zero support/diagonal/isolate conventions. Record maxima and
bitwise equality even when not required. External optimization policy is unchanged.
Dual residuals are diagnostics in the original lifted formulation; LP dual
stationarity/nonnegativity and relative gap must pass 1e-7 in evaluated paths.

Record every solve, every volume evaluation, retune bracket/stop, decision and
prune. Store LP CSR arrays, raw primal/dual, scales, ratios, kernel, graphs and
bounds. Compare entire traces, not only endpoints. On first divergence retain
preceding and current events from both traces, all referenced state, threshold
margins, median/bracket boundary distances and neighbor tie gaps; classify cause
before rerunning. Do not erase any earlier failure. Implementation corrections
require new committed revisions and new output namespaces; no fixture or tolerance
selection by observed agreement.

## Targeted checks and failure injections

Stage fixtures (saved before comparison): exact duplicate rows including signed
zero; three-point squared distances just below/at/above the float32 Gabriel
boundary; ordinary and median-override candidate ties (including >16 entries);
threshold floor and conditional-cap cases; neighbor-distance tie and shared-node
pruning skip; two disconnected edge components plus an isolated vertex; degenerate
zero/one unique point, distinct near-duplicates, asymmetric/negative/nonfinite
input. Expectations are exact stage agreement, or explicit stated refusal. The
raw upstream degenerate/initial-isolate limitation is preserved separately.

Disconnected stage: valid scales/bounds from an explicit adjacency, assembly and
acceptance, volume ratios, affinity diagonal/symmetry/support/isolate masking,
components and checkpoint identities. No implicit component repair. Add an affinity
cutoff/underflow test with scales chosen on both sides of the numeric cutoffs.

Native failure injections on a small fixed valid input: replace the first solver
result with invalid scales before acceptance; throw after atomic validated graph
checkpoint; throw after atomic validated affinity checkpoint. Invalid scales must
not lead to volume/pruning. Graph-only completion must not imply final-retuning or
affinity success. Also inject after final-scale checkpoint to distinguish its
state. Write same-directory temp files, fsync and atomic rename; each immutable
stage includes input/config/source hashes, stable vertex identities and validated
stage status. Stage flags are published only after artifacts are durable. Earlier
artifacts survive failures. No optional repair/path/layout computation is required.

## Execution and stopping point

Keep sources in phase03 under the assigned prototype directory and generated
fixtures/builds/traces under worker/phase03. Preserve accepted phase01/02 and all
auditor records. Commit before runs. One initial complete run per fixture and
condition (12 runs); stage checks and four failure injections separately labeled.
Any diagnostic rerun must answer a concrete discovered failure, use a new namespace
and be disclosed. No timed-repeat claim. Record phase times, RSS and workload as
diagnostics, not a speed/memory superiority benchmark. Deliver committed sources,
all raw outcomes, automated comparison tables, report and factual handoff; stop
for independent audit.
