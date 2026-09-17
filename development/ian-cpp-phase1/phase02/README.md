# Execution fidelity and persistent-sequence prototype

This phase follows the accepted fixed-LP replay. It investigates the large
historical/replay discrepancy and compares repeated solves without repeated
Python imports. [PLAN.md](PLAN.md) fixes the conditions and sequence selection.
[AUDIT-RESPONSE.md](AUDIT-RESPONSE.md) records phase 1 finding N1's wording change.
The phase does not implement the IAN loop or recover the interrupted cohort run.

## Environment and working directory

Run from `/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree`.
Use the private phase 1 Python environment, pinned NumPy/SciPy/CVXPY/Clarabel
versions and ARM64 Rust-backed Clarabel library. No new package is installed.
The phase 1 README contains dependency bootstrap instructions.

```sh
IAN_WORKER=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker
IAN_PHASE="$PWD/development/ian-cpp-phase1/phase02"
IAN_PY="$IAN_WORKER/venv/bin/python"
```

All output directory arguments must be new. To reproduce without replacing the
submission, use distinct names, as below. Keep sources committed before solving.
The driver refuses a dirty tree at measurement launch.

```sh
"$IAN_PY" "$IAN_PHASE/prepare.py" "$IAN_WORKER/phase02/fixtures-reproduction"
"$IAN_PY" "$IAN_PHASE/run_diagnostics.py" \
  --fixtures "$IAN_WORKER/phase02/fixtures-reproduction" \
  --output "$IAN_WORKER/phase02/diagnostics-reproduction"
```

Preparation does not solve. It exports eight late-pruning LPs and four
parameterized final-retuning LPs from original NPZs, with hashes and exact
round trips. The initial recycled check makes the full final phase five solves;
it is recorded as context rather than mislabeled as part of the four-step block.
Preparation AST-extracts two pinned original construction functions without
importing or executing the full IAN module. It reconstructs final C, distances,
graph and bounds from saved primary evidence. The original canonical conic
matrices are saved separately from the LPs. Original IAN BSD license remains in
the private setup directory; no upstream source is vendored here.

The six diagnostic processes vary expression construction, thread policy and
linear-system backend one factor at a time. They include the original expression
with `ignore_dpp=True`, which evaluates parameters before canonicalization.
They preserve the original three 1e-9 tolerances, 300-iteration limit and normal
preprocessing defaults. Each saves actual backend/thread selection before solving,
full solver settings, projected-matrix equality checks, primal/conic-dual vectors
and external LP diagnostics. A single diagnostic is not a repeated benchmark.
Original historical backend telemetry was absent, so reconstruction must be
identified as reconstruction even if it reproduces the historical behavior.

## Native sequence build

The phase 1 official Clarabel.cpp C ABI library is reused unchanged and hashed.
This is a C++17 client of Rust Clarabel, not a new solver implementation.

```sh
cmake -S "$IAN_PHASE" -B "$IAN_WORKER/phase02/build-v1" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCLARABEL_SOURCE="$IAN_WORKER/deps/Clarabel.cpp" \
  -DCLARABEL_LIBRARY="$IAN_WORKER/build-v2/rust-target/release/libclarabel_c.dylib"
cmake --build "$IAN_WORKER/phase02/build-v1" -j 2
"$IAN_PY" "$IAN_PHASE/smoke.py" \
  --native "$IAN_WORKER/phase02/build-v1/ian_sequence" \
  --output "$IAN_WORKER/phase02/smoke-reproduction"
```

Smoke solves two analytic small LPs in each of four path/mode combinations.
Two additional processes solve their first LP and then must reject a dimension
change before the second solve. These ten executed optimizations are setup,
not cohort measurements. Four acceptance adversaries run without optimizing.

## Measured sequences

Wait for diagnostics, compilation and smoke to finish before measurement.

```sh
"$IAN_PY" "$IAN_PHASE/run_sequences.py" \
  --fixtures "$IAN_WORKER/phase02/fixtures-reproduction" \
  --native "$IAN_WORKER/phase02/build-v1/ian_sequence" \
  --output "$IAN_WORKER/phase02/measured-reproduction"
```

This launches 18 serial persistent-process jobs / 96 solves, three repetitions
of six configurations. Each process imports/starts once, then executes the entire
recorded sequence. Fresh construction and data updates have separate labels.
The late-pruning sequence changes matrix shape and is only tested with fresh
construction. No unsupported update is silently reconstructed or padded.

Both sequence paths use the same recorded matrices, QDLDL, one thread, binary64,
1e-9 tolerances and 300 iterations. Presolve and chordal processing are disabled
in both fresh and update modes, and sparse dropzeros is false, so the update
contract is guaranteed. This is a controlled change from historical defaults,
not an unreported tolerance or algorithm change. The native build has no SDP
support, so no chordal processing occurs there. Python invokes CVXPY for every
LP's canonicalization and Clarabel's public constructor/update/solve methods;
it does not cache a parameterized CVXPY model. Thus measured update performance
includes fresh CVXPY modeling. A fully cached modeling layer is untested.

Clarabel updates preserve the existing solver object's initial equilibration
and symbolic structure; numeric factors are recomputed during solving. They do
not import the previous primal/dual solution as an arbitrary warm start. The
pinned source calls `default_start()` each solve. Solver-reported time retains
initial setup while resetting its solve timer; report summed wall phases for
sequence cost instead of adding backend telemetry to those phases.

`validate_outputs.py` reads ORIGINAL source NPZ matrices, recomputes primal
constraint/objective/bound checks and dual stationarity/gap, and compares scales
to historical vectors. A job passes only if its process, all expected steps,
primal policy and additional dual checks pass. Raw failures remain available.
The three-repeat summaries must include coverage and failure counts; do not
compute an all-success speed ratio after dropping invalid jobs.

Memory has two distinct records: root process OS high-water RSS and sampled
sum of process-tree RSS every approximately 20 ms, excluding the parent validator.
No repeated Python startup cost is charged inside a sequence. Sequence wall time
excludes imports, includes per-step I/O/modeling/construction/update/solve/output
and between-step cleanup; process wall includes startup and shutdown. Some short
samples miss activity. The monitoring parent and other host processes can affect
CPU scheduling; these are descriptive measurements on one machine.

## Boundaries

Original phase 1 bundles, audit files and historical run remain unchanged. The
first preparation attempt is preserved if it failed on the discovered canonical
shape difference; later exports occupy another namespace. Derived report tables
come from raw per-step output and process records. No HiGHS sweep, full IAN loop,
R package change, cohort rerun, repair or deployment is included. Backend decisions
and the following small-engine milestone are conclusions for review, not claims
of full reference equivalence or biological validity.
