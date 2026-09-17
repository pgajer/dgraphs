# Phase 06B: frozen restart and recovery specification

Authorized by the user after Phase 06A F1 acceptance. Base candidate is
`e098461c803926bdbe7888f4f37c7a1607c0e948`; numerical policy remains
IAN evaluated-LP 1.0. This plan precedes implementation and executions.

## Boundaries and equivalence

Support restart immediately after a completed, validated pruning iteration
(including its edge removals) and after graph convergence, before weighted final
retuning. Persist every requested number of completed pruning iterations and
always at graph convergence or cooperative cancellation. No mid-solve or
mid-retuning restart: the bracket is local to a completed tune and is recomputed
by the unchanged next-tune rule. Save C, expression-cache mode, solve numbering,
last iteration, graph/bounds/degrees, last ratios, mappings, normalization and
input/configuration/numerical-policy/build identities. The implementation uses
fresh native solver instances as before; no hidden warm-start state is promised.

Resume in a new output directory. Concatenating the saved trace prefix at the
checkpoint with the resumed trace must reproduce uninterrupted event values
exactly except solve timing on this host; final typed outputs must match exactly.
Existing numerical residual checks remain unchanged. Initialization validation
may be recomputed, but accepted optimization solves preceding the boundary must
not be repeated. Reject unsupported integer or floating schema declarations,
incompatible policies/builds/configuration/inputs, corrupted/truncated payloads
and inconsistent state before new solves. Hashes detect accidental corruption;
no authenticity/security claim is made for a maliciously rewritten checkpoint.

## Durability and failure semantics

Use immutable numbered checkpoint envelopes in the run directory. Write a
same-directory temporary file, fully write and fsync it, rename to its committed
name, and fsync the directory. A committed checkpoint binds a payload digest and
trace-prefix identity. Temporary files are ignored during discovery; a corrupted
newest committed file is rejected without silent fallback. There is one writer
per new run directory. Loading never modifies the source run.

Distinguish complete, cancelled/partial resumable, failed with a prior checkpoint,
and failed without one. Progress records and resource observations are separate
from algorithm state and not authoritative restart data. Expose whether a save
was confirmed or failed after rename with uncertain durability. A discovered
valid file after process death may be resumed; this does not prove power-loss
survival. SIGINT/SIGTERM request cancellation at the next supported boundary.
Optional diagnostics run only after native results are durably saved and have
separate success/failure status.

## Prespecified bounded validation

Use no new cohort data, metric, numerical calibration or Python solver runs.
Maximum 1,000 new solver calls, serial under the existing one-thread supervisor.
Stop at an unexplained numerical discrepancy, preserving all failed attempts.

1. Repeat the eight accepted complete native examples and twelve fixed-state
   probes against frozen Phase 06A/05 traces and evaluated-Python references.
2. Resume from early, middle and graph boundaries on the public helix; resume
   a midpoint checkpoint on each 256/300-profile Hellinger example. Check
   concatenated traces, solve accounting, raw payloads and final results.
3. Use the small PreSSMat fixture for cooperative cancellation, actual SIGINT,
   repeated interruption/restart, and external SIGKILL around temporary writes,
   file fsync, rename and directory fsync. Test both absence and availability of
   an earlier confirmed checkpoint. Resume recovered committed snapshots.
4. Exercise deterministic I/O fault injection for open/write/fsync/rename/
   directory-fsync failures, retaining earlier files, and explicit incomplete
   temporary files. These simulate syscall failures, not a physical full disk.
5. Refuse malformed schema/type/range, input/configuration/policy/source/digest
   changes, truncated or internally inconsistent state. Use focused declared
   mutations with zero new solves. Include strict JSON-version cases from F1.
6. Complete a run whose optional diagnostic intentionally fails, retaining
   native complete results. Record elapsed phase time and process memory with
   explicit cumulative/nested conventions; this is not a performance claim.

Implementation sources, schema, scripts and factual report are committed before
associated runs. New evidence lives under worker/phase06b; old sources/evidence
and auditor worktrees stay unchanged. Full R/package/platform qualification is
not repeated. Completion, independent acceptance and advancement remain separate.
Phase 07, production use and cohort recovery are not authorized by this phase.
