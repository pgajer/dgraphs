# Phase06B amendment 1: trace-hashing resource correction

Recorded after the first complete regression workload and before further solves.
The first 460-call workload at `bc9a3ef` passed all frozen comparisons, but the
256-profile process reached 4,282,417,152 bytes peak RSS. Its checkpoint observer
re-read and copied an increasingly large trace at every boundary. This avoidable
implementation pattern is the suspected cause; no allocation profiler was used.
The first workload, including its resource records, remains in regressions-v1.

Replace whole-prefix copies with an incremental SHA-256 context in the writer
and bounded-buffer hashing in the reader. These operations change checkpoint
bookkeeping, not the numerical state or policy. Repeat the 460-call regression
workload under a new namespace before operational tests. Extend the overall
allowance from 1,000 to 1,500 solver calls, including the original 460 and all
new executions. No prior solve is subtracted or reclassified. Subsequent resource
observations can establish improvement in this implementation without proving
per-allocation causality or a general performance result.

Two CLI lifecycle issues identified by source inspection are corrected in the
same pre-operational revision: option-validation failures must not write into an
already existing output directory, and an optional diagnostic exception (including
failure to write its status) must not revise native completion. Add zero-solve
checks of output ownership and diagnostic-status write failure. No published or
accepted earlier phase source is changed.
