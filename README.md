# dgraphs

`dgraphs` is the home for data-derived graph construction utilities split out
from `gflow`.

The package now contains local ANN-backed MkNN, radius, adaptive-radius, SkNN,
and MST-completion graph constructors. Remaining intersection/geodesic kNN and
conversion utilities stay as compatibility bridges until their native
implementations are migrated.

Planned migration sequence:

1. Keep DG3 parity tests against the original `gflow` implementations.
2. Migrate remaining intersection/geodesic kNN constructors.
3. Remove migrated graph-construction exports from `gflow` after downstream
   scripts have switched to `dgraphs`.
