#include "local_geodesic_pruning_r.h"

#include <R.h>
#include <Rinternals.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <functional>
#include <limits>
#include <map>
#include <set>
#include <utility>
#include <vector>

namespace {

struct edge_t {
    int u;
    int v;
    double weight;
    bool alive;
};

struct adj_ref_t {
    int vertex;
    int edge_id;
};

struct pruned_edge_t {
    int u;
    int v;
    double edge_weight;
    double alt_path_length;
    double path_edge_ratio;
};

struct dijkstra_workspace_t {
    std::vector<char> in_local;
    std::vector<double> dist;
    std::vector<std::pair<double, int>> heap;
    std::vector<int> touched;

    explicit dijkstra_workspace_t(int n)
        : in_local(static_cast<size_t>(n), 0),
          dist(static_cast<size_t>(n), std::numeric_limits<double>::infinity()) {}

    void set_dist(int vertex, double value) {
        if (!std::isfinite(dist[static_cast<size_t>(vertex)])) {
            touched.push_back(vertex);
        }
        dist[static_cast<size_t>(vertex)] = value;
    }

    void clear_distances() {
        const double inf = std::numeric_limits<double>::infinity();
        for (int vertex : touched) {
            dist[static_cast<size_t>(vertex)] = inf;
        }
        touched.clear();
    }
};

std::uint64_t edge_key(int u, int v) {
    if (u > v) {
        std::swap(u, v);
    }
    return (static_cast<std::uint64_t>(static_cast<std::uint32_t>(u)) << 32U) |
           static_cast<std::uint32_t>(v);
}

bool is_integerish(double x) {
    return std::isfinite(x) && x == std::floor(x);
}

int read_vertex_index(SEXP row, R_xlen_t pos, const char* name) {
    if (TYPEOF(row) == INTSXP) {
        const int value = INTEGER(row)[pos];
        if (value == NA_INTEGER) {
            Rf_error("%s contains NA vertex IDs.", name);
        }
        return value;
    }
    if (TYPEOF(row) == REALSXP) {
        const double value = REAL(row)[pos];
        if (!is_integerish(value)) {
            Rf_error("%s contains non-integer vertex IDs.", name);
        }
        if (value < static_cast<double>(std::numeric_limits<int>::min()) ||
            value > static_cast<double>(std::numeric_limits<int>::max())) {
            Rf_error("%s contains vertex IDs outside the integer range.", name);
        }
        return static_cast<int>(value);
    }
    Rf_error("%s must contain integer or numeric vectors.", name);
}

double read_weight(SEXP row, R_xlen_t pos) {
    if (TYPEOF(row) == REALSXP) {
        return REAL(row)[pos];
    }
    if (TYPEOF(row) == INTSXP) {
        const int value = INTEGER(row)[pos];
        if (value == NA_INTEGER) {
            return NA_REAL;
        }
        return static_cast<double>(value);
    }
    Rf_error("weight.list must contain numeric vectors.");
}

SEXP make_pruned_edge_stats(const std::vector<pruned_edge_t>& edges) {
    const int nrows = static_cast<int>(edges.size());
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 5));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 5));
    const char* name_values[] = {
        "u", "v", "edge_length", "alt_path_length", "path_edge_ratio"
    };
    for (int i = 0; i < 5; ++i) {
        SET_STRING_ELT(names, i, Rf_mkChar(name_values[i]));
    }
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(1);

    SEXP u = PROTECT(Rf_allocVector(INTSXP, nrows));
    SEXP v = PROTECT(Rf_allocVector(INTSXP, nrows));
    SEXP edge_length = PROTECT(Rf_allocVector(REALSXP, nrows));
    SEXP alt_path_length = PROTECT(Rf_allocVector(REALSXP, nrows));
    SEXP path_edge_ratio = PROTECT(Rf_allocVector(REALSXP, nrows));
    for (int i = 0; i < nrows; ++i) {
        INTEGER(u)[i] = edges[static_cast<size_t>(i)].u + 1;
        INTEGER(v)[i] = edges[static_cast<size_t>(i)].v + 1;
        REAL(edge_length)[i] = edges[static_cast<size_t>(i)].edge_weight;
        REAL(alt_path_length)[i] = edges[static_cast<size_t>(i)].alt_path_length;
        REAL(path_edge_ratio)[i] = edges[static_cast<size_t>(i)].path_edge_ratio;
    }
    SET_VECTOR_ELT(out, 0, u);
    SET_VECTOR_ELT(out, 1, v);
    SET_VECTOR_ELT(out, 2, edge_length);
    SET_VECTOR_ELT(out, 3, alt_path_length);
    SET_VECTOR_ELT(out, 4, path_edge_ratio);
    UNPROTECT(5);

    SEXP row_names = PROTECT(Rf_allocVector(INTSXP, nrows));
    for (int i = 0; i < nrows; ++i) {
        INTEGER(row_names)[i] = i + 1;
    }
    Rf_setAttrib(out, R_RowNamesSymbol, row_names);
    UNPROTECT(1);

    SEXP klass = PROTECT(Rf_mkString("data.frame"));
    Rf_setAttrib(out, R_ClassSymbol, klass);
    UNPROTECT(1);

    UNPROTECT(1);
    return out;
}

