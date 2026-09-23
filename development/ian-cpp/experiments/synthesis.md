# What the IAN project has established

Audience: the scientific owner and future implementers/reviewers. The project has
a functioning, recoverable native implementation with substantial bounded reference
agreement. Its current obstacle is numerical scale selection and larger-trajectory
compatibility, rather than proof that C++ alone makes the solver faster.

## Evidence across questions

The early performance work separates process overhead from solver cost. Native
benchmark clients use less memory, while persistent runtimes are nearly equal.
The large historical speed discrepancy is reproducible through representation,
backend and thread changes in Python. None of this establishes complete-engine
memory gains. See IAN-EXP-001 through IAN-EXP-003.

Small and longer trajectories establish native/evaluated agreement, reusable-core
behavior and bounded restart correctness. Historical-expression arrays do not
always agree even where discrete decisions do. Operational acceptance is confined
to the specified host and failure paths. See IAN-EXP-004 through IAN-EXP-008.

Scale expansion exposes real refusals. Limited retry, normalization and eligibility
changes eventually complete the 500-profile helix, but the 1,000-profile attempt
disagrees across the preserved paths. Exact-input replay attributes the observed terminal
switch to an input perturbation on the tested builds. See IAN-EXP-009 through
IAN-EXP-015. These studies contain informative negative results, not erased failures.

Dual simplex is stable on the two fixed problems but differs from successful
Clarabel. Exact feasible witnesses then show a scale difference of at least 0.33435
within a guaranteed objective allowance of about 1.10503e-8. All six fresh range
endpoints fail exact feasibility; the attained-span claim comes from separately
repaired historical points, with fresh duals supplying outer bounds. This shows
weak determination within a stated band, not multiple exact optima. See IAN-EXP-016
and IAN-EXP-017.

The new zero-solver comparison uses those two certified witness vectors at the
saved graph. Both rounded vectors require further retuning and conditionally
remove the same 52 edges, with identical candidate and removal order. Python and
native calculations agree. The actual later first-pruning control removes 47
edges after additional retuning. This distinguishes fixed-state insensitivity at
two endpoints from the complete-trajectory question studied next. See
[IAN-EXP-023](023-saved-pruning/report.md); independent review is pending.

## Decisions and limits

Keep the scale ladder gated. Any secondary selection rule is an explicit policy
change needing fixed-problem tests and later trajectory/pruning comparison.
Do not adopt HiGHS, loosen a status requirement or select favorable rounded
coefficients merely because a diagnostic succeeds. The internal dgraphs adapter
now has independent bounded macOS arm64 acceptance, including the pinned C/Rust settings
layout repair and actual settings capture. Four small reference outputs reproduce
exactly, and initial/final graphs are returned separately. See
[IAN-EXP-024](024-internal-dgraphs-adapter/report.md). Broader
portability remains pending; a separate typed R 4.5.2 seven-case subset passes on the same Mac. Engine acceptance does not resolve downstream estimator
conditioning, assay matching or biological validity.

## Figures for discussion

Use the historical-runtime comparison to explain attribution; the scale-coverage
matrix to show why completion and acceptance differ; the exact-input/interface
comparison to isolate the perturbation; and the certified range plot to distinguish
attained spans from outer bounds. The illustrated selection includes limitations
and documentary readiness. All are newly reconstructed presentation assets pending
independent review, based on previously audited evidence. No figure implies new
optimization or scientific validation.

## Typed core follow-up

The authorized internal-message refactor replaces JSON inputs, decisions, solver
records and observer messages with typed C++ structures. Direct R diagnostics and
all four full reference traces remain exact apart from timing/build metadata. Disk
checkpoint/resume and failure checks pass; JSON remains at explicit persistence
and legacy test boundaries. See [IAN-EXP-025](025-typed-core-messages/report.md).
Independent review accepts this bounded macOS arm64 implementation evidence,
including the additional R 4.5.2 subset. The maintained catalogue presentation
remains unreviewed; there is no measured performance claim or change to the scale gate.

## Focused helix continuation

The new [arithmetic study](026-helix-arithmetic/report.md) traces the mismatch to
rounding of a squared distance. Matching Python's system-power convention makes
both engines complete the 1,000-profile helix with identical scales, 47 pruning
steps and final affinities. Matching multiplication makes both refuse at the
original point. All 446 fresh attempts are accounted for, and the four small
paired controls pass. This explains the specific interface discrepancy on this
host; it does not prove arithmetic robustness, cross-platform equivalence or
invariance across all near-optimal scale choices. Independent review accepted this bounded study and its current report/figure with
no corrective findings. Wider regression and portability qualification precede any
promotion of this candidate or reopening of the ladder.
