# Phase 07F reproduction and source boundaries

Read [PLAN.md](PLAN.md) and [REPORT.md](REPORT.md). Phase07F does not modify or
rebuild the accepted Phase07E numerical candidate. It reuses that candidate's
binary, Python reference, configuration and pinned backend read-only. The new
source consists only of a fixture generator, harness, independent saved-data
checks and documentation.

`quadforms.R` calls the existing dgraphs geometry-only API by sourcing four
pinned R files from this worktree. No installed dgraphs package is loaded.
`prepare.py` records their hashes and all RNG/specification/sample objects,
checks the embedded coordinates independently, reconstructs every pairwise
distance and freezes all seven input specifications before optimization.
Binary coordinate files are little-endian IEEE binary64 in R column-major order.
RDS files retain the complete R objects; specification.R is readable provenance.

`preflight.py` verifies runtime/source/fixture identity and runs the accepted
Phase07E trace-verifier falsification tests on a small saved trace excerpt, with
zero new solves. `run.py` uses the accepted sampled supervisor and gates each
new input on complete agreement of the previous pair. A selected larger native
restart test is conditional on a completed paired case with pruning; none was
available in this submission. `validate.py` reuses accepted certificate,
transformation, graph and affinity checks and verifies checkpoint envelopes if
present. `analyze.py` reconstructs every saved solve and accounts for physical
attempts. `difference.py` examines the two saved terminal programs without
solving. `finalize.py` verifies preservation and freezes the new inventory.

All commands ran from:
`/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree`.
The paths below identify submitted evidence. Use new output directories and a
scratch worker root for reproduction; do not overwrite frozen or earlier evidence.
Every guarded process has an exact command/cwd/revision/environment/limits record.

```sh
W=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker
R="$W/phase07f"
S=development/ian-cpp-phase1/phase07f
PY="$W/venv/bin/python"
"$PY" -B "$S/prepare.py" "$W" "$R/fixtures-v1" > "$R/prepare-v1.log" 2>&1
# First preflight at 6aef60c failed; no optimization had run.
"$PY" -B "$S/preflight.py" "$W" "$R/preflight-v1" > "$R/preflight-v1.log" 2>&1
# Corrected excerpt at 3b92db4 retains the post-retry outer event.
"$PY" -B "$S/preflight.py" "$W" "$R/preflight-v2" > "$R/preflight-v2.log" 2>&1
"$PY" -B "$S/run.py" "$W" "$R/ladder-v1" > "$R/ladder-v1.log" 2>&1
"$PY" -B "$S/analyze.py" "$R" "$R/analysis-v1" > "$R/analysis-v1.log" 2>&1
"$PY" -B "$S/difference.py" "$R/analysis-v1" "$R/terminal-difference.json"
# After final documentation/source commit and a clean worktree:
"$PY" -B "$S/finalize.py" "$R"
```

The R generator's exact command is in `fixtures-v1/generator-command.json`:
`/usr/local/bin/Rscript --vanilla quadforms.R REPOSITORY OUTPUT`, with full paths
in the record. It receives a one-thread environment. Preparation uses 6aef60c;
the successful preflight and all engine/validation/comparison executions use
3b92db4. Saved-data reconstruction uses e6549be, and the detailed coefficient
comparison uses 1fadde7. Later reporting changes do not modify executed code.
The engine/reference bytes are identical to the accepted Phase07E submission.

For an individual fresh replay with explicit paths:

```sh
F="$R/fixtures-v1/helix_1000.json"
"$W/phase07e/build-v1/ian_engine" "$F" NEW_NATIVE_OUTPUT --interval 100
"$PY" -B development/ian-cpp-phase1/phase07e/candidate/reference.py "$F" NEW_PYTHON_OUTPUT evaluated
"$PY" -B "$S/validate.py" NEW_NATIVE_OUTPUT "$F" NEW_CHECKS "$W/phase07e/build-v1/ian_checkpoint_tool"
"$PY" -B development/ian-cpp-phase1/phase07e/validate.py compare NEW_NATIVE_OUTPUT/trace.jsonl NEW_PYTHON_OUTPUT/trace.jsonl NEW_COMPARISON
```

The submitted native run exits with `retry_exhausted`; the Python run completes.
The first divergence and saved states remain under the comparison directory.
No engine run on the other six inputs occurred. The original failed preflight is
retained. This is a numerical compatibility study, not a speed comparison or R
package qualification. The factual handoff is outside the evidence bundle.
