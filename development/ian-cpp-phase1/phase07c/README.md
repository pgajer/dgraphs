# Phase07C source and reproduction

The [plan](PLAN.md), [execution amendment](AMENDMENT-1.md) and [report](REPORT.md)
define this bounded experiment. The separate policy is
`IAN evaluated-LP retry 0.1`. It is not an adopted replacement for the accepted
Phase06B library or CLI.

## Source boundaries

`extract.py` mechanically derives 26 files from the read-only Phase06B core,
Phase03 Python reference and Phase05 probe. It changes policy declarations,
retry integration, attempt counters/checkpoint bounds and build identity tracking.
The outer graph, tuning, pruning and affinity arithmetic remains copied unchanged.
`src/retry.hpp` and `tests/retry_tests.cpp` are separately authored. The generator,
Python harness/checks, Markdown documents and these two files are canonical.
`verify_derivation.py` regenerates in a temporary directory and compares bytes.

The streaming checker is copied from Phase07. Its treatment of rejected attempts
is supplemented by `validate.py`: independent scalar certificate reconstruction,
strict attempt ordering, eligibility, identical coefficients, and no intervening
outer event. `test_checks.py` falsifies those assertions without solving anything.
The original cross-path array/decision limits are retained. Exact same-path
comparison removes only timing and the five new retry metadata fields.

Full input JSON must declare the experimental policy. Traces record actual
attempt number, first-attempt number (`logical_solve`), attempt index 0 or 1,
solver tolerance, policy and retry eligibility. The tolerance applies to all
three Clarabel stopping tolerances. A second rejection is terminal even when its
`retry_eligible` flag describes an otherwise eligible numerical failure.
No third attempt is permitted. Stage files, results and restart state identify
this separate policy; restart also binds source, configuration and input hashes.

`--test-solver-fault retry_once` and the positional `retry_exhausted` and
`invalid_solver` faults are test-only controls. One-time damage is used solely
because the natural helix fails before any pruning checkpoint. Damaged payloads
are explicitly marked and retain the original primal vector/objective alongside
the modified values. They are not natural optimization failures.

## Recorded commands

Working directory for every command:
`/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree`.
These paths identify submitted evidence. New reproductions must use new build
and output directories, preserving the submitted bundles. `run.py` and
`operational.py` resolve `phase07c/build-v2` and `phase07c/fixtures-v1` under their
worker argument; a separate scratch worker root can supply a fresh build and
copies of the immutable fixture manifest. Each child command is also saved in
its `command.json` and process ledger.

```sh
W=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker
R="$W/phase07c"
S=development/ian-cpp-phase1/phase07c
PY="$W/venv/bin/python"
python3 "$S/extract.py"
"$PY" -B "$S/prepare.py" "$W"
# Run separately for build-v1 and build-v2, with their matching source revisions.
/opt/homebrew/bin/cmake -S "$S" -B "$R/build-v2" -DCMAKE_BUILD_TYPE=Release -DCLARABEL_SOURCE="$W/phase06a/clean-v2/dependencies/Clarabel.cpp" -DCLARABEL_LIBRARY="$W/phase06a/clean-v2/prefix/lib/libclarabel_c.dylib" -DJSON_INCLUDE="$W/phase03/deps" > "$R/configure-v2.log" 2>&1
/opt/homebrew/bin/cmake --build "$R/build-v2" -j2 > "$R/build-v2.log" 2>&1
# Preliminary panel used d8fab3d and build-v1. It remains unchanged.
"$PY" -B "$S/run.py" "$W" "$R/panel-v1" > "$R/panel-v1.log" 2>&1
# Primary panel used e12af84 and the clean build-v2.
"$PY" -B "$S/run.py" "$W" "$R/panel-v2" "$R/panel-v1" > "$R/panel-v2.log" 2>&1
"$PY" -B "$S/operational.py" "$W" "$R/operational-v1" "$R/panel-v2" > "$R/operational-v1.log" 2>&1
"$PY" -B "$S/test_checks.py" "$R/checks-v1" "$R/panel-v2/helix_500/native/child/trace.jsonl" > "$R/checks-v1.log" 2>&1
# Versions 1 and 2 of the census failed; version 3 is the corrected census.
"$PY" -B "$S/analyze.py" "$R" "$R/analysis-v3" > "$R/analysis-v3.log" 2>&1
"$PY" -B "$S/verify_derivation.py" "$R/derivation-v1.json"
"$PY" -B "$S/finalize.py" "$R"
```

Standalone reproduction of a trajectory can use a fresh binary/output directly:

```sh
F="$R/fixtures-v1/helix_500.json"
FRESH_BUILD/ian_engine "$F" NEW_NATIVE_OUTPUT --interval 100
"$PY" -B "$S/reference.py" "$F" NEW_PYTHON_OUTPUT evaluated
"$PY" -B "$S/validate.py" inspect NEW_NATIVE_OUTPUT "$F" NEW_NATIVE_CHECKS
"$PY" -B "$S/validate.py" compare NEW_NATIVE_OUTPUT/trace.jsonl NEW_PYTHON_OUTPUT/trace.jsonl NEW_COMPARISON
```

The helix exits with numerical refusal; a zero exit is not expected. Reproduction
still needs the pinned Python environment, generated adapter sources, native
Clarabel dependency and compiled Gabriel routine identified in earlier manifests.
No dependency installation, package integration, R qualification or platform
portability test was performed in this phase.
