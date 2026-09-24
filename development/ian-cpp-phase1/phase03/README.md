# Small exact-path IAN engine

This standalone C++17 prototype takes frozen specimen feature rows and pairwise
distances, returns the unique-profile native graph, local scales and full small
affinity matrix, and preserves specimen/profile mappings. It executes the exact
precomputed-distance, l1, automatically retuned IAN contract in [PLAN.md](PLAN.md).
It does not compute Hellinger distances from arbitrary raw count tables, run
optional repair/geodesics/layouts, or provide an R interface. It has been tested
on the four small fixtures in this phase, not cohort-scale inputs.

`reference.py` executes the pinned IAN source with the audited adapter, removing
only inactive plotting/approximate-path imports. It loads the retained compiled
Gabriel function directly and adds observation hooks. Original-expression and
evaluated-LP conditions execute the same loop; only the solve expression differs.
`numeric.hpp` contains native geometry/statistics/ordering, `solver.hpp` performs
fresh Clarabel solves and numerical acceptance, and `engine.cpp` owns the native
loop, input checks, atomic stages and failure reporting. The native process does
not call Python or read precomputed solutions/decision traces.

## Dependencies and build

Run from
`/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree`.
The phase 1 private Python environment and pinned native Clarabel library are
reused unchanged. The Python control additionally reads the existing compiled
IAN Cython extension, whose path and hash are recorded in each reference bundle.
No shared environment is modified. Required Python versions are Python 3.12.10,
NumPy 2.2.6, SciPy 1.15.3, CVXPY 1.6.7, Clarabel 0.11.1 and psutil 7.0.0.

The new native dependency is nlohmann JSON's single header, pinned v3.11.3, under
private `worker/phase03/deps`; its downloaded header and MIT license are hashed.
Native atomic writes and SHA-256 use POSIX and macOS CommonCrypto. This build is
currently macOS-specific. No installation portability claim is made.

```sh
IAN_WORKER=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker
IAN_PHASE="$PWD/development/ian-cpp-phase1/phase03"
IAN_PY="$IAN_WORKER/venv/bin/python"
cmake -S "$IAN_PHASE" -B "$IAN_WORKER/phase03/build-reproduction" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCLARABEL_SOURCE="$IAN_WORKER/deps/Clarabel.cpp" \
  -DCLARABEL_LIBRARY="$IAN_WORKER/build-v2/rust-target/release/libclarabel_c.dylib" \
  -DJSON_INCLUDE="$IAN_WORKER/phase03/deps"
cmake --build "$IAN_WORKER/phase03/build-reproduction" -j 2
```

The build disables floating-point contraction (`-ffp-contract=off`) to preserve
arithmetic ordering. The numerical settings are explicit QDLDL, one solver thread,
fresh construction, binary64, the three 1e-9 tolerances and 300 iterations.
Presolve/chordal processing and sparse zero dropping are disabled; native Clarabel
was built without SDP/chordal support. See `config.json`. Data updates are absent.

