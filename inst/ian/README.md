# IAN graphs: setup, results and supported behavior

`dgraphs::create.ian.graph()` returns the actual
initial Gabriel graph, completed final graph, last valid graph, profile/specimen
mapping, local scales, affinity matrix and numerical diagnostics. Graph edge
lengths retain input distance units. Affinities are separate similarities; they
are not substituted for metric edge lengths. Final graph is NULL after any
refusal or interruption, even if graph pruning had converged before later failure.

This package installs the wrapper and pinned backend sources in `backend-sources.zip`,
with per-file identities in `backend-source-manifest.json`. The build helper verifies
and expands them into the fresh build directory. The editable source tree remains
under `inst/ian/backend` in the repository. To inspect an installed copy without
building, extract the ZIP with `python3 -m zipfile -e <archive> <new-directory>`. The native IAN
module is optional and is NOT built during ordinary package installation. Without
it the function gives an explicit unavailable-backend error. Other graph methods
do not depend on this module. Building currently requires macOS arm64, Python 3,
R/Rcpp, Apple's C++ compiler/SDK, Cargo and Rust >=1.77. Cargo uses the checked-in
lockfile; an initial build needs its crates cached or network access. No external
executables are launched by the R graph function.

After installing dgraphs, build the optional module explicitly in a new directory:

```r
library(dgraphs)
backend <- build.ian.backend("ian-build")
X <- rbind(c(0, 0), c(1, 0), c(2, 0), c(0, 0))
fit <- create.ian.graph(X, backend = backend)
stopifnot(fit$complete)
```

Save the returned path and reuse it for later calls. Existing build directories
are refused; no shared package library is changed. If the default Rust toolchain
targets Intel Mac, pass `cargo` and `rustc` paths from the same native arm64
toolchain. `offline=TRUE` requires cached dependencies. The helper uses the calling
R installation and verifies that R/Rscript agree. Rebuild for a different R
runtime or changed backend source. Logs and source identities remain in the build
directory, including failed command records.

The installed Python command-line helper remains available through
`system.file("ian", "build_backend.py", package="dgraphs")`. It accepts
`--build-dir`, optional `--install-dir`, and explicit tool paths. The public R setup
command returns a path for `backend=` and does not use install-dir. The module
has no dependency on the implementer's private workspace at runtime. Current
qualification is bounded to macOS arm64; other platforms and CRAN release are
not established by this interface.

Supply X (specimens in rows), optionally exact unsquared distances, unique IDs and
participant IDs. X defines exact duplicate profiles; distances alone cannot do so.
Absent distances use R's Euclidean `dist`, which can round differently from older
Python distance generation. Supplied graphs are rejected. The adapter permits
at least two specimen rows; there is no fixed experimental row cap or claim of all-input numerical
success. Dense distances and affinities require quadratic memory; the initial
Gabriel construction is cubic in profile count. Summary diagnostics omit dense
per-solve matrices and vectors; full traces are opt-in and may be large. Full
traces retain original zero-based core indices (declared in diagnostics); graph
and mapping objects use one-based R indices.

The `numerical.policy` argument accepts exactly two strings:

- `"IAN evaluated-LP 1.0"` is the explicit strict baseline: no retries,
  and the preserved baseline arithmetic.
- `"IAN evaluated-LP retry-power 0.1"` is the public default. It
  squares constraint quantities using the system power function. After an
  otherwise eligible rejected `Solved` or `AlmostSolved` return, it permits one
  fresh solve in normalized variable units with solver tolerances of `1e-11`
  instead of the ordinary `1e-9`. That retry must return `Solved` and pass all
  unchanged original-unit certificate limits of `1e-7`. A rejected original
  return is never accepted directly. Both attempts and their actual settings
  remain in diagnostics. No second retry or secondary scale objective is used.

The public default adopts the already-qualified retry-power policy and connected
pruning. To select the previous strict/reference behavior, explicitly use
`numerical.policy="IAN evaluated-LP 1.0", preserve.connectivity=FALSE`. These
choices preserve their existing numerical implementations. Neither policy
promises success for every input or identical arithmetic across platforms.

Both policies use pinned Clarabel 0.11.1, QDLDL, one thread and fresh solver state.  The missing `input_sparse_dropzeros` C header field is repaired against
this pinned Rust FFI; runtime size, alignment and every field offset are checked
before solving. Its value is explicitly false as declared in the accepted policy.
All actual settings are captured in each solve's diagnostic record. This fix
qualifies this pinned configuration only, not arbitrary Clarabel feature builds.

A numeric refusal returns `complete=FALSE`, `final_graph=NULL`, an error and any
available initial/last-valid graph. R interrupts are checked at engine events via
R_ToplevelExec, allowing C++ to unwind; an active solver call is allowed to return
before interruption is handled. This is not mid-solve cancellation. No durable
checkpoint or resume interface is exposed by this R interface. `max.solves`
stops execution after its last allowed solve and retains that attempt's record.
R allocation failure and operating-system termination are not recoverable promises.

