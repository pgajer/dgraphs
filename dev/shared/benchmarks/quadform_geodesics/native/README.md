# C++-Accelerated Refinement and Parallel Studies

For the newer self-contained solver, which needs no Python and saves no state,
see [standalone/README.md](standalone/README.md). It has a separate R interface
and versioned C++ random streams. The historical backend and campaign runner
described below remain unchanged for reproducibility.

This development-only backend accelerates the existing Single-point and
Local-network refinement methods. It does not change the exported package API
or activate the frozen comparison registry. The original R implementations
remain available as reference implementations.

## What Is Native

`core.cpp` implements the exact binary coordinate keys, edge deduplication order,
complete local graph construction, deterministic shortest-path search,
compensated summation and quadratic-surface tangent-speed evaluation. Compiler
settings disable fast-math and floating-point contraction. `load.R` installs
these operations only in the native worker's private adapter and runtime.

The existing R integration driver, its tolerances and error estimates are kept.
PCG64 proposal and visit-order streams, initialization, scheduling, acceptance
rules, cache accounting and progress saving are also retained. This is a
C++-accelerated backend, not an all-C++ replacement for the R runtime. In
particular, full-state saving can still limit speed and memory use. The
independent R path checker is loaded in a separate process without native
search overrides.

## Compatibility Checks

`tests.R` checks exact binary keys including signed zero, edge ordering,
compensated sums, tangent speeds and numerical error estimates. Graph checks
cover ties, disconnected endpoints and interruption by the shared calculation
limit. Complete flat and saddle searches compare every published candidate,
final path, random-stream state and calculation count against R.

Saved steep-bowl runs can be replayed by adding a `reference_record` column to
the plan. For fixed-round and fixed-calculation runs, `r-cpp-comparison.csv`
requires exact agreement of initial and final candidates, all published paths,
random states, decision diagnostics and numerical calculation counters. Time
is excluded from that equality test. An agreement failure is evidence to
investigate, not permission to relax the numerical checks.

Ten-second searches are intentionally not required to return the same path:
a faster backend can complete more refinements. Concurrent native time-limited
results must not be pooled with serial R results. Backend, worker count and
timing conditions are recorded in the study manifest.

## Parallel Execution

One coordinator assigns each planned run to exactly one worker. Only that
coordinator writes the shared progress ledger; each job has its own directory.
Each job retains the existing separate search process, memory monitoring and
independent audit. At most the requested number of jobs are in flight, with
BLAS and OpenMP threads restricted to one per process.

Compilation is completed before workers launch. Set `QGC_BUILD_CACHE` to a
private directory and `RETICULATE_PYTHON` to a Python interpreter with NumPy.
Source copies, hashes, dependencies and compiler settings are retained. The
original source files are not modified by loading a native backend.

From the repository root, with the same R dependencies as the sensitivity study
plus Rcpp and a C++ compiler:

```sh
Rscript dev/shared/benchmarks/quadform_geodesics/native/tests.R
Rscript dev/shared/benchmarks/quadform_geodesics/native/run.R \
  /absolute/private/output 12 /absolute/private/plan.rds
```

The plan is the data frame produced by `qgx.plan()` or the saved original plan;
its optional `purpose` attribute describes the study. Use a new private output
directory. Append `resume` only for an exact existing manifest. A started job
without a completed record requires explicit review; there is no silent retry
of interrupted or failed attempts.

Creating `STOP_AFTER_CURRENT` in the output directory asks the coordinator to
stop launching jobs and finish the ones already active. It then writes a
partial summary and a `paused_between_runs` completion record. Remove that
request before explicitly resuming. A coordinator lock prevents duplicate
writers. An unclean shutdown leaves evidence that must be inspected rather
than overwritten.

`progress.json` and `runs.csv` show recorded and available counts. A process
exit alone is not a scientific success criterion. `summary.json` and the
per-run audits identify missing or failed results. At completion, `report.md`
explains the examples, methods, conditions, descriptive results, direction
comparisons and limitations. Exact agreement checks are separate from
performance measurements and from claims about geodesic optimality.

## Profiling

`profile.R` replays eight fixed-work steep-bowl searches selected from a completed
sensitivity study: both methods and all three neighborhood rules at 10,000
calculations, plus both distance-section methods at eight rounds. It uses repeat
50001 in the forward direction. Each workload has three ordinary timing runs,
one instrumented run, and one diagnostic run that constructs every state snapshot
but does not write the full state file. Published paths are still saved. Every
run must exactly match the saved paths, decisions, streams and numerical counters
and pass the independent R final-path integrator. No-state-file runs do not
provide normal recovery guarantees and must never replace production runs.

The eight instrumented runs collect nested stopwatch measurements and R CPU
profiles at 5 ms intervals. Exclusive times subtract measured child calls;
inclusive times must not be added together. Native-helper timings include the
R call boundary and lazy argument evaluation, not solely instructions executing
inside C++. Compare them with the prepared-input tests in `profile_micro.R`.
Profiling overhead and fresh-process startup vary, so use ordinary-run medians
for overall duration, not instrumented timings as a speed benchmark.

```sh
Rscript dev/shared/benchmarks/quadform_geodesics/native/profile_tests.R \
  /absolute/geosmooth/dev/shared/benchmarks/quadform_geodesics/native
Rscript dev/shared/benchmarks/quadform_geodesics/native/profile.R \
  /absolute/geosmooth/dev/shared/benchmarks/quadform_geodesics \
  /absolute/private/completed-study /absolute/private/new-profile
Rscript dev/shared/benchmarks/quadform_geodesics/native/profile_micro.R \
  /absolute/geosmooth/dev/shared/benchmarks/quadform_geodesics \
  /absolute/private/new-profile/isolated
Rscript dev/shared/benchmarks/quadform_geodesics/native/profile_state.R \
  /absolute/geosmooth/dev/shared/benchmarks/quadform_geodesics \
  /absolute/private/new-profile/state-storage \
  /absolute/private/new-profile/005/algorithm-state.rds
```

Use the same environment variables as the parallel runner. Run the complete
search, isolated-operation and state-storage measurements sequentially, not at
the same time. Output directories must be new and outside the checkout. The
complete-search diagnostic uses one worker, a sampled 2 GiB outer memory guard
and a 240-second process timeout; original search time/calculation limits remain
unchanged. It is not a rerun of the earlier concurrent timing campaign.

`profile_micro.R` compares existing R and C++ operations, measures cold and warm
random-stream creation, and tests scalar, cached-method and vector Python random
draws. Vector draws are diagnostic only: a production buffer would need to retain
unused values and exact generator position in checkpoints. `profile_state.R`
compares serialization to memory, normal atomic state-file saving and writing
already-prepared bytes. Those are warm OS-buffered writes, not physical-disk
throughput or forced-storage-sync measurements. No profiler changes solver code
or package exports.
