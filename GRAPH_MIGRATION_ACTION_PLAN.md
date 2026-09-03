# Graph ownership and migration compatibility

`dgraphs` owns data-derived graph construction, graph utilities and graph
diagnostics migrated from `gflow`. It is self-hosted and must not acquire a
runtime dependency on `gflow`.

## Ownership boundary

Generic adjacency, edge, conversion, distance, path, geodesic, spectrum,
embedding, endpoint and graph-selection operations belong in `dgraphs`.
Flow-specific basin membership, complex construction, trajectories and
flow-aware associations remain in their owning packages. Compatibility
wrappers in downstream packages must delegate rather than duplicate migrated
implementations.

## Migration sequence

The historical migration proceeded through pure-R graph utilities (DG1),
small native utilities (DG2), ANN-backed kNN and radius constructors (DG3),
intersection and geodesic kNN constructors (DG4), removal of the runtime bridge
(DG5), and graph utility/documentation consolidation (DG6). Subsequent ownership
changes should preserve these boundaries and the validation contract below.

## Validation contract

1. Preserve graph semantics, object fields, lifecycle stages, index conventions
   and edge weights unless an explicitly documented API change is intended.
2. Run `Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/testthat")'`.
3. Regenerate documentation with `Rscript -e 'roxygen2::roxygenise()'` after
   documented API or registration changes.
4. Run a source-package check after native, dependency or interface changes.
5. For migration work, run `Rscript tests/migration/run_gflow_parity_tests.R`
   against the pinned historical reference. The reproducibility tests remain
   outside ordinary package checks.
6. Check affected downstream packages and their basin/complex boundary tests;
   generic graph ownership changes must not alter flow-specific results.

Public validation scripts belong in the repository. Historical execution logs,
ownership ledgers, prompts, and internal reviews do not form build dependencies.
