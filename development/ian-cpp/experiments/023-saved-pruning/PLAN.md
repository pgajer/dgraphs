# Saved-scale pruning comparison (Phase 07J)

Authorized 23 September 2026: replay the saved pruning calculation with the two already-certified scale vectors, without additional optimization. This bounded diagnostic is separate from the concurrently authorized internal dgraphs adapter.

## Question and fixed conditions

Does the certified near-optimal scale variation change the next retuning action or the conditional pruning decision at the saved Python-generated terminal problem of the 1,000-profile helix?

Use the exact feasible HiGHS-derived witness `bounds.json:q` and Clarabel-derived witness `saved-direction.json:clarabel_feasible_point` from Phase07I. Their certification refers to rational coordinates, the unchanged original LP and the narrowest frozen primary-objective band. Recheck those identities and exact inequalities, then explicitly record conversion to binary64 for the unchanged numerical decision routines. Rounded vectors are diagnostic inputs, not newly certified exact points.

Keep the Phase07F evaluated trace's processed distance matrices, initial edge set, degrees, upper scales, graph iteration, scale conversion, tuning multiplier and current bisection bracket fixed. Bind the original LP to solve number 25 byte-for-byte as parsed data. This solve precedes the first actual pruning decision: the reference performs further retuning. Therefore the pruning comparison is conditional and must not be described as the next action of a resumed trajectory.

## Prescribed calculations and controls

Compute Gaussian neighborhood volume ratios, positive-ratio median, the unchanged retuning convergence predicate, threshold and signed margins, threshold-only candidates, the median-driven fallback candidate rule, final ordered candidates, the first max(1, floor(0.1*n_candidates)) selected nodes, skipped overlapping removals and resulting edge set. Keep metric units and original profile indices; include readable specimen/profile mappings.

Use the unchanged pinned Python function bodies and the accepted native `numeric.hpp` functions for each calculation. Declare native/Python continuous agreement as absolute difference <= 1e-12 + 1e-12*abs(reference); require identical discrete candidate/removal sets and ordering for cross-implementation agreement. Report disagreement rather than adjust thresholds or reorder ties. Cross-witness differences are measured outcomes, not subject to a pass/fail equality requirement.

Controls: reproduce the saved raw solve-25 volume/retuning evaluation; reproduce the first actual saved pruning decision and removed edges using its later solve-29 scales. Add the existing six threshold/tie vectors from the accepted Phase05 stage fixture as inexpensive decision-order controls when available. No new solution, parameter search, interpolation sweep, full trajectory or graph expansion is allowed. Exactly two certified-witness evaluations per implementation, plus the two saved-state controls and six small fixed decision controls. Optimizer-call budget: zero.

## Evidence and interpretation

Commit the harness and this plan before executing the comparison. Save source/input hashes, extracted state, exact and rounded witness checks, all ratios/margins/orderings/removals, cross-implementation comparisons, environment and commands in a fresh private evidence directory. Existing reports, original payloads and audits remain read-only. Outputs are separately labeled as exact source witnesses, rounded numerical evaluations, controls and comparisons.

Identical endpoint decisions do not prove invariance throughout the objective band or later trajectories. Different decisions establish a concrete consequence at this fixed state, but do not select a preferred policy. No scale-selection rule, solver adoption or release gate changes. Study completion and independent acceptance remain separate.
