# First helix disconnections: saved-trajectory diagnosis

23 September 2026. The owner requests diagnosis of the pruning decisions that first disconnect the three Stage 5 helices. This is a new bounded descriptive study, IAN-EXP-032, after acceptance of all five continuation stages. No method change, optimization run, new dataset or estimator fit is planned.

## Question and fixed evidence

Use every saved native and evaluated-LP Python trace for the three 200-point two-turn helices (seeds 6101, 6102, 6103), plus their coordinates and intrinsic parameter from the accepted Stage 5 evidence. Preserve these source bytes and record hashes. Initial graph connectivity and final component counts come from reconstruction, not assumed summary labels. The accepted retry-power policy remains unchanged. The square and sphere are outside this diagnostic question; no favorable helix selection is permitted.

## Reconstruction and explanations

Reconstruct the graph before and after every pruning event, and after each ordered individual removal. Locate the first transition from one component to multiple components. Record every subsequent component-increasing removal for context. For each first-split batch, recover the preceding accepted scale vector, retuning exit, volume statistics, threshold/floor/conditional-cap logic, candidate ordering, top-ten-percent selection and incident-edge removal order. Independently recalculate volume ratios and decision statistics from saved distances/scales, check all pruning events against recorded decisions/removals, and compare both interfaces. Preserve numerical margins rather than classifying a near-boundary result as safely separated.

For each first-split edge report zero-based row indices, stable IDs, helix parameter and sorted-parameter ranks, Euclidean and intrinsic lengths, endpoint degrees/scales/statistics, which endpoint triggered removal, threshold margin, rank among candidates, and whether it was a bridge before the batch or became one during earlier removals. A bridge is an edge whose removal increases component count. Distinguish a genuinely consecutive along-helix link from a link between distant turns. Report sizes and parameter spans of the resulting components and whether any singleton is created.

Compute finite-pair fractions, finite-only intrinsic path errors, disconnected-pair-penalized distance loss and local ten-neighbor recall for initial, immediately before first split, immediately after first split (individual edge and complete batch), and final graphs. All edge weights are original Euclidean distances; reuse the declared Stage 5 metric definitions. Record threshold branch/margins and graph distance changes; these do not establish population causality or justify a new pruning policy.

## Diagnostic controls and bounds

Use simple path, cycle and a batch of two removals that jointly disconnect a cycle to check sequential bridge attribution. Validate constant graph/no-removal behavior, component partition equivalence without assuming identical component labels, and full edge-set accounting at every step. Cross-check connected components by an independent traversal and union-find implementation. State arithmetic tolerances explicitly; recorded candidate/removal identities must match exactly. No comparison involving rounding may erase a decision mismatch.

Bounded work: zero new engine or solver calls; three native/Python trace pairs at n=200; at most 120 seconds per analysis process, 2 GiB output and 4 GiB memory. Calculations are read-only and run serially. New private evidence goes under the dated pruning-diagnosis directory; failed attempts remain separate. Commit analysis source before running it. Commit the plan before implementation.

## Deliverable and interpretation

Produce a maintained catalogue report, a simple figure showing the first split on the helix and component history, machine-readable edge/decision/metric tables, source/evidence identity manifest and factual implementer handoff. Follow the existing PDF/render verification workflow. Ask the same independent auditor for review under the standing Audit Charter, resolve findings and record the disposition. The study is complete when the first disconnections are reproducibly explained; a finding that the reference faithfully removes useful bridges does not authorize a connectivity-preserving variant. Any variant needs a prospective contract and new confirmatory samples.
