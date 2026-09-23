# Can an internal dgraphs adapter preserve results and expose useful graph stages?

IAN-EXP-024 · Internal adapter 1 · Aims IA1 and IA2 · Executed 23 September 2026.

**The installed, unexported adapter reproduces all four small reference examples and returns the actual initial Gabriel graph separately from the completed final graph.** This is a usable local integration candidate with author qualification; independent review and public export remain pending.

## Interface and numerical policy

`dgraphs:::create.ian.graph()` takes a finite specimen-by-feature matrix, optional unsquared distances, specimen/participant identifiers, and a diagnostics level. It returns:

- `initial_graph`: the Gabriel graph captured before any pruning;
- `final_graph`: the completed graph, or NULL if any required stage failed;
- `last_valid_graph`: the latest available graph, which may be incomplete;
- `mapping`: original specimens, unique profiles and participant identifiers;
- `scales`, a separate profile-by-profile `affinity` matrix, and diagnostics;
- `complete`, a structured `error`, and backend provenance.

Metric graph edge lengths retain the input distance units. Affinities are similarities and are not substituted for those lengths. Exact duplicate profiles retain first-occurrence order and explicit specimen mappings. Returned graph/mapping indices are one-based. Optional full diagnostic traces retain zero-based core indices, explicitly declared in the result; ordinary summary diagnostics omit dense optimization payloads.

The adapter uses the accepted Phase06B core and evaluated-LP 1.0 policy. It adopts no experimental retry, changed tolerance or secondary scale-selection rule. The R function permits 2–500 specimen rows as a resource guard, not a guarantee of numerical completion or validation at every size. Coordinates remain required for duplicate identification. Supplied initial graphs are unsupported.

## Qualification and results

Four preserved Phase03 reference examples were replayed. Each is small; only the PreSSMat subset prunes. Additional interface cases test duplicate/participant mappings, supplied versus computed distances, summary versus full diagnostics, certificate rejection, a solve limit, failure after graph convergence, interruption at an engine event, and invalid duplicate inputs.

| Example | Profiles | Initial edges | Final edges | Solves per replay |
|---|---:|---:|---:|---:|
| Nonuniform curve | 64 | 63 | 63 | 2 |
| Variable-density patch | 80 | 170 | 170 | 2 |
| Nearby curved arms | 96 | 142 | 142 | 3 |
| PreSSMat Hellinger subset | 64 | 278 | 274 | 9 |

All graphs and mappings match exactly. Scale and affinity differences are also exactly zero, within the prescribed absolute 10^-7 plus relative 10^-6 bound. The PreSSMat result verifies that the initial graph retains edges later removed.

Two qualification schedules each passed 133 checks with 13 engine calls and 77 solver attempts. **Cumulative use was 26 calls and 154 attempts**, including expected failure injections, below the frozen 30-call/600-attempt budget. The first schedule used an explicit backend path; the final schedule used automatic discovery of a backend freshly built from the installed package's helper. Another 53 package expectations passed without failures, warnings or skips; those checks made no IAN solves. These are author checks, not independent audit acceptance.

Refusals and interruption retain available initial/last-valid graphs and attempt records. They do not return a completed final graph. Interruption is handled at engine events after any active solver call returns; mid-solve cancellation is not claimed.

## Build boundary

The optional backend builds and installs on the tested macOS arm64 host. Ordinary dgraphs installation installs its sources and wrapper but does not automatically compile this module; an unavailable backend gives an explicit error. The installed module uses a relocatable identity and system runtime libraries, with no private worker runtime dependency.

The pinned C/Rust interface now includes the missing `input_sparse_dropzeros` field. Before each solve it verifies size, alignment and offsets of all 39 settings fields, and captures actual settings before solver construction. Qualification covers this pinned configuration only.

The initial offline build failed because a required Cargo crate was absent; its evidence is retained. Successful builds used the accepted read-only vendored crate sources and a fresh Cargo home. Source-package creation warns about vendored paths longer than 100 characters. Installation succeeds on this host; comprehensive portability and CRAN checks have not been performed.

## Delivery and next step

The candidate lives in the isolated branch `codex/ian-internal-adapter-20260923`, separately from the IAN catalogue branch. It is installed in a private R library for testing and has not been merged into the shared dgraphs checkout.

See the [adapter report](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/adapter/worktree/dev/ian/REPORT.md), [frozen contract](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/adapter/worktree/dev/ian/CONTRACT.md), [build and interface guide](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/adapter/worktree/inst/ian/README.md), [tested usage example](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/adapter/worktree/dev/ian/example.R), [handoff and private installation instructions](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/adapter/implementer-handoff.md), [qualification summary](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/adapter/evidence/summary.json), and [maintained snapshot](results-summary.json).

Independent review should cover this bounded implementation and the optional backend arrangement. A supported export, other platforms, durable R checkpoint/resume and larger trajectories remain separate milestones. This study does not complete the [portable R qualification proposal](../020-portable-r-interface/report.md). The numerical scale ladder remains closed.