std::vector<std::vector<int>> exact_knn_index(const double* X, int n, int p, int k) {
    std::vector<std::vector<int>> out(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) {
        std::vector<std::pair<double, int>> distances;
        distances.reserve(static_cast<size_t>(n - 1));
        for (int j = 0; j < n; ++j) {
            if (i == j) {
                continue;
            }
            double d2 = 0.0;
            for (int col = 0; col < p; ++col) {
                const double diff = X[i + n * col] - X[j + n * col];
                d2 += diff * diff;
            }
            distances.push_back({d2, j});
        }
        auto distance_index_less = [](const auto& a, const auto& b) {
            if (a.first < b.first) return true;
            if (a.first > b.first) return false;
            return a.second < b.second;
        };
        if (k < n - 1) {
            auto kth = distances.begin() + k;
            std::nth_element(distances.begin(), kth, distances.end(), distance_index_less);
            std::sort(distances.begin(), kth, distance_index_less);
        } else {
            std::sort(distances.begin(), distances.end(), distance_index_less);
        }
        out[static_cast<size_t>(i)].reserve(static_cast<size_t>(k));
        for (int r = 0; r < k; ++r) {
            out[static_cast<size_t>(i)].push_back(distances[static_cast<size_t>(r)].second);
        }
    }
    return out;
}

double local_dijkstra_distance(const std::vector<std::vector<adj_ref_t>>& adj,
                               const std::vector<edge_t>& edges,
                               const std::vector<int>& local_vertices,
                               int source,
                               int target,
                               int excluded_edge_id,
                               double cutoff,
                               dijkstra_workspace_t& workspace) {
    for (int v : local_vertices) {
        workspace.in_local[static_cast<size_t>(v)] = 1;
    }

    auto cleanup = [&]() {
        for (int v : local_vertices) {
            workspace.in_local[static_cast<size_t>(v)] = 0;
        }
        workspace.clear_distances();
        workspace.heap.clear();
    };

    using queue_item_t = std::pair<double, int>;
    auto heap_greater = std::greater<queue_item_t>();
    workspace.heap.clear();
    workspace.set_dist(source, 0.0);
    workspace.heap.push_back({0.0, source});

    while (!workspace.heap.empty()) {
        std::pop_heap(workspace.heap.begin(), workspace.heap.end(), heap_greater);
        const queue_item_t item = workspace.heap.back();
        workspace.heap.pop_back();

        const double du = item.first;
        const int u = item.second;
        if (du != workspace.dist[static_cast<size_t>(u)]) {
            continue;
        }
        if (du > cutoff) {
            cleanup();
            return std::numeric_limits<double>::infinity();
        }
        if (u == target) {
            cleanup();
            return du;
        }
        for (const auto& adj_edge : adj[static_cast<size_t>(u)]) {
            if (adj_edge.edge_id == excluded_edge_id ||
                !edges[static_cast<size_t>(adj_edge.edge_id)].alive) {
                continue;
            }
            const int v = adj_edge.vertex;
            if (!workspace.in_local[static_cast<size_t>(v)]) {
                continue;
            }
            const double nd = du + edges[static_cast<size_t>(adj_edge.edge_id)].weight;
            if (nd < workspace.dist[static_cast<size_t>(v)] && nd <= cutoff) {
                workspace.set_dist(v, nd);
                workspace.heap.push_back({nd, v});
                std::push_heap(workspace.heap.begin(), workspace.heap.end(), heap_greater);
            }
        }
    }
    cleanup();
    return std::numeric_limits<double>::infinity();
}

