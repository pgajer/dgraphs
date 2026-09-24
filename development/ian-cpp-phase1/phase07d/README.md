# Phase07D source and reproduction

Read the [plan](PLAN.md), [status/restart amendment](AMENDMENT-1.md) and
[report](REPORT.md). All work is a bounded experiment, not an adopted engine policy.

`derive.py` copies the accepted Phase07C implementation into `candidate/` and
applies explicit substitutions for unit-normalized retries and backend-status
recording. All 28 files under `candidate/` are generated; the generator is their
source of truth. `verify_derivation.py` regenerates them in a temporary directory
and checks byte equality. The ordinary graph/tuning/pruning code is copied
unchanged. No accepted source or runtime is overwritten.

The policy is `IAN evaluated-LP retry units11 0.1`. Ordinary solves use the same
1e-9 settings. Eligible rejections receive one fresh solve at 1e-11 after uniform
variable normalization. If alpha=max(upper), the backend solves min c'y subject
to A*y<=b/alpha. Returned x=alpha*y, dual z unchanged and objective multiplied by
alpha are checked against original coefficients and unchanged external limits.
The original problem is recorded in the usual trace fields. Strict attempts also
record alpha, actual backend right-hand side, primal/dual/slack, objective and
residuals. Every attempt records the exact backend status. This metadata does not
make an AlmostSolved return eligible or acceptable.

`support.py` imports the accepted Phase07C sampled supervisor and Phase07B scalar
checker read-only. `validate.py` adds explicit unit/recovery checks to the accepted
Phase07C trace checker and retains the same cross-path rules. Comparison of the
original helix prefix removes only timing and new metadata. The old/new Phase07D
trace comparison removes only timing and the added raw status. The interrupted
and resumed trace is compared with its uninterrupted counterpart without dropping
any metadata except timing. The 24 other input specifications remain gated.

All commands ran from:
`/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree`.
The following paths name submitted evidence; reproductions must use fresh output
and build directories. Scripts refuse to overwrite result directories. Child
command files record exact arguments, source revision and one-thread environment.

```sh
W=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker
R="$W/phase07d"
S=development/ian-cpp-phase1/phase07d
PY="$W/venv/bin/python"
"$PY" -B "$S/prepare.py" "$W" "$R/fixtures-v1"
"$PY" -B "$S/diagnose.py" "$W" "$R/diagnostic-v1" > "$R/diagnostic-v1.log" 2>&1
python3 "$S/derive.py"
"$PY" -B "$S/prepare_engine.py" "$W" "$R/engine-fixtures-v1"
"$PY" -B "$S/test_checks.py" "$R" "$R/checks-v1"
# This configuration/build pair ran separately for build-v1 and build-v2.
/opt/homebrew/bin/cmake -S "$S/candidate" -B "$R/build-v2" -DCMAKE_BUILD_TYPE=Release -DCLARABEL_SOURCE="$W/phase06a/clean-v2/dependencies/Clarabel.cpp" -DCLARABEL_LIBRARY="$W/phase06a/clean-v2/prefix/lib/libclarabel_c.dylib" -DJSON_INCLUDE="$W/phase03/deps" > "$R/configure-v2.log" 2>&1
/opt/homebrew/bin/cmake --build "$R/build-v2" -j2 > "$R/build-v2.log" 2>&1
# trajectory-v1 used source 675b450 and build-v1.
"$PY" -B "$S/trajectory.py" "$W" "$R/trajectory-v1" > "$R/trajectory-v1.log" 2>&1
# trajectory-v2 used source 56d9cbe and build-v2; the prior ledger joins the budget.
"$PY" -B "$S/trajectory.py" "$W" "$R/trajectory-v2" "$R/trajectory-v1" > "$R/trajectory-v2.log" 2>&1
"$PY" -B "$S/operational.py" "$W" "$R/operational-v1" "$R/trajectory-v2" > "$R/operational-v1.log" 2>&1
"$PY" -B "$S/test_trace.py" "$R/trace-checks-v1" "$R/trajectory-v2/helix_500/native/child/trace.jsonl" > "$R/trace-checks-v1.log" 2>&1
"$PY" -B "$S/verify_derivation.py" "$R/derivation-v1.json"
# analysis-v1 failed on the Python error-string wrapper; it remains preserved.
"$PY" -B "$S/analyze.py" "$R" "$R/analysis-v2" > "$R/analysis-v2.log" 2>&1
"$PY" -B "$S/finalize.py" "$R"
```

`trajectory.py` resolves the compiled candidate under `worker/phase07d/build-v2`
and fixtures under `worker/phase07d/engine-fixtures-v1`; it verifies the binary's
configured identity against the actual source. A scratch worker root can contain
a fresh build and copied fixture/diagnostic manifests. Individual reproductions
can instead supply any fresh binary and output path directly:

```sh
F="$R/engine-fixtures-v1/helix_500.json"
FRESH_BUILD/ian_engine "$F" NEW_NATIVE_OUTPUT --interval 100
"$PY" -B "$S/candidate/reference.py" "$F" NEW_PYTHON_OUTPUT evaluated
"$PY" -B "$S/validate.py" inspect NEW_NATIVE_OUTPUT "$F" NEW_CHECKS
"$PY" -B "$S/validate.py" compare NEW_NATIVE_OUTPUT/trace.jsonl NEW_PYTHON_OUTPUT/trace.jsonl NEW_COMPARISON
```

Both helix paths are expected to exit with numerical refusal. A diagnostic child
can exit zero while its solver result is rejected; its certificate is the result,
not the process exit. Clarabel/CVXPY, the pinned IAN generator and compiled Gabriel
routine are reused from their existing isolated environments. No dependencies
were installed and no portability or package qualification is claimed.
