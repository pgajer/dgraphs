# Repository Instructions

## Scope

This repository is the development home for the `dgraphs` R package split
from `gflow`.

`dgraphs` owns data-derived graph construction utilities, including local
ANN-backed MkNN, intersection-kNN, graph-geodesic kNN, radius,
adaptive-radius, SkNN, MST-completion, graph utility, and graph diagnostic
code.

## Preferred Skills

- Prefer `$r-package-qa` for package QA, documentation drift, native build
  issues, and release-readiness work.

## R Style

- Prefer dot-delimited function and variable names for new R code.
- Keep public function names unchanged while moving methods from `gflow`; API
  cleanup should happen after the package is self-hosted and tested.
- Use leading-dot names only for private helpers.

## Package Hygiene

- Validate focused changes first:
  - `Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/testthat")'`
- Run `Rscript -e 'roxygen2::roxygenise()'` after exported API, native
  registration, or documentation changes.
- Run a package check equivalent after native code, dependency, or
  cross-package interface changes.
- Keep local build products, check directories, compiled objects, shared
  libraries, generated tarballs, and logs out of commits.

## Migration Discipline

- Follow `GRAPH_MIGRATION_ACTION_PLAN.md` for the DG phase sequence and
  validation contract.
- Do not create circular dependencies between `dgraphs` and `gflow`.
- Keep bridge functions only for unmigrated surfaces, and remove the bridge
  only once `dgraphs` is self-hosted for the relevant APIs.
- For native graph-constructor phases, preserve or add parity tests against
  the pre-migration `gflow` outputs before replacing old implementations.
- Do not silently change graph semantics, graph object fields, lifecycle-stage
  behavior, or edge/weight conventions during migration.
