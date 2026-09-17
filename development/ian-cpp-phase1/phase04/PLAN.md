# Phase 04: bounded adaptive-trajectory coverage

Baseline: accepted phase 03 commit `7d030ff669be9e4a090ec75829c6477c25a7091c`.
This plan is committed before fixture generation or numerical execution.
The user authorized implementing the review-3 proposal on 2026-09-17.

## Frozen search and selection

Use the unchanged phase 03 **original-expression Python control** for selection.
Its executed IAN/adapter, Cython library, duplicate policy and all solver/algorithm
settings remain pinned. No candidate native execution or evaluated-Python result
is inspected before the selection manifest is saved. Retain actual input bytes,
identities, every reference trace, every failure and all search results.

Exactly six candidates, in this order, with no adaptive extension:

1. `density_patch_200`: a 20-by-10 grid on [0,1]^2, first coordinate raised to
   power 2.5, with independent normal jitter of standard deviation 0.003 from
   NumPy default_rng(2026091801). Euclidean metric.
2. `density_arms_240`: two 120-point circular arcs with angles
   0.12 + 2.68*t^2 and 0.12 + 2.68*(1-(1-t)^2), respectively, t=linspace(0,1,120).
   Radii 1 and 1.08; Euclidean metric. Opposite sampling gradients test density
   variation across close arms. No jitter or data-driven adjustment.
3–6. `hellinger_128`, `hellinger_192`, `hellinger_256`, `hellinger_300`:
   floor(linspace(0,499,n)) indices from the existing authorized PreSSMat
   `build/pilot-20260916-v1/pressmat_500_input.npz`. Save supplied compositions,
   Hellinger distances and representative IDs. Verify distances against the
   compositions; select without CSTs, outcomes or native agreement.

An eligible candidate completes successfully and every original-expression raw
primal and projected LP dual passes the existing independent numerical checks.
Count actual `pruned` events, removed edges, and additional retuning solves during
pruning: at iterations >0 outside final affinity retuning, solve count beyond the
first solve in each iteration. The coverage target is >=10 pruning iterations
and >=1 such additional solve. Also report retuning multiplier changes, bisection
updates and final retuning separately; these definitions must not be conflated.

Rank eligible candidates lexicographically by target reached (true first), then
pruning iteration count descending, additional pruning-retuning solves descending,
and frozen candidate order ascending. Select the first two, or fewer if fewer
are eligible. If none reaches the target, retain the top eligible comparisons as
limited evidence and explicitly report the unmet target; do not add inputs.
Selection is based exclusively on reference behavior. These are purposefully
selected stress tests, not representative performance samples.

## Comparison and changes

Retain phase 03 source and evidence unchanged. Add sources under phase04 and
generated outputs under worker/phase04 in new versioned namespaces. Reuse the
phase 03 Python controls, comparator and supervisor read-only. New native source
is a formatted, separated copy of the accepted source, with arithmetic and
control flow preserved. Separate input, durable I/O, engine and targeted-stage
code for inspection. Add only `scl`, `upper_units` and `upper_to_input_distance`
to the graph checkpoint: internal_distance = input_distance*scl, upper bounds
use internal_distance, conversion back is 1/scl. Other stage identities/hashes
remain explicit. This is metadata, not a new geometry/isolate policy.

Before any selected native comparison, run the new native executable on all four
unchanged phase 03 ordinary inputs and compare against the saved final native
baseline. Require exact numerical and discrete trace equality excluding timings,
and checkpoint equality excluding source hashes plus the three added metadata
fields. Read the graph checkpoint alone to verify the rescaling metadata. Source
and configuration hashes are expected to identify their actual revisions.

For selected inputs reuse the original-expression search trace, and run evaluated
Python then native once each. Compare every event using unchanged phase 03 exact
discrete requirements and floating limits (see phase03/PLAN.md and compare.py).
Do not loosen any limit. Apply external primal and dual checks to every raw
solve. Save the first differing event, preceding complete state, both intermediate
quantities and boundary margins; diagnose a mismatch before additional candidate
comparisons. Any corrective rerun must use a committed source and new namespace.

Record graph component counts and isolate identities at each iteration and after
each removal. Verify these directly from saved edges, rather than merely counting
reported labels. A reference-supported topology transition is compared if it
occurs. No new isolate policy or forced topology alteration is authorized.

Run the supplemented native stage checks against the retained Python results,
including explicit disconnected adjacency, and native operational injections
against the five-point input (invalid solver, after graph, after scales, after
affinity). Check the new graph metadata in partially completed runs too. One
native forced outer-cap diagnostic on the old Hellinger fixture retains the
existing cap semantics; ordinary settings stay unchanged.

## Accounting, limits and stopping point

Maximum ordinary workload: six original-expression selection runs, four native
regressions, two evaluated-Python and two native selected runs. The initial stage
recheck uses one optimization, operational injections eight, cap diagnostic one.
No extra ordinary timing repetitions, solver sweep, changes to settings, cohort
restart/recovery, production integration, R work, merge, automation or other
agent work. Compilation is separate. Timing and OS peak resident memory remain
diagnostic; no new performance claim is planned.

All source needed for each execution must be committed first; all bundles record
revision and input/configuration/executable hashes. Preserve phase 01–03 and
auditor artifacts. Report all selection attempts, coverage and failures,
three-condition comparisons, unchanged regression results, resource limitations,
and exact source-change/run chronology. Freeze final hashes and write a factual
handoff with limitations, commands, clean commit, immutable-baseline boundaries
and reusable-workflow classification. Stop for independent audit. A completed
bounded search that misses the coverage target is reported as such, never as
evidence for longer histories.
