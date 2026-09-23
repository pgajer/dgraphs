# Can the qualified retry and arithmetic rules be integrated into the typed IAN core?

IAN-EXP-027 · Continuation stage 1 · Aims IA1, IA2 and IA4 · 23 September 2026.

**The typed candidate and Python reference agree throughout the full bounded regression panel, including the 1,000-profile helix. R and checkpoint controls also pass. Independent audit is pending.** The strict baseline remains the default; the candidate is an explicit option, not an adopted replacement.

## Purpose and methods

The successful helix arithmetic study used an older experimental engine, while the maintained internal R adapter used the strict policy. This study brings the candidate into the typed core and R interface, retaining both policies. The candidate squares constraint quantities using the system power function and permits one normalized retry after an eligible rejected return. A retry must return strict solver success and pass the unchanged original-unit numerical checks. It never accepts the original rejected result. All 39 actual solver settings are retained, with the existing C/Rust layout guard.

The [prospective plan](../../stages/01-numerical-policy/PLAN.md) prescribed six difficult fixed LPs under two conditions, 86 no-solve classification cases, twelve saved boundary fixtures, six decision controls, eight complete regression examples, four 500-profile geometries and the frozen 1,000-profile helix. Fixed LP replays use Python; all boundary and complete candidate trajectories use both typed native and evaluated Python implementations. R comparisons cover the four original small examples and the 500-profile helix. The native checkpoint test cancels after a pruning boundary reached through successful retries and resumes to the uninterrupted endpoint.

## Results

All 26 paired fixture comparisons pass under the existing numerical and discrete rules. Their optimization coefficients are exactly equal across interfaces; accepted and rejected attempts and retry metadata agree, and dual vectors pass the comparison limits. The table describes one native execution per example; the corresponding Python execution matches.

| Example | Solver attempts | Accepted scale calculations | Rejected attempts | Pruning steps |
| --- | ---: | ---: | ---: | ---: |
| Perturbed PreSSMat, 256 profiles | 195 | 195 | 0 | 182 |
| Perturbed PreSSMat, 300 profiles | 189 | 189 | 0 | 176 |
| PreSSMat, 500 profiles | 405 | 405 | 0 | 396 |
| Helix, 500 profiles | 81 | 61 | 20 | 42 |
| Helix, 1,000 profiles | 112 | 66 | 46 | 47 |

The 1,000-profile helix finishes with 999 edges. Each of its 46 rejected returns is followed by one successful retry. All twelve fixed-problem replays reproduce the previously declared acceptance/refusal outcomes. All 86 C++/Python classification cases agree without optimization.

Four strict-policy R result objects exactly reproduce the preserved typed baseline after excluding timing/build metadata and the declared solve allowance. The corresponding fresh native/R traces are exact apart from timing when exported without rounding. Five candidate R examples agree with native traces. Summary diagnostics retain settings and retry metadata without dense backend vectors. Native cancellation/resume reproduces every subsequent event and the full result exactly apart from event timing. Altered policy, source, configuration and invalid attempt counts stop before solving. Invalid scales are refused without retry, and an observer exception after rejection prevents the next attempt.

Cumulative execution comprises **89 process launches: 12 fixed LP calls and 77 engine/probe/R launches, totaling 2,455 physical optimization attempts**. The latter includes zero-solve controls and one failed reference launch before execution. All processes have accounting records. The prescribed ceilings were 100 engine launches plus 24 fixed calls and 8,000 attempts. These are correctness runs, not a performance benchmark.

## Preserved failures and corrections

An eligibility-test source typo caused a compile failure, corrected before its successful zero-solve test. The first Python decision-control launch lacked a copied configuration file and stopped before optimization; its correction and continuation are recorded in [amendment 1](../../stages/01-numerical-policy/AMENDMENT-1.md). Completed fixed solves were not repeated.

The first R test-trace exporter rounded a multiplier from 0.6625000000000001 to 0.6625, failing an exact comparison despite unchanged saved R results. [Amendment 2](../../stages/01-numerical-policy/AMENDMENT-2.md) preserves that export and failed comparison. A 17-significant-digit exporter recovered exact native/R trace agreement from the existing RDS files, without new baseline solves. Neither correction changes the numerical policy or acceptance limits.

## Interpretation and remaining boundaries

This supports integration on the tested macOS arm64 host. It does not establish cross-platform power-function equivalence, robustness to every small input perturbation, uniqueness of local scales, or scientific utility. The reference panel produced no Python stderr warnings in this execution; that does not explain historical library warnings. Larger scale expansion remains pending audit and stage advancement.

The R tests use the candidate source wrapper and a freshly compiled module with the privately installed baseline dgraphs package. A fresh package installation and full package/platform qualification belong to stage 3. The unchanged pinned Rust archive was reused; it was not rebuilt here. Documentation regeneration passed with existing package compiler warnings. No public export or shared installation occurred. Native checkpoint support does not yet provide an R restart API.

## Evidence and reproduction

- [Cumulative summary](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage01-policy/summary.json) and [complete evidence identities](/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage01-policy/manifest.json).
- [Build and fixture derivation](../../stages/01-numerical-policy/prepare.py), [paired execution](../../stages/01-numerical-policy/run.py), [R and operational controls](../../stages/01-numerical-policy/supplement.py), [read-only finalization](../../stages/01-numerical-policy/finalize.py).
- [Typed policy and records](../../../../inst/ian/backend/core/include/ian/core.hpp), [solver implementation](../../../../inst/ian/backend/core/src/solver.hpp) and [R wrapper](../../../../R/ian_graph.R).
- [Project status and next steps](../analysis-queue.md).
