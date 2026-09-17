# Phase 06A: reusable IAN core with unchanged numerical behavior

The IAN calculation now runs through a typed C++ library without requiring an
output directory or JSON files. The command-line adapter retains the accepted
traces and saved stages. Eight complete regression runs and all twelve fixed-state
probes reproduce the accepted native traces exactly apart from timing and pass
the unchanged evaluated-Python comparisons. A fresh solver/library build, an
external C++ consumer and a minimal R call also pass their declared comparisons.

Status: implementer-complete, submitted for independent audit. The user authorized
Phase06A. Independent acceptance is pending. Numerical policy remains
**IAN evaluated-LP 1.0**; no tolerance, solver setting, arithmetic ordering,
pruning rule, duplicate rule or isolate policy changed. Phase06B has not started.

## Purpose and implementation

The purpose was to separate the accepted algorithm from file handling and language
interfaces so later engineering can reuse one computational core. It was not an
algorithm improvement or a performance benchmark. The [frozen plan](PLAN.md)
prespecified the old complete examples, Phase05 decision-boundary cases, existing
failure checks, public-interface checks and small build/R feasibility work.

The installed public header defines typed input, specimen/profile/participant
mappings, graph state, scales, affinities, validity flags and structured errors.
Each synchronous call owns fresh execution state and returns its own buffers.
An optional observer receives diagnostic events and validated stages; the file
adapter handles trace writing, hashes and existing atomic stage files. The core
can run without an observer. The public header has only standard-library
dependencies; JSON and Clarabel are private implementation dependencies.

Private numerical routines and the solver adapter were mechanically extracted
from Phase04. The committed extraction check verifies their unchanged bodies
and the declared engine I/O substitutions. The core still uses private JSON
objects for parts of the inherited implementation and retains dense matrices and
copies. No zero-copy, memory reduction or timing improvement is claimed.

The [version-1 consumer contract](SCHEMAS.md) distinguishes adjacency, input-unit
metric edge lengths, internal and input-unit scales, affinity support, component
labels and identities. Optional participant IDs stay at specimen level; exact
profile duplicates can belong to different participants. In-memory validity is
explicitly different from successful durable output. The interface has no
checkpoint restoration or cancellation facility.

## Regression results

Each row is one new command-line run against saved accepted native and evaluated
Python evidence. Python optimizations and boundary calibration were not rerun.

| Complete input | Profiles | Solves | Pruning iterations | Removed edges | Result |
|---|---:|---:|---:|---:|---|
| Nonuniform curve | 64 | 2 | 0 | 0 | Exact native trace except timing; Python limits pass |
| Variable-density patch | 80 | 2 | 0 | 0 | Same |
| Nearby curved arms | 96 | 3 | 0 | 0 | Same |
| Small PreSSMat Hellinger subset | 64 | 9 | 4 | 4 | Same |
| Perturbed PreSSMat Hellinger subset | 256 | 195 | 182 | 238 | Same |
| Perturbed PreSSMat Hellinger subset | 300 | 189 | 176 | 228 | Same |
| Nonuniform helix | 120 | 31 | 15 | 39 | Same |
| Jittered saddle | 144 | 3 | 0 | 0 | Same |

These eight runs use 434 solves. All twelve Phase05 fixed-state cases use another
16 solves and reproduce their native trace and result values exactly, while
passing the frozen evaluated-Python limits. The six threshold/tie vectors agree
exactly. The earlier duplicate, float32 Gabriel, supplied disconnected graph,
pruning-order and affinity-cutoff tests pass, including their single LP solve.

The four existing controlled exceptions and pruning-cap regression retain their
accepted behavior. Invalid solver scales never drive a volume or pruning decision.
Earlier saved stages survive the later injected exceptions. These remain
controlled-exception tests, not evidence for crash recovery or resumability.

Original-expression historical array failures remain unchanged and documented in
the accepted Phase05 evidence. This extraction does not reclassify them as passes
or establish general historical equivalence.

## Public API, clean build and R feasibility

The clean build used a fresh Cargo home, 48 vendored crate packages, the existing
pinned lockfile, a copied Clarabel source tree, a new target directory and a
private installation prefix. It rebuilt Clarabel 0.11.1 with Rust 1.85.1; the
development solver binary was not reused. Compiler and SDK tools and the OS
account were shared on the same macOS ARM64 host. This is dependency isolation
and one-host feasibility, not another-machine or cross-platform qualification.