double global_dijkstra_distance(const std::vector<std::vector<adj_ref_t>>& adj,
                                const std::vector<edge_t>& edges,
                                int source,
                                int target,
                                int excluded_edge_id,
                                double cutoff,
                                dijkstra_workspace_t& workspace) {
    using queue_item_t = std::pair<double, int>;
    auto heap_greater = std::greater<queue_item_t>();
    workspace.heap.clear();
    workspace.set_dist(source, 0.0);
    workspace.heap.push_back({0.0, source});

    while (!workspace.heap.empty()) {
        std::pop_heap(workspace.heap.begin(), workspace.heap.end(), heap_greater);
        const queue_item_t item = workspace.heap.back();
        workspace.heap.pop_back();

        const double du = item.first;
        const int u = item.second;
        if (du != workspace.dist[static_cast<size_t>(u)]) {
            continue;
        }
        if (du > cutoff) {
            workspace.clear_distances();
            workspace.heap.clear();
            return std::numeric_limits<double>::infinity();
        }
        if (u == target) {
            workspace.clear_distances();
            workspace.heap.clear();
            return du;
        }
        for (const auto& adj_edge : adj[static_cast<size_t>(u)]) {
            if (adj_edge.edge_id == excluded_edge_id ||
                !edges[static_cast<size_t>(adj_edge.edge_id)].alive) {
                continue;
            }
            const int v = adj_edge.vertex;
            const double nd = du + edges[static_cast<size_t>(adj_edge.edge_id)].weight;
            if (nd < workspace.dist[static_cast<size_t>(v)] && nd <= cutoff) {
                workspace.set_dist(v, nd);
                workspace.heap.push_back({nd, v});
                std::push_heap(workspace.heap.begin(), workspace.heap.end(), heap_greater);
            }
        }
    }
    workspace.clear_distances();
    workspace.heap.clear();
    return std::numeric_limits<double>::infinity();
}

