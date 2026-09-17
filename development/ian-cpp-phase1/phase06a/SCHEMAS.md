# IAN core and scientific consumer contract, version 1

This document describes the typed C++ interface in `include/ian/core.hpp` and the
schema-1 CLI result adapter. Numerical policy remains **IAN evaluated-LP 1.0**.
Schema version and numerical-policy version are separate: changing a file format
does not authorize changing the algorithm. This prototype is a C++17 source/API
contract on the tested platform, not a stable cross-compiler binary ABI.

## Input and identity

`ian::Input` owns `features` and `distances` as vectors of row vectors of binary64
values, plus specimen identifiers. The synchronous `run` call borrows that input
read-only. Version defaults to 1 and policy to the declared reference; unsupported
values return explicit errors before any solve.

Distances must be square, finite, nonnegative, exactly symmetric with zero
diagonal. Feature rows must have a common length and finite values. Row counts
and identifier counts must agree; specimen identifiers are unique strings.
Exact feature duplicates collapse in first-occurrence order, and supplied
distances must agree with that collapse. At least two unique profiles are needed;
the existing refusal of nearly coincident distinct profiles and initial isolates
remains unchanged. The core does not choose or recompute the supplied metric.

Optional `participant_ids` is either empty or a nonempty string for each specimen.
Repeated participant IDs are allowed. Multiple participants can share an exact
feature profile. There is no invented one-participant-per-profile mapping.
Specimen-to-profile mapping and specimen-level participant IDs jointly represent
this relation; missing metadata is not inferred or silently imputed.

## Typed result

| Field | Meaning |
|---|---|
| `version`, `policy` | Result schema and numerical policy. |
| `mapping.representatives` | Zero-based original row of each unique profile, first occurrence. |
| `mapping.member_to_profile` | Zero-based profile for every original specimen. |
| `mapping.specimen_ids`, `profile_ids` | Original identifiers and representative identifiers in corresponding order. |
| `mapping.participant_ids` | Optional original specimen-level metadata, preserved without collapsing. |
| `graph.edges` | Sorted undirected pairs of profile indices, zero-based, smaller endpoint first. |
| `graph.edge_lengths` | Supplied metric distances for those edges, in input units. No affinity-to-length conversion. |
| `graph.degrees`, `components`, `isolates` | Native graph topology. Components are zero-based labels; isolates are profile indices. |
| `graph.internal_upper` | Final graph's upper scale bounds in internal distance units. |
| `graph.distance_multiplier` | Internal distance = input distance times this multiplier. |
| `scales`, `internal_scales` | Final weighted-retuning scales in input and internal units. |
| `affinity` | Dense numerical affinity matrix on unique profiles under the accepted cutoff policy. |
| `stats`, `weighted_stats` | Last graph-convergence ratios and final weighted ratios, respectively; available on complete success. |
| `multiplier` | Final retuning parameter C, distinct from distance-unit conversion. |
| `solves`, `last_iteration` | Solver call count and zero-based last visited pruning iteration. |
| `graph_valid`, `scales_valid`, `affinity_valid` | Which in-memory stages passed validation. These do not certify a file write. |
| `complete` | All core stages and callbacks finished successfully. |
| `error` | Error category, stable code where specified, and message. |

Each result owns its buffers independently of the input and subsequent calls.
Graph results are available before weighted affinity retuning; scales and affinity
follow. If a callback fails after a valid graph is produced, a failed result may
still contain that graph. Consumers must consult validity flags, not infer success
from a nonempty buffer. Default/invalid fields have no scientific interpretation.
For isolates, preserve raw solver scales as returned; their affinity rows and
columns are zero and those scales do not define an active neighborhood.

Affinities and graph adjacency are distinct objects. The numerical affinity uses
the preserved Gaussian calculation, then cutoff `1e-8`, with exact zero rows and
columns for isolates, unit diagonal for active vertices and symmetry. Zero denotes
the implemented numerical support, not proof of zero theoretical Gaussian weight.
This phase returns a dense matrix; no lazy kernel operator or connectivity repair
is implemented. Components are not silently bridged. No finite between-component
geodesic convention is supplied by this API.

`source_identity()` and `configuration_identity()` expose the built source and
configuration hashes for caller provenance. The caller is responsible for its
input identity and any surrounding scientific metadata. The CLI supplies input,
source and configuration hashes in its existing stage artifacts.

## Errors and observation

Error categories are `input`, `unsupported`, `numerical`, `observer`, `internal`
and `none`. Existing validation/solver/cap messages become codes, including
`input_shape_or_identity`, `invalid_distances_or_features`,
`duplicate_distance_inconsistency`, `fewer_than_two_unique_profiles`,
`nearly_identical_distinct_profiles`, `unsupported_initial_isolate`,
`invalid_solver_result`, `retuning_cap` and `pruning_iteration_cap`.
New interface codes are `unsupported_schema`, `unsupported_policy`,
`participant_shape_or_identity` and `observer_failure`.

No observer is required. When provided, it receives synchronous borrowed event
and stage references, which it must copy if it needs them after the callback.
Events carry a name, phase, iteration and optional-consumption JSON diagnostics.
Core consumers can ignore JSON entirely. Observer exceptions stop the run and
return partial in-memory state with an `observer` error. Resource exhaustion is
not guaranteed recoverable. Thread safety, reentrant callbacks, asynchronous
interruption and cancellation are not qualified. Independent successive calls
in one process are tested. Diagnostic fault injection and fixed-state entry
points are private testing interfaces, not installed consumer APIs.

## File and R adapters

The CLI accepts legacy `features`, `distances`, `ids` JSON and optional
`schema_version`, `numerical_policy`, `participant_ids`. It retains accepted
`trace.jsonl` fields and graph/scales/affinity stage files, including atomic writes
and status hashes. These legacy files retain their historical schema and mapping
fields; specimen-level participant metadata is carried by the new `result.json`.
The latter has schema/policy, mapping, graph, scales, affinity, statistics, validity
flags and structured error. Its graph adds input-unit edge lengths; JSON uses
zero-based indices. Legacy status records durable stage completion, distinct from
the new result's in-memory stage validity. File-adapter errors are reported as
adapter failures and can prevent a new result file from being written.

The feasibility R bridge copies double matrices into C++ row vectors and copies
results back into R-owned vectors/matrices. It converts edges, representative/
member indices, component labels and isolate indices to one-based values; degrees
are counts and remain unchanged. It preserves specimen/profile/participant strings,
input-unit scales/edge lengths, internal scales and both multipliers. It returns
structured core failures; malformed R argument types raise R errors. It uses
registered `.Call` entry points and no Rcpp or installed R package. It is a local
feasibility adapter, not the final R API. R allocation failure/interrupt behavior,
package lifecycle and other R builds remain unqualified. No zero-copy or reduced
memory claim is made; internal JSON/value copies also remain for later profiling.

## Scientific use boundary

EXP-038 and EXP-039 consumers must identify which graph, distances, scales and
affinity support they use, together with schema/policy/input/source identities.
Participant mappings do not by themselves specify assay matching, visits,
analysis populations, smoothing weights or independent validation. Acceptance of
these engine artifacts is separate from acceptance of a downstream estimator.
This interface does not resolve EXP-039's observed-response conditioning or
repeated-assay adjudication issues and does not promise biological validity.

No result is a resumable state in Phase06A. Periodic checkpoints, restart schema,
cancellation and interruption recovery belong to Phase06B.
