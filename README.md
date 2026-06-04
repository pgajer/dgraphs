# dgraphs

`dgraphs` is the planned home for data-derived graph construction utilities
currently housed in `gflow`.

The package starts with bridge exports that delegate to `gflow`, plus vendored
ANN headers under `inst/include/ANN`. This lets downstream code move imports to
`dgraphs` before the ANN-backed native constructors are extracted from `gflow`.

Planned migration sequence:

1. Expose graph-construction APIs from `dgraphs` as compatibility bridges.
2. Migrate ANN-backed kNN, radius, adaptive-radius, and mutual-kNN native code.
3. Move MST repair and graph-pruning utilities needed by those constructors.
4. Remove graph-construction exports from `gflow` after downstream scripts have
   switched to `dgraphs`.
