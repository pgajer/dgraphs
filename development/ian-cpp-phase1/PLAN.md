# Frozen first-phase plan

Implementer-authored, unaudited. Scope: six fixed LPs, no IAN fits.

Select before measuring either backend: at multiplier 4.5 take the first initial
solve of uniform_arc, the first post_prune solve of gap_observations, and the
last final_affinity_retuning solve of gap_observations. For combined_full take
first and last post_prune solves and last final_affinity_retuning solve.
Within a phase order by (iteration, number), never by timings or numerical ease.
These cover initialization, a small pruning transition, small final retuning,
early/late cohort pruning and the last cohort affinity-scale solve. A saved scale
solve is not a saved affinity matrix.

Use binary64, Clarabel 0.11.1, QDLDL, one solver thread, tol_gap_abs=tol_gap_rel=
tol_feas=1e-9 and max_iter=300. Other common core settings remain defaults.
Use a fresh process for each repetition; no warm starts or reuse.
Three measured blocks, case order rotated by 0, 2, 4 positions; alternate path
order by (repetition + position) parity. Exactly 36 measured solves, serial.
Smoke/setup commands have separate directories. Failures remain in the table.

Use saved A including bounds, b and c without variable elimination, scaling,
objective normalization or changing inequalities. Export exact little-endian
binary with byte-exact round trip, retain original NPZ, record all hashes.
Recompute normalized row violations, objective and active-scale positivity
outside solvers using the recorded 1e-7 policy. Report raw bound residuals,
scale and objective differences. Preserve status distinctions. Store duals and
recompute stationarity and dual objective as additional diagnostics, without
claiming a formal optimality certificate.

Report both child timing and process start-to-exit timing, sampled process-tree
RSS (same 10 ms sampler both paths), load average/system CPU, process thread
counts, versions, build flags and telemetry availability. Resident memory is a
sampled lower bound on peak, not precise allocation attribution. Imports are
part of Python end-to-end and separately timed. Compilation is setup only.

Canonical source lives here; all dependencies, builds, fixtures, runs and the
factual handoff live in the assigned private worker directory. No shared edits,
full port, scientific outcome analysis, production repair, merge or publication.
