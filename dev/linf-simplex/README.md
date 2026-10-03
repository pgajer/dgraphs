# Exact Euclidean-length geodesics on the max-normalized simplex

`linf.simplex.distances()` maps each nonzero nonnegative row to
`u = x / max(x)`. It computes intrinsic **Euclidean** length on the union of
faces `u_i = 1`, with all coordinates in `[0,1]`. It is not an L-infinity
length metric, a nearest-neighbor graph, or a sample-density approximation.
It supports dense matrices, source/target blocks, explicit pairs, and returned
piecewise-linear paths. Coordinates absent from both samples can be omitted
from the search, while still being present in returned paths.

## Derivation

Write the endpoint deficits as `a = 1-u`, `b = 1-v`. The surface is the union
of coordinate-zero faces of the nonnegative orthant, truncated at coordinate
one. A shortest path need not revisit a face: replace the subpath between two
visits by its straight chord inside that convex face. Thus we need only
consider face sequences with distinct indices.

For a sequence `f_0,...,f_r`, with `a[f_0]=0` and `b[f_r]=0`, unfolding across
successive right-angle faces gives a Euclidean endpoint separation whose square is

```
L^2 = ||u-v||_2^2 + 2 C
C = sum_{k=0}^{r-1} a[f_{k+1}] (b[f_k] + b[f_{k+1}]).
```

Every path with that sequence has length at least this unfolded separation.
Minimizing C is a nonnegative directed shortest-path problem on face indices,
with edge cost `w(i,j) = a[j]*(b[i]+b[j])`, zero-cost initial labels at faces
with `a[i]=0`, and terminal faces with `b[j]=0`.

The lower bound is attained by a minimum-cost sequence. Its unfolded crossing
times are `t_k = a[f_k]/(a[f_k]+b[f_{k-1}])`. If two successive times were out
of order, then `a[f_k]*b[f_k] > a[f_{k+1}]*b[f_{k-1}]`. Removing face `f_k`
would decrease C, because the cost difference is

```
a[f_k]*b[f_{k-1}] + a[f_k]*b[f_k]
  + a[f_{k+1}]*b[f_k] - a[f_{k+1}]*b[f_{k-1}] > 0.
```

This contradicts minimality. Hence the unfolded straight segment crosses
faces in the required order. On a visited coordinate, the refolded deficit
falls linearly to zero, stays zero on that face, then rises linearly to its
terminal value. Other coordinates interpolate linearly. Every coordinate
therefore remains between zero and the larger endpoint deficit, at most one.
This constructs a feasible path attaining the bound inside the truncated
orthant, proving global optimality (in exact arithmetic).

Of initial faces only the one with smallest b can improve costs; of terminal
faces only the one with smallest a matters. Their direct sequence supplies an
upper bound at most one for C. An intermediate node with `a[i]*b[i] >= best`
cannot improve it. In particular, a feature zero in both original samples has
`a[i]=b[i]=1` and may be omitted. A shared endpoint face gives the ordinary
Euclidean chord immediately.

The C++ implementation uses double precision, deterministic index-order ties,
and Dijkstra search with those pruning rules. No nearest-face shortcut or
restriction to two or three faces is imposed. Runtime per pair is quadratic
in the union of nonzero features in the worst case; source blocks avoid
all-pairs output storage.

## Checks

`tests/testthat/test-linf-simplex.R` checks known two-feature distances,
same-face chords, an intermediate-face shortcut, independent constrained
path optimization in three features, returned endpoint coordinates, surface
membership along every segment, ordered crossing times, path lengths,
triangle inequalities, symmetry, rescaling, block and pair queries, and
invalid inputs. The source/target API is also used in the comb-V3V4-tx batch;
that application and its full-data timings are separate from package tests.
