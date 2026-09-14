## dgraphs 0.3.0 release candidate

This release introduces a breaking common `dgraph` representation and stage
accessors, consistent `adj.list`/`length.list` arguments, increasing `k.values`,
and a uniform self-plus-k-other-vertices intersection convention. Superseded
interfaces are removed without wrappers. It also adds reusable synthetic
geometry, embeddings and point sampling
migrated from geosmooth, a symmetric-kNN parameter sequence, and two installed
vignettes covering the complete API and synthetic geometry workflows.
The geometry vignette includes six ivue galleries with 36 selectable 3D
examples and labeled coordinate axes; static projections are available when
the optional visualization packages are absent.
Statistical responses, truth, recipe registries and model fitting remain in
geosmooth; dgraphs has no dependency on geosmooth.

The release carries forward native ANN error-handling and ownership fixes,
serial construction with unsupported OpenMP branches removed, complete S3
method documentation and silent adjacency-list comparison by default. The
0.2.0 fix for CRAN's LTO One Definition Rule diagnostic remains intact.
LICENSE identifies Pawel Gajer as copyright holder, matching Authors@R.

## Completed local checks — 2026-09-14

Checked the source tarball dgraphs_0.3.0.tar.gz on macOS Tahoe 26.6.1,
Apple Silicon (aarch64-apple-darwin23), R-devel 4.7.0
(2026-06-24 r90190), Apple Clang 21.0.0 and SDK 26.5.

`R_TIDYCMD=/opt/homebrew/bin/tidy make check` builds the package and runs
`R CMD check --as-cran`. Result: 0 errors, 0 warnings, 1 note.
The note reports `ivue` under "Suggests or Enhances not in mainstream
repositories". ivue 0.1.0 is installed locally but was absent from the CRAN
source index checked on 2026-09-14. This new optional dependency must be
coordinated with the ivue release before submission.
All 2,626 test expectations passed with no failures, warnings or skips.
The installed self-containment script, examples, all three vignettes and their
rebuilds, PDF manual and HTML validation passed. All declared dependencies
were available locally. A separate forced-static render also passed.
All 36 interactive choices were exercised in a WebGL browser over local HTTP;
rotation, camera reset and examples from all six galleries were inspected.
The standalone HTML embeds its assets and has no local/private URLs.

The API catalog contains exactly one row for each of 122 explicit exports;
all 38 registered S3 methods have documented help references. Installed help
resolves for every export and method. Both new guides and the existing graph
workflow appear in the installed vignette index with HTML, Rmd and R sources.

The native installation emits 15 unused-variable diagnostics from RcppEigen
headers under Clang. These remain visible and unsuppressed; they did not
produce R CMD check warnings.

## Evidence still to refresh before submission

Resolve ivue repository availability before submitting this candidate.

A separate source-loaded pkgload debug run aborted at the existing native
invalid-matrix conversion test, including after a clean debug rebuild. The
standard optimized installation passed that test and the complete suite.
The debug-build-specific failure remains unresolved; it is not reported as
a passed configuration. See dev/design/graph-api-validation.md for the audit.

No Windows, Linux, other R-version, remote-builder or downstream checks were
run against this 0.3.0 candidate. Earlier platform checks concerned a different
maintenance candidate and are not presented as evidence for this tarball.
Refresh these checks, verify final release contents, and reconcile any private
submission correspondence before uploading. No CRAN submission was made here.

Once the release is available, geosmooth should require dgraphs (>= 0.3.0)
and refresh its CRAN-only dependency check. Local version metadata and a
successful local check do not establish CRAN availability.
