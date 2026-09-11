# Quadform solver interface and comparison harness

The installed native solvers and unified `quadform_geodesics()` interface now
belong to dgraphs. Use its package help, solver tests and frozen-input comparison
runner for current native development. This older R adapter protocol remains
here with its geometry-constructor checks until the geometry/sampling migration.
Its registry and historical qualification status are unchanged. The standalone
compatibility loader below now requires a dgraphs build containing the solvers.

Development interface **0.3.2** owns the shared adapter contract, numerical
connector cache, independent trajectory audit, process supervision, and
comparison scheduler. Scientific inputs remain in the
[sealed fixture collection](../../fixtures/quadform_geodesics/README.md).
Nothing here is an exported package API; `dev/` is excluded from R builds.

The later package-integrated C++ solver is a separate configuration,
`self-contained-cpp-analytic-v3`, documented in
[the native solver guide](native/standalone/README.md) and Appendix B of
[the mathematical specification](../../fixtures/quadform_geodesics/adaptive_quadform_geodesic_refinement.tex).
Its exact computed-weight graph sums, cancellation-safe returned heights,
occurrence IDs, short-path initialization and incomplete-exploration labels
do not alter the historical adapter protocol described below.

## Status and quick checks

The registry retains eight historical comparison entries and three adaptive-family
entries as **planned** until their implementations are independently reviewed
and activated. The working `direct_connector` control returns the lifted
straight parameter segment. It is useful for testing the harness and supplying
an upper bound, not as a general shortest-path solver.

Adaptive source files are being developed separately. Their presence does not
activate the registry, certify protocol compliance, or constitute calibration
evidence. `adaptive_initializer.R` now calls the identical shared initializer
without subdivision or RNG initialization. Its registry entry remains planned
pending review; there is no direct-connector fallback.

Requirements: R, `callr`, `processx`, `ps`, `jsonlite`, `digest`, and a POSIX C
compiler supporting `clock_gettime(CLOCK_MONOTONIC)`. `testthat` is test-only.
The small development-only `clock.c` bridge is compiled into a source-hashed
temporary cache with `R CMD SHLIB`; it does not compile or modify the R package.
Adaptive backend requirements belong to the adapters, not to this control suite.

## Experimental three-point configuration

Appendix A of the [refinement specification](../../fixtures/quadform_geodesics/adaptive_quadform_geodesic_refinement.tex)
defines `qg-three-point-center-v1`. It starts with 16 equal-surface-length
segments of the direct lifted curve, visits interior points in a fresh random
order each epoch, and draws 32 candidates from the domain-clipped disk centered
at the point being refined. Only immediate neighbors delimit a replacement.
There are no larger windows, endpoint disks, global draws, or scheduled
subdivision after initialization. The existing numerical acceptance rule is
unchanged.

`three_point_vertex.R`, `three_point_local_graph.R`, and
`three_point_initializer.R` are separate adapters. They load the historical
helpers in private environments and replace only the configuration-specific
initialization, sampling, and scheduling functions from `adaptive/three_point.R`.
The old adapters and the main registry are unchanged. These experimental
adapters are not activated for the frozen calibration campaign.

Run `Rscript dev/shared/benchmarks/quadform_geodesics/tests/test_three_point.R`
from the repository root for focused checks. The PCG64 test requires reticulate
and a Python interpreter with NumPy; select the interpreter through
`RETICULATE_PYTHON` if necessary. For the bounded real-surface verification, run
`Rscript dev/shared/benchmarks/quadform_geodesics/verify_three_point.R OUTPUT`,
where `OUTPUT` is a new private directory with an existing parent. This runs
20 selected calculations plus two reproducibility reruns, using both methods
on a flat square, a steep bowl, and a saddle. Each has its own 120-second,
200,000-length-evaluation, 512-MiB allowance and independent numerical path
checks. The runner preserves all outcomes; its exit alone does not certify
that every calculation passed. Inspect `summary.csv` and the saved records.

