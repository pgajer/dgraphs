# Phase07B sources and reproduction

The [plan](PLAN.md) precedes executions; the [report](REPORT.md) distinguishes
baseline reproduction, experimental results, numerical-policy compatibility and
the unimplemented next-step proposal. New source lives here and in the coordinator
roadmap. Previously accepted runtime, numerical settings, evidence and audit
sources are unchanged.

All commands ran from
`/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree`.
The variables below abbreviate the exact paths used. Existing output directories
are submitted evidence; reproductions must use new directories.

```sh
W=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker
R="$W/phase07b"
PY="$W/venv/bin/python"
S=development/ian-cpp-phase1/phase07b
LAUNCH=development/ian-cpp-phase1/phase05/launch.py
# 8982dd7: capture four saved evaluated LPs and one actual canonical problem
"$PY" -B "$LAUNCH" "$R/prepare-driver-v1" "$S/prepare.py" "$W" "$R/fixtures-v1"
# 59bcd03: seven no-solve checks and all 33 fixed diagnostic solves
"$PY" -B "$LAUNCH" "$R/check-driver-v1" "$S/test_checks.py" "$R/checks-v1"
"$PY" -B "$LAUNCH" "$R/replay-driver-v1" "$S/run.py" "$R/fixtures-v1" "$R/replays-v1"
# b3b6f89: revalidate saved returns and reconstruct numerical mechanisms
"$PY" -B "$LAUNCH" "$R/analysis-driver-v1" "$S/analyze.py" "$R" "$R/analysis-v1"
# 5ac67c5: exact rational feasibility witnesses, zero new solves
"$PY" -B "$LAUNCH" "$R/witness-driver-v1" "$S/feasible_witness.py" "$R/fixtures-v1" "$R/witness-v1"
# Final revision: verify prior preservation and inventory the new bundle
"$PY" -B "$S/finalize.py" "$R"
```

`prepare.py` chooses the recorded states using the frozen rule, archives their
hashes, captures the historical canonical problem without solving, and checks
its projection. The capture's expected `CapturedBeforeSolve` traceback and
adapter status are not evidence of a new failed optimization.

`replay.py` performs exactly one new fixed solve per invocation and saves problem,
full settings, raw solution, iteration telemetry and diagnostic result. For row
normalization, original duals are row_factor times transformed duals. All external
checks remain against the original LP. `run.py` controls the fixed schedule,
records each command/cwd/source/resources, and imposes sampled limits. This
supervisor had no limit event; actual resource exhaustion was not injected.

`common.py` computes scalar constraint/objective/dual checks with `math.fsum` and
checks the worst row with Decimal. `analyze.py` reconstructs these checks from
raw returns, verifies transformations and compares global residual telemetry.
Its 5e-14 absolute reconstruction allowance concerns agreement between two ways
of calculating a reported residual; it is not a changed IAN or solver acceptance
tolerance. The actual maximum discrepancy is below 8.60e-16.

`feasible_witness.py` uses exact rational representations of the binary64 inputs
to prove feasibility of x=upper for the five original projected LPs. It does not
claim optimality or certify the historical returned auxiliary vector.

Authored Python and Markdown files are canonical. Generated fixtures, raw solver
data, logs, diagnostic tables and manifests live in the worker bundle. No native
build, Rust/Python package modification, outer IAN experimental run, replacement
solver policy or R artifact was generated. Source commits after replays add
analysis/witness/report/provenance only; the replay source remains unchanged.

The finalizer verifies prior manifests through Phase07 and its audit, historical
source blobs, the unchanged dependency/runtime identities, recorded fixture and
source hashes, and inventories this phase. The handoff is outside the frozen
bundle. Its independent-review state is separate from study completion and
authorization for a retry implementation.
