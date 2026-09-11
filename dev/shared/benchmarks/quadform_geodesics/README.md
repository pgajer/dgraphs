# Quadratic-surface geodesic comparisons

The installed dgraphs package owns the internal `quadform_geodesics` interface,
the Single-point and Local-network refinements, their best-of-six combination,
Grid Dijkstra and the paraboloid Clairaut method. They estimate surface paths;
they do not certify global optimality. The package help documents their scope,
controls, error estimates and explicit unsupported results.

Run the small solver tests with `make test-quadform`. To compare all five methods
on the frozen collection, install this package into a dedicated library, set
`R_LIBS_USER` to that library, and run:

```sh
Rscript dev/shared/benchmarks/quadform_geodesics/verify.R /absolute/private/empty-output
```

The development runner additionally needs jsonlite. It resolves input paths
relative to itself, never loads a geosmooth checkout, and writes results only
to the supplied empty directory outside the repository. It checks endpoints,
domain membership, known bounds and independent lengths where applicable.
Randomized forward/reverse differences are observations, not failures.

Frozen v1 bytes remain unchanged. The older R reference/protocol tools and
geometry-constructor validation still reside in geosmooth pending the separate
geometry migration. Their historical qualification status is not changed by
this native-code move. Past private reports continue to describe the package
and source used at the time; they are not rewritten as dgraphs results.
