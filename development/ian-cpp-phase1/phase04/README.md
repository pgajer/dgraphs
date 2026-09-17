# Adaptive-trajectory extension

Phase 04 preserves the accepted phase 03 directory and adds a reviewable native
copy, self-contained graph units, six frozen reference-search fixtures and a
bounded longer-trajectory comparison. See [PLAN.md](PLAN.md) for the fixed search
and its recorded continuation, and [REPORT.md](REPORT.md) for results. The strict
original-expression/evaluated-Python array comparisons fail on both selected
inputs; the evaluated-Python/native comparisons pass. These are distinct results.

## Source organization

- `input.hpp`: input validation and first-occurrence exact-duplicate mapping.
- `checkpoint.hpp`: file hashes and durable atomic JSON writes.
- `numeric.hpp`: unchanged arithmetic, graph, statistics and ordering functions.
- `solver.hpp`: unchanged fresh native Clarabel LP assembly/acceptance.
- `engine.hpp`: retuning, pruning loop and separate durable output stages.
- `stages.hpp`: targeted graph/statistics/affinity tests.
- `engine.cpp`: CLI entry and failure status handling.

The arithmetic/control-flow token comparison in `refactor_check.py` matches the
accepted implementation except the declared checkpoint metadata. Formatting uses
the committed `.clang-format`; the check normalizes adjacent C++ help literals.
`config.json` is byte-identical to phase 03. The Python references, comparator,
supervisor and failure driver are reused from earlier phase directories without
editing them. The phase 03 provenance and dependency limitations still apply.

`graph.json` now includes `scl`, `upper_units` and
`upper_to_input_distance`. Internal distance equals supplied input distance
times `scl`; multiply the saved upper bounds by `upper_to_input_distance` to
recover input units. A reader no longer needs the processed trace for this
conversion, including after a failure immediately following graph checkpointing.
These fields are metadata only. Isolate policy, dense affinities, threshold rules,
retuning and numerical limits are unchanged.

## Build and reproduce

Working directory:
`/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree`.
The existing private Python environment, native Clarabel library and JSON header
are reused. No dependency is installed or upgraded. This remains a macOS C++17
prototype using CommonCrypto/POSIX, not a portable package or R interface.

```sh
IAN_WORKER=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker
IAN_PHASE=development/ian-cpp-phase1/phase04
IAN_PY="$IAN_WORKER/venv/bin/python"
cmake -S "$IAN_PHASE" -B "$IAN_WORKER/phase04/build-reproduction" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
  -DCLARABEL_SOURCE="$IAN_WORKER/deps/Clarabel.cpp" \
  -DCLARABEL_LIBRARY="$IAN_WORKER/build-v2/rust-target/release/libclarabel_c.dylib" \
  -DJSON_INCLUDE="$IAN_WORKER/phase03/deps"
cmake --build "$IAN_WORKER/phase04/build-reproduction" -j 2
```

All driver output paths must be new; sources must be committed and the tree clean.
`fixtures.py OUTPUT` freezes all six inputs; `search.py FIXTURES OUTPUT` runs the
original-expression controls and freezes selection without consulting native
agreement. `regress.py OLD_EVIDENCE OUTPUT --native EXE` checks all four old native
fixtures, stage tests and operational failures. `selected.py SELECTION
REGRESSION_CHECKS OUTPUT --native EXE` stops at the first failed comparison.
`diagnose.py LEFT RIGHT COMPARISON OUTPUT` analyzes the retained difference
without solving. `continue_selected.py ROOT OUTPUT --native EXE` is the explicit
submission-specific continuation after the documented representation difference;
it reuses the existing Hellinger-256 Python traces and does not relabel failure
as success. Its fixed namespace assumptions are intentional, not a general
restart/resume facility.

`analyze.py ROOT OUTPUT` independently recomputes all saved primal/dual payloads,
topology histories and checkpoint contents, and regenerates tables without new
solves. The canonical submitted analysis is `worker/phase04/analysis-v2`.
`analysis-v1` remains preserved: its affinity column used maxima over all weighted
retuning attempts while labeled final affinity. Version 2 obtains final affinity
differences directly from the durable matrices; raw results and pass/fail outcomes
are unchanged. The final snapshot uses `finalize.py ROOT ANALYSIS LABEL`.
Exact executed commands and revisions are in the private `phase04/commands.md`.

The authored report, plan and sources are canonical. Input JSON, reference/native
traces, checks, tables and build outputs are generated evidence. The final
manifest covers them and the canonical source hashes; the later factual handoff
is outside that snapshot. Original failed checks and the stopped comparison
remain retained. No larger run is implied by successful script execution.
