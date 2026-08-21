## Submission

This is a subsequent release of `dgraphs`. Version 0.2.0 deliberately removes
deprecated, superseded, and low-level public entry points introduced in the
initial 0.1.0 release.

## Changes in version 0.2.0

* Removed the deprecated `create.radius.graph()` and
  `create.adaptive.radius.graph()` wrappers. Their supported replacement is
  `create.rknn.graph()` with `type = "fixed"` or
  `type = "adaptive.radius"`, respectively.
* Removed the temporary public `cpp.create.rknn.graphs()` backend entry point.
  Its supported replacement is `create.rknn.graphs(backend = "cpp")`.
* Internalized three low-level helpers that were not intended as public API:
  `dist.to.knn()`, `euclidean.distance()`, and `graph.adj.mat()`.
* Removed the superseded `adjlist.to.igraph()` function and extended
  `as_igraph()` to convert bare adjacency lists with optional aligned weights.
* Removed four unused functions belonging to an incomplete graph-edit
  workflow: `graph.edit.distance()`, `load.graph.data()`,
  `calculate.edit.distances()`, and `create.distance.plot()`.
* Updated documentation, tests, installed-package self-containment checks,
  vignettes, and the package-paper materials for the revised API.

These removals are intentional breaking changes and are documented in
`NEWS.md`.

## Test environments

* macOS 26.6.1 (Apple Silicon), R-devel 4.7.0 (2026-06-24 r90190),
  Apple clang 21.0.0, GNU Fortran 14.2.0:
  0 errors | 0 warnings | 2 notes
* GitHub Actions, Ubuntu, R-devel, R release, and R oldrel-1:
  0 errors | 0 warnings | 0 notes on each configuration
* R-hub, R-devel, Linux, Windows, and macOS:
  0 errors | 0 warnings | 0 notes on each configuration
* Win-builder, Windows Server 2022, x86_64 UCRT:
  - R-devel (2026-08-17 r90424):
    0 errors | 0 warnings | 1 note
  - R 4.6.1:
    0 errors | 0 warnings | 1 note
  - R 4.5.3:
    0 errors | 0 warnings | 1 note

## R CMD check results

0 errors | 0 warnings | 2 notes

## Notes

The local R-devel check reports this incoming-feasibility note:

```
Maintainer: 'Peter Gajer <pgajer@gmail.com>'

Days since last update: 1
```

The second note is local-environment-only: the installed HTML Tidy is too old
for R-devel's HTML-manual validation. The PDF and HTML manuals were both built
successfully, and all Rd checks passed.

The single Win-builder note on each R version is the same incoming-feasibility
note shown above. All Win-builder examples, tests, vignettes, and PDF and HTML
manual checks passed.

## Additional checks

* All 381 package expectations pass locally under R-devel.
* The source tarball contains no compiled objects or shared libraries.
* The R Journal paper audit, including citation verification and the package
  article readiness scan, passes for version 0.2.0.
