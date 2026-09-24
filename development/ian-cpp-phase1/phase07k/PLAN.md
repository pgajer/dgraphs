# Helix arithmetic compatibility: bounded continuation

Authorized by the user on 23 September 2026. This is an experiment, not adoption
of a new numerical policy or authorization for the scale ladder/public export.

1. Reconstruct the two saved helix coefficient sets without solving. Record the
   exact binary64 arithmetic at the differing constraint and compare every saved
   coefficient against explicit square-by-multiplication and library-power rules.
2. Analyze the already audited eight fixed-problem solver histories, separating
   residual convergence from the original-unit acceptance certificate. Do not
   infer an unobserved internal termination branch from the final status.
3. Derive two disposable engine/reference pairs from Phase 07E. Change only the
   three constraint squares (distance, scaled distance and tuning constant):
   multiply(x)=x*x; power(x)=system libm pow(x,2). Disable C++ contraction and
   prevent optimization of pow into multiplication. Keep all solver settings,
   validation, retry eligibility, retry limit, graph rules and bounds unchanged.
   Observe and require the previously recorded native ABI dropzeros byte to be
   zero. These experiments retain the historical retry policy, not the strict
   policy used by the internal dgraphs adapter.
4. Execute six helix trajectories: preserved native/Python baselines and both
   interfaces under each square rule. Then run the power rule on both interfaces
   for the four original small examples. Compare full traces, accepted and
   rejected scales separately, every pruning decision, and final affinities.
   A refused trajectory is a valid study outcome; never accept a rejected return.

Maximum 14 engine invocations, 2,000 physical optimization attempts, 500 attempts
per invocation, 180 seconds per process, 900 aggregate child seconds, 4 GiB tree
RSS, 16 GiB study output, at least 20 GiB free space. A process finishing its last
permitted attempt must be reaped and accounted for before closing the budget.
Reserve invocations before launch; record every process including failures.
No additional solves to improve an inconvenient outcome. All read-only validation
and reporting is outside the solver budget. Source must be committed before runs.

Success requires each accepted payload to pass the unchanged scalar checks and
matching discrete decisions. Numerical comparisons retain the historical field
tolerances; exact coefficient equality is reported separately. Compare fresh
baselines to the saved traces (excluding time/provenance only). Study completion,
bounded compatibility, independent acceptance, and policy adoption remain separate.

All original evidence is read-only. New evidence belongs in a new directory under
`/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/helix-arithmetic/`.
