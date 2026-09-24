# Difficult fixed problems

`prepare.py` reproducibly freezes six original evaluated LPs in
`worker/phase07e/fixtures-v1/`, with exact matrices, vectors, old returned solutions,
source hashes and expected certificate outcomes. This versioned collection remains
part of permanent project evidence. Its manifest is the machine-readable index.

The cases are the Phase07C unresolved helix LP, its accepted predecessor, the
first repaired helix LP, a small-helix control, the deterministically selected
PreSSMat stress control, and the Phase07D post-pruning terminal LP. The earlier
strict retries and the separately labeled auditor terminal probe remain referenced
as historical evidence. They are not additional fresh observations.

For each case, `diagnose.py` runs ordinary and normalized-retry settings exactly
once. The six ordinary outcomes must match their saved acceptance results; all
six normalized returns are expected to pass unchanged checks. Rejected ordinary
returns are successful regression observations when rejection matches expectation.
No general success rate or unseen-geometry validation follows from this collection.
New natural failures are saved under the phase analysis directory, without silently
adding solver settings. Later phases can version this collection and add those
failures while keeping these original entries unchanged.
