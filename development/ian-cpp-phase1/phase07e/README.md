# Phase 07E source and reproduction

Read the [frozen plan](PLAN.md), [report](REPORT.md) and
[fixed-problem collection description](REGRESSION_COLLECTION.md).

`derive.py` generates all 29 `candidate/` files from the accepted Phase07D candidate,
with explicit changes to policy declarations, finite/shape preconditions and
retry eligibility. It is their source of truth. `verify_derivation.py` performs
regeneration in a temporary directory and checks byte equality without changing
measured source. Native and Python classification helpers are used by their
respective runtimes and the 86-case no-solve test. Ordinary numerical assembly,
graph processing, pruning and normalization are inherited unchanged.

`support.py` reuses the accepted Phase07C process supervisor and Phase07B scalar
certificate checker read-only. `validate.py` reuses the frozen Phase03/07C
comparison and graph/affinity inspection rules while independently reconstructing
the new eligibility decisions and retry transforms. `prepare.py` preserves six
fixed problems; `diagnose.py` executes exactly twelve ordinary/normalized solves.
`trajectory.py` gates the other 24 specifications on helix completion and checks.
`operational.py` retains declaration, failure and restart controls. `analyze.py`
reconstructs numerical outcomes and counts physical executions, excluding copies.
`finalize.py` checks historical evidence/source versions and freezes the new bundle.

All commands ran from:
`/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree`.
These commands identify submitted outputs. Reproduction must use fresh output
and build directories; do not overwrite the frozen bundle or historical evidence.
Scripts refuse to overwrite result directories. A scratch worker root can contain
copied read-only historical manifests/fixtures and a fresh phase07e build.
Each guarded child's `command.json` records its full command, revision, working
directory, limits and one-thread environment.

```sh
W=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker
R="$W/phase07e"
S=development/ian-cpp-phase1/phase07e
PY="$W/venv/bin/python"
python3 -B "$S/derive.py"
/opt/homebrew/bin/cmake -S "$S/candidate" -B "$R/build-v1" -DCMAKE_BUILD_TYPE=Release -DCLARABEL_SOURCE="$W/phase06a/clean-v2/dependencies/Clarabel.cpp" -DCLARABEL_LIBRARY="$W/phase06a/clean-v2/prefix/lib/libclarabel_c.dylib" -DJSON_INCLUDE="$W/phase03/deps" > "$R/configure-v1.log" 2>&1
/opt/homebrew/bin/cmake --build "$R/build-v1" -j2 > "$R/build-v1.log" 2>&1
"$PY" -B "$S/prepare.py" "$W" "$R/fixtures-v1"
"$PY" -B "$S/prepare_engine.py" "$W" "$R/engine-fixtures-v1"
"$PY" -B "$S/test_eligibility.py" "$R/eligibility-v1" "$R/build-v1/ian_retry_tests"
"$PY" -B "$S/verify_derivation.py" "$R/derivation-v1.json"
"$PY" -B "$S/diagnose.py" "$W" "$R/diagnostic-v1" > "$R/diagnostic-v1.log" 2>&1
"$PY" -B "$S/test_checks.py" "$R" "$R/checks-v1"
"$PY" -B "$S/trajectory.py" "$W" "$R/trajectory-v1" > "$R/trajectory-v1.log" 2>&1
"$PY" -B "$S/operational.py" "$W" "$R/operational-v1" "$R/trajectory-v1" > "$R/operational-v1.log" 2>&1
"$PY" -B "$S/test_trace.py" "$R/trace-checks-v1" "$R/trajectory-v1/helix_500/native/child/trace.jsonl" > "$R/trace-checks-v1.log" 2>&1
# The first census at revision dd0565f failed on stage-only output handling.
"$PY" -B "$S/analyze.py" "$R" "$R/analysis-v1" > "$R/analysis-v1.log" 2>&1
# Revision 15173c6 corrects only the census's stage-only branch.
"$PY" -B "$S/analyze.py" "$R" "$R/analysis-v2" > "$R/analysis-v2.log" 2>&1
# Run after the final report/source commit and a clean worktree.
"$PY" -B "$S/finalize.py" "$R"
```

The build, fixtures, classification tests, fixed solves and full panel use
`839415e5d1b960d52c19112afffbbc3abf886ee1`. Operational and trace tests use
`dd0565f` with identical runtime, reference, configuration and generator bytes.
The successful final census uses `15173c6`; it does not execute solvers. Later
report/roadmap edits do not alter the validated numerical source. Compiled
source/configuration identities are independently recomputed and checked against
the trajectory ledger and binary at freeze time.

Individual fresh runs can instead use explicit paths:

```sh
F="$R/engine-fixtures-v1/helix_500.json"
FRESH_BUILD/ian_engine "$F" NEW_NATIVE_OUTPUT --interval 100
"$PY" -B "$S/candidate/reference.py" "$F" NEW_PYTHON_OUTPUT evaluated
"$PY" -B "$S/validate.py" inspect NEW_NATIVE_OUTPUT "$F" NEW_CHECKS
"$PY" -B "$S/validate.py" compare NEW_NATIVE_OUTPUT/trace.jsonl NEW_PYTHON_OUTPUT/trace.jsonl NEW_COMPARISON
```

The native CLI's `--cancel-after 0` cancels after the first pruning boundary;
`--resume CHECKPOINT` continues it. Operational command files record the exact
checkpoint path used. Restart comparison retains every event field except timing.
Policy/source/configuration mismatches are intentionally refused.

The numerical test suite is neither package qualification nor a performance
benchmark. The existing isolated Python environment, pinned native backend and
Gabriel extension are reused. No old source, accepted runtime or audit tree is
modified. The handoff lives outside the frozen evidence inventory.
