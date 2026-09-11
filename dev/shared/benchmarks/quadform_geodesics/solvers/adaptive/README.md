# Adaptive refinement implementation

Implements the search family in the revised
`dev/shared/fixtures/quadform_geodesics/adaptive_quadform_geodesic_refinement.tex`,
Sections 8.1–8.7. All numerical settings remain provisional. This is an
implementation awaiting shared-runtime alignment and independent implementation
audit, not a protocol-compliance or benchmark result.

## Tie-order resolution (before implementation)

The specification uses numeric coordinate lexicographic order for initializer
ties in 8.1, but encoded vertex-key path order in 8.7. We resolve the conflict by
using 8.7, the later and more specific rule, for **all path-cost ties**, including
the grid initializer. Numeric coordinate order applies only to equal-distance
endpoint attachment choices. Subdivision length ties use current path order.
Equal-cost alternatives always retain the incumbent (the direct connector is
the incumbent during initialization); other path ties compare the complete
ordered sequence of exact binary vertex keys. All byte/hex ordering uses radix
order, independent of locale. Negative-coordinate tests distinguish these rules.
This resolution is recorded as `path-key-8.7-attachment-numeric-8.1-v1` in metadata.

## Scope and shared interfaces

The R entry points return ordinary `qgs.adapter` objects. All connector work
uses `control$edge`; there is no adaptive cache, auditor, or campaign runner.
Only a temporary comparison batch and immutable per-segment records of the
acknowledged path hold returned edge records. Batches are discarded before the
next attempt. Unaffected path segments retain their publication-time estimates;
new/changed segments come from the completed comparison batch. These records
never avoid a required control lookup or answer a later edge request.
NumPy PCG64 is embedded through optional `reticulate`, not a background Python
process. The Python interpreter is selected through reticulate's normal explicit
configuration (`RETICULATE_PYTHON`); NumPy/Python/reticulate versions and the exact
JSON RNG state are recorded. There is no R-RNG fallback and no rounded seed.

The shared interface is now **0.3.2**. Real workers provide the capability
declaration and a durable `control$checkpoint(state)` sink. Preparation checks
`cache_policy = "lru65536-levels01-v1"`, `edge_key = "u32be-f64be-v1"`,
`edge_failures = "qgs_edge_error-v1"`, and `checkpoint = "adaptive-state-v1"`.
A bare `qgs.control(request)` has no durable sink and still fails explicitly;
that is not evidence that the worker interface is missing.

Connector calls retain their `(from, to, tighter)` signature and successful
`length/error_estimate` result. Completed numerical failures use
`qgs_edge_error`; budget interruptions propagate as `qgs_budget` without
becoming completed cache entries. Algorithm state, accepted publications, and
shared cache/resource state are recorded by the runtime. Mid-attempt restore is
still unsupported: recording state is not a recovery claim.

`adaptive_initializer.R` now supplies the deterministic baseline by calling the
same `qga.initialize` implementation, without insertion or PCG64 initialization.
All three adaptive-family entries remain planned pending review. The shared
runner captures a terminal diagnostic snapshot and acknowledged publication
history for the reporting code; optional publication audits follow the mandatory
initializer/terminal/resource-checkpoint queue. No full calibration is claimed.

For an explicit local test environment already available on this machine:

```sh
env R_LIBS_USER=/Users/pgajer/.codex/private/geosmooth/adaptive-refinement/r-library \
  RETICULATE_PYTHON=/Users/pgajer/miniforge3/envs/pacmap_env/bin/python \
  PYTHONDONTWRITEBYTECODE=1 Rscript --vanilla \
  dev/shared/benchmarks/quadform_geodesics/tests/test_adaptive_vertex.R
```

The backend is optional for the deterministic baseline and identity paths.
It is required for stochastic refinements; there is no automatic dependency
installation or R-RNG fallback. Record effective library paths and versions,
since startup settings may otherwise change interpreter selection.
The adaptive-family registry entries remain planned. After review, its owner
can activate the entries with `file: solvers/adaptive_vertex.R` (respectively
`adaptive_local_graph.R`) and `sources: ["solvers/adaptive/common.R"]`;
local-graph also needs `"solvers/adaptive/local_graph.R"` in that array.

## Focused tests

From the repository root (or use absolute script paths):

```
Rscript dev/shared/benchmarks/quadform_geodesics/tests/test_adaptive_vertex.R
Rscript dev/shared/benchmarks/quadform_geodesics/tests/test_adaptive_local_graph.R
```

The tests exercise the algorithm, not a calibration campaign. Synthetic test
controls have no cache and make no audit or compliance claim. Real shared-kernel
checks explicitly report the runtime's limitations. Optional NumPy tests require
reticulate and a selected Python with NumPy; missing dependencies are explicit.
The fixture payload is read-only and never rebuilt.

## Implementation validation

The 18 vertex-focused test cases passed before the final validation of the
8 local-graph cases (26 total). NumPy/reticulate tests were executed, not skipped.
Coverage includes raw-bit and signed-zero keys; the negative-coordinate tie
counterexample; complete ordered retries; subdivision exclusions and midpoint
rounding; rejected/late publications; persistent path-occurrence IDs; immutable
segment estimates; stage escalation and clipping; PCG64 reference values; graph
versus vertex search power; vertex caps; and a shared-kernel curved-path check.
These tests do not replace the requested independent implementation audit.
No calibration campaign, fixture rebuild, registry activation, or compliance
qualification has been performed by this implementation.
