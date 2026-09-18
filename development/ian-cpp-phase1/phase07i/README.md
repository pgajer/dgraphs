# Phase 07I reproduction

Read PLAN.md and REPORT.md. Use the isolated implementation-worktree and existing
worker/venv/bin/python with PYTHONDONTWRITEBYTECODE=1. Use a new output root;
never overwrite accepted evidence or auditor files. No installation/build required.

1. `prepare.py NEW_ROOT` copies the common Python-generated LP and saved HiGHS
   return, reconstructs exact bounds and feasible witnesses, checks equality with
   the auditor's saved fractions, generates/fixes all six augmented LPs and performs
   no-solve controls and saved-direction arithmetic.
2. From a clean committed checkout, `execute.py NEW_ROOT` runs exactly six reserved
   calls under the accepted phase07h one-shot guard, imported read-only. Each client
   saves actual settings/model and refuses a second backend run().
3. `analyze.py NEW_ROOT` creates certificates/ and results.json, recomputing exact
   feasibility, strict objective-band membership, repairs and dual bounds. No solves.
4. `saved_span.py NEW_ROOT` verifies and combines the separately labeled historical
   feasible witnesses with the fresh extremum bounds. It does not rewrite results.json
   or claim new optimization results.
5. After source/report commit, `finalize.py NEW_ROOT` verifies prior inventories,
   unchanged dependencies and measured sources, then freezes evidence. Its assertions
   describe this specific submission's observed outcomes.

Preparation, all measured calls and primary analysis use ad5fad6. Separate no-solve
saved-span synthesis uses eb6bd6c. No optimizer call is rerun. Fraction pairs contain
numerator and denominator strings; parse these for exact claims rather than subtracting
rounded decimal objectives. The existing external numerical thresholds remain 1e-7,
but objective-band membership and derived feasible witnesses admit zero exact violation.
