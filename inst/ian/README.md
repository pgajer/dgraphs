# Internal IAN adapter (bounded local qualification)

`dgraphs:::create.ian.graph()` is deliberately unexported. It returns the actual
initial Gabriel graph, completed final graph, last valid graph, profile/specimen
mapping, local scales, affinity matrix and numerical diagnostics. Graph edge
lengths retain input distance units. Affinities are separate similarities; they
are not substituted for metric edge lengths. Final graph is NULL after any
refusal or interruption, even if graph pruning had converged before later failure.

This package installs the wrapper and pinned backend sources. The native IAN
module is optional and is NOT built during ordinary package installation. Without
it the function gives an explicit unavailable-backend error. Other graph methods
do not depend on this module. Building currently requires macOS arm64, Python 3,
R/Rcpp, Apple's C++ compiler/SDK, Cargo and Rust >=1.77. Cargo uses the checked-in
lockfile; an initial build needs its crates cached or network access. No external
executables are launched by the R graph function.

After installing dgraphs into a writable private library, locate the helper:

```r
system.file("ian", "build_backend.py", package = "dgraphs")
system.file("ian", package = "dgraphs")
```

Run `python3 <helper> --build-dir <fresh-directory> --install-dir <ian-directory>/native`.
Alternatively omit install-dir and pass `backend="<build-directory>/dgraphs_ian.so"`
to the R function. Build outputs and a command/source identity ledger stay in the
fresh build directory. The helper checks the Rust host architecture before building;
if the default toolchain targets Intel Mac, select `--rustc /path/to/arm64/rustc`
and `--cargo /path/to/arm64/cargo` from the same native arm64 toolchain.
The statically linked module has no worker-directory
runtime dependency. The strict typed baseline has independent bounded qualification on macOS arm64;
the explicit retry-power option has independent integration and frozen scale-panel acceptance on the tested Mac. Neither claim establishes broader portability or CRAN acceptance. Public export and unrestricted larger sizes remain gated.

Supply X (specimens in rows), optionally exact unsquared distances, unique IDs and
participant IDs. X defines exact duplicate profiles; distances alone cannot do so.
Absent distances use R's Euclidean `dist`, which can round differently from older
Python distance generation. Supplied graphs are rejected. The adapter permits
2–500 specimen rows; this is a resource guard, not a claim of all-input numerical
success. Dense distances and affinities require quadratic memory; the initial
Gabriel construction is cubic in profile count. Summary diagnostics omit dense
per-solve matrices and vectors; full traces are opt-in and may be large. Full
traces retain original zero-based core indices (declared in diagnostics); graph
and mapping objects use one-based R indices.

The `numerical.policy` argument accepts exactly two strings:

- `"IAN evaluated-LP 1.0"` is the unchanged default: strict acceptance, no retries,
  and the preserved baseline arithmetic.
- `"IAN evaluated-LP retry-power 0.1"` is an explicit experimental candidate. It
  squares constraint quantities using the system power function. After an
  otherwise eligible rejected `Solved` or `AlmostSolved` return, it permits one
  fresh solve in normalized variable units with solver tolerances of `1e-11`
  instead of the ordinary `1e-9`. That retry must return `Solved` and pass all
  unchanged original-unit certificate limits of `1e-7`. A rejected original
  return is never accepted directly. Both attempts and their actual settings
  remain in diagnostics. No second retry or secondary scale objective is used.

For example, add `numerical.policy="IAN evaluated-LP retry-power 0.1"` to an
internal function call to request the candidate. It has not been adopted as the
default. It is selected explicitly for internal qualification after accepted integration and 1,000-profile native/Python studies. R retains its 500-row guard. Matching the system power operation on one host does not promise
identical arithmetic across platforms.

Both policies use pinned Clarabel 0.11.1, QDLDL, one thread and fresh solver state.  The missing `input_sparse_dropzeros` C header field is repaired against
this pinned Rust FFI; runtime size, alignment and every field offset are checked
before solving. Its value is explicitly false as declared in the accepted policy.
All actual settings are captured in each solve's diagnostic record. This fix
qualifies this pinned configuration only, not arbitrary Clarabel feature builds.

A numeric refusal returns `complete=FALSE`, `final_graph=NULL`, an error and any
available initial/last-valid graph. R interrupts are checked at engine events via
R_ToplevelExec, allowing C++ to unwind; an active solver call is allowed to return
before interruption is handled. This is not mid-solve cancellation. No durable
checkpoint or resume interface is exposed by this first R adapter. `max.solves`
stops execution after its last allowed solve and retains that attempt's record.
R allocation failure and operating-system termination are not recoverable promises.

Source provenance and licenses are under backend/. Ordinary package tests perform
argument checks without solving. Qualification with a built module is separate
under dev/ian and writes attempt accounting outside the source tree.

Internal messages now use typed C++ input, decision, solve, settings, event and
stage structures. The R bridge constructs diagnostic lists directly, without
JSON parsing. Optional file/test serializers preserve the historical JSON schema.
Canonical input fingerprinting still uses the previous JSON encoding at a separate
persistence boundary, so its format is unchanged. The C++ observer interface has
changed: Event now carries an EventPayload variant instead of a JSON string.
