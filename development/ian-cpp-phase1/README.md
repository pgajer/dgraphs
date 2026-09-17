# Bounded IAN LP replay

Prototype C++/Clarabel and Python/CVXPY fixed-LP comparison. No IAN fit is launched.
Read [PLAN.md](PLAN.md), [REPORT.md](REPORT.md) and [ARCHITECTURE.md](ARCHITECTURE.md).
All scientific input and output stays local. The historical paths are read-only.

## Reproduction environment

Commands below run from:
`/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree`.
Choose a **new** private output directory for each replay; existing bundles are
never overwritten. These variables are convenient names, not system settings:

```sh
IAN_WORKER=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker
IAN_SOURCE="$PWD/development/ian-cpp-phase1"
IAN_HISTORY=/Users/pgajer/current_projects/ZB/experiments/038-ian-community-graph-geometry/build/full-combined-hellinger-20260916-175755
```

The recorded environment uses a private Python 3.12 virtual environment. For a
fresh install, run `python3.12 -m venv "$IAN_WORKER/venv"` then
`"$IAN_WORKER/venv/bin/pip" install -r "$IAN_SOURCE/requirements-lock.txt"`.
The full lock pins all installed Python packages, including CVXPY's unused solver
dependencies. None of those alternative solvers is used in this benchmark.

For native dependencies clone `https://github.com/oxfordcontrol/Clarabel.cpp.git`
into `$IAN_WORKER/deps/Clarabel.cpp`, checkout
`0de6259a3edfd5cc041ec42b2148599ce63e73cb`, then run
`git submodule update --init --recursive` there. Its core is Clarabel.rs tag
`v0.11.1`. Copy `clarabel-wrapper.Cargo.lock` to the clone's `rust_wrapper/Cargo.lock`.
The clone is an isolated dependency checkout, not a project worktree.

The working macOS ARM64 build uses private Rust 1.85.1. The existing system Rust
was 1.73.0 for x86_64. Setup downloaded the official aarch64-apple-darwin
`rustup-init` from `https://static.rust-lang.org/rustup/dist/aarch64-apple-darwin/rustup-init`.
With `CARGO_HOME="$IAN_WORKER/cargo-native"` and `RUSTUP_HOME="$IAN_WORKER/rustup"`,
it ran `rustup-init -y --no-modify-path --profile minimal --default-toolchain 1.85.1`.
This does not edit shell startup files or replace the user's default Rust.

```sh
export CARGO_HOME="$IAN_WORKER/cargo-native"
export RUSTUP_HOME="$IAN_WORKER/rustup"
export PATH="$CARGO_HOME/bin:$PATH"
cmake -S "$IAN_SOURCE" -B "$IAN_WORKER/build-v2" \
  -DCLARABEL_SOURCE="$IAN_WORKER/deps/Clarabel.cpp" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=/usr/bin/clang++
cmake --build "$IAN_WORKER/build-v2" --target ian_lp_replay -j 2
```

CMake invokes `cargo build --release --locked` with a build-local target directory.
The official wrapper Cargo release profile uses opt-level 3, LTO and one codegen
unit. C++ uses the CMake Release flags; no fast-math flag is introduced. Rust core
requires at least 1.70.0 according to its manifest, but transitive dependencies
and optional build tools can require newer versions. The client requires a
64-bit little-endian host. Linux/Windows portability has not been exercised.

## Fixtures, checks and runs

Commit all prototype/harness source before measured runs. The driver refuses a
dirty working tree at launch. Export selects the six cases using trace fields;
no timings enter selection. Example reproduction uses new names below:

```sh
"$IAN_WORKER/venv/bin/python" "$IAN_SOURCE/export_cases.py" \
  "$IAN_HISTORY" "$IAN_WORKER/fixtures-reproduction"
"$IAN_WORKER/venv/bin/python" "$IAN_SOURCE/test_validation.py"
"$IAN_WORKER/build-v2/ian_lp_replay" \
  "$IAN_WORKER/fixtures-reproduction/control_initial/problem.bin" \
  "$IAN_WORKER/native-echo.bin" --echo
cmp "$IAN_WORKER/fixtures-reproduction/control_initial/problem.bin" "$IAN_WORKER/native-echo.bin"
"$IAN_WORKER/venv/bin/python" "$IAN_SOURCE/run_benchmark.py" \
  --fixtures "$IAN_WORKER/fixtures-reproduction" \
  --native "$IAN_WORKER/build-v2/ian_lp_replay" \
  --output "$IAN_WORKER/smoke-reproduction" --smoke
"$IAN_WORKER/venv/bin/python" "$IAN_SOURCE/run_benchmark.py" \
  --fixtures "$IAN_WORKER/fixtures-reproduction" \
  --native "$IAN_WORKER/build-v2/ian_lp_replay" \
  --output "$IAN_WORKER/measured-reproduction"
```

The measured command runs exactly 36 optimizations serially. Smoke runs two
solves of the first selected control only. Test controls require no optimizer.
Every invocation starts a new process and overwrites no prior bundle. No IAN or
cohort job, wall-time cutoff, retuning search or repair is invoked. Interrupted
benchmarks retain their raw directories and logs and must not be labeled complete.

`problem.bin` is little-endian: 8-byte `IANLP001`, three uint64 counts
(rows, columns, nonzeros), then CSR float64 values, uint64 column indices,
uint64 row pointers, float64 b, c and upper, and uint8 active flags. No implicit
bounds or objective multiplier are added. Original NPZ and saved trace event
remain beside it. Export verifies all arrays, the +I/-I rows, c=1, active/bounds,
historical residuals and round-trip equality. The native `--echo` mode parses and
rewrites every coefficient without solving. Its six-case results are in setup.
Python additionally asserts exact equality after CVXPY canonicalization.

Independent residual/objective validation runs in the parent after each child
exits. Both children save primal and dual vectors. The parent captures process
exit, wall time, system load, sampled tree RSS and root `wait4` RSS high-water
mark. Tree sampling may miss brief activity; root high-water memory is reported
separately. Raw timings retain startup, input, setup, solve call and output phases;
backend setup is included in the Python solve call and unavailable separately.

## Evidence regeneration

`provenance.py "$IAN_WORKER"` records primary source identities, upstream hash
checks, historical controller totals, native pins and toolchain. It writes
`setup/provenance.json`; preserve its previous version before an intentional
reproduction. `summarize.py` builds tables from a completed measured bundle;
its usage is `summarize.py FIXTURES MEASURED OUTPUT_DIRECTORY`. It validates
coverage and emits per-attempt, paired-comparison and per-case summaries. Report
prose and architecture are canonical Markdown; generated tables remain private.

The factual handoff identifies final source and all measured revisions. This
submission is implementer-validated and awaits independent review.