std::vector<edge_t> validate_and_convert_graph(SEXP s_adj_list,
                                               SEXP s_weight_list,
                                               int n,
                                               std::vector<std::vector<adj_ref_t>>& adj) {
    if (!Rf_isVectorList(s_adj_list) || !Rf_isVectorList(s_weight_list)) {
        Rf_error("adj.list and weight.list must be lists.");
    }
    if (Rf_length(s_adj_list) != n || Rf_length(s_weight_list) != n) {
        Rf_error("adj.list and weight.list must have length nrow(X).");
    }

    std::vector<std::vector<std::pair<int, double>>> directed_adj(static_cast<size_t>(n));
    std::vector<edge_t> edges;

    for (int i = 0; i < n; ++i) {
        SEXP nbrs = VECTOR_ELT(s_adj_list, i);
        SEXP weights = VECTOR_ELT(s_weight_list, i);
        if ((TYPEOF(nbrs) != INTSXP && TYPEOF(nbrs) != REALSXP) ||
            (TYPEOF(weights) != REALSXP && TYPEOF(weights) != INTSXP)) {
            Rf_error("adj.list and weight.list entries must be numeric vectors.");
        }
        const R_xlen_t row_len = Rf_xlength(nbrs);
        if (Rf_xlength(weights) != row_len) {
            Rf_error("adj.list and weight.list entries must have matching lengths.");
        }
        std::set<int> seen_neighbors;
        directed_adj[static_cast<size_t>(i)].reserve(static_cast<size_t>(row_len));
        for (R_xlen_t pos = 0; pos < row_len; ++pos) {
            const int j1 = read_vertex_index(nbrs, pos, "adj.list");
            if (j1 < 1 || j1 > n) {
                Rf_error("adj.list contains vertex IDs outside 1..nrow(X).");
            }
            const int j = j1 - 1;
            if (j == i) {
                Rf_error("adj.list cannot contain self edges.");
            }
            if (!seen_neighbors.insert(j).second) {
                Rf_error("adj.list contains duplicate neighbors within a row.");
            }
            const double w = read_weight(weights, pos);
            if (!std::isfinite(w) || w <= 0.0) {
                Rf_error("weight.list must contain finite positive edge weights.");
            }
            directed_adj[static_cast<size_t>(i)].push_back({j, w});
            if (i < j) {
                edges.push_back(edge_t{i, j, w, true});
            }
        }
    }

    const double weight_tol = 1e-12;
    for (int i = 0; i < n; ++i) {
        for (const auto& edge : directed_adj[static_cast<size_t>(i)]) {
            const int j = edge.first;
            const double w = edge.second;
            const auto& reciprocal_row = directed_adj[static_cast<size_t>(j)];
            const auto it = std::find_if(reciprocal_row.begin(), reciprocal_row.end(),
                                         [&](const auto& reciprocal) {
                                             return reciprocal.first == i;
                                         });
            if (it == reciprocal_row.end()) {
                Rf_error("adj.list must describe an undirected graph with reciprocal edges.");
            }
            const double scale = std::max({1.0, std::fabs(w), std::fabs(it->second)});
            if (std::fabs(w - it->second) > weight_tol * scale) {
                Rf_error("weight.list has mismatched reciprocal edge weights.");
            }
        }
    }

    std::map<std::uint64_t, int> edge_id_by_key;
    for (int edge_id = 0; edge_id < static_cast<int>(edges.size()); ++edge_id) {
        edge_id_by_key.emplace(edge_key(edges[static_cast<size_t>(edge_id)].u,
                                        edges[static_cast<size_t>(edge_id)].v),
                               edge_id);
    }

    adj.assign(static_cast<size_t>(n), {});
    for (int i = 0; i < n; ++i) {
        adj[static_cast<size_t>(i)].reserve(directed_adj[static_cast<size_t>(i)].size());
        for (const auto& edge : directed_adj[static_cast<size_t>(i)]) {
            const auto id_it = edge_id_by_key.find(edge_key(i, edge.first));
            if (id_it == edge_id_by_key.end()) {
                Rf_error("internal error while indexing graph edges.");
            }
            adj[static_cast<size_t>(i)].push_back(adj_ref_t{edge.first, id_it->second});
        }
    }

    return edges;
}

SEXP make_result(const std::vector<std::vector<adj_ref_t>>& adj,
                 const std::vector<edge_t>& edges,
                 const std::vector<pruned_edge_t>& pruned_edges,
                 double prune_tau,
                 int prune_local_k,
                 bool with_pruned_edge_stats) {
    const int n = static_cast<int>(adj.size());
    int n_edges_after = 0;
    for (const auto& edge : edges) {
        if (edge.alive) {
            n_edges_after += 1;
        }
    }
    const int n_edges_before = static_cast<int>(edges.size());

    SEXP result = PROTECT(Rf_allocVector(VECSXP, 9));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 9));
    const char* name_values[] = {
        "adj_list", "weight_list",
        "n_edges_before_pruning", "n_edges_after_pruning", "n_pruned_edges",
        "pruned_edge_stats", "prune_tau", "prune_local_k",
        "with_pruned_edge_stats"
    };
    for (int i = 0; i < 9; ++i) {
        SET_STRING_ELT(names, i, Rf_mkChar(name_values[i]));
    }
    Rf_setAttrib(result, R_NamesSymbol, names);
    UNPROTECT(1);

    SEXP out_adj = PROTECT(Rf_allocVector(VECSXP, n));
    SEXP out_weight = PROTECT(Rf_allocVector(VECSXP, n));
    for (int i = 0; i < n; ++i) {
        const auto& row = adj[static_cast<size_t>(i)];
        R_xlen_t alive_degree = 0;
        for (const auto& adj_edge : row) {
            if (edges[static_cast<size_t>(adj_edge.edge_id)].alive) {
                alive_degree += 1;
            }
        }
        SEXP a = PROTECT(Rf_allocVector(INTSXP, alive_degree));
        SEXP w = PROTECT(Rf_allocVector(REALSXP, alive_degree));
        R_xlen_t out_pos = 0;
        for (const auto& adj_edge : row) {
            const edge_t& edge = edges[static_cast<size_t>(adj_edge.edge_id)];
            if (!edge.alive) {
                continue;
            }
            INTEGER(a)[out_pos] = adj_edge.vertex + 1;
            REAL(w)[out_pos] = edge.weight;
            out_pos += 1;
        }
        SET_VECTOR_ELT(out_adj, i, a);
        SET_VECTOR_ELT(out_weight, i, w);
        UNPROTECT(2);
    }
    SET_VECTOR_ELT(result, 0, out_adj);
    SET_VECTOR_ELT(result, 1, out_weight);
    UNPROTECT(2);

    SET_VECTOR_ELT(result, 2, Rf_ScalarInteger(n_edges_before));
    SET_VECTOR_ELT(result, 3, Rf_ScalarInteger(n_edges_after));
    SET_VECTOR_ELT(result, 4, Rf_ScalarInteger(n_edges_before - n_edges_after));

    SEXP stats = PROTECT(make_pruned_edge_stats(pruned_edges));
    SET_VECTOR_ELT(result, 5, stats);
    UNPROTECT(1);

    SET_VECTOR_ELT(result, 6, Rf_ScalarReal(prune_tau));
    SET_VECTOR_ELT(result, 7, Rf_ScalarInteger(prune_local_k));
    SET_VECTOR_ELT(result, 8, Rf_ScalarLogical(with_pruned_edge_stats ? TRUE : FALSE));

    UNPROTECT(1);
    return result;
}

} // namespace

