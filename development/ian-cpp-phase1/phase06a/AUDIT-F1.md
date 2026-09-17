# Phase 06A correction: JSON schema declarations

The [independent audit](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/auditor/review-6a/audit.md)
identified a format-validation defect: the CLI converted a JSON version value
to an integer before testing it. This allowed `1.5` and `4294967297` to become
version 1 on the tested platform. The correction validates the original JSON
type and value before assigning the supported C++ version.

An omitted declaration still defaults to 1. An explicit declaration must be a
JSON integer equal to 1. Floating representations such as `1.0` and `1e0` are
deliberately rejected. Unsupported versions and malformed declarations produce
an explicit `unsupported_schema` adapter error before the core is called. This
choice and the output contract are documented in [SCHEMAS.md](SCHEMAS.md).

The only runtime source change is in `src/json_adapter.hpp`. No core algorithm,
numerical setting, tolerance, typed C++ API or R adapter changed. Original
submitted evidence and the original report/handoff remain intact. This addendum
records the correction separately; independent acceptance remains pending.

## Focused validation

The CLI was rebuilt from committed source at `7fd0b2e` in a new private build
directory, using the previously recorded clean-build Clarabel library. The solver
dependency was not rebuilt again. The test uses the unchanged 64-profile
nonuniform-curve fixture, altering only the presence or value of `schema_version`.

All 18 CLI cases passed:

| Declarations | Expected and observed behavior |
|---|---|
| Omitted; integer `1` | Complete success; two solves per run |
| `1.5`; `4294967297`; `2` | Rejected before core execution |
| `1.0`; `1e0` | Rejected under the documented integer-only rule |
| `-1`; `0`; maximum signed and unsigned 64-bit integers; one above unsigned range | Rejected before core execution |
| String `"1"`; `true`; `false`; `null`; array `[1]`; object `{"version":1}` | Rejected before core execution |

All 16 rejected cases exit with status 1 and save only `status.json`, containing
`error_kind: "adapter"`, `error: "unsupported_schema"` and false completion/stage
flags. The parser returns before an observer or core run is created; no solve,
trace, result or validated stage is produced.

The two valid cases produce exactly the original Phase 06A result values and
complete event traces after excluding elapsed solve time. Saved stages agree
after excluding changed input/source provenance hashes; their status hashes
verify. All four new saved optimization payloads pass the unchanged numerical
checks. These four calls are separate from the original 560-call submission.
No numerical failure or test rerun occurred in this correction workload.

The committed `schema_regression.py` exercises the executable boundary rather
than only the typed C++ interface. `extract.py --check` still passes. The
finalization script checks unchanged algorithm/configuration bytes, build/source
identity, and original submission plus audit manifest preservation. Reproduction
commands and exact candidate/hash provenance are in the
[correction handoff](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase06a-correction-f1-handoff.md).

## Limits and status

This parser-only change was tested on the existing macOS ARM64 host. The earlier
complete numerical, dependency-build and C++/R interface workloads were not
repeated; their passing evidence remains relevant to unchanged code. No new
Python solves, numerical calibration, platform qualification, checkpoint/resume
work or production integration was performed. Earlier historical-expression,
calibration and diagnostic-warning limitations remain. F1 is addressed in the
implementation and submitted for re-audit; Phase 06A is not marked independently
accepted, and Phase 06B has not started.
