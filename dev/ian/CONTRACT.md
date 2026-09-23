# Internal dgraphs IAN adapter contract — frozen before qualification

Authorized by user 2026-09-23, implemented by an agent originating in the IAN task
in isolated dgraphs branch codex/ian-internal-adapter-20260923. Existing main and
frozen IAN studies are read-only. This is author QA, not independent review.

Scope: optional installed module, unexported create.ian.graph, actual initial
Gabriel graph, completed final graph only on complete engine success, last valid
state, one-based mappings, metric lengths separate from full affinity matrix.
Accepted Phase06B evaluated-LP 1.0 arithmetic and criteria. No retries or policy
changes. Header repair, exhaustive settings layout probe and actual settings
capture address the pinned ABI problem. Build on macOS arm64 only.

Qualification budget: at most 30 native engine invocations, at most 600 total
solver attempts, at most 80 attempts per invocation, at most 96 specimens per
fixture, one macOS host. Each invocation records a result (including failed
injections) and every returned solve before the next invocation. Initial small
reference fixtures: Phase03/06A curve, 2-D patch, arms and 64-profile PreSSMat if
available; full outputs compared against preserved evaluated/native output with
original 1e-7 absolute + 1e-6 relative comparison bound, exact graph/mapping.
Additional calls may cover duplicates, supplied distance vs computed distances,
summary/full diagnostics equality, numerical refusal injection, solve budget and
user interruption at event boundary. No 500/1000-scale or new scientific studies.
Dependency builds and R validation errors do not optimize. All attempted solves
(including expected failures) count. Tests stop on unexplained differences.

Package QA: generated documentation with make document, make build, private
library installation, targeted installed-package tests and existing graph-object
regressions. Broader check only if practical; report exclusions explicitly.
Interruption is bounded to event checks after active solver completion, not an
ability to abort Rust interior-point iterations. Numerical failures return
structured incompleteness; they do not create a final graph from partial edges.

Pre-execution inventory amendment: historical patch/arms fixtures contain 80/96
specimens; ceiling raised from 64 to 96 before any qualification optimization.
No call/attempt budget change.
