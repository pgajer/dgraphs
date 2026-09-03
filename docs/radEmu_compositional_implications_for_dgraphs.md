# radEmu Implications for dgraphs

Written: 2026-06-25; public-source provenance checked: 2026-09-03.

Source basis: McLaren, Willis and Callahan (2019),
[Consistent and correctable bias in metagenomic sequencing experiments](https://doi.org/10.7554/eLife.46923),
and Clausen, Teichman and Willis (2025),
[Estimating Fold Changes from Partially Observed Outcomes with Applications in Microbial Metagenomics](https://arxiv.org/abs/2402.05231v2)
(the version-2 radEmu preprint) [@mclaren2019; @clausen2025].
See [BibTeX metadata](compositional-references.bib) and
[claim-level verification](compositional-citation-verification.html).
The graph implications and proposed stress tests below are deductions from
these measurement models, not graph-construction results reported by the papers.

## Main Implication

For `dgraphs`, the radEmu literature matters because graph construction can
turn measurement bias into geometry.  If kNN or radius graphs are built from
observed relative abundances, distances may reflect taxon-specific efficiency,
sample mean efficiency, and closure as well as biology.

This is especially important when efficiency varies with batch, condition,
subject state, location, or sequencing depth.  In that setting, a graph can
connect samples by measurement mechanism rather than biological proximity.

## Consequences for Graph Construction

- kNN graphs on proportions can be distorted by changes in taxa outside the
  focal signal because the denominator changes.
- Log-ratio or ratio-derived distances can cancel some sample-level effects,
  but only when the relevant relative efficiencies are stable.
- Mutual kNN, intersection kNN, and MST completion can stabilize graph topology
  but cannot by themselves identify biological distance under differential
  efficiency.
- Aggregated features should be treated as new measured variables with
  mixture-dependent effective efficiencies.

## Benchmark Additions

Useful graph-construction stress tests:

- compare graphs from true absolute abundances and observed biased compositions;
- vary sample mean efficiency along a latent manifold coordinate;
- introduce batch-correlated efficiency shifts and test whether graph components
  align with batch;
- compare proportion, log-ratio, and calibrated-distance graph inputs;
- quantify neighbor overlap between biology-scale and observed-scale graphs.

## Practical Rule

When building graphs for compositional microbiome data, record whether the graph
is intended to represent:

1. observed-composition similarity;
2. ratio-based similarity under stated efficiency assumptions;
3. biological proximity requiring calibration, controls, or sensitivity checks.
