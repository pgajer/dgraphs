# Graph API redesign for dgraphs 0.3.0

Status: implemented for the 0.3.0 release candidate. Breaking changes are
intentional. Removed functions, arguments and graph payload fields have no
compatibility wrappers, aliases or automatic translation. The sections below
record the accepted design; validation and downstream follow-up are recorded
in [the implementation report](graph-api-validation.md).

The purpose is to let callers use the same graph operations across constructor
families without remembering each family's list-field names. This also removes
an inconsistency in neighborhood size when an intersection graph is rebuilt
using graph distances.

## 1. A common graph object and a small set of accessors

Introduce a `dgraph` base class. Every graph constructor, including basic
fixtures, should return this class; constructor-specific classes may precede
it for specialized print or summary methods. A sequence is a collection of
graph objects, not itself a graph. Path-search results remain separate result
objects and contain their graph explicitly.

Use a constructor for user-supplied lists:

```r
# Public graph accessors.
dgraph(adj.list, length.list = NULL, edge.attributes = list())
graph.adjacency(graph, stage = "final")
graph.lengths(graph, stage = "final")
graph.edges(graph, stage = "final")
graph.order(graph)
graph.stages(graph)
graph.edge.attribute(graph, name, stage = "final")
```

| Entry point | Contract |
|---|---|
| `dgraph()` | Validate and construct an undirected simple graph from aligned lists. Every list element represents a vertex, including isolates. |
| `graph.adjacency()` | Return a list of 1-based integer neighbor vectors, one per vertex. |
| `graph.lengths()` | Return aligned finite, nonnegative edge-length lists, or `NULL` for a graph that has no lengths. Never substitute overlap scores, conductances or unit lengths. |
| `graph.edges()` | Return one row per undirected edge, ordered by `from`, then `to`, with `from < to`. Include a `length` column when lengths exist and named columns for other scalar edge attributes. An edgeless result retains its column types. |
| `graph.order()` | Return the number of vertices, including isolates. The number of undirected edges is `nrow(graph.edges(graph))`. |
| `graph.stages()` | List the stages actually stored; inspecting stages performs no graph reconstruction. |
| `graph.edge.attribute()` | Retrieve an explicitly named, aligned attribute list such as `overlap` or `conductance`. Reject an absent attribute. |

These accessors should initially be ordinary functions validating the common
class, not seven extensible S3 generics with family-specific field-detection
methods. Constructor-specific methods can use them. A common representation
eliminates the need for a growing list of exceptions like the current class
switch in [graph stage lookup](../../R/geodesic_distances.R).

Keep the base object compact and consistent:

```r
list(
  n.vertices = n,
  stages = list(
    final = list(
      adj.list = ...,
      length.list = ...,
      edge.attributes = list(overlap = ...)
    )
  ),
  metadata = list(...)
)
```

Expose the accessors as the supported way to read graph contents. Do not retain
the previous `$adj_list`, `$weight_list`, `$adjacency.list` or other duplicate
field spellings. Native results can be converted once by the internal
constructor; callers should never need to know native field names.

Retain the existing stage names `raw`, `pruned`, `raw.repaired`,
`pruned.repaired`, `repaired.pruned` and `final` to avoid changing a useful
vocabulary. Every graph has `final`. A request for a missing stage is an error,
not a fallback to final, and accessors never prune, repair or recompute it.
All stored stages share the same vertex order. Subgraph extraction produces a
new object with explicit original-vertex mapping.

Validate lists together: row counts, neighbor indices, per-row lengths,
reciprocal edges and values, no duplicate neighbors, and no self-loops. Reject
invalid input rather than silently dropping a duplicate neighbor while leaving
its length in place. If neighbors are sorted, apply that permutation to every
aligned length and attribute. Allow zero edge lengths for coincident points;
keep a stored zero-length edge distinct from a missing edge. Topology-only
graphs have `length.list = NULL`. A length-based path operation must reject
such a graph; hop distance must be requested explicitly.

The first common class should support undirected simple graphs only, matching
the main construction workflows. Do not add a `directed` switch until the
algorithms actually implement its contract. `convert.to.undirected()` can
remain a raw-list utility for explicitly preparing asymmetric input.

## 2. One spelling for each input type

Use dotted R argument names, matching most existing public functions. Keep
most function names intact; this proposal does not impose a package-wide
function-name rewrite.

| Meaning | Proposed spelling | Existing spellings to replace in that role |
|---|---|---|
| A complete graph object | `graph` | `gflow.graph`, `S.graph`, `G`, and a graph hidden in a generic `x` argument where S3 does not require that name |
| A bare adjacency list | `adj.list` | `adjacency.list`, or `graph` when the argument actually requires a bare list |
| Aligned additive edge lengths | `length.list` | `edge.lengths`, `edge.length.list`, `weight.list`, `weights.list` when these are used as lengths |
| Two raw graphs being compared | `adj.list1`, `length.list1`, `adj.list2`, `length.list2` | `graph1.adj.list`, `graph1.weights`, and corresponding graph2 spellings |
| Two complete graphs being compared | `graph1`, `graph2` | Mixed complete-object and raw-list arguments |
| A path-search result | `path.result` | `pg`, or `x` outside required S3 generic signatures |
| Neighborhood sizes for a sequence | `k.values` | `kmin`/`kmax` public pairs and their stored attributes |
| Neighborhood size used to construct an auxiliary graph | `k.graph` | Uppercase `K` alongside lowercase query `k` |

