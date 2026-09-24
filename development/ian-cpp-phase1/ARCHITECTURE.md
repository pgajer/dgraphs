# Proposed IAN core and staged development

This is a proposal, not a completed port or an independently accepted design.
The immediate objective is reproducible numerical behavior with inspectable
intermediate results. Computational efficiency supports the approved ZAPPS–PreSSMat
aims; it does not establish valid biological neighborhoods. The authoritative
[aims, version 1.0, approved 14 September 2026](/Users/pgajer/current_projects/ZB/docs/project_aims.md)
prioritize within-cohort organization and between-cohort comparison, with
conditional molecular profiles and residual covariance as a working direction.
Repeated visits require participant-aware analysis downstream. Attractive layouts,
CST concordance, successful optimization, and agreement on six LPs establish
neither biological validity nor early-pregnancy predictive performance.

## Reference-compatible behavior first

The reference is the pinned IAN 1.1.2 source at upstream revision
`06606ab27b52a1ea60daebae082a0e6752625521`, together with the frozen executed
adapter, not unmodified upstream alone. The adapter makes solver tolerances and
validation explicit, rejects caps, and masks adjacency-confirmed isolates in the
affinity calculation. A reference-compatible mode must identify both versions.
The [IAN paper, sections 3.4–3.5](https://arxiv.org/html/2208.09123v3)
provides the covering/LP and volume-pruning rationale. Executed code remains the
authority for precise arithmetic and stopping conventions in this comparison.

A future core should separate the following interfaces. Each returns typed data
and diagnostics; optional downstream work must not determine whether earlier
valid outputs survive.

| Module | Input and output contract | Compatibility and performance considerations |
|---|---|---|
| Input validation and duplicates | Nonnegative finite compositions or validated distances; unique profiles, stable specimen-to-profile map, metric/transform metadata, distance scale factor | Preserve exact duplicate definition, input order and expansion semantics. Reject near-zero distinct distances as the pinned code does. Hellinger is Euclidean distance between square-root proportions divided by sqrt(2). Do not collapse repeated participants merely because of dependence. |
| Distances and Gabriel initialization | Valid symmetric distance operator/matrix; sorted undirected edges and adjacency | Reference exact mode rescales minimum off-diagonal distance to one, then casts squared distances to float32. Preserve epsilon, arithmetic and ties. Blocked distance storage may save memory, but approximate neighbor search is a separate method variant. |
| Sparse LP assembly | Graph, current furthest-neighbor bounds, C and retained constraint bookkeeping; immutable CSR/CSC A,b,c plus active mask | Two rows per native edge, then +I and -I. Keep all variables including isolates in compatible mode. Backend boundary receives fixed LP with no hidden normalization or tolerance changes. |
| Optimization backend | LP and complete settings; raw primal/dual vectors, status, telemetry | Validate outside solver. QDLDL factorization is already compiled Rust. Alternative backends implement the same contract; they do not choose pruning or retuning policies. |
| Retuning | LP assembler, graph, bounds and volume evaluator; solved C, scales, ratios, current bracket and stop reason | C is an outer parameter, not an LP variable. Preserve separate initial, post-pruning and final-affinity phases, bisection arithmetic, boundary predicates and cap rejection. |
| Volume statistics and pruning | Scales, distances, degrees, graph and policy; ratios, thresholds, selected vertices and exact removed edges | Preserve degree correction, percentile method, ordering, candidate override and per-iteration cap. Snapshot graph state after each accepted iteration. |
| Native graph outputs | Accepted graph plus mapping and scale records; graph, component labels, isolate information and native distances | Native components are substantive output. Return infinite intercomponent graph distances, with component/isolate flags. Do not invent finite geodesics. |
| Affinity and kernel application | Accepted final retuning state plus distances and truncation policy; sparse affinity and/or apply(v) | Distinguish native adjacency from affinities. Expose numerical support and truncation metadata. A blocked kernel application avoids storing a dense matrix but is not automatically bitwise equivalent. |
| Checkpointing and optional diagnostics | Immutable accepted state and explicit diagnostic requests; versioned bundles with independent completion fields | Atomic write, manifest/hash, then publish accepted stage. Repair, embeddings, all-pairs paths and precision diagnostics run afterward in separate outputs/processes if appropriate. |

## Decision details that cannot be silently improved

**Gabriel graph.** The compiled Cython routine traverses pairs and potential
blocking points in index order. It removes a candidate edge if any third point
satisfies the squared-distance sum test against the edge squared distance plus
`10 * float32 epsilon`. Stored squared distances are float32 even though some
local temporaries are double. A future port must test intermediate rounding and
boundary cases against compiled reference behavior, not merely copy a formula
into all-double arithmetic. The exact routine is already compiled; translating
Python orchestration does not remove its worst-case cubic number of tests.

**Local scales and units.** The current upper bound is the distance to the
furthest remaining neighbor. After pruning, isolated vertices receive upper
bound zero. Raw slightly signed isolate values are retained as numerical
output; active scales must remain strictly positive and may not be clipped.
The adapter confirms isolates from graph degrees, excludes them from kernel
division and zeroes their affinity rows/columns. This differs from upstream's
near-zero heuristic and is part of the executed reference contract. Initial
isolates are an unresolved upstream edge case: its initialization uses empty
arrays filled by encountered adjacency rows. The proposed core should reject
unsupported initial-isolate input or specify a separately tested correction,
not silently claim equivalent behavior there.

**Thresholds and ordering.** The C3 location is `0.333*(q1+median+q3)` and its
dispersion uses the finite-sample normal-quantile expression in `getMuStdev`.
Preserve those constants, percentile interpolation and treatment of positive
ratios. The threshold starts at `max(2.75, location + 4.5*dispersion)`. The cap
`5 - median_residual` replaces it only if all ratios are already at or below
the first threshold and the cap is smaller. It is not an unconditional clamp.
Preserve the additional median-based candidate override. The ordinary candidate
sort is stable descending statistic, starting from ascending vertex indices;
the override uses NumPy's default argsort and reverse. Equal-statistic behavior
in that override needs version-specific fixtures before a deterministic C++
ordering can be called compatible. Furthest neighbors are sorted descending by
(distance, neighbor index), hence larger index wins an equal-distance tie.
Pruning retains the one-edge-per-node rule and `max(1,int(.1*candidate_count))`
limit. A new tie rule or parallel deletion order is a named variant.

**Retuning boundaries.** The main routine fixes median tolerance at 0.1. Initial
bounds are `min(C,0.5)` and `max(C,1)`; they move during bisection. Stop when
`abs(median-1)<=0.1`, or when the sign of its deviation permits stopping near
the appropriate current bound using `np.isclose` (`rtol=1e-5, atol=1e-8`).
Twenty updates are rejected by the adapter even if a superficially plausible
scale vector is present. Persist the last solved C separately from a proposed
next C. Preserve the distinct last affinity retuning, including its volume
calculation, before marking affinity output complete.

**Kernel meaning.** For active vertices the theoretical multiscale Gaussian has
entries `exp(-d_ij^2/(sig2scl*s_i*s_j))`; finite positive scales generally give
nonzero affinities for every pair. The executed numerical representation omits
entries below `tol=1e-8` and suppresses exponentiation past a dtype-dependent
cutoff `-log(2*epsilon)`. It takes a maximum with its transpose, not an average.
The main routine uses `sig2scl=1`; do not adopt helper default values accidentally.
Pruning-phase volume statistics use a single scale squared for each row;
final-affinity statistics use the multiscale matrix instead. Isolate masking is
explicit. Sparse kernel zeros and missing native graph edges have different
meanings. Record cutoff, dtype, symmetrization, self-weight and isolate policy
with every kernel artifact. A more aggressive truncation changes the method.

## Checkpoints and memory

The failed historical run did return from IAN, but diagnostics preceded final
file export. The repair function forms all upper-triangle indices and then sorts
Python tuples of distance and endpoints. With 4,841 profiles there are 11,715,220
unordered pairs. That code structure plausibly explains its memory demand;
there is no per-allocation measurement proving attribution. Do not recover or
modify that run as part of this proposal.

Persist the converged native graph immediately, then final scales/retuning and
affinity when each stage is validated. A manifest must distinguish graph
convergence, affinity completion, optional diagnostic completion and overall
process failure. A repair failure must leave valid native artifacts available.
Repair should be explicit, labeled as a separate graph with added edges and
original components. If later authorized, compare a streaming/component-aware
minimum-edge approach or external sorting under a memory budget against exact
reference repair, including equal-distance ordering. Changing repair must not
alter the native graph. All-pairs shortest paths still require quadratic output
if fully materialized; use component-wise or queried distances where the
consumer's contract permits. Do not replace disconnected values with a large
finite constant.

## Reuse, packaging and sequence benchmarks

The reusable core should depend on contiguous numeric buffers, sparse matrices
and explicit policies; R objects belong in a thin optional Rcpp boundary.
Return graph edges, scales in original metric units, duplicate mappings,
components, raw numerical diagnostics and checkpoint identifiers. Avoid retaining
R pointers in Rust or asynchronous work. For long calls, cancellation must occur
at documented safe boundaries and preserve completed checkpoints. An eventual
kernel operator should document ownership, index base, sparse zero meaning and
thread safety; conversion to R's sparse matrix representation should be measured.

[Clarabel's official native guide](https://clarabel.org/stable/user_guide_c_cpp/)
points to a C/C++ wrapper over Rust. The present C++ executable uses its shipped
C ABI directly; the Eigen convenience wrapper is unnecessary here. This is not
a dependency-free C++ solver. The installed native Rust was initially Intel-only;
a private ARM64 toolchain was needed. The stock build also attempted to install
an unpinned header generator that the old toolchain could not compile. Our final
build compiles the official Rust wrapper with a pinned Cargo lockfile and uses
the shipped C headers, avoiding header regeneration. Cross-platform binaries,
R package installation, Windows toolchains and Linux installation remain untested.

The IAN code is BSD-3-Clause, the Clarabel wrapper/core are Apache-2.0, and this
checkout declares dgraphs MIT. Those declarations do not remove dependency
attribution, redistribution and transitive-license obligations. A distributable
package needs a complete license inventory and native build strategy; this phase
does not certify legal or CRAN compliance. No upstream IAN source is vendored in
the prototype. Keep the core/backend prototype separate for now. A companion
package would contain the Rust toolchain/binary burden and permit optional
integration into dgraphs; direct integration should wait for portability,
maintenance and correctness evidence, not just one speed measurement.

[Official data-update documentation](https://clarabel.org/stable/user_guide_data_updating/)
requires unchanged dimensions and sparsity for updates and restricts preprocessing.
The pinned 0.11.1 implementation more precisely checks whether presolve, chordal
processing or sparse-zero removal changed structure. Pruning removes rows and
changes sparsity; retuning changes coefficients with potentially unchanged
structure. These are different reuse opportunities. Its solve implementation
calls `default_start()` each time; the inspected API supplies no useful arbitrary
primal/dual warm-start interface for this workload. Data update is not evidence
of a warm start or reusable numeric factors. No sequence performance was measured.
An LP-specific solver with basis reoptimization is a sensible next *bounded*
comparison, not an established improvement.

## Staged milestones

1. Review this fixed-LP replay, provenance, numerical checks and portability
   limitations. An accepted LP replay is a prerequisite, not full IAN equivalence.
2. Implement input/duplicate and distance/Gabriel contracts with exact ordering,
   float32-boundary fixtures and disconnected/degenerate cases. Compare graph
   edges and preprocessing units against the executed reference.
3. Implement assembly, retuning, ratios and pruning on small controls. Compare
   every iteration's matrices, brackets, thresholds, deletions and numerical
   diagnostics. Report alternate optima and divergent pruning rather than hiding
   them behind matching objective values.
4. Implement stage checkpoints and final affinity/kernel application. Inject
   diagnostic/export interruptions; demonstrate preserved accepted artifacts,
   truthful completion fields and disconnected distance semantics.
5. Benchmark short recorded sequences for assembly/reuse and an LP-specific
   backend, then test installation on ARM64 macOS, Linux and Windows. Measure
   representative scale only after correctness and resource gates are established.
6. Design R/Rcpp packaging and integration from those results. Scientific method
   variants—different pruning, approximate initialization, altered truncation or
   graph-conditioned estimators—require separate names, evaluation plans and
   biological justification. Cohort fits and outcome models require later scope.
