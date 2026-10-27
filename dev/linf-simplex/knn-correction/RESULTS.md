# Intrinsic simplex kNN correction — validation, 27 October 2026

The public simplex kNN graph interfaces now use the same intermediate-face
shortest-path solver as `linf.simplex.distances()`. The old endpoint-face-only
calculation has been removed. Every candidate is evaluated; self comes first
and equal-distance neighbors are ordered by row index. This is exhaustive search,
with quadratic pair count and row-wise distance storage, not approximate ANN.

The regression example uses (1,0,.99,0), (0,1,.99,0), and (1,1,0,1). The first
two points are separated by 1.01 sqrt(2), about 1.42836, via the third feature's
face. A route restricted to their endpoint faces has length 2 and gives the
wrong nearest neighbor. The corrected graph chooses the intermediate-face path.

Final targeted graph/native suite: **2,116 passed, zero failures/warnings/skips**.
This includes exhaustive comparisons across sparse, tied and one-dimensional
inputs; existing independent path-realization and constrained-optimization
checks; public single/sequence graph interfaces; malformed input controls; and
cache compatibility. Old simplex v3 caches are rejected; simplex v4 and existing
Euclidean v3 caches load. Near-one input rows are normalized and tiny admitted
negative values clamped, as documented.

Commands (from the package root, BLAS/OpenMP limited to one thread):

```r
pkgbuild::compile_dll('.', debug=FALSE)
pkgload::load_all('.', recompile=FALSE)
testthat::test_local('.',
  filter='knn|graph-api|linf|native-safety|endpoint-native|iknn',
  load_package='none', stop_on_failure=TRUE)
```

Roxygen documentation was regenerated from source (`load='source'`, avoiding
an unintended debug rebuild). `make audit-guides repo-hygiene` passed. A private
staged installation loaded successfully. These are targeted correctness and
installation checks, not a full CRAN release check or a runtime benchmark.
No cohort graphs, cached scientific results, or outcome models were rerun.