The R implementation retains the existing memory and progress-saving behavior.
This verification tests the new algorithm, not a C++ implementation, general
geodesic accuracy, or completion of the full frozen collection.

### Direction and neighborhood experiments

The [sensitivity study](experiments/README.md) compares distributions of complete
forward and reverse runs, and tests whether point-density-dependent neighborhoods
explain differences between the two refinement methods. It retains the original
three-point rule as a baseline and adds two explicitly experimental, fixed-scale
alternatives. `run_sensitivity.R` defaults to 100 runs per direction and method,
with separate round-, calculation-, and time-limited comparisons. Use
`--plan-only` to inspect the full plan before starting a large study. Generated
records stay outside the package; these experiments do not activate the registry.

From the repository root:

```sh
make test-quadform-fixtures
make test-quadform-interface
Rscript dev/shared/benchmarks/quadform_geodesics/run.R --list
Rscript dev/shared/benchmarks/quadform_geodesics/run.R --method direct_connector --case flat2_ball --output /tmp/quadform-interface-smoke
```

Outputs require a new directory with an existing parent. Frozen fixture
directories are protected, including through symlinked parents. The example
selects 14 of 394 queries and exits **2** for incomplete coverage even when all
selected queries pass. Exit **0** requires complete consistent coverage; **1**
indicates execution-level or cross-query gate failure. No rows are repaired.

## Adapter contract

Each adapter file returns a `qgs.adapter(id, supports, prepare, solve, inspect = NULL)` object;
[solvers/direct_connector.R](solvers/direct_connector.R) is the minimal example.
`supports(request)` returns a supported flag and reason. Only supported requests
reach `prepare(request, control)`, then `solve(state, request, control)`.
Exceptions become explicit failures. Preparation and solution are timed
separately, including time spent before an exception.

A solve response has `status` equal to `candidate`, `failed`, or `unsupported`,
a nonempty `termination`, and optional diagnostics. A candidate response requires
an acknowledged incumbent published through `control$publish`; an untracked
final path or scalar is insufficient. Never silently substitute another method.

Set a registry entry to `implemented` only after its adapter and tests exist and
integration is reviewed. Its `file` is relative to this directory. Every
additional implementation file belongs in its `sources` array for hashing.
Record provenance/licenses for imported code and exact backend versions in
diagnostics. External children must terminate with their R worker.

**Request:** interface and collection versions; case/pair/direction identifiers;
repeat label, seed digest and exact seed hex; geometry, declared domain, length
scale, oriented endpoints, parameters, limits, method and configuration IDs.
Campaign requests add `budget = list(metric, values)`. Analytic answers and
reference bounds are deliberately excluded. The domain is the original sampling
ball/box, never the sampled point-cloud hull.

Seeds use SHA256 of
`qg-refine-v1|collection_sha256|case_id|pair_id|direction|repeat_label`.
`seed_hex` is the first 16 hexadecimal characters, the exact unsigned 64-bit
big-endian pattern. NumPy uses `PCG64(int(seed_hex, 16))`, never an R double
round-trip or an R RNG substitute. Methods/cohorts may share starting streams
but never share mutable RNG state.

Every query, direction, cohort, and repetition starts cold in a fresh R worker.
No graph, cache, initializer, or RNG state is shared across runs. A future
amortized comparison must declare its different lifecycle explicitly.

## Shared control

`qgs.candidate(U, length, error_estimate)` describes lifted straight parameter
segments with rows of `U` as vertices. Endpoints must equal the request, all
vertices must be inside its declared convex domain without projection/slack,
and estimates must be finite and nonnegative. Exact duplicates contribute zero;
near-coincident endpoints are not merged. Ambient isometries preserve length.

Native trajectories and distance-only representations may be retained, but
are **not audited or exported as passing distances**. Sampled BVP points and
polyhedral chords must not be relabeled as an original continuous trajectory.

The control provides:

