# Frozen quadratic-surface inputs

`v1/` is the unchanged shared test collection frozen in geosmooth. All original
identifiers, geometry, endpoint pairs, bounds, checksums and provenance are
preserved. Do not edit these files or regenerate their seal during migration.

The dgraphs solver comparison reads these inputs without using geosmooth.
The original constructor-validation tools remain with geosmooth until the
geometry and sampling migration; that stage should reconcile the two identical
read-only copies and move the validator with its dependencies. Scientific
papers and private reports do not belong in this directory.
