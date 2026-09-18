# Phase 07G reproduction

Read PLAN.md and REPORT.md first. Eight fixed LP solves, not complete IAN runs.
All commands run from the isolated implementation-worktree. Use the existing
worker/venv/bin/python and set PYTHONDONTWRITEBYTECODE=1. Choose a new output root;
never overwrite the frozen evidence. The executed source revision is 446ff96.

1. Run `prepare.py NEW_ROOT` with that Python. It copies the two saved terminal
   LPs, exports exact CSC arrays, checks CVXPY canonicalization without solving,
   and records no-solve controls and environment metadata.
2. Configure CMake in `NEW_ROOT/build` from this directory, Release, with
   CLARABEL_SOURCE=worker/phase06a/clean-v2/dependencies/Clarabel.cpp,
   CLARABEL_LIBRARY=worker/phase06a/clean-v2/prefix/lib/libclarabel_c.dylib and
   JSON_INCLUDE=worker/phase03/deps. Use absolute paths. Build the new client;
   do not build the backend. The original build was moved from a temporary sibling
   build directory after compilation; its CMake cache retains that original path.
3. From a clean checkout, run `execute.py NEW_ROOT`, then `analyze.py NEW_ROOT`.
   The former invokes precisely the eight cells with the accepted resource guard.
   The latter reads outputs only; results.json preserves status, acceptance and
   vector-comparison results separately.
4. Run `supplement.py NEW_ROOT` to build and execute a no-solve settings probe,
   correct the dependency revision attribution, and write results-v2.json. This
   does not alter the replay executable or its original evidence. The original
   incomplete settings capture remains a stated limitation.
5. `finalize.py NEW_ROOT` is the submission freezer, run only after documentation
   is committed. It verifies previous manifests, dependencies and runtime, plus
   unchanged executed source, before writing a new manifest. Its assertions encode
   this submission's observed outcome and expected historical prerequisites.

Supporting tools are imported read-only from Phase07B (scalar arithmetic checks)
and Phase07C (sampled resource supervisor). The status and vector allowances are
unchanged. Handoff is outside the frozen evidence root. No installs or new inputs.