- `edge(from, to, tighter = FALSE)`: connector length and estimated integration
  error; all adaptive connector work must pass through it.
- `batch(edges, tighter = FALSE)`: sort and deduplicate a list of
  `list(from, to)` edges by full key, then evaluate the complete batch.
  Numerical failures are retained as records; budget interruptions propagate.
- `publish(candidate, phase, diagnostics)`: persist a proposed publication
  before acknowledging it. Use phase `initializer` for the completed initializer.
  Late persistence cannot replace the acknowledged incumbent.
- `poll()`: cooperative time check during non-edge work.
- `stats()`, `latest()`, `initializer()`: counters and acknowledged paths.
- `finish(reason)`, `checkpoints()`: resource-grid observations. Completed
  schedules can carry the terminal path forward; resource-censored runs cannot.
- `checkpoint(state)`: atomically persist one binary bundle containing adapter
  state, acknowledged incumbent, initializer, exact cache/LRU, counters, elapsed
  search time, and resource checkpoints. It does not publish a new path.
- `capabilities()`: explicit cache/key/error/checkpoint protocol identifiers.
  A control without a persistence sink advertises checkpointing as unavailable.
- `snapshot(adapter_state)`: low-level exact snapshot, accepted by
  `qgs.control(..., restore = snapshot)` only for the same request/version/cache
  capacity. This primitive is not an interrupted-solver resume implementation.

The cache holds **65,536 undirected edges**, each with level-0/level-1 records.
Keys encode uint32 dimension and IEEE binary64 coordinates in big-endian order,
preserving signed zeros; endpoint order is unsigned-byte lexicographic order.
Every lookup updates LRU, including misses at a fidelity and failed hits.
Eviction removes both levels. A successful level-1 answer satisfies level 0;
a coarse answer never satisfies level 1. Completed numerical failures are cached
and signal `qgs_edge_error`; budget interruptions signal `qgs_budget` and are
not cached. Counters distinguish lookups, calls, failures, upgrades, and eviction.

Every actual kernel invocation, including identity and failed attempts, consumes
one edge call; hits do not. Quadrature uses relative tolerance `1e-10`, absolute
tolerance `1e-12 * length_scale`, and 1,000 subdivisions; level 1 divides both
tolerances by 100. Sums use compensated accumulation. Tie rules, proposal order,
and stage schedules remain the adapter's responsibility.

Search/checkpoint serialization is charged to algorithm time. Exact edge-count
thresholds include fully committed updates at that count, before the next kernel
call; time thresholds retain the last publication completed by the deadline.
A raw publication file can precede acknowledgement, so it alone is not proof of
an accepted path. Binary RDS is authoritative for coordinates and state; JSON is
a readable companion and is not used to restore exact floating-point bits.

State checkpoints are recording infrastructure, **not automatic recovery**.
The current runner does not restore an interrupted adapter, reconcile a
mid-attempt state machine, or qualify an unacknowledged publication after a
forced kill. Those require a separately reviewed restore/publication contract.
The adaptive state hook preserves exact RNG state supplied by the adapter but
does not itself implement or restore PCG64.

## Independent audit and qualification

A separate process audits initializer, terminal, then primary-budget checkpoints
in ascending budget order. Deduplication uses the entire exact ordered path plus
geometry/domain/semantics, not its reported length. One integral can serve several
aliases, but each alias's own frozen search estimate is compared separately.

The auditor constructs tangents directly from the forms, independently of the
search kernel's coefficient expansion/cache. Both use R's integration library:
this is an independent integrand, not an independent quadrature backend or a
rigorous error certificate. Tolerances are relative `1e-12` and absolute
`1e-14 * length_scale` per segment, with compensated accumulation.

Agreement allows the sum of reported integration errors plus
`64 * machine_epsilon * (m + 1) * max(length_scale, audited_length, search_length)`,
where `m` is the number of segments. Identity lengths must be exactly zero.
Audit never moves vertices or improves a path. Exports use independently audited
lengths while retaining search estimates, discrepancies, and estimated errors.

