# dgraphs

`dgraphs` is the home for data-derived graph construction utilities split out
from `gflow`.

The package now contains local ANN-backed MkNN, intersection-kNN,
graph-geodesic kNN, radius, adaptive-radius, SkNN, and MST-completion graph
constructors.

## Project Notes

- [radEmu implications for dgraphs](docs/radEmu_compositional_implications_for_dgraphs.md):
  notes on how sample mean efficiency, taxon-specific efficiency, and closure
  affect kNN and related graph construction for compositional microbiome data.
  HTML companion:
  [docs/html/radEmu_compositional_implications_for_dgraphs.html](docs/html/radEmu_compositional_implications_for_dgraphs.html).

Planned migration sequence:

1. Keep DG3/DG4 parity tests against the original `gflow` implementations.
2. Audit downstream scripts against `dgraphs`.
3. Remove migrated graph-construction exports from `gflow` after downstream
   scripts have switched to `dgraphs`.
