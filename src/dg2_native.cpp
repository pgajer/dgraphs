#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include <algorithm>
#include <cmath>
#include <limits>
#include <map>
#include <deque>
#include <memory>
#include <queue>
#include <set>
#include <tuple>
#include <unordered_set>
#include <utility>
#include <vector>

namespace {

std::vector<std::vector<int>> convert_adj_list_from_R(SEXP s_adj_list) {
    if (!Rf_isNewList(s_adj_list)) {
        Rf_error("adjacency list must be an R list.");
    }
    const int n = Rf_length(s_adj_list);
    std::vector<std::vector<int>> out(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) {
        SEXP s_item = VECTOR_ELT(s_adj_list, i);
        if (TYPEOF(s_item) != INTSXP && TYPEOF(s_item) != REALSXP) {
            Rf_error("adjacency entries must be integer or numeric vectors.");
        }
        const int m = Rf_length(s_item);
        out[static_cast<size_t>(i)].resize(static_cast<size_t>(m));
        for (int j = 0; j < m; ++j) {
            out[static_cast<size_t>(i)][static_cast<size_t>(j)] =
                TYPEOF(s_item) == INTSXP ? INTEGER(s_item)[j] :
                static_cast<int>(REAL(s_item)[j]);
        }
    }
    return out;
}

std::vector<std::vector<double>> convert_weight_list_from_R(SEXP s_weight_list) {
    if (!Rf_isNewList(s_weight_list)) {
        Rf_error("weight list must be an R list.");
    }
    const int n = Rf_length(s_weight_list);
    std::vector<std::vector<double>> out(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) {
        SEXP s_item = VECTOR_ELT(s_weight_list, i);
        if (TYPEOF(s_item) != REALSXP && TYPEOF(s_item) != INTSXP) {
            Rf_error("weight entries must be numeric vectors.");
        }
        const int m = Rf_length(s_item);
        out[static_cast<size_t>(i)].resize(static_cast<size_t>(m));
        for (int j = 0; j < m; ++j) {
            out[static_cast<size_t>(i)][static_cast<size_t>(j)] =
                TYPEOF(s_item) == REALSXP ? REAL(s_item)[j] :
                static_cast<double>(INTEGER(s_item)[j]);
        }
    }
    return out;
}

SEXP flat_vector_to_R_matrix(const std::vector<double>& x, int nr, int nc) {
    SEXP out = PROTECT(Rf_allocMatrix(REALSXP, nr, nc));
    for (int i = 0; i < nr; ++i) {
        for (int j = 0; j < nc; ++j) {
            REAL(out)[i + nr * j] = x[static_cast<size_t>(i * nc + j)];
        }
    }
    UNPROTECT(1);
    return out;
}

struct path_graph_t {
    std::vector<std::vector<int>> adj_list;
    std::vector<std::vector<double>> weight_list;
    std::map<std::pair<int, int>, std::vector<int>> shortest_paths;
};

struct path_graph_plus_t {
    std::vector<std::vector<int>> adj_list;
    std::vector<std::vector<double>> weight_list;
    std::vector<std::vector<int>> hop_list;
    std::map<std::pair<int, int>, std::vector<int>> shortest_paths;
};

std::unique_ptr<std::vector<double>> shortest_path(
        const std::vector<std::vector<int>>& graph,
        const std::vector<std::vector<double>>& edge_lengths,
        std::vector<int> vertices) {
    const int n = static_cast<int>(vertices.size());
    auto distance_matrix = std::make_unique<std::vector<double>>(
        static_cast<size_t>(n * n),
        std::numeric_limits<double>::infinity()
    );
    auto get_index = [n](int i, int j) { return i * n + j; };
    auto cmp = [](std::pair<int, double> left, std::pair<int, double> right) {
        return left.second > right.second;
    };

    for (int i = 0; i < n; ++i) {
        int start = vertices[i];
        std::vector<double> dist(graph.size(), std::numeric_limits<double>::infinity());
        std::priority_queue<std::pair<int, double>,
                            std::vector<std::pair<int, double>>,
                            decltype(cmp)> pq(cmp);
        dist[static_cast<size_t>(start)] = 0.0;
        pq.push({start, 0.0});
        while (!pq.empty()) {
            int u = pq.top().first;
            double d = pq.top().second;
            pq.pop();
            if (d > dist[static_cast<size_t>(u)]) continue;
            auto it = std::find(vertices.begin(), vertices.end(), u);
            if (it != vertices.end()) {
                int j = static_cast<int>(std::distance(vertices.begin(), it));
                (*distance_matrix)[static_cast<size_t>(get_index(i, j))] = d;
            }
            for (size_t v = 0; v < graph[static_cast<size_t>(u)].size(); ++v) {
                int to = graph[static_cast<size_t>(u)][v];
                double len = edge_lengths[static_cast<size_t>(u)][v];
                if (dist[static_cast<size_t>(u)] + len < dist[static_cast<size_t>(to)]) {
                    dist[static_cast<size_t>(to)] = dist[static_cast<size_t>(u)] + len;
                    pq.push({to, dist[static_cast<size_t>(to)]});
                }
            }
        }
    }
    return distance_matrix;
}

path_graph_plus_t create_path_graph_plus(
        const std::vector<std::vector<int>>& adj_list,
        const std::vector<std::vector<double>>& weight_list,
        int h) {
    const int n_vertices = static_cast<int>(adj_list.size());
    path_graph_plus_t result;
    result.adj_list.resize(static_cast<size_t>(n_vertices));
    result.weight_list.resize(static_cast<size_t>(n_vertices));
    result.hop_list.resize(static_cast<size_t>(n_vertices));

    std::vector<double> distances(static_cast<size_t>(n_vertices));
    std::vector<int> hops(static_cast<size_t>(n_vertices));
    std::vector<int> parent(static_cast<size_t>(n_vertices));
    std::vector<bool> in_queue(static_cast<size_t>(n_vertices));

    struct neighbor_info_t {
        int vertex;
        double distance;
        int hops;
        neighbor_info_t(int v, double d, int h_) : vertex(v), distance(d), hops(h_) {}
    };
    std::vector<neighbor_info_t> current_neighbors;
    current_neighbors.reserve(static_cast<size_t>(std::max(1, n_vertices / 2)));

    for (int start = 0; start < n_vertices; ++start) {
        std::fill(distances.begin(), distances.end(), std::numeric_limits<double>::infinity());
        std::fill(hops.begin(), hops.end(), std::numeric_limits<int>::max());
        std::fill(parent.begin(), parent.end(), -1);
        std::fill(in_queue.begin(), in_queue.end(), false);
        current_neighbors.clear();

        distances[static_cast<size_t>(start)] = 0.0;
        hops[static_cast<size_t>(start)] = 0;
        std::deque<int> q{start};
        in_queue[static_cast<size_t>(start)] = true;

        while (!q.empty()) {
            int current = q.front();
            q.pop_front();
            in_queue[static_cast<size_t>(current)] = false;
            if (hops[static_cast<size_t>(current)] >= h) continue;
            const double current_dist = distances[static_cast<size_t>(current)];
            const int next_hops = hops[static_cast<size_t>(current)] + 1;
            for (size_t i = 0; i < adj_list[static_cast<size_t>(current)].size(); ++i) {
                const int neighbor = adj_list[static_cast<size_t>(current)][i];
                if (neighbor == current) continue;
                const double new_distance = current_dist +
                    weight_list[static_cast<size_t>(current)][i];
                if (new_distance < distances[static_cast<size_t>(neighbor)]) {
                    distances[static_cast<size_t>(neighbor)] = new_distance;
                    hops[static_cast<size_t>(neighbor)] = next_hops;
                    parent[static_cast<size_t>(neighbor)] = current;
                    if (!in_queue[static_cast<size_t>(neighbor)] && next_hops <= h) {
                        q.push_back(neighbor);
                        in_queue[static_cast<size_t>(neighbor)] = true;
                    }
                }
            }
        }

        for (int v = 0; v < n_vertices; ++v) {
            if (v != start && hops[static_cast<size_t>(v)] <= h) {
                current_neighbors.emplace_back(
                    v,
                    distances[static_cast<size_t>(v)],
                    hops[static_cast<size_t>(v)]
                );
                if (start < v) {
                    auto& path = result.shortest_paths[{start, v}];
                    path.clear();
                    path.reserve(static_cast<size_t>(hops[static_cast<size_t>(v)] + 1));
                    for (int current = v; current != -1;
                         current = parent[static_cast<size_t>(current)]) {
                        path.push_back(current);
                    }
                    std::reverse(path.begin(), path.end());
                }
            }
        }

        const size_t n_new_neighbors = current_neighbors.size();
        result.adj_list[static_cast<size_t>(start)].resize(n_new_neighbors);
        result.weight_list[static_cast<size_t>(start)].resize(n_new_neighbors);
        result.hop_list[static_cast<size_t>(start)].resize(n_new_neighbors);
        for (size_t i = 0; i < n_new_neighbors; ++i) {
            const auto& info = current_neighbors[i];
            result.adj_list[static_cast<size_t>(start)][i] = info.vertex;
            result.weight_list[static_cast<size_t>(start)][i] = info.distance;
            result.hop_list[static_cast<size_t>(start)][i] = info.hops;
        }
    }
    return result;
}

path_graph_t convert_to_path_graph(const path_graph_plus_t& plus_graph) {
    path_graph_t result;
    result.adj_list = plus_graph.adj_list;
    result.weight_list = plus_graph.weight_list;
    result.shortest_paths = plus_graph.shortest_paths;
    return result;
}

std::vector<path_graph_t> create_path_graph_series(
        const std::vector<std::vector<int>>& adj_list,
        const std::vector<std::vector<double>>& weight_list,
        const std::vector<int>& h_values) {
    int h_max = *std::max_element(h_values.begin(), h_values.end());
    path_graph_plus_t max_graph = create_path_graph_plus(adj_list, weight_list, h_max);
    std::vector<path_graph_t> result;
    result.reserve(h_values.size());
    for (int h : h_values) {
        path_graph_t sub;
        const int n_vertices = static_cast<int>(max_graph.adj_list.size());
        sub.adj_list.resize(static_cast<size_t>(n_vertices));
        sub.weight_list.resize(static_cast<size_t>(n_vertices));
        for (int v = 0; v < n_vertices; ++v) {
            for (size_t i = 0; i < max_graph.adj_list[static_cast<size_t>(v)].size(); ++i) {
                if (max_graph.hop_list[static_cast<size_t>(v)][i] <= h) {
                    const int u = max_graph.adj_list[static_cast<size_t>(v)][i];
                    sub.adj_list[static_cast<size_t>(v)].push_back(u);
                    sub.weight_list[static_cast<size_t>(v)].push_back(
                        max_graph.weight_list[static_cast<size_t>(v)][i]
                    );
                    if (v < u) {
                        sub.shortest_paths[{v, u}] = max_graph.shortest_paths.at({v, u});
                    }
                }
            }
        }
        result.push_back(std::move(sub));
    }
    return result;
}

SEXP path_graph_from_path_graph_t(path_graph_t& path_graph) {
    const int n_vertices = static_cast<int>(path_graph.adj_list.size());
    SEXP r_result = PROTECT(Rf_allocVector(VECSXP, 3));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(names, 0, Rf_mkChar("adj_list"));
    SET_STRING_ELT(names, 1, Rf_mkChar("edge_length_list"));
    SET_STRING_ELT(names, 2, Rf_mkChar("shortest_paths"));
    Rf_setAttrib(r_result, R_NamesSymbol, names);

    SEXP adj_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    SEXP edge_length_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    for (int i = 0; i < n_vertices; ++i) {
        SEXP RA = PROTECT(Rf_allocVector(INTSXP, path_graph.adj_list[static_cast<size_t>(i)].size()));
        for (size_t j = 0; j < path_graph.adj_list[static_cast<size_t>(i)].size(); ++j) {
            INTEGER(RA)[j] = path_graph.adj_list[static_cast<size_t>(i)][j] + 1;
        }
        SET_VECTOR_ELT(adj_list, i, RA);
        UNPROTECT(1);
        SEXP RD = PROTECT(Rf_allocVector(REALSXP, path_graph.weight_list[static_cast<size_t>(i)].size()));
        for (size_t j = 0; j < path_graph.weight_list[static_cast<size_t>(i)].size(); ++j) {
            REAL(RD)[j] = path_graph.weight_list[static_cast<size_t>(i)][j];
        }
        SET_VECTOR_ELT(edge_length_list, i, RD);
        UNPROTECT(1);
    }
    SET_VECTOR_ELT(r_result, 0, adj_list);
    SET_VECTOR_ELT(r_result, 1, edge_length_list);

    const int npairs = static_cast<int>(path_graph.shortest_paths.size());
    SEXP shortest_paths = PROTECT(Rf_allocVector(VECSXP, 3));
    SEXP i_coords = PROTECT(Rf_allocVector(INTSXP, npairs));
    SEXP j_coords = PROTECT(Rf_allocVector(INTSXP, npairs));
    SEXP paths = PROTECT(Rf_allocVector(VECSXP, npairs));
    int k = 0;
    for (const auto& entry : path_graph.shortest_paths) {
        INTEGER(i_coords)[k] = entry.first.first + 1;
        INTEGER(j_coords)[k] = entry.first.second + 1;
        SEXP path_vec = PROTECT(Rf_allocVector(INTSXP, entry.second.size()));
        for (size_t m = 0; m < entry.second.size(); ++m) {
            INTEGER(path_vec)[m] = entry.second[m] + 1;
        }
        SET_VECTOR_ELT(paths, k, path_vec);
        UNPROTECT(1);
        ++k;
    }
    SET_VECTOR_ELT(shortest_paths, 0, i_coords);
    SET_VECTOR_ELT(shortest_paths, 1, j_coords);
    SET_VECTOR_ELT(shortest_paths, 2, paths);
    SEXP sp_names = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(sp_names, 0, Rf_mkChar("i"));
    SET_STRING_ELT(sp_names, 1, Rf_mkChar("j"));
    SET_STRING_ELT(sp_names, 2, Rf_mkChar("paths"));
    Rf_setAttrib(shortest_paths, R_NamesSymbol, sp_names);
    SET_VECTOR_ELT(r_result, 2, shortest_paths);
    UNPROTECT(9);
    return r_result;
}

SEXP path_graph_plus_to_R(const path_graph_plus_t& path_graph) {
    const int n_vertices = static_cast<int>(path_graph.adj_list.size());
    SEXP r_result = PROTECT(Rf_allocVector(VECSXP, 4));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 4));
    SET_STRING_ELT(names, 0, Rf_mkChar("adj_list"));
    SET_STRING_ELT(names, 1, Rf_mkChar("edge_length_list"));
    SET_STRING_ELT(names, 2, Rf_mkChar("hop_list"));
    SET_STRING_ELT(names, 3, Rf_mkChar("shortest_paths"));
    Rf_setAttrib(r_result, R_NamesSymbol, names);

    SEXP adj_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    SEXP edge_length_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    SEXP hop_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    for (int i = 0; i < n_vertices; ++i) {
        const size_t deg = path_graph.adj_list[static_cast<size_t>(i)].size();
        SEXP RA = PROTECT(Rf_allocVector(INTSXP, deg));
        SEXP RD = PROTECT(Rf_allocVector(REALSXP, deg));
        SEXP RH = PROTECT(Rf_allocVector(INTSXP, deg));
        for (size_t j = 0; j < deg; ++j) {
            INTEGER(RA)[j] = path_graph.adj_list[static_cast<size_t>(i)][j] + 1;
            REAL(RD)[j] = path_graph.weight_list[static_cast<size_t>(i)][j];
            INTEGER(RH)[j] = path_graph.hop_list[static_cast<size_t>(i)][j];
        }
        SET_VECTOR_ELT(adj_list, i, RA);
        SET_VECTOR_ELT(edge_length_list, i, RD);
        SET_VECTOR_ELT(hop_list, i, RH);
        UNPROTECT(3);
    }
    SET_VECTOR_ELT(r_result, 0, adj_list);
    SET_VECTOR_ELT(r_result, 1, edge_length_list);
    SET_VECTOR_ELT(r_result, 2, hop_list);

    path_graph_t base = convert_to_path_graph(path_graph);
    SEXP base_r = PROTECT(path_graph_from_path_graph_t(base));
    SET_VECTOR_ELT(r_result, 3, VECTOR_ELT(base_r, 2));
    UNPROTECT(6);
    return r_result;
}