extern "C" SEXP S_prune_graph_local_geodesic(SEXP s_X,
                                             SEXP s_adj_list,
                                             SEXP s_weight_list,
                                             SEXP s_prune_tau,
                                             SEXP s_prune_local_k,
                                             SEXP s_with_pruned_edge_stats) {
    if (!Rf_isMatrix(s_X) || TYPEOF(s_X) != REALSXP) {
        Rf_error("X must be a numeric matrix.");
    }
    SEXP s_dim = PROTECT(Rf_getAttrib(s_X, R_DimSymbol));
    if (s_dim == R_NilValue || TYPEOF(s_dim) != INTSXP || Rf_length(s_dim) < 2) {
        UNPROTECT(1);
        Rf_error("X must have a valid dim attribute.");
    }
    const int n = INTEGER(s_dim)[0];
    const int p = INTEGER(s_dim)[1];
    UNPROTECT(1);
    if (n < 2 || p < 1) {
        Rf_error("X must have at least two rows and one column.");
    }

    const double prune_tau = Rf_asReal(s_prune_tau);
    if (!std::isfinite(prune_tau) || prune_tau <= 1.0) {
        Rf_error("prune.tau must be a finite number greater than 1.");
    }
    const int prune_local_k = Rf_asInteger(s_prune_local_k);
    if (prune_local_k < 1 || prune_local_k >= n) {
        Rf_error("prune.local.k must be a positive integer smaller than nrow(X).");
    }
    const int stats_flag = Rf_asLogical(s_with_pruned_edge_stats);
    if (stats_flag == NA_LOGICAL) {
        Rf_error("with.pruned.edge.stats must be TRUE or FALSE.");
    }
    const bool with_pruned_edge_stats = (stats_flag == TRUE);

    std::vector<std::vector<adj_ref_t>> adj;
    std::vector<edge_t> candidates = validate_and_convert_graph(s_adj_list, s_weight_list, n, adj);
    const int n_edges_before = static_cast<int>(candidates.size());
    if (n_edges_before == 0) {
        std::vector<pruned_edge_t> empty_stats;
        return make_result(adj, candidates, empty_stats, prune_tau, prune_local_k,
                           with_pruned_edge_stats);
    }

    std::vector<int> candidate_ids(static_cast<size_t>(n_edges_before));
    for (int edge_id = 0; edge_id < n_edges_before; ++edge_id) {
        candidate_ids[static_cast<size_t>(edge_id)] = edge_id;
    }
    std::sort(candidate_ids.begin(), candidate_ids.end(), [&](int a_id, int b_id) {
        const edge_t& a = candidates[static_cast<size_t>(a_id)];
        const edge_t& b = candidates[static_cast<size_t>(b_id)];
        if (a.weight > b.weight) return true;
        if (a.weight < b.weight) return false;
        if (a.u < b.u) return true;
        if (a.u > b.u) return false;
        return a.v < b.v;
    });

    const std::vector<std::vector<int>> local_nn =
        exact_knn_index(REAL(s_X), n, p, prune_local_k);

    std::vector<pruned_edge_t> pruned_edges;
    if (with_pruned_edge_stats) {
        pruned_edges.reserve(candidates.size());
    }

    const double tol = 1e-12;
    dijkstra_workspace_t dijkstra_workspace(n);
    for (int edge_id : candidate_ids) {
        edge_t& candidate = candidates[static_cast<size_t>(edge_id)];
        if (!candidate.alive) {
            continue;
        }

        const double edge_length = candidate.weight;

        std::vector<int> local_vertices;
        local_vertices.reserve(static_cast<size_t>(2 + 2 * prune_local_k));
        local_vertices.push_back(candidate.u);
        local_vertices.push_back(candidate.v);
        for (int x : local_nn[static_cast<size_t>(candidate.u)]) {
            local_vertices.push_back(x);
        }
        for (int x : local_nn[static_cast<size_t>(candidate.v)]) {
            local_vertices.push_back(x);
        }
        std::sort(local_vertices.begin(), local_vertices.end());
        local_vertices.erase(std::unique(local_vertices.begin(), local_vertices.end()),
                             local_vertices.end());

        const double cutoff = prune_tau * edge_length;
        const double alt = local_dijkstra_distance(adj, candidates, local_vertices,
                                                   candidate.u, candidate.v,
                                                   edge_id, cutoff + tol,
                                                   dijkstra_workspace);
        if (std::isfinite(alt) && alt <= cutoff + tol) {
            candidate.alive = false;
            if (with_pruned_edge_stats) {
                pruned_edges.push_back(pruned_edge_t{
                    candidate.u,
                    candidate.v,
                    edge_length,
                    alt,
                    alt / edge_length
                });
            }
        }
    }

    return make_result(adj, candidates, pruned_edges, prune_tau, prune_local_k,
                       with_pruned_edge_stats);
}