Source provenance and licenses are in the source archive (and the repository backend/ tree). Ordinary package tests perform
argument checks without solving. Qualification with a built module is separate
under dev/ian and writes attempt accounting outside the source tree.

Internal messages now use typed C++ input, decision, solve, settings, event and
stage structures. The R bridge constructs diagnostic lists directly, without
JSON parsing. Optional file/test serializers preserve the historical JSON schema.
Canonical input fingerprinting still uses the previous JSON encoding at a separate
persistence boundary, so its format is unchanged. The C++ observer interface has
changed: Event now carries an EventPayload variant instead of a JSON string.

## Connectivity-preserving default

The default `preserve.connectivity=TRUE` selects `IAN bridge-protected 0.1`:

```r
fit <- dgraphs::create.ian.graph(
    X, distances = D,
    numerical.policy = "IAN evaluated-LP retry-power 0.1",
    preserve.connectivity = TRUE)
fit$initial_graph
fit$final_graph
fit$diagnostics$connectivity$protected.edges
fit$diagnostics$connectivity$history
fit$diagnostics$connectivity$stop.reason
```

Explicit `FALSE` retains reference pruning. Rebuild the optional backend for
this interface; old modules are rejected with an explicit rebuild message. The
new module retains the previous eight-argument native entry point for old callers.
The public defaults select the existing connected and retry-power policies.

For each potential longest-incident-edge proposal in statistical order, the
variant first skips a cached bridge or checks endpoint reachability with that
edge omitted. Only a nonbridge proceeds to the pruning-eligibility test. Bridge
status is permanent while only edges are deleted; nonbridge status is checked
again after earlier deletions. Global threshold and ranking context still use
the whole graph. Skips do not consume the actual-deletion allowance; later
proposals are considered. A vertex already used by an earlier deletion in the
batch is excluded before forming another proposal, as in reference pruning. For
each actual proposal, the opposite-endpoint exclusion follows the bridge and
pruning-eligibility tests. No shorter edge is substituted for a protected one.
A full pass with no removal terminates, with `no_connectivity_preserving_removal`
if statistical candidates remain, or `no_pruning_candidates` otherwise.

`protected.edges` records encountered bridges (one-based profile indices/IDs),
first/last encounter iteration, count and first statistic/threshold/margin. This
is not a claim that every protected edge met the pruning conditions, which are
not tested for skipped bridges. `history` records per-pass checks, skips,
condition rejections, endpoint conflicts and actual deletions. Summary iterations
are one-based; full trace `pruning_attempt` events retain the declared zero-based
core indices and state whether conditions were tested. These diagnostics remain
available on refusal. The list need not contain every bridge in the graph.

An initially disconnected graph is refused before solving. Protected edges remain
in scale and affinity calculations; all unique-profile vertices are retained.
A numerical refusal still returns no final graph. Native checkpoints bind the
variant and bridge cache; R checkpoint/resume is still not exposed. Connected
output does not establish that every connecting edge is biologically useful.

## Input size and resource use

The former 500-specimen rejection is removed. Matrix dimensions must be
representable by R and the native index types; these are technical bounds, not a
recommended size or tested capacity. Resources can be exhausted well below them.
The wrapper checks these dimensions before making distances, and the native
bridge checks dimensions and exact integer conversion at its interface.

One dense n-by-n double matrix uses `8*n*n` bytes excluding overhead: 8 MB at
1,000 rows, 200 MB at 5,000 and 800 MB at 10,000 (decimal units). Distances,
squared distances, affinities and conversion copies can coexist. These numbers
are individual array sizes, not peak memory estimates. Initial Gabriel-graph
construction has cubic worst-case work; actual time also depends on geometry,
pruning and solving. Full diagnostics retain extra dense objects; summary remains
the default. The specimen-level distance matrix is allocated before duplicate
profiles are collapsed, so original row count matters for memory.

Removing the cap does not certify every larger input. IAN-EXP-034 records
author qualification on all seven frozen 1,000-profile geometries in reference
and connected modes, and two 2,000-profile examples in connected mode with
summary R diagnostics, on Mac arm64 R-devel. Native/R outputs match exactly.
Independent review is recorded in that experiment’s audit summary. A proposed
5,000-profile pair was not executed because the preceding full-diagnostic native
runs exceeded its prospective memory gate. Rebuild the optional module: the
updated wrapper requires the checked-size entry point and rejects older modules. Numerical policy, pruning defaults,
solve budget and interrupt behavior are unchanged. Interrupts are checked at
engine events and do not preempt a running solver or every initialization loop.
