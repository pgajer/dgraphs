# Phase 06B: durable checkpoints and restart

The IAN engine can now stop at a completed pruning iteration or converged graph
and continue in a new process from saved state. On the bounded tests, resumed
execution preserves subsequent decisions, scale values and affinities exactly,
excluding elapsed solve time. Process termination and simulated storage failures
leave either a validated checkpoint that can be resumed or an explicit refusal;
incomplete files are not mistaken for completed saves.

Status: implementer-complete, submitted for independent audit. Phase 06A was
accepted after closure of F1. Phase 06B was authorized separately and remains
subject to its own acceptance. Phase 07 has not started. Numerical policy remains
**IAN evaluated-LP 1.0**.

## What was implemented and tested

The [frozen plan](PLAN.md) specifies the restart boundaries and comparison promise.
The implementation extends the accepted typed core with owned restart state and
an observer callback at accepted boundaries. State includes graph ordering,
degrees and upper bounds, multiplier, last ratios, normalization, iteration and
solve count, mappings, and the flag governing reuse of the constraint expression.
The local retuning bracket is not saved because each supported boundary occurs
after retuning has finished; the next bracket is constructed by the unchanged
rule. The solver already starts fresh for each optimization, so no warm-start or
factorization state is omitted.

The CLI writes a versioned snapshot through a temporary file, file fsync, rename
and directory fsync. It binds the input, compiled-source identity, configuration,
policy, payload checksum and trace prefix. Resumed runs use a new directory and
retain checkpoint lineage. Cancellation is cooperative, at supported boundaries.
Progress and resource records are separate from restart authority. Native results
are saved before optional diagnostics, which have separate failure status.

The [schema and lifecycle contract](SCHEMA.md) defines these details. Restart
requires the original input, trace prefix and referenced parent checkpoint to
remain available. This is a private run bundle, not a portable standalone file.
The source/configuration identities do not independently fingerprint every
compiler, loaded library or host property; all tests use the same pinned native
backend on the same host. Cross-build/runtime migration is not qualified.

The regression workload repeats the eight complete examples from Phase 06A:
the nonuniform curve, variable-density patch, nearby curved arms, small PreSSMat
Hellinger subset, perturbed 256- and 300-profile Hellinger subsets, nonuniform
helix and jittered saddle. It also retains all twelve fixed-state probes, six
decision-threshold/tie examples, earlier stage cases and controlled failures.
The larger examples exercise 182 and 176 pruning iterations. Comparisons use
saved accepted native and evaluated-Python evidence; no new Python solves or
calibration were performed.

## Results

Both the original and corrected regression workloads pass. All complete native
traces match the accepted reference except timing, and the unchanged evaluated-
Python comparison limits pass. The first workload revealed a resource problem,
described below; numerical agreement does not erase that problem.

The main recovery workload contains 73 executions and 19 full continuation
comparisons. It covers early, middle and graph restart points on the public
helix; middle checkpoints on each larger Hellinger example; and short PreSSMat
runs subjected to cancellation, repeated interruption and failures. Every tested
successful continuation matches the corresponding uninterrupted trace prefix
plus remaining events and the complete final typed result. The solver count
confirms that completed optimization work is not repeated. A separate three-run
check of nondefault save intervals adds another exact resumed continuation.

| Operational test | Outcome |
|---|---|
| Cooperative cancellation, repeated cancellation/resume, actual SIGINT | Saved boundary state resumes with exact continuation |
| Eight externally delivered SIGKILLs: four commit positions, with and without an earlier checkpoint | Correct committed-file availability; six recoveries match, two correctly refuse because no checkpoint exists |
| Six injected storage failures: open, partial write, file fsync, rename, directory fsync | Explicit failure; earlier confirmed state retained when available; post-rename uncertainty reported |
| Incomplete temporary file and corrupted newest committed file | Temporary file ignored; corrupted committed file refused without silent fallback |
| 31 declared checkpoint mutations and changed input | Rejected before new solves, including mutations whose payload checksum was recomputed |
| Six existing-output ownership cases | Existing files remain unchanged |
| Eighteen inherited CLI schema cases | Strict version validation remains correct; valid inputs preserve results |
| Nondefault save interval and forced cancellation save | Expected boundaries saved; resumed cadence and outputs preserved |
| Optional diagnostic exception and failure to save its status | Native completion and saved results remain intact |

