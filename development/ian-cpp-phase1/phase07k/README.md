# Reproduce the bounded helix arithmetic study

The scientific report is [IAN-EXP-026](../../ian-cpp/experiments/026-helix-arithmetic/report.md).
The prospective [plan](PLAN.md) defines the 14-run schedule and limits. Preparation
and execution were committed at `96f887125693d091f7b76a9702690d2772d45a03`.
Subsequent commits add read-only validation, synthetic guard tests and reporting.

Run from this implementation worktree, with a clean Git status, using the pinned
numerical environment:

```sh
PY=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/venv/bin/python
STUDY=/absolute/path/to/a/new-study-directory
$PY -B development/ian-cpp-phase1/phase07k/prepare.py "$STUDY"
$PY -B development/ian-cpp-phase1/phase07k/arithmetic.py "$STUDY"
$PY -B development/ian-cpp-phase1/phase07k/execute.py "$STUDY"
$PY -B development/ian-cpp-phase1/phase07k/analyze.py "$STUDY"
$PY -B development/ian-cpp-phase1/phase07k/supplement.py "$STUDY"
$PY -B development/ian-cpp-phase1/phase07k/test_guard.py "$STUDY"
$PY -B development/ian-cpp-phase1/phase07k/finalize.py "$STUDY"
```

Only `execute.py` invokes numerical solvers. Preparation copies the preserved
Phase07E source into private candidates, applies three square-operation changes
and a read-only check of the pinned backend's trailing settings byte, records all
file hashes, and builds with the preserved native Clarabel library. It also changes
the Python constraint-construction squares to explicit multiply or system power.
It never edits the historical source or current typed-core/adapter candidates.

The manifest contains compiler commands and generated source identities. Each run
records its command, environment, process samples, trace, status and available
durable outputs. Complete runs save graphs, scales and affinities. Refused runs
retain their traces and incomplete status. The supervisor checks process exit
before enforcing limits, and always writes accounting in finalization; synthetic
controls include the last permitted event, excess events and signal/exit races.

`arithmetic.py` reconstructs every saved native/Python constraint, using scalar
binary64 arithmetic and exact fractions to identify correct rounding of the
triggering square. It also verifies the previously audited histories across both
interfaces and both repeats. `analyze.py` reuses the established Phase07E scalar,
retry-sequencing, graph, kernel and trace checks, plus exact coefficient/vector
comparison. It distinguishes a passed bounded power experiment from the preserved
negative controls. `supplement.py` records matching-policy small controls after
the initial fixture links selected older traces without retry metadata.

The report figure is reconstructed from its maintained `figure-data.json`, whose
source hashes bind the private numerical summaries. Run its `build_figure.py`
using the ReportLab Python runtime, then the catalogue's standard full build/check
commands. Rendering makes no solver calls. Figure/data hashes and the private
evidence manifest support review; neither is an independent audit.
