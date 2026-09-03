## Update to dgraphs 0.2.1

This maintenance update fixes the type reported by summaries of empty local
extrema and hardens native error handling. ANN errors now propagate through
C++ exceptions to registered R entry points rather than returning silently.
Point/tree ownership and native kNN input validation were strengthened.

Global compiler-diagnostic suppression and unsupported native OpenMP branches
were removed. Native graph construction remains serial, as in the standard
0.2.0 build. Compatibility arguments remain accepted. Every exported function
and registered S3 method now has documented results and runnable examples.
Adjacency-list comparisons are silent unless `verbose = TRUE` is requested.

The 0.2.0 fix for CRAN's LTO One Definition Rule diagnostic is preserved:
the unused conflicting `edge_t` was removed, and the MST helper type remains
renamed and confined to an unnamed namespace. No public functions are removed
in 0.2.1 and graph scoring/edge conventions are unchanged.

## Completed checks (2026-09-03)

* macOS 26.6.1, Apple Silicon, R-devel 4.7.0 (2026-06-24 r90190),
  Apple Clang 21 and GNU Fortran 14.2:
  full `R CMD check --as-cran`: 0 errors, 0 warnings, 2 notes.
  Examples, tests, vignettes and PDF manual passed.
* 432 test expectations: no failures, warnings or skips, under both the
  standard Clang build and a GCC 16.1 build with link-time optimization.
* Standalone ANN error-path tests passed with Clang AddressSanitizer and
  UndefinedBehaviorSanitizer, and with GCC 16.1.
* Documentation coverage includes all 86 exports and 36 registered S3 methods.

## Notes and compiler diagnostics

The incoming-feasibility note reports three days since the previous update.
This is a release-timing consideration, not an environment-only note. The
candidate is being prepared for a later submission; the interval and test
evidence must be refreshed at submission time.

The other local note reports outdated HTML Tidy. Manuals build successfully,
but this local HTML validator does not supply validation evidence.

With suppression removed, the installed RcppEigen 0.3.4.0.2 headers expose an
unused-variable warning in SparseCore/TriangularSolver.h under Clang and
class-memaccess warnings in Eigen NEON headers under GCC. GCC's additional
`-Wextra` flags also report standard R/Rcpp native-registration function-pointer
casts. These diagnostics remain visible; none is suppressed by the package.
No ODR diagnostic was reported in the GCC LTO build.

## Evidence to refresh before upload

Current external Linux/Windows/macOS and R release/devel/oldrelease results,
downstream comparisons, and the maintainer's confirmation of the copyright
holder name must be recorded before this file is used for submission. Historical
0.2.0 platform results are not presented as checks of this candidate.
