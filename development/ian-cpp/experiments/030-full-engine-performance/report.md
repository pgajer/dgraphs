# What does a complete IAN run cost in a persistent process?

The C++ implementation is faster than the evaluated-LP Python reference on all three tested examples. Its matched workers use about **53% less peak memory**. The internal R adapter adds little time on the 500-profile helix, but constructing R graph objects is noticeable on the much smaller example. These are measurements on one Mac, with the numerical behavior unchanged; independent review is pending.

## What was compared

The frozen examples are a 64-profile PreSSMat Hellinger-distance subset, a 500-profile helix and a 1,000-profile quadform with four intrinsic dimensions embedded in five coordinates. C++ and Python run all three. R runs the first two because its accepted input limit remains 500 rows. Each uses the same supplied distances and explicit retry-power policy accepted in Stage 1.

Three fresh processes per interface each perform one warmup and three measured calls per example. Interface order rotates between blocks. Each call returns the initial Gabriel graph, final graph, local scales, dense affinities and solver history. File parsing, build, module loading and output serialization are outside the call timer; no durable checkpoints or full traces are requested during these primary timings. One numeric thread is used on an Apple M4 Max, macOS 26.6.1. The machine was not reserved exclusively.

These are implementation-pipeline measurements. Python includes CVXPY model work and converts parsed lists to arrays inside the call; native input is already typed, and R starts with matrices. R retains richer summaries. Observation hooks remain active. Consequently, the timings do not isolate a pure C++ versus Python language effect. The [profiling contract](../../stages/04-performance/NOTES.md) defines these boundaries and all timer scopes.

## Time and memory

Each cell below is the median of nine measured calls, with its observed minimum–maximum in parentheses. Repeated calls on the same fixtures describe machine variability, not independent scientific samples.

| Example | C++ seconds | Python seconds | Internal R seconds |
| --- | --- | --- | --- |
| PreSSMat subset, 64 profiles | 0.0102 (0.0096–0.0107) | 0.0343 (0.0339–0.0377) | 0.026 (0.025–0.049) |
| Helix, 500 profiles | 0.479 (0.458–0.493) | 0.859 (0.830–0.877) | 0.532 (0.519–0.542) |
| Quadform, 1,000 profiles | 4.165 (4.107–4.248) | 4.753 (4.701–4.876) | Not run: exceeds accepted R limit |

C++ takes about 30%, 56% and 88% of Python's time, respectively. Its relative advantage shrinks on the larger example. The within-program setup medians are 0.270 seconds for native and 0.868 seconds for Python, which load all three fixtures, and 0.194 seconds for R, which loads two. These setup measurements omit OS launch and interpreter initialization before the script starts. Warmups remain in the evidence but are excluded from the table.

The three matched native workers peak at **215–219 MiB**, versus **465–469 MiB** for Python. Comparing the median process peaks gives a 53% reduction. These peaks include loaded libraries, all fixtures, warmups, saved-result serialization and allocator capacity retained across calls; they do not identify the core engine's intrinsic memory requirement. R peaks at 240–255 MiB on its shorter fixture schedule, so its memory cannot be directly ranked against the other workers here.

## Where time goes

For native C++, median initialization/pruning/final-retuning intervals are 0.0009/0.0082/0.0010 seconds for the small subset, 0.042/0.434/0.004 seconds for the helix and 0.148/3.922/0.097 seconds for the quadform. The nested LP timers account for approximately 85–91% of native total time. The corresponding Python intervals are 0.0016/0.0281/0.0046, 0.020/0.822/0.017 and 0.064/4.547/0.142 seconds. These event intervals include observation work; final time includes affinity retuning and output formation. Component medians need not add exactly to the median total.

For R, the native bridge takes 0.011 seconds on the small subset and 0.489 seconds on the helix. This includes conversion to/from native structures and the core itself. Constructing the three R graph objects takes another 0.014 and 0.038 seconds. Remaining wrapper work is typically 0.001–0.002 seconds; its millisecond-resolution clock and occasional allocation costs explain some variation. Separate pure conversion and core timings were not obtained.

The native checkpoint diagnostic uses six additional helix executions, all with full traces: three checkpoint after every pruning step and three retain only the final graph checkpoint. Median CLI elapsed time is **1.275 versus 0.932 seconds**, excluding input loading in both cases. The explicit checkpoint interval accounts for 0.375 versus 0.009 seconds. This shows a real durability cost for this example; it does not justify silently reducing recovery protection or compare checkpoint performance across languages.

## Numerical preservation and interpretation

All **110 engine entries and 5,166 physical solver attempts** are accounted for; all 23 child processes completed and were reaped. Eight full-trace qualification calls reproduce accepted optimization inputs, scale and dual vectors, graph decisions and final outputs. All 96 persistent calls match their qualified graphs, scales, affinities and compact histories exactly. Every helix call retains its 20 successful retries among 81 attempts. All six checkpoint runs retain identical optimization payloads apart from timing. The author recalculated all **846 available full-payload certificates**; the remaining 4,320 attempts have summary/result regression evidence. Total numerical child wall time was 181 seconds. No numerical refusal, process failure or resource limit stopped this schedule.

The measurements support efficient bounded internal use on this Mac. They do not establish performance above 1,000 profiles, on other platforms, with arbitrary diagnostics or on new scientific geometries. Previously documented Python library warnings remain visible and unresolved at their low-level source; no warning was suppressed and no numerical policy was relaxed.

No optimization patch is proposed from these results. LP work dominates the larger native runs, while R graph conversion matters mainly when the engine itself takes only milliseconds. A numerical redesign requires its own compatibility study; it should be driven by a demonstrated application need. After independent acceptance with all findings closed, Stage 5 can test whether the accepted graphs help recover known geometry and prescribed smooth conditional means, compared with simpler alternatives.

## Evidence

The [prospective plan](../../stages/04-performance/PLAN.md), [maintained scripts](../../stages/04-performance/prepare.py), [complete summary](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage04-performance/summary.json), [launch and completion ledger](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage04-performance/ledger.json) and [individual timing rows](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage04-performance/timing-rows.json) identify the conditions and results. The prior [package audit](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/auditor/review-stage03-package/audit.md) qualifies the reused Mac R build. This report does not add a public export or expand R's limits.