Audit has a 10-second process budget and 4,096 segment-call budget. Completed
qualifications are atomically retained if later work times out. Unavailable
audit and failed search are distinct outcomes; already-established feasibility
is preserved when numerical auditing runs out of budget.

Qualification layers remain separate: search outcome, path feasibility and
agreement, per-query fixture checks, then unchanged full-collection checks for
symmetry, available triangles, scaling, and domain inclusion. Passing these is
necessary consistency, not global shortest-path optimality. Abnormal worker
exits remain failures, even when raw artifacts are useful for diagnosis.

## Comparison campaign

`campaign.R` freezes the provisional `qg-refine-calibration-v2` schedule:

- 16 selected endpoint pairs, both directions, five repeat labels 4101--4105.
- Edge cohort: checkpoints 10,000 / 50,000 / 200,000; caps 200,000 calls and 120 s.
- Time cohort: checkpoints 1 / 5 / 20 s; caps 20 s and 2,000,000 calls.
- 512 MiB sampled worker-tree RSS and 257 path vertices per run.
- 64 deterministic initializer baselines first, then 640 adaptive runs.
  Odd repeats run A then B; even repeats run B then A within each query.
- Four hours active campaign wall time; no automatic retries.

```sh
Rscript dev/shared/benchmarks/quadform_geodesics/compare.R plan /tmp/quadform-plan
Rscript dev/shared/benchmarks/quadform_geodesics/compare.R status /tmp/quadform-plan
# Only after adapter review, baseline binding, and a fresh source-frozen plan:
Rscript dev/shared/benchmarks/quadform_geodesics/compare.R run /tmp/quadform-plan
```

Creating a plan does not run any solver. Execution fails closed if any bound
adapter is absent or planned. Changes to source, registry, fixtures, or plan
invalidate resumption: create a new campaign after integration rather than
editing the old manifest. Programmatic plans can explicitly bind other methods
or use reduced smoke cohorts; these must have a different protocol label and
must not be represented as adaptive calibration evidence.

Campaigns reserve a full job timeout plus audit/startup overhead before launch.
Clean completion refunds unused reservation. An abandoned in-flight attempt
keeps its reservation and becomes `interrupted`, never silently rerun.
Completed jobs are retained; `run DIRECTORY MAX_JOBS` pauses at job boundaries
and a later run consumes pending jobs only. Paused time is not charged.
An outer watchdog also limits active campaign orchestration/export time.

An exclusive `run.lock/` records owner PID/host. After an actual parent crash,
confirm the owner and descendants are stopped before removing a stale lock.
Never run two writers against the same output. A watchdog interruption can leave
derived CSVs stale; binary state and completed records remain authoritative.

Campaign outputs include exact and readable plans, source/environment manifest,
state ledger, per-job requests/records/logs, and:
`checkpoints.csv`, `summary.csv`, `paired.csv`, `directional.csv`, plus
full **394-row** fixture exports/gates per role/cohort/repeat/checkpoint.
The default checkpoint ledger has 2,112 rows including not-run/censored outcomes.

Summaries show conditional distributions and planned/usable/failure counts;
usable means numerically audited, not necessarily fixture-qualified.
The checkpoint ledger separately exposes row status and collection gate.
Paired differences and directional discrepancies remain raw, with unavailable
values left missing. Analytic errors exist only where an exact answer is known;
chord gaps are not errors against an unknown geodesic. No symmetry repair,
best-repeat selection, or hidden denominator changes are applied.

## Single-method runs and limitations

`run.R` accepts `--method`, `--case`, `--repeat` (default 4101), and
`--config` JSON with `parameters` and/or `limits`. Default limits are
`edge_calls: 200000`, `seconds: 120`, `max_vertices: 257`, `rss_mib: 512`.
Programmatic `qgs.run()` also accepts unique case/pair/direction selection rows.
Unselected queries remain `not_run`; output reuse is rejected.