double vertex_eccentricity(const std::vector<std::vector<int>>& graph,
                           const std::vector<std::vector<double>>& weights,
                           int start) {
    std::vector<int> all(graph.size());
    for (size_t i = 0; i < graph.size(); ++i) all[i] = static_cast<int>(i);
    auto dist = shortest_path(graph, weights, all);
    double ecc = 0.0;
    const int n = static_cast<int>(graph.size());
    for (int j = 0; j < n; ++j) {
        double d = (*dist)[static_cast<size_t>(start * n + j)];
        if (std::isfinite(d)) ecc = std::max(ecc, d);
    }
    return ecc;
}

void add_undirected_edge(std::vector<std::map<int, double>>& graph,
                         int i, int j, double w) {
    graph[static_cast<size_t>(i)][j] = w;
    graph[static_cast<size_t>(j)][i] = w;
}

void remove_undirected_edge(std::vector<std::map<int, double>>& graph,
                            int i, int j) {
    graph[static_cast<size_t>(i)].erase(j);
    graph[static_cast<size_t>(j)].erase(i);
}

} // namespace

extern "C" {

SEXP S_adaptive_radius_edges_ann(SEXP s_X, SEXP s_k_scale, SEXP s_radius_factor,
                                 SEXP s_radius_rule);
SEXP S_compute_mstree_total_length(SEXP s_X);
SEXP S_create_mknn_graph(SEXP RX, SEXP Rk);
SEXP S_create_mknn_graphs(SEXP s_X, SEXP s_kmin, SEXP s_kmax,
                          SEXP s_max_path_edge_ratio_thld,
                          SEXP s_path_edge_ratio_percentile,
                          SEXP s_compute_full,
                          SEXP s_verbose);
SEXP S_create_mst_completion_graph(SEXP s_X, SEXP s_q_thld, SEXP s_verbose);
SEXP S_create_single_iknn_graph(SEXP s_X, SEXP s_k,
                                SEXP s_max_path_edge_ratio_thld,
                                SEXP s_path_edge_ratio_percentile,
                                SEXP s_threshold_percentile,
                                SEXP s_compute_full,
                                SEXP s_with_isize_pruning,
                                SEXP s_with_edge_pruning_stats,
                                SEXP s_knn_cache_path,
                                SEXP s_knn_cache_mode,
                                SEXP s_knn_metric,
                                SEXP s_linf_tol,
                                SEXP s_verbose);
SEXP S_create_iknn_graphs(SEXP s_X, SEXP s_kmin, SEXP s_kmax,
                          SEXP s_max_path_edge_ratio_thld,
                          SEXP s_path_edge_ratio_percentile,
                          SEXP s_threshold_percentile,
                          SEXP s_compute_full,
                          SEXP s_with_isize_pruning,
                          SEXP s_with_edge_pruning_stats,
                          SEXP s_n_cores,
                          SEXP s_parallel_mode,
                          SEXP s_hybrid_batch_size,
                          SEXP s_knn_cache_path,
                          SEXP s_knn_cache_mode,
                          SEXP s_knn_metric,
                          SEXP s_linf_tol,
                          SEXP s_verbose);
SEXP S_compare_iknn_graph_builders(SEXP s_X, SEXP s_k, SEXP s_runs, SEXP s_tolerance);
SEXP S_create_geodesic_iknn_graph(SEXP s_adj_list, SEXP s_weight_list, SEXP s_k);
SEXP S_linf_simplex_knn(SEXP s_X, SEXP s_k, SEXP s_linf_tol);
SEXP S_create_sknn_graph(SEXP s_X, SEXP s_k, SEXP s_connect_components,
                         SEXP s_connect_method, SEXP s_neighbor_method,
                         SEXP s_ann_eps, SEXP s_knn_index,
                         SEXP s_bridge_knn_index, SEXP s_bridge_k,
                         SEXP s_bridge_k_max, SEXP s_bridge_growth,
                         SEXP s_prune_edges, SEXP s_prune_method,
                         SEXP s_prune_tau, SEXP s_prune_local_k,
                         SEXP s_with_pruned_edge_stats);
SEXP S_graph_connected_components(SEXP R_graph);
SEXP S_kNN(SEXP RX, SEXP Rk);
SEXP S_mstree(SEXP X);
SEXP S_prune_graph_global_geodesic_ratio(SEXP s_adj_list,
                                         SEXP s_weight_list,
                                         SEXP s_max_ratio_threshold,
                                         SEXP s_path_edge_ratio_percentile,
                                         SEXP s_with_pruned_edge_stats);
SEXP S_prune_graph_local_geodesic(SEXP s_X, SEXP s_adj_list,
                                  SEXP s_weight_list, SEXP s_prune_tau,
                                  SEXP s_prune_local_k,
                                  SEXP s_with_pruned_edge_stats);
SEXP S_wgraph_prune_long_edges(SEXP s_adj_list,
                               SEXP s_edge_length_list,
                               SEXP s_alt_path_len_ratio_thld,
                               SEXP s_use_total_length_constraint,
                               SEXP s_verbose);

SEXP S_shortest_path(SEXP s_graph, SEXP s_edge_lengths, SEXP s_vertices) {
    std::vector<std::vector<int>> graph = convert_adj_list_from_R(s_graph);
    std::vector<std::vector<double>> edge_lengths = convert_weight_list_from_R(s_edge_lengths);
    const int n = Rf_length(s_vertices);
    std::vector<int> vertices(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) {
        vertices[static_cast<size_t>(i)] =
            TYPEOF(s_vertices) == INTSXP ? INTEGER(s_vertices)[i] :
            static_cast<int>(REAL(s_vertices)[i]);
    }
    std::unique_ptr<std::vector<double>> result = shortest_path(graph, edge_lengths, vertices);
    return flat_vector_to_R_matrix(*result, n, n);
}

SEXP S_create_path_graph_plus(SEXP s_adj_list, SEXP s_edge_length_list, SEXP s_h) {
    std::vector<std::vector<int>> adj_vect = convert_adj_list_from_R(s_adj_list);
    std::vector<std::vector<double>> weight_vect = convert_weight_list_from_R(s_edge_length_list);
    int h = INTEGER(s_h)[0];
    path_graph_plus_t path_graph = create_path_graph_plus(adj_vect, weight_vect, h);
    return path_graph_plus_to_R(path_graph);
}

SEXP S_create_path_graph_series(SEXP s_adj_list, SEXP s_weight_list, SEXP s_h_values) {
    std::vector<std::vector<int>> adj_vect = convert_adj_list_from_R(s_adj_list);
    std::vector<std::vector<double>> weight_vect = convert_weight_list_from_R(s_weight_list);
    const int n = Rf_length(s_h_values);
    std::vector<int> h_values(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) {
        h_values[static_cast<size_t>(i)] = INTEGER(s_h_values)[i];
    }
    std::vector<path_graph_t> graph_series =
        create_path_graph_series(adj_vect, weight_vect, h_values);
    SEXP r_result = PROTECT(Rf_allocVector(VECSXP, n));
    for (int i = 0; i < n; ++i) {
        SEXP path_graph = PROTECT(path_graph_from_path_graph_t(graph_series[static_cast<size_t>(i)]));
        SET_VECTOR_ELT(r_result, i, path_graph);
        UNPROTECT(1);
    }
    UNPROTECT(1);
    return r_result;
}

SEXP S_create_uniform_grid_graph(SEXP s_adj_list,
                                 SEXP s_weight_list,
                                 SEXP s_grid_size,
                                 SEXP s_start_vertex,
                                 SEXP s_snap_tolerance) {
    std::vector<std::vector<int>> input_adj_list = convert_adj_list_from_R(s_adj_list);
    std::vector<std::vector<double>> input_weight_list = convert_weight_list_from_R(s_weight_list);
    const int grid_size = INTEGER(s_grid_size)[0];
    const int start_vertex = INTEGER(s_start_vertex)[0];
    const double snap_tolerance = REAL(s_snap_tolerance)[0];

    const double graph_diameter = vertex_eccentricity(input_adj_list, input_weight_list, start_vertex);
    const double grid_spacing = graph_diameter / grid_size;
    const double epsilon = grid_spacing * snap_tolerance;

    std::vector<std::map<int, double>> expanded(input_adj_list.size() + 2 * static_cast<size_t>(grid_size));
    for (int i = 0; i < static_cast<int>(input_adj_list.size()); ++i) {
        for (size_t j = 0; j < input_adj_list[static_cast<size_t>(i)].size(); ++j) {
            expanded[static_cast<size_t>(i)][input_adj_list[static_cast<size_t>(i)][j]] =
                input_weight_list[static_cast<size_t>(i)][j];
        }
    }

    struct vertex_data_t {
        double distance_from_start = 0.0;
        bool visited = false;
        int parent = -1;
    };
    std::vector<vertex_data_t> vertex_data(expanded.size());
    std::unordered_set<int> grid_vertices;
    grid_vertices.insert(start_vertex);
    vertex_data[static_cast<size_t>(start_vertex)].visited = true;
    std::queue<int> bfs_queue;
    bfs_queue.push(start_vertex);
    std::vector<std::tuple<int, int, double>> all_edges_to_process;
    while (!bfs_queue.empty()) {
        int current_vertex = bfs_queue.front();
        bfs_queue.pop();
        for (const auto& edge_info : expanded[static_cast<size_t>(current_vertex)]) {
            int neighbor = edge_info.first;
            double edge_length = edge_info.second;
            if (!vertex_data[static_cast<size_t>(neighbor)].visited) {
                vertex_data[static_cast<size_t>(neighbor)].visited = true;
                vertex_data[static_cast<size_t>(neighbor)].parent = current_vertex;
                vertex_data[static_cast<size_t>(neighbor)].distance_from_start =
                    vertex_data[static_cast<size_t>(current_vertex)].distance_from_start + edge_length;
                bfs_queue.push(neighbor);
                all_edges_to_process.emplace_back(current_vertex, neighbor, edge_length);
            }
        }
    }

    int next_vertex_id = static_cast<int>(input_adj_list.size());
    for (const auto& item : all_edges_to_process) {
        int v1 = std::get<0>(item);
        int v2 = std::get<1>(item);
        double edge_length = std::get<2>(item);
        double d_start = vertex_data[static_cast<size_t>(v1)].distance_from_start;
        double d_end = d_start + edge_length;
        int num_complete_intervals = static_cast<int>(d_start / grid_spacing);
        double next_grid_pos = (num_complete_intervals + 1) * grid_spacing;
        if (std::abs(next_grid_pos - d_start) < epsilon) {
            grid_vertices.insert(v1);
            next_grid_pos += grid_spacing;
        }
        if (next_grid_pos < d_end - epsilon) {
            remove_undirected_edge(expanded, v1, v2);
            int prev_vertex = v1;
            double curr_pos = next_grid_pos;
            while (curr_pos < d_end - epsilon) {
                if (next_vertex_id >= static_cast<int>(expanded.size())) {
                    expanded.resize(expanded.size() * 2);
                    vertex_data.resize(expanded.size());
                }
                int new_vertex = next_vertex_id++;
                grid_vertices.insert(new_vertex);
                double edge_weight = (prev_vertex == v1) ? curr_pos - d_start : grid_spacing;
                add_undirected_edge(expanded, prev_vertex, new_vertex, edge_weight);
                vertex_data[static_cast<size_t>(new_vertex)].distance_from_start = curr_pos;
                vertex_data[static_cast<size_t>(new_vertex)].parent = prev_vertex;
                prev_vertex = new_vertex;
                curr_pos += grid_spacing;
            }
            double final_weight = (prev_vertex == v1) ?
                edge_length : (d_end - vertex_data[static_cast<size_t>(prev_vertex)].distance_from_start);
            add_undirected_edge(expanded, prev_vertex, v2, final_weight);
            double closest_grid_pos = std::round(d_end / grid_spacing) * grid_spacing;
            if (std::abs(d_end - closest_grid_pos) < epsilon) grid_vertices.insert(v2);
        } else {
            double closest_grid_pos = std::round(d_end / grid_spacing) * grid_spacing;
            if (std::abs(d_end - closest_grid_pos) < epsilon) grid_vertices.insert(v2);
        }
    }
    while (!expanded.empty() && expanded.back().empty()) expanded.pop_back();

    const int n_vertices = static_cast<int>(expanded.size());
    SEXP r_result = PROTECT(Rf_allocVector(VECSXP, 3));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(names, 0, Rf_mkChar("adj_list"));
    SET_STRING_ELT(names, 1, Rf_mkChar("weight_list"));
    SET_STRING_ELT(names, 2, Rf_mkChar("grid_vertices"));
    Rf_setAttrib(r_result, R_NamesSymbol, names);

    SEXP r_adj_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    SEXP r_weight_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    for (int i = 0; i < n_vertices; ++i) {
        SEXP r_adj = PROTECT(Rf_allocVector(INTSXP, expanded[static_cast<size_t>(i)].size()));
        SEXP r_weights = PROTECT(Rf_allocVector(REALSXP, expanded[static_cast<size_t>(i)].size()));
        int idx = 0;
        for (const auto& edge_info : expanded[static_cast<size_t>(i)]) {
            INTEGER(r_adj)[idx] = edge_info.first + 1;
            REAL(r_weights)[idx] = edge_info.second;
            ++idx;
        }
        SET_VECTOR_ELT(r_adj_list, i, r_adj);
        SET_VECTOR_ELT(r_weight_list, i, r_weights);
        UNPROTECT(2);
    }
    SET_VECTOR_ELT(r_result, 0, r_adj_list);
    SET_VECTOR_ELT(r_result, 1, r_weight_list);

    SEXP r_grid_vertices = PROTECT(Rf_allocVector(INTSXP, grid_vertices.size()));
    int counter = 0;
    for (int v : grid_vertices) INTEGER(r_grid_vertices)[counter++] = v + 1;
    SET_VECTOR_ELT(r_result, 2, r_grid_vertices);
    UNPROTECT(5);
    return r_result;
}

static const R_CallMethodDef CallEntries[] = {
    {"S_adaptive_radius_edges_ann", (DL_FUNC) &S_adaptive_radius_edges_ann, 4},
    {"S_compute_mstree_total_length", (DL_FUNC) &S_compute_mstree_total_length, 1},
    {"S_create_mknn_graph", (DL_FUNC) &S_create_mknn_graph, 2},
    {"S_create_mknn_graphs", (DL_FUNC) &S_create_mknn_graphs, 7},
    {"S_create_mst_completion_graph", (DL_FUNC) &S_create_mst_completion_graph, 3},
    {"S_create_single_iknn_graph", (DL_FUNC) &S_create_single_iknn_graph, 13},
    {"S_create_iknn_graphs", (DL_FUNC) &S_create_iknn_graphs, 17},
    {"S_compare_iknn_graph_builders", (DL_FUNC) &S_compare_iknn_graph_builders, 4},
    {"S_create_geodesic_iknn_graph", (DL_FUNC) &S_create_geodesic_iknn_graph, 3},
    {"S_linf_simplex_knn", (DL_FUNC) &S_linf_simplex_knn, 3},
    {"S_create_sknn_graph", (DL_FUNC) &S_create_sknn_graph, 16},
    {"S_shortest_path", (DL_FUNC) &S_shortest_path, 3},
    {"S_create_path_graph_plus", (DL_FUNC) &S_create_path_graph_plus, 3},
    {"S_create_path_graph_series", (DL_FUNC) &S_create_path_graph_series, 3},
    {"S_wgraph_prune_long_edges", (DL_FUNC) &S_wgraph_prune_long_edges, 5},
    {"S_create_uniform_grid_graph", (DL_FUNC) &S_create_uniform_grid_graph, 5},
    {"S_graph_connected_components", (DL_FUNC) &S_graph_connected_components, 1},
    {"S_kNN", (DL_FUNC) &S_kNN, 2},
    {"S_mstree", (DL_FUNC) &S_mstree, 1},
    {"S_prune_graph_global_geodesic_ratio", (DL_FUNC) &S_prune_graph_global_geodesic_ratio, 5},
    {"S_prune_graph_local_geodesic", (DL_FUNC) &S_prune_graph_local_geodesic, 6},
    {NULL, NULL, 0}
};

void R_init_dgraphs(DllInfo* dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}

} // extern "C"
