# Reproducing Phase 07H

Use a fresh output directory. Keep the accepted evidence and auditor areas read-only.
Run from the isolated implementation-worktree using the existing worker/venv/bin/python
and PYTHONDONTWRITEBYTECODE=1. No installation or native build is required.

1. `prepare.py NEW_ROOT`: copy and verify unchanged Phase07G fixtures; check the
   installed HiGHS version, allowed options and hand-calculated dual signs. No solves.
2. `test_guard.py NEW_ROOT/guard-controls`: six child-process controls with synthetic
   events and an exhausted-budget refusal. Zero optimization calls.
3. From a clean committed checkout, `execute.py NEW_ROOT`: reserve and run the four
   prescribed fresh-process calls. Each child records its actual effective backend
   options and loaded model before calling HiGHS. Resource/accounting failure stops
   further dispatch. A reservation is consumed even if its child fails.
4. `analyze.py NEW_ROOT`: recompute original-unit certificates and compare scales,
   duals and repeats. No further solves. The installed private SciPy wrapper is
   observed through a forwarding proxy, not modified on disk.
5. `finalize.py NEW_ROOT`: after report/source commit, verify all prerequisite
   inventories, unchanged dependencies and executed code, and freeze this bundle.
   The finalizer includes assertions for the specific outcomes of this submission.

Measured source is 2d62cde; preflight/guard controls ran at a663060 before the
pre-run enum-serialization correction in replay.py. No numerical run was repeated.
The accepted Phase07G Clarabel measurements are reused, not counted as fresh solves.

Use phase07h/oneshot_guard.py for new one-shot diagnostics. Do not reuse the old
Phase07G supervisor: its exact-quota behavior is preserved as historical source.
This new guard must not replace multi-solve engine budget enforcement unchanged.