Source ports follow the IAN BSD-3-Clause license; the NumPy indexed-sort adaptation
retains its BSD notice. See `IAN-LICENSE.txt` and `NUMPY-LICENSE.txt`. The Clarabel
core/wrapper are Apache-2.0 and JSON is MIT. The exact NumPy ARM64 indexed quicksort
order matters for tied median-override candidates; it is not a new stable tie
policy. References: [NumPy 2.2.6 sort source](https://github.com/numpy/numpy/blob/v2.2.6/numpy/_core/src/npysort/quicksort.cpp),
[JSON v3.11.3](https://github.com/nlohmann/json/releases/tag/v3.11.3), and
[Clarabel's native interface](https://clarabel.org/stable/user_guide_c_cpp/).

## Run and reproduce

All output directories must be new. Commit source before any runs. The drivers
require a clean working tree and record the revision, input/executable hashes,
commands and resources. Jobs run serially. The fixture generator saves actual
coordinates/compositions and distance matrices with hashes, including a fixed
64-profile selection from the pre-existing authorized 500-profile test input.

```sh
"$IAN_PY" -B "$IAN_PHASE/fixtures.py" "$IAN_WORKER/phase03/fixtures-reproduction"
"$IAN_PY" -B "$IAN_PHASE/run_stages.py" \
  "$IAN_WORKER/phase03/fixtures-reproduction" "$IAN_WORKER/phase03/stages-reproduction" \
  --native "$IAN_WORKER/phase03/build-reproduction/ian_engine"
"$IAN_PY" -B "$IAN_PHASE/run_case.py" \
  "$IAN_WORKER/phase03/fixtures-reproduction/nonuniform_curve.json" \
  "$IAN_WORKER/phase03/cases-reproduction/nonuniform_curve" \
  --native "$IAN_WORKER/phase03/build-reproduction/ian_engine"
```

Run `run_case.py` similarly for `variable_density_patch`, `nearby_curved_arms` and
`pressmat_hellinger_subset`. Each invokes the original Python control, evaluated
Python reference and native engine once. Inspect the comparisons before continuing
past a divergence. The engine CLI also accepts `input.json new-output` directly.
Input features define exact duplicate rows; distances remain the supplied metric.
Representatives use first occurrence, retaining original specimen identities.
Distinct near-duplicates, malformed distances and fewer than two unique profiles
are refused. Upstream's undefined initial-isolate state is explicitly unsupported
for full runs; disconnected/isolated adjacency is exercised at downstream stages.

```sh
"$IAN_PY" -B "$IAN_PHASE/failures.py" \
  "$IAN_WORKER/phase03/fixtures-reproduction/failure_input.json" \
  "$IAN_WORKER/phase03/failures-reproduction" \
  --native "$IAN_WORKER/phase03/build-reproduction/ian_engine"
```

Failure-injection CLI labels are `invalid_solver`, `after_graph`, `after_scales`,
`after_affinity` and `pruning_cap`. The last is a labeled diagnostic override of the
outer iteration limit to one; ordinary runs retain 2000. Solver tolerances do not
change. `verify_native.py` documents and executes the bounded cap check and final
native-only rechecks against existing Python traces. `supplement.py` adds the
predeclared conditional-cap decision test in a separate namespace.

## Artifacts and acceptance

Each accepted native stage is written to a same-directory exclusive temporary
file, flushed, renamed atomically and followed by a directory flush. Files are
immutable per output directory. `status.json` is updated atomically and records
stage hashes. A failed run can legitimately have valid earlier stages.

- `graph.json`: converged native edges, degrees, furthest-neighbor bounds,
  components, isolates, vertex mappings, input/configuration/source hashes.
  Bounds are in internally rescaled distance units; the rescaling is recorded in
  the `processed` trace event and the final scale stage. The graph alone does not
  assert successful final retuning or affinity completion.
- `scales.json`: accepted final scales in original and internal units, the
  rescaling factor and final solved C, with provenance and mappings.
- `affinity.json`: validated full weighted matrix with original-unit scales,
  provenance and mappings. Active diagonal is one; isolate rows/columns are zero.
  Native graph components are not silently joined by repair. The affinity kernel
  is its separately defined distance/scale function, not the graph adjacency.
- `trace.jsonl`: every iteration, retuning evaluation, raw LP/primal/LP-dual,
  scale/ratio/kernel evaluation, threshold/candidate order and removed edge.
  The original-expression condition records projected LP data and the conic
  shape/cone dimensions; its auxiliary-coordinate primal/dual values are not
  retained in this phase. Fixed-LP projection was established in phase 02.
- `status.json`: graph/scales/affinity and overall completion flags, hashes and
  errors. Diagnostic failure does not invalidate already committed stages.

External raw checks are separate from solver status. `compare.py` applies exact
discrete comparisons, the frozen floating-array limits and primal/dual checks.
It retains full latest preceding state and decision margins on first divergence.
`kernel_checks` verifies matrix range, symmetry, diagonal and isolates directly.
`finalize.py` independently reconstructs graph degrees/bounds/components and
checks durable affinities from distances/scales, as well as hashes and provenance.

## Analysis and evidence boundaries

`REPORT.md` is authored interpretation. `analysis-v1/results.json` and `tables.md`
are generated by `summarize.py`. Its default submitted layout includes initial
ordinary runs, final native verification, stage supplement and operational tests.
Reproduce the numerical analysis of the retained immutable evidence without any
new optimization using a new output path:

```sh
"$IAN_PY" -B "$IAN_PHASE/summarize.py" "$IAN_WORKER/phase03" \
  "$IAN_WORKER/phase03/analysis-reproduction"
```

The final snapshot command is `finalize.py "$IAN_WORKER/phase03" v1`, run only
after final source is committed. It is a submission-specific evidence checker,
not a generic package QA tool. It preserves and verifies the accepted phase 01/02
bundles, includes failed build attempts, and excludes its own manifest and the
later handoff outside the phase 3 root. Exact executed commands and source-revision
changes are recorded in the worker's `phase03/commands.md` and the handoff.