Retain S3-required `x`, `object` and `...` signatures for `print`, `summary`
and `plot`; their conventions are not naming inconsistencies.

Make high-level operations consume `graph`; list-level utilities explicitly
consume `adj.list` and `length.list`. Do not give every function a union of
complete objects and bare lists, and do not permit an external length list to
silently override lengths already stored in a graph.

Examples of the proposed signatures:

```r
as_igraph(graph, stage = "final", ...)
graph.geodesic.distances(graph, vertices = NULL, stage = "final")
graph.connected.components(graph, stage = "final")

shortest.path(adj.list, length.list, vertices)
create.path.graph(adj.list, length.list, h)
wgraph.prune.long.edges(adj.list, length.list, alt.path.len.ratio.thld, ...)
extract.trajectory.edge.lengths(traj, adj.list, length.list, ...)
```

Here `...` abbreviates existing named controls in the proposal; it is not a
proposal to absorb obsolete arguments through R's `...`. Actual functions
should list their supported controls explicitly and fail on old argument
names. For example, convert raw lists using
`as_igraph(dgraph(adj.list, length.list))` rather than maintaining the current
`as_igraph(gflow.graph, weight.list = ...)` overload and legacy basin adapter.

Basic constructors return graph objects. Code needing just the list uses
`graph.adjacency(create.graph("chain", n))`. The generic `vertices()` remains
for result objects such as local-extrema results; it should not become a
second spelling of the graph adjacency accessor.

### Lengths and other weights are different quantities

The current [nerve constructor](../../R/basic_graphs.R)
uses overlap cardinalities as weights. Those are not distances. Store them as
`edge.attributes$overlap` with `length.list = NULL`. Intersection-neighbor
graphs may store both a metric `length.list` and an `overlap` attribute.
Store connection strengths as `conductance` when that interpretation is
intended. Any conversion from lengths to conductances must be explicit and
must define what happens at zero length.

Generic weighted-matrix conversions may retain `weight.list` because their
values genuinely need not be lengths, but should remain clearly separated
from metric-graph constructors. Do not use a mechanical global replacement
of every occurrence of “weight” with “length”. For graph layouts, name the
selected edge quantity and any reciprocal transformation explicitly instead
of guessing its meaning from whichever field is available.

Use `graph.edges(graph)$length` as the ordinary unique-length extractor.
Retire the overlapping public `get.edge.weights()` and
`extract.edge.lengths()` entry points once their callers have been migrated.
For non-length values, select the named attribute column in `graph.edges()`.
No obsolete function is kept as a forwarding wrapper.

## 3. Neighborhood size means the number of other vertices

Adopt the following single rule for coordinate and graph-geodesic
intersection workflows:

> `k` is the requested number of nearest **other** vertices. An intersection
> neighborhood is the vertex itself plus those neighbors.

For vertex i, let N_k(i) contain k other vertices under the selected metric.
Define the cover set C_k(i) = {i} union N_k(i). Two distinct vertices are
adjacent exactly when their cover sets intersect. Membership of i in its own
cover set does not create a self-loop in the output graph.

| Workflow | Before 0.3.0 | 0.3.0 support size |
|---|---|---|
| `create.single.iknn.graph(X, k)` | Requests k + 1 search results, intended to include self | Self explicitly inserted plus k other vertices |
| `create.iknn.graphs(X, ...)` | Same coordinate convention | Same rule for every value in `k.values` |
| `create.geodesic.iknn.graph(graph, k)` | Takes k finite vertices total, normally including self | Self explicitly inserted plus k other finite vertices |
| `create.iterated.iknn.graphs(X, ...)` | Initial coordinate step and later graph steps use different counts | Same requested non-self count at the initial step and every rebuild |

The distinction follows the R coordinate calls and
[geodesic neighbor selection](../../src/geodesic_iknn_graphs.cpp).
The current geodesic implementation sorts all finite vertices by distance and
index, then truncates. With zero-distance ties, this can even exclude the
source itself. The new rule removes self by identity before selection, then
adds it explicitly, so tied or coincident points cannot change the convention.

For a connected graph with distinct points, old geodesic `k = 6` normally
corresponds to new `k = 5`. Old geodesic `k = 1` creates singleton covers and
no intersection edges; new `k = 1` includes a nearest other vertex and can
create edges. There is no supported new `k = 0` compatibility setting.
Changes in an iterated sequence propagate into subsequent distances and
neighborhoods; old experiment results must not simply be relabeled.

