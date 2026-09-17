# Phase07 source and reproduction record

The [plan](PLAN.md), [bounded continuation amendment](AMENDMENT-1.md) and
[report](REPORT.md) define the work. Authored Python/Markdown files here are
canonical. Fixtures, raw traces, diagnostics, manifests and process records are
generated under the private worker root. No accepted runtime source changed.

Phase06B audit N1 is resolved in the coordinator's [roadmap](../coordinator/ROADMAP.md):
the Phase06A table row now says independently accepted, F1 closed. Phase06B's
frozen report remains a historical pre-audit submission. Its accepted artifacts
are checked read-only, not rewritten to update their status.

All execution commands below ran from:
`/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree`.
These are existing evidence namespaces; any reproduction must use fresh paths.
Each driver records actual command, cwd, revision, exit and resources. The shell
variables below abbreviate the exact absolute paths used in the commands.

```sh
W=/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker
R="$W/phase07"
PY="$W/venv/bin/python"
S=development/ian-cpp-phase1/phase07
LAUNCH=development/ian-cpp-phase1/phase05/launch.py
# dcfd85c: fixtures and first harness attempt (the latter failed on NaN reporting)
"$PY" -B "$LAUNCH" "$R/fixture-driver-v1" "$S/fixtures.py" "$R/fixtures-v1"
"$PY" -B "$LAUNCH" "$R/harness-driver-v1" "$S/test_harness.py" "$W" "$R/harness-v1"
# 9fe9ee6: corrected harness and initial measured batch
"$PY" -B "$LAUNCH" "$R/harness-driver-v2" "$S/test_harness.py" "$W" "$R/harness-v2"
"$PY" -B "$LAUNCH" "$R/ladder-driver-v1" "$S/run.py" "$W" "$R/ladder-v1"
# 1ee1a45: prospectively amended continuation, no duplicate solver runs
"$PY" -B "$LAUNCH" "$R/ladder-driver-v2" "$S/run.py" "$W" "$R/ladder-v2" "$R/ladder-v1"
# d48ce34: first final census (incorrect optional bitwise assertion; no solves)
"$PY" -B "$LAUNCH" "$R/analysis-driver-v1" "$S/analyze.py" "$R" "$R/analysis-v1"
# eb5235e: corrected descriptive bitwise census; no numerical rule changed
"$PY" -B "$LAUNCH" "$R/analysis-driver-v2" "$S/analyze.py" "$R" "$R/analysis-v2"
# Final source revision: preservation verification and manifest, no solves
"$PY" -B "$S/finalize.py" "$R"
```

To reproduce a historical failed harness/census attempt, use its named commit
in another isolated checkout. Current source intentionally contains the corrections.
The numerical client commands and per-run checker commands are also fully recorded
inside each run directory; `ledger.json` contains their identities. Final documentation
and preservation inventory were added after measured runs and do not modify their
runtime sources. An ad hoc read-only vector scan after the first census assertion
helped locate the unequal fields; the corrected census contains the durable result.

The accepted runtime is `worker/phase06b/build-v3/ian_engine`, with the accepted
native dependency `worker/phase06a/clean-v2/prefix/lib/libclarabel_c.dylib`.
The private `ian_checkpoint_tool` only reserializes payloads for hash checking; it
does not optimize. Runtime/dependency hashes and linkage appear in the final
preservation record. This phase adds no fresh native build or R evidence.

The seven input files and manifest in `fixtures-v1` include unused 1,000-profile
inputs. `ladder-v1` retains the original conservative gate; `ladder-v2/ledger.json`
references its original process records and adds the remaining fixed 500-profile
panel. It does not duplicate their solver calls. `analysis-v2/results.json` is the
final census, including all failures. The `harness-v1` malformed NaN fixture is
intentional falsification data and is not a new solver execution.

The supervisor stops children by SIGTERM then SIGKILL if necessary. Its 50 ms RSS
and one-second disk/solve polling allow overshoot; these are not kernel-enforced
memory limits. Its wall-termination smoke test passes; actual RSS/disk exhaustion
and whole-study budget exhaustion were not injected. Driver memory and final
census resources are separately recorded by the outer existing supervisor.

The preservation script checks prior manifests and historical source blobs,
including review-6b, verifies fixtures and the reused engine/dependency hashes,
and inventories this phase. The handoff is outside the frozen evidence root to
avoid a circular manifest. No shared checkout, audit directory, installed R
library, production environment, or previous evidence bundle is modified.
