# Phase 05 reproduction and artifact map

Canonical sources are this directory, the unchanged phase03 Python reference and
comparator, and phase04 native headers/configuration. Generated inputs, executables,
traces, logs, comparisons and manifests live under `worker/phase05`. The original
IAN license is retained in the adjacent phase03/phase04 directories; the reference
probe extracts functions from that pinned executed source, without changing them.

Run from `/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree`.
The commands below describe the actual study, not instructions to overwrite its
evidence. Programs refuse existing output directories. For reproduction use new
output namespaces and preserve failed runs; comparison analysis currently names
`probes-v2`, `full-v1`, and `stages-v1` explicitly. The existing native engine and
pinned isolated dependencies are read-only inputs. No installation is needed.

```sh
W=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker
R="$W/phase05"
S=development/ian-cpp-phase1/phase05
PY="$W/venv/bin/python"
```

Source was clean and committed before numerical execution. Frozen plan/contract:
`e21c1f3`; fixture source: `6f8ec7b`; calibration/probe source and build:
`419e9b9`; initial comparison driver: `564e19c`; documented continuation:
`bbfc840`; complete-run driver: `352fe00`; no-solve analysis: `a7a00b5`.
The final manifest records full hashes and final submission revision.

Executed generation, calibration and build commands:

```sh
"$PY" -B "$S/fixtures.py" "$W/phase04" "$R/fixtures-v1" > "$R/setup/fixtures-v1.log" 2>&1
"$PY" -B "$S/launch.py" "$R/calibration-driver-v1" "$S/calibrate.py" "$R/fixtures-v1" "$R/calibration-v1"
cmake -S "$S" -B "$R/build-v1" -DCMAKE_BUILD_TYPE=Release -DCLARABEL_SOURCE="$W/deps/Clarabel.cpp" -DCLARABEL_LIBRARY="$W/build-v2/rust-target/release/libclarabel_c.dylib" -DJSON_INCLUDE="$W/phase03/deps" > "$R/setup/configure-v1.log" 2>&1
cmake --build "$R/build-v1" -j2 > "$R/setup/build-v1.log" 2>&1
```

Executed comparison commands, in order. The first probe driver exits 4 on the
historical scale discrepancy; its continuation reads and verifies earlier child
outputs and never reruns those solves. `continuation-1.json` records the diagnosis
and narrowly defined continuation class. Each parent `process.json` contains the
expanded command, working directory, source revision and resource diagnostics;
each child has its own process record and stdout/stderr logs.

```sh
"$PY" -B "$S/launch.py" "$R/stages-driver-v1" "$S/study.py" "$R" "$R/stages-v1" --mode stages
"$PY" -B "$S/launch.py" "$R/probes-driver-v1" "$S/study.py" "$R" "$R/probes-v1" --mode probes
"$PY" -B "$S/launch.py" "$R/probes-driver-v2" "$S/study.py" "$R" "$R/probes-v2" --mode probes --prior "$R/probes-v1/ledger.json" --ack "$S/continuation-1.json"
"$PY" -B "$S/launch.py" "$R/full-driver-v1" "$S/study.py" "$R" "$R/full-v1" --mode full --ack "$S/continuation-1.json"
"$PY" -B "$S/launch.py" "$R/analysis-driver-v1" "$S/analyze.py" "$R" "$R/analysis-v1"
```

The single-thread environment is applied by the unchanged phase02 supervisor.
Native fixed-state execution uses `build-v1/ian_probe`; complete execution reuses
the previously accepted `worker/phase04/build-v1/ian_engine`, verified against its
manifest. Python runs use the unchanged phase03 solver/algorithm observer. The
probe adds only entry points and diagnostic observation; it does not implement a
replacement algorithm. The single-solve native convergence predicate is a copied
diagnostic expression; the retuning cases invoke the actual accepted routine.

`fixtures-v1/manifest.json` records original-only state selection and frozen input
hashes. `calibration-v1/manifest.json` records every calibration trial and the twelve
frozen comparison inputs. `probes-v2/ledger.json` is the complete fixed-state
inventory, referencing six earlier child runs in `probes-v1` and thirty new child
runs. `full-v1/ledger.json` contains twelve complete runs. `stages-v1/ledger.json`
contains the no-solve stage comparisons. Comparison folders preserve all failing
fields and complete state before the first difference. `analysis-v1` recomputes
all 1,330 raw checks and the twelve sets of stage checkpoints; it is not a
summary-table-only validation.

Final preservation and manifest creation (no new optimization):

```sh
"$PY" -B "$S/finalize.py" "$R" v1
```

`final-checks-v1.json` records source/environment/evidence preservation checks.
`final-manifest-v1.json` hashes generated files and final canonical sources.
The factual handoff is written outside this root after the manifest so it can
state the final revision and manifest hash without a circular dependency.
The native source, reference probe, fixtures, calibration and launch programs
remain byte-identical to their execution revisions. Later changes concern driver
continuation/schema handling, analysis, documentation and evidence finalization.

No standalone package test, R check, full-cohort solve, new checkpoint-failure
experiment or portability build was run in Phase 05. The evidence and warnings
are described in [REPORT.md](REPORT.md).
