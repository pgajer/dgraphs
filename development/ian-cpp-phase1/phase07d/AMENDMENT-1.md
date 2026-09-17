# Phase07D: status telemetry and partial-trajectory restart evidence

The 25 fixed solves completed as prescribed. Only units11 passes all five
problems; tighter stopping and tighter refinement both return AlmostSolved with
invalid stationarity on the unresolved problem. No other remedy qualifies.

The units11 full-helix attempts in trajectory-v1 make 30 attempts each. All 13
retries pass, initial tuning finishes and two pruning steps occur. The ordinary
attempt at pruning iteration 2 returns a nonoptimal status and is ineligible for
retry under the unchanged policy. Native and Python agree, including this stop.
No completed helix fit exists. The remaining 24 panel input specifications are
gated and will not be run unless the declared complete-helix gate passes.

The inherited trace schema collapses all nonoptimal backend statuses into one
label. Add the raw solver status as a metadata field, rebuild in build-v2 and
repeat the same two helix attempts in trajectory-v2. Require equality of every
existing trace field apart from timing; count all executions against the original
8,000-solve/3,600-second budget. This changes observation only, not numerical
policy, coefficients, eligibility or retry count. The full regression gate remains
unchanged. Preserve trajectory-v1 and build-v1 without alteration.

A natural successful-retry pruning boundary now exists even though the full run
fails. Exercise cancellation at that boundary and resume to the same terminal
refusal. Require concatenated trace and partial result to match uninterrupted
execution, including all policy and attempt metadata. Run the planned declaration,
eligibility, exhaustion, observer and checkpoint-mutation controls on this same
candidate. This establishes continuation to the tested refusal, not completion,
recovery from arbitrary failures or approval to retry a nonoptimal return.
No further setting, geometry, backend, retry eligibility or acceptance-limit
change is introduced. The unavailable successful full-trajectory/regression claims
remain explicit in the final report.