Single-method artifacts include source/version manifest, all-query selection
plan, per-query binary checkpoints and optional `algorithm-state.rds`, logs,
records, complete candidate-results ledger, and cross-query gate. A
`results.csv` is written only for a consistent gate, possibly incomplete.

Search uses a monotonic clock and an independently supervised worker deadline
starting at its recorded initialization time, with a separate 5-second startup
allowance. RSS is sampled approximately every 20 ms over worker and descendants,
not an OS address-space cap; brief peaks may be missed and shared pages may be
double-counted. Search, audit, and end-to-end timings and observed peak RSS are
recorded separately. Backend thread environment limits are set to one; this
does not prove every third-party library obeys them.

The harness is not a completed solver comparison. The 0.3.1 reporting correction
has passed independent review; the later readiness instrumentation is a separate
revision. Historical/native-path adapters, calibration/resource qualification,
and interrupted-solver recovery remain outstanding.
No adaptive calibration has been run as part of the shared-runtime tests.

Keep exploratory outputs in scratch/private storage or ignored `runs/`.
Internal agent reviews belong outside the public package. Do not modify or
rebuild the sealed fixture payload during interface or solver development.

## Revised failure and reporting semantics

Version 0.3.2 adds a bounded readiness runner and monitor diagnostics. The monitor
retains the first 64 sampling exceptions (message, class, PID, scope, observed
process state), a total exception count, and approximately one RSS sample per
second plus the terminating observation. A truncation flag exposes omitted
exceptions. The three-consecutive-missing-sample stop rule, RSS cap, deadlines,
and child-sampling behavior are unchanged. Missing child samples still contribute
zero under the existing policy, now with explicit diagnostics; traces are not
continuous memory profiles or hard memory bounds.

`readiness.R` runs a separate 24-job pilot: I/A/B, the flat box `grid_direction`
and high-curvature paraboloid `ab` pairs, both directions, repeat 4103 for A/B,
and the provisional edge/time cohorts above. It retains the 512 MiB cap and
257-vertex cap. A 30-minute outer watchdog bounds the pilot. It requires a clean,
unchanged committed source tree; it never retries or resumes. All planned rows,
including failures and not-run entries, remain in the exports. Explicit pilot
adapter bindings do not activate the registry or bypass normal campaign gates.

```sh
Rscript dev/shared/benchmarks/quadform_geodesics/readiness.R plan /path/to/new-pilot
Rscript dev/shared/benchmarks/quadform_geodesics/readiness.R run /path/to/new-pilot
```

The parent output directory must already exist. Use private or ignored storage.
The plan/source manifest is finalized before execution; `pilot-stdout.log`,
`state.rds`, job records, and `pilot-monitor.rds` retain progress and outcomes.
This pilot uses the existing provisional tie/endpoint conventions without
ratifying them or freezing a calibration. Pilot outcomes do not justify method
rankings. A new source/version revision always needs a new pilot directory.

Version 0.3.0 follows the first independent implementation audit. Sources and
report columns changed, so old campaign manifests cannot be resumed as this
revision. No registry entry was activated and the sealed v1 payload was not
rebuilt. The collection helper's domain norm was made range-safe; its scientific
inputs, result schema, and declared geometric tests were not relaxed.

A checkpoint supplies comparison lengths only when its durable ledger status is
`complete`, its search status is `candidate`, its checkpoint is observed/carried,
and its numerical audit passed. Refined arms A/B also require their own
initializer audit to pass, even for absolute-length comparisons. The initializer
baseline I is not a refined run: its checkpoint length needs the checkpoint
audit; initializer-dependent shortening and ablation fields still require the
initializer audit. Earlier paths from failed, interrupted, or
uncommitted attempts remain diagnostics, never qualifying comparison values.
Search, path feasibility, audit, fixture-row, and collection statuses remain
separate. Numerical integration failures preserve feasibility already established
by vertex/domain validation. Distinct endpoints cannot qualify with zero length.

