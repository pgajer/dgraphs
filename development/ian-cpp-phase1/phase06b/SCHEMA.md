# Checkpoint and restart contract, version 1

This is a bounded macOS ARM64 source-level prototype using IAN evaluated-LP 1.0.
It does not establish a stable ABI or power-loss-safe storage on arbitrary filesystems.

## Core interface

`RestartState` and `resume(Input, RestartState, Observer*)` extend the Phase06A
owned-result interface. `Observer::on_checkpoint` receives a borrowed state after
an accepted pruning iteration or converged graph. Copy it if retaining it.
Returning false requests cooperative cancellation and returns a partial Result
with `ErrorKind::cancelled`; throwing returns an observer failure. A pruning
snapshot is resumable computational state, not an accepted final native graph.
The old graph/scales/affinity validity flags retain their meaning.

Restart preserves edges in their original sorted order, degrees, upper bounds,
last ratios, multiplier C, distance normalization, iteration and cumulative
solver count, duplicate/specimen/participant mappings, and the expression-cache
flag. Every tune has finished; its local bracket does not survive into the next
tune even in uninterrupted execution. No native solver instance survives a solve
in this engine, so no factorization, warm start or hidden solver state is omitted.
Restoring a graph snapshot repeats only final weighted retuning, not pruning.

Input preprocessing and normalization are recomputed without trace emissions on
resume. Before any new solve the core validates schema, policy, build/configuration
and semantic input fingerprints, mappings, finite state, index/count ranges,
edge ordering/subset membership, recomputed degrees/bounds and the boundary's
stopping predicate. It then restores the state. This is not a replay proof of the
entire prior trajectory. Checksums detect accidental alteration and are not an
authentication mechanism against an adversary who can rewrite all fields/hashes.

## File format and retention

`checkpoints/checkpoint-NNNNNN.json` is an immutable checkpoint envelope. Both
`checkpoint_schema` and payload `version` require integer 1; omission, floats
(including 1.0), boolean/string/null and other versions are rejected. Other
integer state fields are range-checked before conversion. Hashes use SHA-256.

The envelope contains the typed payload and its canonical-JSON digest, the exact
input-file hash, the absolute trace path with byte/event counts and prefix hash,
and the originating checkpoint path/hash for runs started by resumption. The
payload contains the semantic input hash, compiled source identity, configuration
identity and numerical policy. JSON dumps round-trip binary64 values on the tested
platform; exact continuation comparisons test that property. File schema and
numerical policy are distinct compatibility conditions. Resume requires the same
compiled identity; cross-build migration is unsupported.

The supplied original input is required. The trace prefix and parent checkpoint
must remain available; this is a private run bundle, not a standalone portable
checkpoint. A future exporter could make a self-contained bundle. The loader
checks the direct parent hash; the validation harness follows full lineage when
comparing repeated resumes. No output is written to source bundles. The bounded
loader limits prefix lengths/counts to signed 32-bit integers and rejects larger
ones. Checkpoints do not authorize overwriting completed or partial run directories.

A commit writes an exclusive same-directory `.tmp`, writes all bytes, fsyncs the
file, closes it, renames it to its committed name, then fsyncs its directory.
The trace prefix is flushed and fsynced before the snapshot. Discovery considers
only committed numbered files; incomplete temporary files are ignored. It selects
the greatest committed name and rejects corruption there without fallback.
An explicit older checkpoint may be selected by its full path. Single-writer
ownership is required. Storage/integrity violations are explicit failures.

A failure after rename but before directory fsync has uncertain durability.
Progress retains the prior confirmed checkpoint and marks this uncertainty.
After process death the loader may recover a visible, valid renamed file. This
establishes observed process-death recovery, not survival of a power outage or
kernel/filesystem failure. Checkpoint copies and prefix hashing are intentionally
simple and may be expensive; no performance or memory improvement is claimed.

## CLI, progress and resources

`ian_engine input.json new-output [--resume checkpoint-or-checkpoints-directory]
[--interval positive-integer] [--cancel-after iteration]` writes ordinary accepted
stage files and results plus restart snapshots. The default interval is one
completed pruning iteration; graph convergence is always checkpointed. SIGINT
and SIGTERM set a cancellation flag checked at these boundaries, never inside a
solve. A request arriving during final weighted retuning may finish normally;
there is no mid-retuning safe point. Exit 0 means native completion, 3 cooperative
cancellation, 1 failure, 2 usage/output-directory refusal. Existing diagnostic
injection modes remain test-only.

`progress.json` distinguishes running, cancelled, failed and complete. It records
last confirmed checkpoint, resumability and commit uncertainty. A killed process
may leave stale progress; discovery of committed, validated checkpoints is the
restart authority. A malformed resumed state is not reported as resumable merely
because its envelope was parsed. Result/status files describe this execution;
solve numbering in results remains cumulative while this execution's trace holds
only new events. The prefix at the chosen checkpoint plus new events defines the
continuation; later events in a source trace are not part of that continuation.

Resource records separate input/checkpoint loading from wall time observed in
initialization, pruning, final retuning, checkpoint I/O and output. These phase
wall intervals are nonoverlapping labels in the file observer; callback overhead
is included. RSS is the process's cumulative peak at observation time, in Darwin
bytes, not independent per-phase peaks. External supervision separately records
process-tree measurements. These observations are not an attribution benchmark.

Optional diagnostics follow durable native result/status writes and have a
separate diagnostics result. The test-only failing diagnostic demonstrates that
its failure leaves native completion intact. No biological or connectivity-repair
diagnostic is implemented by this demonstration.