An external C++ program compiled using only the installed public header and CMake
target. It ran the public curve twice in one process, appended an exact duplicate
with a different participant identity, and verified unchanged geometry and
preserved identities. Input buffers were unchanged, returned values remained
owned after input mutation, and eight malformed/version/policy inputs were
refused before a solve. Event and stage callback exceptions returned explicit
failure states, retaining a valid in-memory graph when available.

The clean-build CLI, installed C++ consumer and R call each ran the public helix.
The fresh CLI trace matches the accepted native trace exactly apart from timing.
C++ and R returned exactly matching graph, mapping, scale and affinity values
after the documented R index conversion. The R bridge calls the library directly
through registered `.Call`, uses base R only, and is not an installed R package.
The test checks one-based R indices, unchanged degree counts, explicit buffer
copies, participant IDs, and invalid type/nonfinite/mapping inputs. Binary test
data preserve supplied doubles without introducing decimal-parser differences.

R was the installed development build, `2026-06-24 r90190`, on
`aarch64-apple-darwin23`, running macOS Tahoe 26.6.1. It is not a validated stable-R
release matrix. Neither dgraphs nor a shared R library was modified.

## Numerical and artifact evidence

There were **560 new solver calls**, below the prespecified 700-call bound:
460 in the regression workload and 100 in clean-build/interface checks. Of these,
**491 saved optimization payloads** are available for external reconstruction:
490 pass and one intentionally corrupted solver vector is rejected as intended.
The remaining **69 solver calls through observer-free C++/R executions** have output/invariant/error checks
but no saved primal/dual vectors. They are not represented as raw-payload
revalidation. Seven of these calls belong to the curve API checks, 31 to the
installed C++ helix and 31 to R.

Among valid saved payloads, maximum normalized primal violation is `1.24087e-8`,
dual stationarity residual `1.13142e-8`, relative primal-dual gap `9.95602e-10`,
and objective recomputation discrepancy `1.45490e-15`. Each is below the unchanged
external `1e-7` limit. Maximum absolute primal violation is `7.72338e-8`, reported
separately. All **33 saved stage artifacts** pass state/identity/hash checks;
affinities are reconstructed from saved distances and scales with matching
numerical support. The count includes available stages in the existing failure
regressions as well as successful runs.

The first clean build succeeded but exposed a harness logging defect: Cargo's
vendor destination overlapped the command-log folder and removed its open log
files. That build is retained as `clean-v1`; its vendoring stdout/stderr text is
unavailable. The corrected harness separates the folders, and `clean-v2` repeats
the clean build with preserved logs. No numerical execution used `clean-v1`.
There was no failed numerical comparison, policy change or optimization rerun to
replace a failed observation. [Build notes](BUILD-NOTES.md) record the correction.

Existing compiler/dependency warnings remain. Phase05's Python diagnostic-warning
evidence is preserved and the underlying cause remains an explicit follow-up.
The current work did not run new Python solves or suppress those warnings.

## Limits and next boundary

The tested inputs and platform remain bounded. Biological subsets overlap; some
examples do not prune; full trajectories do not cover initial isolates or a split
into multiple components containing edges. The R bridge is a feasibility adapter,
with no qualified interruption/allocation-failure behavior, package lifecycle,
stable ABI, cross-platform support or concurrent-call promise. Existing atomic
files and exception tests do not establish restart safety. Private JSON/value
copies and dense storage remain potential future profiling targets.

The consumer contract separates numerical engine artifacts from downstream
estimator acceptance. It does not resolve observed-response conditioning, assay
matching or scientific validation. No cohort expansion, production replacement,
public packaging, performance optimization or estimator work was performed.

After independent review, the proposed next milestone remains Phase06B: checkpoint
and restart behavior with its own frozen state/equivalence specification. It is
not part of this submission.

Evidence: [derived checks and census](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase06a/analysis-v1/results.json),
[derived table](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase06a/analysis-v1/tables.md),
[reproduction commands](README.md), and
[factual handoff](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase06a-implementer-handoff.md).