Norms use scaled arithmetic for small/large finite values. Finite input alone is
not a guarantee that every quadratic product, displacement, or integral is
representable; nonfinite intermediate arithmetic fails explicitly. No arbitrary
precision or accuracy guarantee over all binary64 inputs is claimed.

Workers reconcile their descendants before normal return or an ordinary error.
The parent retains creation-time-qualified handles to observed descendants and
also cleans them after interruption/exit. This covers ordinary process ancestry,
not deliberately escaped/reparented daemons that evade observation. Backends that
escape the supervised process tree are unsupported. Checkpoint files use atomic
rename for process visibility, not a demonstrated fsync/power-loss guarantee.

The optional adapter `inspect(state)` hook supplies a read-only terminal diagnostic
snapshot. Only fully acknowledged publications enter the returned lightweight
history. After mandatory initializer, terminal, and resource-checkpoint targets,
remaining audit budget can qualify publication histories and raw grid/direct
routes. It never displaces the mandatory queue or increases the audit budget.

New reporting fields include relative initializer shortening, the numeric
shortening allowance, feasibility/status columns, accepted/inserted/deleted
counts, terminal vertices/stage/sweep, and raw-grid/direct diagnostics. Unavailable
fields remain missing. Counts of search failures, censoring, unavailable audits,
and failed audits have explicit denominators; overlapping flags are not a
partition of outcomes.

Version 0.3.1 applies the own-initializer gate to every refined checkpoint length,
fixture export, and derived comparison, not just shortening. `comparison_status`
reports `qualified` or the first exclusion reason in ledger, search, checkpoint,
checkpoint-audit, initializer-audit order. Raw audit statuses and retained paths
are unchanged; excluded lengths and their error/gap readouts remain missing.
`audit_failed` and `audit_unavailable` count rows affected by either checkpoint
or required initializer audits, once per row within each flag. Separate
`checkpoint_audit_*` and `initializer_audit_*` counts identify the contributors;
the latter count only required initializer audits. All planned rows remain in
denominators. Paired/directional tables carry both sides' comparison and
initializer statuses, with explicit availability flags. These source/schema
changes do not permit resuming a 0.3.0 campaign as 0.3.1; old retained exports
remain historical evidence, not silently rebuilt results.

`ablations.csv` joins each refined observation with the separate deterministic
baseline and its A/B counterpart. Initializer estimates must agree within summed
uncertainty and have matching path keys. Initial subdivision paths must match,
with a completed first subdivision and no initial identity-check failures.
Missing evidence yields `unavailable`; mismatches yield an explicit invalid
status and no baseline-benefit value. Later stochastic paths are not required to
match, and each refined run still needs its own initializer audit.

The 0.1% target is declared reached only at an audited, acknowledged publication
whose shortening exceeds the target plus numerical allowance. Work/time fields
identify that first qualified observation, not an interpolated crossing.
`target_prefix_fully_audited` distinguishes complete preceding qualification from
an upper-bound observation with earlier unaudited states. A missing audit is not
reported as a demonstrated failure to reach the target. No failed search supplies
a target attainment value.

Target-attainment and terminal adapter counters are whole-run observations,
repeated alongside each checkpoint row; they do not claim the target had already
been reached at an earlier checkpoint. Checkpoint quality uses that checkpoint's
own accepted path and audit. Endpoint equality is numeric without tolerance
(signed zeros coincide geometrically); keys and stored paths retain exact bits.

`paired.csv` and `directional.csv` include source statuses; `paired-summary.csv`
shows paired coverage and conditional difference distributions. `pair-summary.csv`
and `equal-pair-summary.csv` give equal weight to observed per-pair summaries,
separating analytic and unknown cases and exposing missing/complete pair counts.
Directions remain independently visible before descriptive aggregation. These
conditional summaries do not establish population performance or inferential
independence, and do not repair a failed fixture gate.
