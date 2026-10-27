# Intrinsic kNN correction

Keep public graph interfaces. Replace endpoint-face calculations with the shared
exact intrinsic path solver and exhaustively consider all candidates. Preserve
self-first and row-index tie rules. Use O(n + nk + sparse input) memory; time
is quadratic in sample count and includes the general solver's per-pair work.
No unsafe nearest-candidate truncation or unproved pruning is introduced.

Invalidate only simplex caches (v4 vs legacy v3); retain Euclidean v3. Test a
three-point neighbor reversal, random sparse/tied/one-dimensional cases against
full intrinsic matrices, graph call paths and old cache rejection. The existing
path tests independently compare constrained optimization, path length and
metric inequalities. No cohort analysis or saved results are rerun.

Resources: October 27 user allocation up to 6 single-threaded workers/30 GiB alongside
the explorer asset build. Compile once, optimized, in supervisor. Targeted tests
and modest synthetic parity checks share this allocation. No package runtime
benchmark claim. Logs and binaries remain untracked; source is committed/pushed.
