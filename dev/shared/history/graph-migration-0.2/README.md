# Historical graph migration oracle

These scripts record the 0.2-era migration from a pinned gflow implementation.
They compare entire legacy objects and intentionally preserve that historical
interface. They are not tests of the breaking 0.3.0 API and must be run from the
corresponding pre-0.3 source revision, where their original location was
`tests/migration`. Git history retains that executable arrangement.

Current behavior is tested in `tests/testthat`, including independent native
versus R endpoint comparisons, graph stage round trips, nearest-neighbor tie
fixtures, cache invalidation, and explicit errors for removed interfaces.
The pinned legacy oracle does not establish downstream compatibility.