Process-kill tests use an explicit stop/handshake at each selected commit point
and an external SIGKILL. These are actual process deaths, distinct from the
injected I/O exceptions. They do not simulate a power outage or arbitrary kernel
failure. An error after rename but before directory fsync is marked as uncertain;
a subsequent loader can use a visible, valid file without claiming it had been
confirmed durable before the interruption.

There are **1,318 new solver calls**: 460 in the original regression workload,
460 in its corrected repetition, 376 in recovery tests, four in valid CLI-schema
controls, and 18 in interval tests. All have saved numerical payloads. **1,316
pass** the unchanged checks; **two deliberately corrupted vectors are rejected**,
one in each inherited regression workload. These are not two unexpected solver
failures. Maximum normalized primal violation is `1.24087e-8`, dual stationarity
residual `1.13142e-8`, relative primal-dual gap `9.95602e-10` and objective
recomputation discrepancy `1.45490e-15`, all below the unchanged `1e-7` limits.
Maximum absolute primal violation is `7.72338e-8`, reported separately.

The final no-solve census reconstructs checkpoint graph state, solve counters,
multiplier and ratios from their trace boundaries, verifies prefix and payload
hashes, and checks saved-stage hashes. The complete checks and resource records
are in [analysis-v3/results.json](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase06b/analysis-v3/results.json).

## Resource correction and retained failures

The first checkpoint writer repeatedly read and copied the growing trace to
compute its prefix hash. Although all numerical comparisons passed, the two
larger native processes reached roughly 4.0 and 4.6 GiB peak RSS. This was an
unacceptable implementation cost for these small inputs. The writer now updates
a hash incrementally; the reader verifies prefixes using a 64 KiB buffer.

| Profiles in Hellinger example | Original peak RSS | Corrected peak RSS | Original elapsed time | Corrected elapsed time |
|---|---:|---:|---:|---:|
| 256 | 4,282,417,152 bytes | 37,486,592 bytes | 29.75 s | 3.94 s |
| 300 | 4,957,093,888 bytes | 50,642,944 bytes | 32.38 s | 4.74 s |

These are individual serial native-process observations on one host, with saves
at every pruning iteration. They establish the observed improvement after the
checkpoint implementation change, not a general C++ speed advantage or measured
per-allocation attribution. The Python verification process is separate and can
use much more memory while comparing full traces. Phase wall measurements label
initialization, pruning, final retuning, checkpoint I/O and output without adding
nested timings; RSS remains a cumulative process peak, not a per-phase peak.

[Amendment 1](AMENDMENT-1.md) records the change before further numerical runs and
raises the original 1,000-call allowance to 1,500, including the first 460 calls.
The final 1,318-call count is within that amended bound. The first build and
resource-heavy evidence remain intact. No numerical discrepancy was replaced by
a successful rerun.

Two harness issues also remain recorded. The first supplementary schema command
passed the build directory rather than the executable and stopped before any
solve; the first census then stopped because those results did not exist. The
corrected command and census use new namespaces. A periodic-test launch was
refused by the clean-tree gate while a finalization script was uncommitted; that
script was committed before the launch proceeded. None of these bookkeeping
failures changed runtime code or erased numerical evidence.

## Limits and next boundary

This is bounded single-platform restart evidence. It does not establish mid-solve
or mid-retuning recovery, survival of power loss, distributed or concurrent
writers, cross-build state migration, or restart from arbitrary modified state.
Trace-prefix lengths above the loader's signed 32-bit bound are unsupported.
Original input and trace/parent files must be retained; hashes are integrity
checks, not authentication against malicious rewriting. Storage-failure tests
inject syscall-equivalent failures; they do not fill or disconnect a physical disk.
SIGINT was exercised; the shared SIGTERM handler was not separately signaled.

No new R restart binding or package/platform qualification was attempted. The
native backend was reused from the accepted pinned clean build. Earlier
historical-expression array discrepancies, incomplete calibration, diagnostic
warnings, biological overlap and downstream-estimator limitations remain. No
cohort was recovered, enlarged or put into production, and no performance target
or scientific estimator was accepted by this phase.

After independent acceptance, Phase 07 remains the proposed bounded size and
generalization study. It requires its own run specification and authorization.
[Reproduction notes](README.md) and the
[factual handoff](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase06b-implementer-handoff.md)
identify the submitted source and preserved evidence.
