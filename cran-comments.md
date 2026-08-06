## Submission

This is a resubmission of the new package `dgraphs`, which constructs and
analyzes graphs derived from numerical observations.

## Changes in response to CRAN review

* Added four methodological references to the `Description` field using DOI
  links in CRAN's requested format.
* Added and expanded `\value` documentation for every Rd file containing a
  function usage section, including all five files identified by CRAN. The
  documentation now states the returned class or structure and its meaning, or
  documents an invisible return used by print and plot methods.
* The example for `remove.knn.outliers()` now saves and restores the user's
  graphical parameters.
* `get.edge.weights()` no longer registers or replaces the user's global
  `foreach` backend. Parallel work now uses a function-local cluster that is
  stopped with an immediate `on.exit()` registration. The remaining plotting
  helper that changes `par()` now also saves and restores all graphical
  parameters with an immediate `on.exit()` registration.
* Expanded `Authors@R` to identify the contributors and copyright holders of
  the bundled ANN and Spectra code. This includes Sunil Arya, David M. Mount,
  the University of Maryland, Yixuan Qiu, Anna Araslanova, Gael Guennebaud,
  Jitse Niesen, and the Netherlands eScience Center. The retained upstream
  notices and licenses are also summarized in `inst/COPYRIGHTS`.

## Test environments

* macOS 26.3.1 (Apple Silicon), R-devel 4.7.0 (2026-06-24
  r90190), Homebrew GCC 15.2.0, GNU Fortran 14.2.0:
  0 errors | 0 warnings | 2 notes
* GitHub Actions, Ubuntu, R-devel, R 4.6.1, and R 4.5.3:
  0 errors | 0 warnings | 0 notes on each configuration
* R-hub, R-devel:
  - Ubuntu 24.04.4, x86_64 (2026-06-21 r90185):
    0 errors | 0 warnings | 0 notes
  - Windows Server 2022, x86_64 UCRT (2026-08-05 r90355):
    0 errors | 0 warnings | 0 notes
  - macOS 15.7.7, x86_64 (2026-06-24 r90190):
    0 errors | 0 warnings | 0 notes
* win-builder, Windows Server 2022, x86_64 UCRT:
  - R-devel (2026-08-05 r90355):
    0 errors | 0 warnings | 1 note
  - R 4.6.1:
    0 errors | 0 warnings | 1 note
  - R 4.5.3:
    0 errors | 0 warnings | 1 note

## R CMD check results

0 errors | 0 warnings | 2 notes

## Notes

The local R-devel check reports the expected incoming-feasibility note:

```
Maintainer: 'Peter Gajer <pgajer@gmail.com>'

New submission
```

The second note is local-environment-only: the Apple-provided HTML Tidy is too
old for R-devel's HTML-manual validation. The PDF and HTML manuals were both
built successfully, and all Rd checks passed.

Win-builder's incoming-feasibility output also lists `Brito`, `Gower`, and
`Sauer` as possibly misspelled words; these are surnames of the cited authors.
The listed words `et` and `al` are the standard abbreviation "et al." used in
one citation. They are included in `inst/WORDLIST`.

## Additional checks

* `urlchecker::url_check()` reports that all URLs are correct.
* All 359 package expectations pass locally under R-devel.
