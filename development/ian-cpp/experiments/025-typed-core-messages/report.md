# Can typed C++ messages preserve IAN behavior?

IAN-EXP-025 · Typed core refactor · Aims IA1 and IA2 · Executed 23 September 2026.

The bounded implementation has independent acceptance on macOS arm64. This maintained catalogue presentation still awaits independent review.

The numerical engine and R bridge now exchange typed C++ structures. Four small
reference examples retain exactly the same graphs, scales, affinities and complete
R diagnostic traces, after excluding elapsed timings, build identities and the
trace-format description. Numerical policy remains evaluated-LP 1.0.

## What changed

Input preprocessing returns a typed mapping. Pruning returns a Decision, and the
solver returns a SolveRecord with typed settings and certificate fields. Fourteen
named event payloads form an EventPayload variant. Observers inspect these values
directly. Stage completion assigns typed Result fields before notifying observers.
The R bridge constructs the existing diagnostic lists directly, including their
names, types, ordering and array/list shapes; it no longer parses JSON messages.
The numerical/event headers compile without including the JSON library.

JSON remains at explicit boundaries: file traces/checkpoints, optional legacy test
interfaces, and canonical input fingerprinting in identity_json.cpp. The latter
preserves the previous fingerprint format and avoids an unrelated checkpoint change.
The ordinary R module does not link the legacy JSON test entry points. JSON has
not been removed from the whole distribution, and the existing NumPy-derived
numerical routines and license notice are unchanged.

C++ Observer users must switch from Event.json to Event.payload, usually inspected
with std::get_if<T>. The existing R function and result fields are retained. Full
R diagnostics still use zero-based core indices; graph/mapping objects are one-based.

## Bounded checks

The unchanged examples were the nonuniform curve (64 profiles), variable-density
patch (80), nearby curved arms (96), and PreSSMat Hellinger subset (64). All four
new full traces match fresh old-version traces exactly except the declared metadata.
All 13 interface-panel results also match the previous adapter's stored results,
including incomplete/error objects, mappings and summary/full diagnostic structure.
Only PreSSMat prunes in this small reference panel; broader coverage is not implied.

| Schedule | Engine calls | Solver attempts | Outcome |
|---|---:|---:|---|
| Fresh old-version full traces | 4 | 16 | Baseline captured |
| Typed adapter interface/failure panel | 13 | 77 | 133 checks pass; all 13 stored results agree |
| Typed adapter full traces | 4 | 16 | All four comparisons exact |
| Typed C++ observer and restart checks | 5 | 18 | All checks pass |
| Total | 26 | 127 | Within 36-call / 400-attempt budget |

The native test saves an actual disk checkpoint, validates its trace prefix,
resumes to exactly the uninterrupted result, and rejects a deliberately corrupted
trace and malformed restart. Cancellation and observer exceptions retain structured
incompleteness. Six existing threshold/tie decision controls match their stored
native outputs exactly without new solves. The optional JSON serializer reproduces
all 58 events in the PreSSMat baseline trace apart from elapsed times.

The fresh optional backend build, make document, make build and private-library
installation passed. The selected package regressions passed 53 expectations with
no failures, warnings or skips. Source tar creation retains the previously known
long-path portability warnings. No new numerical refusal or corrective numerical
patch occurred. An additional comparison-script commit preserves R class/attribute
checks; it changes no package execution source.

## Delivery and limits

Branch: codex/ian-typed-core-20260923, based on the preserved adapter commit
9fbabc6a5d36098f896936cd79e8f7a963ec363c. Package execution source is e6728bc;
subsequent development comparison/report changes are excluded from the package.
The new private installation and full evidence paths are in the private handoff.
The older tested adapter and all historical evidence remain in place.

The author qualification and subsequent independent implementation acceptance
cover one macOS arm64 host. No performance improvement was measured. General
numerical robustness, other platforms, public export and larger runs remain outside
this acceptance. Cross-build
checkpoint migration is still unsupported; source identities continue to guard it.

## Source and evidence

See the [typed structures](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/typed-core/worktree/inst/ian/backend/core/include/ian/core.hpp), [engine](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/typed-core/worktree/inst/ian/backend/core/src/engine.hpp), [plan](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/typed-core/worktree/dev/ian/typed-core/PLAN.md), [handoff and installed-use instructions](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/typed-core/implementer-handoff.md), [summary](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/typed-core/evidence/summary.json), and [evidence manifest](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/typed-core/evidence/manifest.json). The [previous adapter study](../024-internal-dgraphs-adapter/report.md) remains a separate preserved result.

## Subsequent independent review

The [independent audit](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/auditor/review-adapter-layout/audit.md) accepted the typed-message, numerical and failure-preservation claims, with no corrective findings requiring an implementer patch. Fresh installed-source builds, all 13 interface cases, four full traces, native checkpoint/observer tests, six fixed decision controls and direct/serialized event comparisons pass within the stated scope. All 39 captured settings match the intended Rust settings, and every deliberately mismatched layout response is refused before solver construction.

The combined original/typed/R-version audit made 46 engine calls and 237 attempts: 234 accepted and three deliberately rejected numerical returns. Seven typed-candidate cases under an isolated R 4.5.2 installation match the fresh typed R-devel results after the declared timing/build exclusions. The original adapter and full interrupt schedule were not separately tested under R 4.5.2. Environment and auditor-checker failures are preserved in the audit; none required a candidate source correction. Linux, Windows and other-architecture runtime qualification remain outside this acceptance.
