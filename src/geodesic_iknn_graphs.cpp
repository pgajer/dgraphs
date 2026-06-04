#include <R.h>
#include <Rinternals.h>

#include <algorithm>
#include <climits>
#include <cmath>
#include <cstdint>
#include <functional>
#include <limits>
#include <queue>
#include <stdexcept>
#include <unordered_map>
#include <utility>
#include <vector>

namespace {

struct weighted_edge_t {
    int vertex;
    double weight;
};

struct edge_accumulator_t {
    int isize;
    double weight;
};

using weighted_adj_t = std::vector<std::vector<weighted_edge_t>>;
using edge_map_t = std::unordered_map<std::uint64_t, edge_accumulator_t>;

static inline std::uint64_t pack_edge_key(int u, int v) {
    return (static_cast<std::uint64_t>(static_cast<std::uint32_t>(u)) << 32U) |
           static_cast<std::uint64_t>(static_cast<std::uint32_t>(v));
}

static inline std::pair<int, int> unpack_edge_key(std::uint64_t key) {
    return {
        static_cast<int>(key >> 32U),
        static_cast<int>(key & 0xFFFFFFFFULL)
    };
}

int as_neighbor_index(SEXP adj_row, R_xlen_t pos, int n_vertices) {
    int value = NA_INTEGER;
    if (TYPEOF(adj_row) == INTSXP) {
        value = INTEGER(adj_row)[pos];
    } else if (TYPEOF(adj_row) == REALSXP) {
        const double raw = REAL(adj_row)[pos];
        if (!std::isfinite(raw) || raw != std::floor(raw)) {
            Rf_error("adj_list contains a non-integer neighbor index.");
        }
        if (raw < static_cast<double>(INT_MIN) || raw > static_cast<double>(INT_MAX)) {
            Rf_error("adj_list contains a neighbor index outside integer range.");
        }
        value = static_cast<int>(raw);
    } else {
        Rf_error("Each adj_list entry must be an integer or numeric vector.");
    }

    if (value == NA_INTEGER || value < 1 || value > n_vertices) {
        Rf_error("adj_list contains an index outside 1:n.");
    }
    return value - 1;
}

weighted_adj_t parse_weighted_graph(SEXP s_adj_list, SEXP s_weight_list) {
    if (TYPEOF(s_adj_list) != VECSXP || TYPEOF(s_weight_list) != VECSXP) {
        Rf_error("adj_list and weight_list must both be lists.");
    }
    const R_xlen_t n_xlen = Rf_xlength(s_adj_list);
    if (n_xlen != Rf_xlength(s_weight_list)) {
        Rf_error("adj_list and weight_list must have the same length.");
    }
    if (n_xlen > static_cast<R_xlen_t>(INT_MAX)) {
        Rf_error("Graph has too many vertices for this implementation.");
    }
    const int n_vertices = static_cast<int>(n_xlen);
    weighted_adj_t graph(static_cast<size_t>(n_vertices));

    for (int i = 0; i < n_vertices; ++i) {
        SEXP adj_row = VECTOR_ELT(s_adj_list, i);
        SEXP weight_row = VECTOR_ELT(s_weight_list, i);
        if (TYPEOF(weight_row) != REALSXP) {
            Rf_error("Each weight_list entry must be a numeric vector.");
        }
        const R_xlen_t row_len = Rf_xlength(adj_row);
        if (row_len != Rf_xlength(weight_row)) {
            Rf_error("adj_list and weight_list row lengths differ.");
        }
        if (row_len > static_cast<R_xlen_t>(INT_MAX)) {
            Rf_error("A graph row has too many neighbors for this implementation.");
        }

        graph[static_cast<size_t>(i)].reserve(static_cast<size_t>(row_len));
        for (R_xlen_t j = 0; j < row_len; ++j) {
            const int neighbor = as_neighbor_index(adj_row, j, n_vertices);
            const double weight = REAL(weight_row)[j];
            if (neighbor == i) {
                Rf_error("Self-edges are not supported in the input graph.");
            }
            if (!std::isfinite(weight) || weight < 0.0) {
                Rf_error("weight_list must contain finite, non-negative edge weights.");
            }
            graph[static_cast<size_t>(i)].push_back({neighbor, weight});
        }
    }

    return graph;
}

std::vector<double> dijkstra(const weighted_adj_t& graph, int source) {
    const int n = static_cast<int>(graph.size());
    const double inf = std::numeric_limits<double>::infinity();
    std::vector<double> distances(static_cast<size_t>(n), inf);
    using queue_entry_t = std::pair<double, int>;
    std::priority_queue<
        queue_entry_t,
        std::vector<queue_entry_t>,
        std::greater<queue_entry_t>
    > queue;

    distances[static_cast<size_t>(source)] = 0.0;
    queue.push({0.0, source});

    while (!queue.empty()) {
        const auto [current_distance, vertex] = queue.top();
        queue.pop();
        if (current_distance != distances[static_cast<size_t>(vertex)]) {
            continue;
        }

        for (const auto& edge : graph[static_cast<size_t>(vertex)]) {
            const double candidate = current_distance + edge.weight;
            if (candidate < distances[static_cast<size_t>(edge.vertex)]) {
                distances[static_cast<size_t>(edge.vertex)] = candidate;
                queue.push({candidate, edge.vertex});
            }
        }
    }

    return distances;
}

std::vector<std::vector<double>> all_pairs_shortest_paths(const weighted_adj_t& graph) {
    const int n = static_cast<int>(graph.size());
    std::vector<std::vector<double>> distances(static_cast<size_t>(n));
    for (int source = 0; source < n; ++source) {
        distances[static_cast<size_t>(source)] = dijkstra(graph, source);
    }
    return distances;
}

std::vector<std::vector<int>> graph_metric_knn_sets(
    const std::vector<std::vector<double>>& distances,
    int k) {

    const int n = static_cast<int>(distances.size());
    std::vector<std::vector<int>> knn_sets(static_cast<size_t>(n));

    for (int i = 0; i < n; ++i) {
        std::vector<int> finite_vertices;
        finite_vertices.reserve(static_cast<size_t>(n));
        for (int j = 0; j < n; ++j) {
            if (std::isfinite(distances[static_cast<size_t>(i)][static_cast<size_t>(j)])) {
                finite_vertices.push_back(j);
            }
        }

        std::sort(
            finite_vertices.begin(),
            finite_vertices.end(),
            [&distances, i](int lhs, int rhs) {
                const double lhs_dist = distances[static_cast<size_t>(i)][static_cast<size_t>(lhs)];
                const double rhs_dist = distances[static_cast<size_t>(i)][static_cast<size_t>(rhs)];
                if (lhs_dist < rhs_dist) return true;
                if (lhs_dist > rhs_dist) return false;
                return lhs < rhs;
            }
        );

        const int keep = std::min(k, static_cast<int>(finite_vertices.size()));
        knn_sets[static_cast<size_t>(i)].assign(
            finite_vertices.begin(),
            finite_vertices.begin() + keep
        );
    }

    return knn_sets;
}

edge_map_t build_geodesic_iknn_edge_map(
    const std::vector<std::vector<int>>& knn_sets,
    const std::vector<std::vector<double>>& distances) {

    const int n = static_cast<int>(knn_sets.size());
    std::vector<std::vector<int>> buckets(static_cast<size_t>(n));
    for (int point = 0; point < n; ++point) {
        for (int neighbor : knn_sets[static_cast<size_t>(point)]) {
            buckets[static_cast<size_t>(neighbor)].push_back(point);
        }
    }

    edge_map_t edge_map;
    for (const auto& bucket : buckets) {
        const size_t m = bucket.size();
        for (size_t a = 0; a < m; ++a) {
            for (size_t b = a + 1; b < m; ++b) {
                const int first = bucket[a];
                const int second = bucket[b];
                if (first == second) {
                    continue;
                }
                const int u = std::min(first, second);
                const int v = std::max(first, second);
                const double edge_weight = distances[static_cast<size_t>(u)][static_cast<size_t>(v)];
                if (!std::isfinite(edge_weight)) {
                    continue;
                }

                const std::uint64_t key = pack_edge_key(u, v);
                auto it = edge_map.find(key);
                if (it == edge_map.end()) {
                    edge_map.emplace(key, edge_accumulator_t{1, edge_weight});
                } else {
                    it->second.isize += 1;
                }
            }
        }
    }

    return edge_map;
}

SEXP make_graph_result(const edge_map_t& edge_map, int n_vertices) {
    std::vector<std::vector<int>> adj(static_cast<size_t>(n_vertices));
    std::vector<std::vector<double>> weights(static_cast<size_t>(n_vertices));
    std::vector<std::vector<int>> isizes(static_cast<size_t>(n_vertices));

    for (const auto& kv : edge_map) {
        const auto [u, v] = unpack_edge_key(kv.first);
        const edge_accumulator_t& edge = kv.second;

        adj[static_cast<size_t>(u)].push_back(v + 1);
        weights[static_cast<size_t>(u)].push_back(edge.weight);
        isizes[static_cast<size_t>(u)].push_back(edge.isize);

        adj[static_cast<size_t>(v)].push_back(u + 1);
        weights[static_cast<size_t>(v)].push_back(edge.weight);
        isizes[static_cast<size_t>(v)].push_back(edge.isize);
    }

    for (int i = 0; i < n_vertices; ++i) {
        std::vector<size_t> order(adj[static_cast<size_t>(i)].size());
        for (size_t j = 0; j < order.size(); ++j) {
            order[j] = j;
        }
        std::sort(order.begin(), order.end(), [&adj, i](size_t lhs, size_t rhs) {
            return adj[static_cast<size_t>(i)][lhs] < adj[static_cast<size_t>(i)][rhs];
        });

        std::vector<int> sorted_adj;
        std::vector<double> sorted_weights;
        std::vector<int> sorted_isizes;
        sorted_adj.reserve(order.size());
        sorted_weights.reserve(order.size());
        sorted_isizes.reserve(order.size());

        for (size_t idx : order) {
            sorted_adj.push_back(adj[static_cast<size_t>(i)][idx]);
            sorted_weights.push_back(weights[static_cast<size_t>(i)][idx]);
            sorted_isizes.push_back(isizes[static_cast<size_t>(i)][idx]);
        }

        adj[static_cast<size_t>(i)] = std::move(sorted_adj);
        weights[static_cast<size_t>(i)] = std::move(sorted_weights);
        isizes[static_cast<size_t>(i)] = std::move(sorted_isizes);
    }

    SEXP r_adj = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    SEXP r_weights = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    SEXP r_isizes = PROTECT(Rf_allocVector(VECSXP, n_vertices));

    for (int i = 0; i < n_vertices; ++i) {
        const size_t row_size = adj[static_cast<size_t>(i)].size();
        if (row_size > static_cast<size_t>(INT_MAX)) {
            Rf_error("A result graph row has too many neighbors for R vectors.");
        }

        SEXP r_adj_row = PROTECT(Rf_allocVector(INTSXP, static_cast<R_xlen_t>(row_size)));
        SEXP r_weight_row = PROTECT(Rf_allocVector(REALSXP, static_cast<R_xlen_t>(row_size)));
        SEXP r_isize_row = PROTECT(Rf_allocVector(INTSXP, static_cast<R_xlen_t>(row_size)));

        for (size_t j = 0; j < row_size; ++j) {
            INTEGER(r_adj_row)[j] = adj[static_cast<size_t>(i)][j];
            REAL(r_weight_row)[j] = weights[static_cast<size_t>(i)][j];
            INTEGER(r_isize_row)[j] = isizes[static_cast<size_t>(i)][j];
        }

        SET_VECTOR_ELT(r_adj, i, r_adj_row);
        SET_VECTOR_ELT(r_weights, i, r_weight_row);
        SET_VECTOR_ELT(r_isizes, i, r_isize_row);
        UNPROTECT(3);
    }

    SEXP r_result = PROTECT(Rf_allocVector(VECSXP, 4));
    SEXP r_names = PROTECT(Rf_allocVector(STRSXP, 4));
    SET_STRING_ELT(r_names, 0, Rf_mkChar("adj_list"));
    SET_STRING_ELT(r_names, 1, Rf_mkChar("weight_list"));
    SET_STRING_ELT(r_names, 2, Rf_mkChar("isize_list"));
    SET_STRING_ELT(r_names, 3, Rf_mkChar("n_edges"));
    Rf_setAttrib(r_result, R_NamesSymbol, r_names);
    UNPROTECT(1);

    SEXP r_n_edges = PROTECT(Rf_ScalarInteger(static_cast<int>(edge_map.size())));
    SET_VECTOR_ELT(r_result, 0, r_adj);
    SET_VECTOR_ELT(r_result, 1, r_weights);
    SET_VECTOR_ELT(r_result, 2, r_isizes);
    SET_VECTOR_ELT(r_result, 3, r_n_edges);

    UNPROTECT(5);
    return r_result;
}

} // namespace

extern "C" SEXP S_create_geodesic_iknn_graph(SEXP s_adj_list,
                                             SEXP s_weight_list,
                                             SEXP s_k) {
    if (!Rf_isInteger(s_k) || Rf_xlength(s_k) != 1) {
        Rf_error("k must be a length-1 integer.");
    }

    const int k = INTEGER(s_k)[0];
    if (k == NA_INTEGER || k < 1) {
        Rf_error("k must be a positive integer.");
    }

    const weighted_adj_t graph = parse_weighted_graph(s_adj_list, s_weight_list);
    const int n_vertices = static_cast<int>(graph.size());
    if (n_vertices < 1) {
        Rf_error("Input graph must contain at least one vertex.");
    }

    const std::vector<std::vector<double>> distances = all_pairs_shortest_paths(graph);
    const std::vector<std::vector<int>> knn_sets = graph_metric_knn_sets(distances, k);
    const edge_map_t edge_map = build_geodesic_iknn_edge_map(knn_sets, distances);
    return make_graph_result(edge_map, n_vertices);
}
