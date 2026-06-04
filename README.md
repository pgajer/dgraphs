# dgraphs

`dgraphs` is the home for data-derived graph construction utilities split out
from `gflow`.

The package now contains local ANN-backed MkNN, intersection-kNN,
graph-geodesic kNN, radius, adaptive-radius, SkNN, and MST-completion graph
constructors.

Planned migration sequence:

1. Keep DG3/DG4 parity tests against the original `gflow` implementations.
2. Audit downstream scripts against `dgraphs`.
3. Remove migrated graph-construction exports from `gflow` after downstream
   scripts have switched to `dgraphs`.