extern "C" SEXP S_prune_graph_global_geodesic_ratio(SEXP s_adj_list,
                                                    SEXP s_weight_list,
                                                    SEXP s_max_ratio_threshold,
                                                    SEXP s_path_edge_ratio_percentile,
                                                    SEXP s_with_pruned_edge_stats) {
    if (!Rf_isVectorList(s_adj_list) || !Rf_isVectorList(s_weight_list)) {
        Rf_error("adj.list and weight.list must be lists.");
    }
    if (Rf_length(s_adj_list) != Rf_length(s_weight_list)) {
        Rf_error("adj.list and weight.list must have matching lengths.");
    }
    const int n = Rf_length(s_adj_list);
    if (n < 1) {
        Rf_error("adj.list and weight.list must contain at least one vertex.");
    }

    const double max_ratio_threshold = Rf_asReal(s_max_ratio_threshold);
    if (!std::isfinite(max_ratio_threshold)) {
        Rf_error("max.ratio.threshold must be finite.");
    }
    const double path_edge_ratio_percentile = Rf_asReal(s_path_edge_ratio_percentile);
    if (!std::isfinite(path_edge_ratio_percentile) ||
        path_edge_ratio_percentile < 0.0 ||
        path_edge_ratio_percentile > 1.0) {
        Rf_error("path.edge.ratio.percentile must be in [0, 1].");
    }
    const int stats_flag = Rf_asLogical(s_with_pruned_edge_stats);
    if (stats_flag == NA_LOGICAL) {
        Rf_error("with.pruned.edge.stats must be TRUE or FALSE.");
    }
    const bool with_pruned_edge_stats = (stats_flag == TRUE);

    std::vector<std::vector<adj_ref_t>> adj;
    std::vector<edge_t> edges = validate_and_convert_graph(s_adj_list, s_weight_list, n, adj);
    const int n_edges_before = static_cast<int>(edges.size());
    std::vector<pruned_edge_t> pruned_edges;
    if (n_edges_before == 0 || max_ratio_threshold <= 1.0) {
        return make_result(adj, edges, pruned_edges, NA_REAL, NA_INTEGER,
                           with_pruned_edge_stats);
    }

    std::vector<int> edge_ids(static_cast<size_t>(n_edges_before));
    for (int edge_id = 0; edge_id < n_edges_before; ++edge_id) {
        edge_ids[static_cast<size_t>(edge_id)] = edge_id;
    }
    std::sort(edge_ids.begin(), edge_ids.end(), [&](int a_id, int b_id) {
        const edge_t& a = edges[static_cast<size_t>(a_id)];
        const edge_t& b = edges[static_cast<size_t>(b_id)];
        if (a.weight < b.weight) return true;
        if (a.weight > b.weight) return false;
        if (a.u < b.u) return true;
        if (a.u > b.u) return false;
        return a.v < b.v;
    });

    double threshold_weight = 0.0;
    if (path_edge_ratio_percentile <= 0.0) {
        threshold_weight = edges[static_cast<size_t>(edge_ids.front())].weight - 1.0;
    } else if (path_edge_ratio_percentile >= 1.0) {
        threshold_weight = edges[static_cast<size_t>(edge_ids.back())].weight + 1.0;
    } else {
        const int threshold_index = std::min(
            n_edges_before - 1,
            static_cast<int>(std::floor(n_edges_before * path_edge_ratio_percentile))
        );
        threshold_weight = edges[static_cast<size_t>(
            edge_ids[static_cast<size_t>(threshold_index)]
        )].weight;
    }

    std::vector<int> candidate_ids;
    candidate_ids.reserve(edge_ids.size());
    const double tol = 1e-12;
    dijkstra_workspace_t dijkstra_workspace(n);
    for (int edge_id : edge_ids) {
        const edge_t& edge = edges[static_cast<size_t>(edge_id)];
        if (edge.weight < threshold_weight) {
            continue;
        }
        const double cutoff = max_ratio_threshold * edge.weight;
        const double alt = global_dijkstra_distance(adj, edges, edge.u, edge.v,
                                                    edge_id, cutoff + tol,
                                                    dijkstra_workspace);
        if (std::isfinite(alt) && alt / edge.weight <= max_ratio_threshold + tol) {
            candidate_ids.push_back(edge_id);
        }
    }

    if (candidate_ids.empty()) {
        return make_result(adj, edges, pruned_edges, NA_REAL, NA_INTEGER,
                           with_pruned_edge_stats);
    }

    std::sort(candidate_ids.begin(), candidate_ids.end(), [&](int a_id, int b_id) {
        const edge_t& a = edges[static_cast<size_t>(a_id)];
        const edge_t& b = edges[static_cast<size_t>(b_id)];
        if (a.weight > b.weight) return true;
        if (a.weight < b.weight) return false;
        if (a.u < b.u) return true;
        if (a.u > b.u) return false;
        return a.v < b.v;
    });

    if (with_pruned_edge_stats) {
        pruned_edges.reserve(candidate_ids.size());
    }
    for (int edge_id : candidate_ids) {
        edge_t& edge = edges[static_cast<size_t>(edge_id)];
        if (!edge.alive) {
            continue;
        }
        const double edge_length = edge.weight;
        const double cutoff = max_ratio_threshold * edge_length;
        const double alt = global_dijkstra_distance(adj, edges, edge.u, edge.v,
                                                    edge_id, cutoff + tol,
                                                    dijkstra_workspace);
        if (std::isfinite(alt) && alt / edge_length <= max_ratio_threshold + tol) {
            edge.alive = false;
            if (with_pruned_edge_stats) {
                pruned_edges.push_back(pruned_edge_t{
                    edge.u,
                    edge.v,
                    edge_length,
                    alt,
                    alt / edge_length
                });
            }
        }
    }

    return make_result(adj, edges, pruned_edges, NA_REAL, NA_INTEGER,
                       with_pruned_edge_stats);
}
