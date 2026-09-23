# Internal IAN adapter: bounded author qualification

The installed, unexported `create.ian.graph()` adapter works on the four accepted
small reference examples and preserves the initial Gabriel graph separately from
the completed final graph. This is a usable local integration candidate, not a
public export or general numerical acceptance.

The optional module uses the accepted Phase06B reusable core and evaluated-LP 1.0
policy, without the later experimental retry policies. Metric edge lengths retain
input distance units; the affinity matrix is returned separately. Exact duplicate
profiles preserve first-occurrence order and explicit specimen/participant mappings.
Graph/mapping indices are one-based. Optional full traces preserve core-native
zero-based indices, explicitly declared in diagnostics.

## What was tested

The original nonuniform curve (64 profiles), variable-density patch (80), nearby
curved arms (96), and PreSSMat Hellinger subset (64) were replayed against preserved
Phase03 native graph, scale and affinity outputs. There were no new scientific
fixtures or scale-ladder runs. Additional small interface cases tested duplicates,
computed versus supplied distances, summary versus full diagnostics, certificate
refusal injection, a solver-attempt limit, failure after graph convergence, actual
SIGINT injected at an event boundary, and invalid duplicate inputs.

Two complete qualification schedules passed: first using an explicit development
module path, then using default discovery of a module built with the helper from
the installed package. Each schedule contained 13 engine calls, 77 solver attempts
and 133 checks. Cumulative accounting is 26 calls and 154 attempts, including the
expected injected failures. Ordinary package tests added 53 passing expectations,
with zero warnings, skips or failures. These package tests did not run IAN solves.

| Reference example | Initial edges | Final edges | Solves | Maximum absolute scale / affinity difference |
|---|---:|---:|---:|---:|
| Nonuniform curve | 63 | 63 | 2 | 0 / 0 |
| Variable-density patch | 170 | 170 | 2 | 0 / 0 |
| Nearby curved arms | 142 | 142 | 3 | 0 / 0 |
| PreSSMat Hellinger subset | 278 | 274 | 9 | 0 / 0 |

The reference acceptance bound was 1e-7 absolute plus 1e-6 relative; all observed
scale and affinity differences were exactly zero. Graphs and mappings also matched
exactly. PreSSMat demonstrates that the initial graph retains the four removed
edges. Full success is required for a non-NULL final_graph. Expected refusals and
interruptions retained available initial/last-valid graphs and diagnostic records.

## Solver interface and build

The pinned C header now includes Rust's missing input_sparse_dropzeros field.
Before each solve, the module checks C versus Rust size, alignment and offsets of
all 39 settings fields. The declared dropzeros=false setting is explicit. Every
actual setting is captured before constructing the solver and retained with that
attempt's result. This qualifies the pinned no-SDP, double-precision configuration;
it does not qualify arbitrary feature combinations or solver releases.

`make document`, `make build`, private-library installation and a fresh optional
backend build all passed on macOS arm64. The installed module statically links its
solver and uses only system runtime libraries; default discovery has no private
worker-path dependency. Package installation does not automatically build it.
The first offline backend build failed because its Cargo cache lacked a crate;
no optimization ran. That failed log remains. The correction used a fresh Cargo
home with the accepted read-only vendored crate sources. Subsequent builds passed.
Tar creation warns that some vendored source paths exceed 100 characters. This
host's build/install passes; portable packaging remains unqualified.

## Limits and next work

This is implementation-author QA. Neither independent audit, comprehensive R CMD
check/CRAN qualification, other operating systems, larger datasets, user-supplied
initial graphs, distance-only duplicate semantics nor durable R checkpoint/resume
is established. Interruptions are handled at events after any active solver call
returns, not inside an interior-point iteration. Allocation failure and process
termination are outside recovery promises. The public export and numerical scale
ladder remain gated. The next integration review should evaluate this explicit
optional dependency arrangement before any supported dgraphs API is proposed.

The private evidence directory holds complete command logs, build/source hashes,
reference identities, result RDS objects, settings/attempt ledgers and a handoff.
No original IAN evidence or shared dgraphs main files were modified.
