# Shared quadform geodesic test collection

Version **1.0.0**, frozen **2026-09-09**. This is a runnable, solver-independent
collection of scientific inputs, not a catalogue of methods or a completed
benchmark. All methods must use these same geometries, domains and endpoints.

## Frozen inputs

[v1/INDEX.md](v1/INDEX.md) lists the **30 cases and 197 unordered endpoint
pairs**, including **71 analytic controls**. Each pair has forward and reverse
queries, for **394 directed queries** (including identity controls).

- Flat controls in dimensions 2, 3 and 4, on balls and boxes.
- Isotropic paraboloids, saddles, anisotropic and cross-term forms; disks,
  squares and narrow rectangles; high-curvature and radius-64 cases.
- Higher-dimensional mixed forms and a two-form, codimension-two surface.
- Boundary, coincident and near-coincident endpoints, triangle checks,
  rigid-frame invariance, physical scaling and nested-domain comparisons.
- Six recovered mesh-refinement outlier pairs and one recovered
  zero-path-segment failure pair from the September embedding study.
- Two short/long pair sentinels per historical saddle cloud, explicitly not
  claimed to be the original offending pairs, which were not retained.

Four additional **opt-in full-cloud workloads**, each with 240 saved points
and 28,680 unordered pairs, preserve the larger workloads. They are not part
of the default 394-query result template or its completion verdict. A saved
duplicate-interior-vertex starting path provides a separate robustness input;
it is constructed, not a recovered optimizer trajectory.

The embedding convention is
`F(u) = Q * (u, u^T A1 u, ..., u^T Am u) + offset`, with **no implicit 1/2**.
`Q` is an isometry. Distances mean Euclidean arc length along this embedded
surface, constrained to its declared parameter domain.

**The surface domain is the closed population domain supplied to the sampling
routine:** a disk/ball or rectangle/box. It is never reconstructed from sample
extrema, triangulation faces or a sample convex hull. Sampling density does
not further constrain paths. The historical study's saved faces are retained
for provenance only; its old hull-based reference distances are not truth for
the new square-domain problem. See [v1/provenance.json](v1/provenance.json).

## Files and integrity

- [v1/collection.json](v1/collection.json): explicit forms, frames, domains,
  endpoint coordinates, analytic values, bounds and cross-case relations.
- `v1/source_inputs/`: original scientific CSV snapshots. No private checkout
  or original random-number generator is needed to consume the collection.
- `v1/manifest.json` and `v1/SEAL.sha256`: payload sizes and SHA-256 hashes,
  plus a checksum of the manifest. These detect drift, not malicious resealing;
  version control provides the reviewed provenance.
- `collection.R`: reader, package geometry adapter and consistency checks.
- `verify.R` and `test_collection.R`: read-only fixture checks and validator
  regression tests. The latter use mock answers, never benchmark evidence.
- `freeze_v1.R`: explicit deterministic construction recipe. Verification does
  not regenerate fixtures, and the builder refuses an existing destination.

Do not edit `v1/` in place. Changed inputs, domains or expectations require a
new collection version; preserve the old release and record the reason.
Reference this one canonical directory from method workspaces, rather than
maintaining independently edited copies. Track these small scientific sources
and fixtures; keep internal agent reviews outside the package repository.

## Run the checks

From the repository root, with the package's development dependencies and
`jsonlite`, `digest` and `pkgload` installed:

```sh
make test-quadform-fixtures
Rscript dev/shared/fixtures/quadform_geodesics/verify.R --template /tmp/quadform-results.csv
Rscript dev/shared/fixtures/quadform_geodesics/verify.R --results /tmp/quadform-results.csv
```

The verifier loads the checkout without recompiling it; an up-to-date local
package compilation is needed for package loading. Template generation refuses
to overwrite an existing file. It initializes every query as `not_run`, not
as success. Keep result files outside the sealed `v1/` directory.

Use one result file per method/configuration. Preserve every query and its
collection checksum, including failures and unsupported cases. Executed rows
need a method name, solver revision and finite nonnegative elapsed seconds.
Only `ok` rows may contain distances; `failed` and `unsupported` rows need a
diagnostic. Accompany results with the configuration, software environment,
hardware, seed (if any), discretization/refinement settings and runtime-budget
convention so another worker can reproduce that particular run.

Exit status is **0** for successful fixture verification (or a complete,
consistent submitted result set), **1** for validation errors, and **2** for
a valid but incomplete result set. `failed`, `unsupported` and `not_run`
remain incomplete; omitting them cannot improve reported coverage.

## What a pass means

Known exact distances cover flat surfaces, identity, straight saddle rulings
and isotropic apex-to-point radial arcs. Other distances are explicitly
**unknown**. Every pair has an ambient-chord lower bound and a straight
parameter-segment lifted-length upper bound, independently integrated from
the declared forms. Balls and boxes are convex, so that upper-bound path is
feasible. The verifier also checks the package embedding and segment-length
adapter against those independent calculations.

Submitted distances are checked for finite nonnegative values, identity,
positive separation, geometric bounds, analytic agreement, symmetry, available
triangle inequalities, scaling/isometry and domain inclusion. Numerical
comparison tolerance is `1e-12 * case_length_scale + 1e-8 * abs(reference)`;
identity must be exactly zero. The collection records the scale for each case.
This is a strict consistency gate, not a discretization error allowance.

**Passing does not certify unknown curved distances or global optimality.**
This first release does not execute solvers, validate returned trajectories,
test convergence under refinement, or enforce full-cloud runtime budgets.
Solver adapters must separately check both endpoints, containment of the
entire returned path (not only its vertices), independently integrated length,
and refinement/multistart evidence. Those results and robustness/full-cloud
outcomes must not be implied by the distance-only verdict.

For an explicit reconstruction check, build into a fresh scratch directory:

```sh
Rscript dev/shared/fixtures/quadform_geodesics/freeze_v1.R --output /tmp/quadform-v1-rebuilt
diff -r dev/shared/fixtures/quadform_geodesics/v1 /tmp/quadform-v1-rebuilt
```

The bundled source snapshots are used by default. Byte-for-byte reconstruction
is checked with the release toolchain; numerical/library changes can affect
serialization or quadrature. The committed, sealed payload remains authoritative,
and a different reconstruction must never silently replace it.