### Boundaries, disconnected components and ties

- Require integer `1 <= k < n`; sequence `k.values` is an explicitly supplied,
  strictly increasing vector of unique valid integers.
- Self never counts toward k. Distinct observations at distance zero do count.
- For graph distances, only finite-distance other vertices are eligible.
  By default, error before construction if a component has fewer than k + 1
  vertices. Report the affected component sizes.
- Offer `small.component = "truncate"` only as an explicit alternative to the
  default `"error"`. Use every reachable other vertex in an undersized
  component and record `effective.k` per vertex. An isolated vertex has
  effective.k zero and the singleton cover containing itself. No artificial
  infinite-distance neighbors or implicit connectivity repair are allowed.
- Break equal-distance ties by ascending 1-based vertex index, preserving
  exactly k neighbors. This makes results deterministic for a fixed row order;
  it does not promise invariance to permuting tied rows.
- Exact and ANN-backed exact searches must honor the same tie rule. Sorting an
  arbitrary set of k returned candidates is insufficient when the kth distance
  is tied: collect all boundary ties or use an exact fallback. Approximate
  search, if retained, must be explicitly requested and cannot promise the
  same graph as exact search.

Store the requested `k`, per-vertex `effective.k`, metric identity, tie rule
and explicit self-inclusion policy in neighborhood metadata. Cached neighbor
matrices contain only non-self neighbors; invalidate old caches by updating
the cache format/convention version. Cache reuse also requires the same point
values and row order, metric, preprocessing and adequate maximum k. A change
to graph edges or lengths invalidates a cached graph-distance neighborhood.

Use the same helper to implement the rule in single, plural and iterated
constructors. Remove public/internal metadata that makes users reason about
`k_internal`. Native search allocation can use extra slots internally, but
self insertion and counting must be explicit at the neighborhood boundary.

### Standardizing k does not standardize edge lengths

Keep the two existing edge-length definitions explicit in this change:

- Coordinate intersection edges use the minimum summed metric distance
  through a common neighbor, in the coordinates used for neighbor search.
- Graph-geodesic intersection edges use the previous graph's shortest-path
  distance between their endpoints.

These can differ even when the cover sets coincide. Unifying them would be a
separate algorithmic decision, not a consequence of consistent argument names
or neighborhood size. Neither length definition should be confused with the
number of shared neighbors stored in `overlap`.

## 4. Implementation and release plan

These changes are implemented for 0.3.0 before its first submission.
The version bump alone does not mean this proposal has been implemented or
that the package is available on CRAN.

1. Introduce the common graph constructor and accessors. Convert constructor
   results, stages and their print/summary methods to that representation.
   Keep path-search results and parameter sequences as clearly separate types.
2. Migrate all package functions, native-to-R result assembly, examples,
   tests, vignettes and development applications to the chosen spellings.
   Remove superseded exports and fields outright. Regenerate help and the
   audited function catalog; the current 117-export/37-method counts will change.
3. Apply the non-self k convention and explicit small-component policy across
   coordinate, geodesic and iterated construction. Version the caches and
   update fixtures affected by actual algorithm changes with an explanation.
4. Audit owned downstream packages for calls using old names or direct list
   fields. Migrate those call sites directly rather than creating adapters.
   geosmooth is already a known consumer, so an absence of outside users does
   not eliminate the need to update our own callers. Inventory first; do not
   presume that only its 25 imported geometry functions matter.
5. Check the exact resulting 0.3.0 source tarball locally and refresh external
   platform/downstream evidence before release. Once 0.3.0 is published,
   geosmooth should declare `dgraphs (>= 0.3.0)`.

Acceptance checks should establish behavior, not just renamed signatures:

| Check | What it establishes |
|---|---|
| Reciprocal adjacency and aligned lengths/attributes, including isolates and zero-length edges | The common representation preserves graph meaning. |
| Every retained stage round-trips through accessors and igraph conversion | Stage selection and conversion preserve topology and edge values. |
| Invalid or missing lengths and stages fail explicitly | Algorithms do not invent metric information or silently change stages. |
| Coordinate and graph-metric neighbor selection on the same distance matrix | Identical non-self counts, explicit self inclusion and deterministic ties. |
| k = 1, k = n - 1, duplicate coordinates and zero-distance graph vertices | Counting and self handling remain correct at boundaries. |
| Undersized components under both policies | Default exact-size failure and opt-in truncation behave as documented. |
| Single versus sequence versus iterated construction | The same k convention is applied at every entry point and iteration. |
| Cache hits agree with fresh computation; old conventions are rejected | Reuse cannot silently reinstate the previous semantics. |
| Removed names and obsolete named arguments fail | No compatibility wrapper or alias survives the migration. |
| Owned downstream checks | Known consumers use the new API directly. |

The version bump alone does not publish this API to CRAN. Known downstream
callers require migration before coordinated release.
