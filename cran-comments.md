## Submission

This is a new submission of `dgraphs`, an R package for constructing and
analyzing graphs derived from numerical observations.

## Test environments

* macOS 26.3.1 (Apple Silicon), R-devel 4.7.0 (2026-06-24
  r90190), Apple clang 17.0.0, GNU Fortran 14.2.0:
  0 errors | 0 warnings | 0 notes
* macOS 26.3.1 (Apple Silicon), R 4.6.1, Homebrew GCC 15.2.0:
  0 errors | 0 warnings | 0 notes
* win-builder:
  - Pending.

## R CMD check results

0 errors | 0 warnings | 0 notes

## Notes

This is a new submission.

The local R-devel package check with remote CRAN incoming checks disabled
completed with `Status: OK`.

## Additional checks

* `urlchecker::url_check()` reports that all URLs are correct.
* Package tests pass locally.
* One downstream `gflow` test has an R 4.6.1 numerical-tolerance difference
  in a PHATE embedding test that does not exercise `dgraphs`; this result will
  be resolved or documented before submission.
