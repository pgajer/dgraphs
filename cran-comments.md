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

The copyright-holder name in LICENSE is corrected to Pawel Gajer, matching
Authors@R, following the maintainer's confirmation. The maintainer email is
pgajer@gmail.com.

The 0.2.0 fix for CRAN's LTO One Definition Rule diagnostic is preserved:
the unused conflicting `edge_t` was removed, and the MST helper type remains
renamed and confined to an unnamed namespace. No public functions are removed
in 0.2.1 and graph scoring/edge conventions are unchanged.

## Completed checks (2026-09-03)

* macOS 26.6.1, Apple Silicon, R-devel 4.7.0 (2026-06-24 r90190),
  Apple Clang 21 and GNU Fortran 14.2:
  full `R CMD check --as-cran`: 0 errors, 0 warnings, 1 note.
  Examples, tests, vignettes, PDF manual and HTML validation passed. HTML Tidy
  5.8.0 was selected explicitly with `R_TIDYCMD=/opt/homebrew/bin/tidy`.
* 432 test expectations: no failures, warnings or skips, under both the
  standard Clang build and a GCC 16.1 build with link-time optimization.
* Standalone ANN error-path tests passed with Clang AddressSanitizer and
  UndefinedBehaviorSanitizer, and with GCC 16.1.
* Documentation coverage includes all 86 exports and 36 registered S3 methods.
* GitHub Actions on Ubuntu, R 4.6.1, R-devel (2026-09-02 r90473) and
  R 4.5.3: 0 errors, 0 warnings, 0 notes for each configuration.
* R-hub Linux, R-devel (2026-09-02 r90473), GCC 13.3, and Windows,
  R-devel (2026-09-02 r90474 UCRT), GCC 14.3: both report Status: OK.
* R-hub macOS 15.7.9, Intel, R-devel 4.7.0, Apple Clang 17:
  Status: OK.
* Fresh isolated installations and test suites of owned downstream packages:
  gflow (1006 passes, 10 skips), gflowx (1568 passes, 3 skips), geosmooth
  (12058 passes, 1 skip), and gflowui (1579 passes, 1 skip), with no failures
  or warnings. Skips are declared by those packages. gflow's source-only
  documentation test required regenerating its help files; the failure also
  reproduced against dgraphs 0.2.0. gflowx/gflowui required current optional
  ivue in the isolated library. No downstream source fixes were required.
* Current CRAN metadata lists no hard reverse dependencies.

## Notes and compiler diagnostics

The incoming-feasibility note reports three days since the previous update.
This is a release-timing consideration, not an environment-only note. The
candidate is being prepared for a later submission; the interval and test
evidence must be refreshed at submission time.

An initial environment note about Apple's old HTML Tidy was resolved for the
final check by selecting the already-installed modern validator explicitly.
No user startup file was modified.

With suppression removed, the installed RcppEigen 0.3.4.0.2 headers expose an
unused-variable warning in SparseCore/TriangularSolver.h under Clang and
class-memaccess warnings in Eigen NEON headers under GCC. GCC's additional
`-Wextra` flags also report standard R/Rcpp native-registration function-pointer
casts. These diagnostics remain visible; none is suppressed by the package.
No ODR diagnostic was reported in the GCC LTO build.

## Evidence to refresh before upload

Win-builder responses are being collected for the source before the
copyright-name correction. That tarball was accepted for Win-builder release,
devel and oldrelease. These are pending evidence, not completed checks.
The completed external/downstream checks predate the copyright-name correction;
the rebuilt candidate differs only in LICENSE and the generated Packaged timestamp.
Historical 0.2.0 platform results are not presented as checks of this candidate.
