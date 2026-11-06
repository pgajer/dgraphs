#include <ANN/ANN.h>
#include <R.h>
#include <Rinternals.h>

#include <algorithm>
#include <cmath>
#include <chrono>
#include <cstdint>
#include <limits>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

std::uint64_t edge_key(int u, int v) {
    if (u > v) {
        std::swap(u, v);
    }
    return (static_cast<std::uint64_t>(static_cast<std::uint32_t>(u)) << 32U) |
           static_cast<std::uint32_t>(v);
}

std::pair<int, int> unpack_edge_key(std::uint64_t key) {
    const int u = static_cast<int>(key >> 32U);
    const int v = static_cast<int>(key & 0xffffffffU);
    return {u, v};
}

double seconds_since(std::chrono::steady_clock::time_point start,
                     std::chrono::steady_clock::time_point end) {
    return std::chrono::duration<double>(end - start).count();
}

double adaptive_threshold(double sigma_i,
                          double sigma_j,
                          double radius_factor,
                          int radius_rule_id) {
    if (radius_rule_id == 0) {
        return radius_factor * std::max(sigma_i, sigma_j);
    }
    if (radius_rule_id == 1) {
        return radius_factor * std::min(sigma_i, sigma_j);
    }
    return radius_factor * std::sqrt(sigma_i * sigma_j);
}

double inclusive_squared_radius(double radius) {
    const double tol = 64.0 * std::numeric_limits<double>::epsilon();
    const double expanded_radius = radius * (1.0 + tol) + tol;
    return expanded_radius * expanded_radius;
}

void check_matrix(SEXP s_X, int& n, int& p) {
    if (!Rf_isMatrix(s_X) || TYPEOF(s_X) != REALSXP) {
        Rf_error("X must be a numeric matrix.");
    }
    SEXP s_dim = PROTECT(Rf_getAttrib(s_X, R_DimSymbol));
    if (s_dim == R_NilValue || TYPEOF(s_dim) != INTSXP || Rf_length(s_dim) < 2) {
        UNPROTECT(1);
        Rf_error("X must have a valid dim attribute.");
    }
    n = INTEGER(s_dim)[0];
    p = INTEGER(s_dim)[1];
    UNPROTECT(1);
    if (n < 2 || p < 1) {
        Rf_error("X must have at least two rows and one column.");
    }
}

ANNpointArray ann_points_from_R_matrix(const double* X, int n, int p) {
    ANNpointArray data = annAllocPts(n, p);
    for (int i = 0; i < n; ++i) {
        for (int col = 0; col < p; ++col) {
            data[i][col] = X[i + n * col];
        }
    }
    return data;
}

std::vector<double> local_scales(ANNkd_tree* tree,
                                 ANNpointArray data,
                                 int n,
                                 int k_scale) {
    const int k_query = std::min(n, k_scale + 1);
    std::vector<ANNidx> idx(static_cast<size_t>(k_query));
    std::vector<ANNdist> dist(static_cast<size_t>(k_query));
    std::vector<double> sigma(static_cast<size_t>(n), 0.0);

    for (int i = 0; i < n; ++i) {
        tree->annkSearch(data[i], k_query, idx.data(), dist.data(), 0.0);
        int seen_nonself = 0;
        double kth = 0.0;
        for (int j = 0; j < k_query; ++j) {
            if (idx[static_cast<size_t>(j)] == i) {
                continue;
            }
            ++seen_nonself;
            kth = ANN_ROOT(static_cast<double>(dist[static_cast<size_t>(j)]));
            if (seen_nonself == k_scale) {
                break;
            }
        }

        // Degenerate tie safeguard: if the self point did not appear in the
        // bounded result because many duplicates tie at distance zero, the
        // k_scale-th non-self distance is still represented by position k_scale-1.
        if (seen_nonself < k_scale && k_query > 0) {
            const int fallback = std::min(k_scale - 1, k_query - 1);
            kth = ANN_ROOT(static_cast<double>(dist[static_cast<size_t>(fallback)]));
        }
        sigma[static_cast<size_t>(i)] = kth;
    }
    return sigma;
}

std::vector<std::vector<double>> local_scales_from_max_knn(
        const std::vector<ANNidx>& knn_idx,
        const std::vector<ANNdist>& knn_dist,
        int n,
        int k_query,
        const std::vector<int>& k_values) {
    std::vector<std::vector<double>> sigma_by_k(
        k_values.size(),
        std::vector<double>(static_cast<size_t>(n), 0.0)
    );

    for (size_t k_pos = 0; k_pos < k_values.size(); ++k_pos) {
        const int k_scale = k_values[k_pos];
        for (int i = 0; i < n; ++i) {
            int seen_nonself = 0;
            double kth = 0.0;
            const int row_offset = i * k_query;
            for (int j = 0; j < k_query; ++j) {
                const int idx = knn_idx[static_cast<size_t>(row_offset + j)];
                if (idx == i) {
                    continue;
                }
                ++seen_nonself;
                kth = ANN_ROOT(static_cast<double>(
                    knn_dist[static_cast<size_t>(row_offset + j)]
                ));
                if (seen_nonself == k_scale) {
                    break;
                }
            }

            // Match local_scales(): when many duplicate points displace self
            // from the bounded result, the kth non-self distance is represented
            // by the same sorted-distance fallback position.
            if (seen_nonself < k_scale && k_query > 0) {
                const int fallback = std::min(k_scale - 1, k_query - 1);
                kth = ANN_ROOT(static_cast<double>(
                    knn_dist[static_cast<size_t>(row_offset + fallback)]
                ));
            }
            sigma_by_k[k_pos][static_cast<size_t>(i)] = kth;
        }
    }

    return sigma_by_k;
}

SEXP edge_map_to_data_frame(const std::map<std::uint64_t, double>& edges) {
    const int n_edges = static_cast<int>(edges.size());
    SEXP edge_df = PROTECT(Rf_allocVector(VECSXP, 3));
    SEXP edge_names = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(edge_names, 0, Rf_mkChar("from"));
    SET_STRING_ELT(edge_names, 1, Rf_mkChar("to"));
    SET_STRING_ELT(edge_names, 2, Rf_mkChar("weight"));
    Rf_setAttrib(edge_df, R_NamesSymbol, edge_names);

    SEXP from = PROTECT(Rf_allocVector(INTSXP, n_edges));
    SEXP to = PROTECT(Rf_allocVector(INTSXP, n_edges));
    SEXP weight = PROTECT(Rf_allocVector(REALSXP, n_edges));

    int row = 0;
    for (const auto& kv : edges) {
        const auto uv = unpack_edge_key(kv.first);
        INTEGER(from)[row] = uv.first + 1;
        INTEGER(to)[row] = uv.second + 1;
        REAL(weight)[row] = kv.second;
        ++row;
    }

    SET_VECTOR_ELT(edge_df, 0, from);
    SET_VECTOR_ELT(edge_df, 1, to);
    SET_VECTOR_ELT(edge_df, 2, weight);

    SEXP df_class = PROTECT(Rf_allocVector(STRSXP, 1));
    SET_STRING_ELT(df_class, 0, Rf_mkChar("data.frame"));
    Rf_setAttrib(edge_df, R_ClassSymbol, df_class);

    SEXP compact_rownames = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(compact_rownames)[0] = NA_INTEGER;
    INTEGER(compact_rownames)[1] = -n_edges;
    Rf_setAttrib(edge_df, R_RowNamesSymbol, compact_rownames);

    UNPROTECT(7);
    return edge_df;
}

SEXP numeric_vector_from_std_vector(const std::vector<double>& values) {
    SEXP out = PROTECT(Rf_allocVector(REALSXP, static_cast<int>(values.size())));
    for (int i = 0; i < Rf_length(out); ++i) {
        REAL(out)[i] = values[static_cast<size_t>(i)];
    }
    UNPROTECT(1);
    return out;
}

}  // namespace

extern "C" SEXP S_adaptive_radius_edges_ann(SEXP s_X,
                                            SEXP s_k_scale,
                                            SEXP s_radius_factor,
                                            SEXP s_radius_rule_id) {
    int n = 0;
    int p = 0;
    check_matrix(s_X, n, p);
    const int k_scale = Rf_asInteger(s_k_scale);
    const double radius_factor = Rf_asReal(s_radius_factor);
    const int radius_rule_id = Rf_asInteger(s_radius_rule_id);

    if (k_scale < 1 || k_scale >= n) {
        Rf_error("k.scale must be a positive integer smaller than nrow(X).");
    }
    if (!R_FINITE(radius_factor) || radius_factor <= 0.0) {
        Rf_error("radius.factor must be a positive finite numeric scalar.");
    }
    if (radius_rule_id < 0 || radius_rule_id > 2) {
        Rf_error("Invalid radius.rule id.");
    }

    const auto setup_start = std::chrono::steady_clock::now();
    const double* X = REAL(s_X);
    ANNpointArray data = ann_points_from_R_matrix(X, n, p);
    ANNkd_tree* tree = nullptr;

    try {
        tree = new ANNkd_tree(data, n, p);
    } catch (...) {
        annDeallocPts(data);
        annClose();
        throw;
    }
    const auto setup_end = std::chrono::steady_clock::now();

    std::vector<double> sigma;
    std::map<std::uint64_t, double> edges;
    std::chrono::steady_clock::time_point scale_start;
    std::chrono::steady_clock::time_point scale_end;
    std::chrono::steady_clock::time_point radius_start;
    std::chrono::steady_clock::time_point radius_end;

    try {
        scale_start = std::chrono::steady_clock::now();
        sigma = local_scales(tree, data, n, k_scale);
        scale_end = std::chrono::steady_clock::now();

        radius_start = std::chrono::steady_clock::now();
        const double tol = 64.0 * std::numeric_limits<double>::epsilon();
        for (int i = 0; i < n; ++i) {
            const double search_radius = radius_factor * sigma[static_cast<size_t>(i)];
            const double sq_radius = inclusive_squared_radius(search_radius);
            int count = tree->annkFRSearch(data[i], sq_radius, 0, nullptr, nullptr, 0.0);
            if (count <= 0) {
                continue;
            }
            std::vector<ANNidx> idx(static_cast<size_t>(count));
            std::vector<ANNdist> dist(static_cast<size_t>(count));
            tree->annkFRSearch(data[i], sq_radius, count, idx.data(), dist.data(), 0.0);

            for (int pos = 0; pos < count; ++pos) {
                const int j = idx[static_cast<size_t>(pos)];
                if (j < 0 || j >= n || j == i) {
                    continue;
                }
                const double d = ANN_ROOT(static_cast<double>(dist[static_cast<size_t>(pos)]));
                const double threshold = adaptive_threshold(
                    sigma[static_cast<size_t>(i)],
                    sigma[static_cast<size_t>(j)],
                    radius_factor,
                    radius_rule_id
                );
                if (d <= threshold * (1.0 + tol) + tol) {
                    edges[edge_key(i, j)] = d;
                }
            }
        }
        radius_end = std::chrono::steady_clock::now();
    } catch (...) {
        delete tree;
        annDeallocPts(data);
        annClose();
        throw;
    }

    delete tree;
    annDeallocPts(data);
    annClose();

    const auto materialization_start = std::chrono::steady_clock::now();
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(names, 0, Rf_mkChar("edges"));
    SET_STRING_ELT(names, 1, Rf_mkChar("sigma"));
    SET_STRING_ELT(names, 2, Rf_mkChar("timing"));
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(1);

    const int n_edges = static_cast<int>(edges.size());
    SEXP edge_df = PROTECT(Rf_allocVector(VECSXP, 3));
    SEXP edge_names = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(edge_names, 0, Rf_mkChar("from"));
    SET_STRING_ELT(edge_names, 1, Rf_mkChar("to"));
    SET_STRING_ELT(edge_names, 2, Rf_mkChar("weight"));
    Rf_setAttrib(edge_df, R_NamesSymbol, edge_names);
    UNPROTECT(1);

    SEXP from = PROTECT(Rf_allocVector(INTSXP, n_edges));
    SEXP to = PROTECT(Rf_allocVector(INTSXP, n_edges));
    SEXP weight = PROTECT(Rf_allocVector(REALSXP, n_edges));

    int row = 0;
    for (const auto& kv : edges) {
        const auto uv = unpack_edge_key(kv.first);
        INTEGER(from)[row] = uv.first + 1;
        INTEGER(to)[row] = uv.second + 1;
        REAL(weight)[row] = kv.second;
        ++row;
    }
    SET_VECTOR_ELT(edge_df, 0, from);
    SET_VECTOR_ELT(edge_df, 1, to);
    SET_VECTOR_ELT(edge_df, 2, weight);

    SEXP df_class = PROTECT(Rf_allocVector(STRSXP, 1));
    SET_STRING_ELT(df_class, 0, Rf_mkChar("data.frame"));
    Rf_setAttrib(edge_df, R_ClassSymbol, df_class);

    SEXP sigma_vec = PROTECT(Rf_allocVector(REALSXP, n));
    for (int i = 0; i < n; ++i) {
        REAL(sigma_vec)[i] = sigma[static_cast<size_t>(i)];
    }

    // Compact data.frame row names: c(NA, -n_edges)
    SEXP compact_rownames = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(compact_rownames)[0] = NA_INTEGER;
    INTEGER(compact_rownames)[1] = -n_edges;
    Rf_setAttrib(edge_df, R_RowNamesSymbol, compact_rownames);

    SET_VECTOR_ELT(out, 0, edge_df);
    SET_VECTOR_ELT(out, 1, sigma_vec);

    const auto materialization_end = std::chrono::steady_clock::now();

    SEXP timing_vec = PROTECT(Rf_allocVector(REALSXP, 4));
    REAL(timing_vec)[0] = seconds_since(setup_start, setup_end);
    REAL(timing_vec)[1] = seconds_since(scale_start, scale_end);
    REAL(timing_vec)[2] = seconds_since(radius_start, radius_end);
    REAL(timing_vec)[3] = seconds_since(materialization_start, materialization_end);
    SEXP timing_names = PROTECT(Rf_allocVector(STRSXP, 4));
    SET_STRING_ELT(timing_names, 0, Rf_mkChar("ann.setup"));
    SET_STRING_ELT(timing_names, 1, Rf_mkChar("ann.scale.search"));
    SET_STRING_ELT(timing_names, 2, Rf_mkChar("ann.fixed.radius.search"));
    SET_STRING_ELT(timing_names, 3, Rf_mkChar("ann.edge.materialization"));
    Rf_setAttrib(timing_vec, R_NamesSymbol, timing_names);
    UNPROTECT(1);
    SET_VECTOR_ELT(out, 2, timing_vec);

    UNPROTECT(9);
    return out;
}

extern "C" SEXP S_adaptive_radius_edges_ann_graphs(SEXP s_X,
                                                   SEXP s_k_values,
                                                   SEXP s_radius_factor,
                                                   SEXP s_radius_rule_id) {
    int n = 0;
    int p = 0;
    check_matrix(s_X, n, p);
    if (TYPEOF(s_k_values) != INTSXP || Rf_length(s_k_values) < 1) {
        Rf_error("k.values must be a non-empty integer vector.");
    }

    std::vector<int> k_values(static_cast<size_t>(Rf_length(s_k_values)));
    int max_k = 0;
    for (int i = 0; i < Rf_length(s_k_values); ++i) {
        const int k = INTEGER(s_k_values)[i];
        if (k < 1 || k >= n) {
            Rf_error("k.values must contain positive integers smaller than nrow(X).");
        }
        k_values[static_cast<size_t>(i)] = k;
        max_k = std::max(max_k, k);
    }

    const double radius_factor = Rf_asReal(s_radius_factor);
    const int radius_rule_id = Rf_asInteger(s_radius_rule_id);
    if (!R_FINITE(radius_factor) || radius_factor <= 0.0) {
        Rf_error("radius.factor must be a positive finite numeric scalar.");
    }
    if (radius_rule_id < 0 || radius_rule_id > 2) {
        Rf_error("Invalid radius.rule id.");
    }

    const auto setup_start = std::chrono::steady_clock::now();
    const double* X = REAL(s_X);
    ANNpointArray data = ann_points_from_R_matrix(X, n, p);
    ANNkd_tree* tree = nullptr;

    try {
        tree = new ANNkd_tree(data, n, p);
    } catch (...) {
        annDeallocPts(data);
        annClose();
        throw;
    }
    const auto setup_end = std::chrono::steady_clock::now();

    const int k_query = std::min(n, max_k + 1);
    std::vector<ANNidx> knn_idx(static_cast<size_t>(n * k_query));
    std::vector<ANNdist> knn_dist(static_cast<size_t>(n * k_query));
    std::vector<std::vector<double>> sigma_by_k;
    std::vector<std::map<std::uint64_t, double>> edges_by_k(k_values.size());
    std::chrono::steady_clock::time_point scale_start;
    std::chrono::steady_clock::time_point scale_end;
    std::chrono::steady_clock::time_point radius_start;
    std::chrono::steady_clock::time_point radius_end;

    try {
        scale_start = std::chrono::steady_clock::now();
        for (int i = 0; i < n; ++i) {
            tree->annkSearch(
                data[i],
                k_query,
                &knn_idx[static_cast<size_t>(i * k_query)],
                &knn_dist[static_cast<size_t>(i * k_query)],
                0.0
            );
        }
        sigma_by_k = local_scales_from_max_knn(
            knn_idx,
            knn_dist,
            n,
            k_query,
            k_values
        );
        scale_end = std::chrono::steady_clock::now();

        radius_start = std::chrono::steady_clock::now();
        const double tol = 64.0 * std::numeric_limits<double>::epsilon();
        std::vector<double> sigma_i_by_k(k_values.size(), 0.0);
        std::vector<double> directional_sq_radius_by_k(k_values.size(), 0.0);
        for (int i = 0; i < n; ++i) {
            double max_sigma_i = 0.0;
            for (size_t k_pos = 0; k_pos < k_values.size(); ++k_pos) {
                const double sigma_i = sigma_by_k[k_pos][static_cast<size_t>(i)];
                sigma_i_by_k[k_pos] = sigma_i;
                const double directional_radius = radius_factor * sigma_i;
                directional_sq_radius_by_k[k_pos] =
                    inclusive_squared_radius(directional_radius);
                max_sigma_i = std::max(max_sigma_i, sigma_i);
            }

            const double search_radius = radius_factor * max_sigma_i;
            const double sq_radius = inclusive_squared_radius(search_radius);
            int count = tree->annkFRSearch(data[i], sq_radius, 0, nullptr, nullptr, 0.0);
            if (count <= 0) {
                continue;
            }
            std::vector<ANNidx> idx(static_cast<size_t>(count));
            std::vector<ANNdist> dist(static_cast<size_t>(count));
            tree->annkFRSearch(data[i], sq_radius, count, idx.data(), dist.data(), 0.0);

            for (int pos = 0; pos < count; ++pos) {
                const int j = idx[static_cast<size_t>(pos)];
                if (j < 0 || j >= n || j == i) {
                    continue;
                }
                const double candidate_sq = static_cast<double>(
                    dist[static_cast<size_t>(pos)]
                );
                const double d = ANN_ROOT(candidate_sq);
                const std::uint64_t key = edge_key(i, j);
                for (size_t k_pos = 0; k_pos < k_values.size(); ++k_pos) {
                    if (candidate_sq > directional_sq_radius_by_k[k_pos]) {
                        continue;
                    }
                    const std::vector<double>& sigma = sigma_by_k[k_pos];
                    const double threshold = adaptive_threshold(
                        sigma_i_by_k[k_pos],
                        sigma[static_cast<size_t>(j)],
                        radius_factor,
                        radius_rule_id
                    );
                    if (d <= threshold * (1.0 + tol) + tol) {
                        edges_by_k[k_pos][key] = d;
                    }
                }
            }
        }
        radius_end = std::chrono::steady_clock::now();
    } catch (...) {
        delete tree;
        annDeallocPts(data);
        annClose();
        throw;
    }

    delete tree;
    annDeallocPts(data);
    annClose();

    const auto materialization_start = std::chrono::steady_clock::now();
    const int n_k = static_cast<int>(k_values.size());
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 4));
    SEXP out_names = PROTECT(Rf_allocVector(STRSXP, 4));
    SET_STRING_ELT(out_names, 0, Rf_mkChar("edges"));
    SET_STRING_ELT(out_names, 1, Rf_mkChar("sigma"));
    SET_STRING_ELT(out_names, 2, Rf_mkChar("k_values"));
    SET_STRING_ELT(out_names, 3, Rf_mkChar("timing"));
    Rf_setAttrib(out, R_NamesSymbol, out_names);

    SEXP edges_list = PROTECT(Rf_allocVector(VECSXP, n_k));
    SEXP sigma_list = PROTECT(Rf_allocVector(VECSXP, n_k));
    SEXP list_names = PROTECT(Rf_allocVector(STRSXP, n_k));
    SEXP k_vec = PROTECT(Rf_allocVector(INTSXP, n_k));
    for (int i = 0; i < n_k; ++i) {
        const std::string k_name = std::to_string(k_values[static_cast<size_t>(i)]);
        SET_STRING_ELT(list_names, i, Rf_mkChar(k_name.c_str()));
        INTEGER(k_vec)[i] = k_values[static_cast<size_t>(i)];
    }
    Rf_setAttrib(edges_list, R_NamesSymbol, list_names);
    Rf_setAttrib(sigma_list, R_NamesSymbol, list_names);

    for (int i = 0; i < n_k; ++i) {
        SEXP edge_df = PROTECT(edge_map_to_data_frame(edges_by_k[static_cast<size_t>(i)]));
        SET_VECTOR_ELT(edges_list, i, edge_df);
        UNPROTECT(1);

        SEXP sigma_vec = PROTECT(numeric_vector_from_std_vector(sigma_by_k[static_cast<size_t>(i)]));
        SET_VECTOR_ELT(sigma_list, i, sigma_vec);
        UNPROTECT(1);
    }

    SET_VECTOR_ELT(out, 0, edges_list);
    SET_VECTOR_ELT(out, 1, sigma_list);
    SET_VECTOR_ELT(out, 2, k_vec);

    const auto materialization_end = std::chrono::steady_clock::now();
    SEXP timing_vec = PROTECT(Rf_allocVector(REALSXP, 4));
    REAL(timing_vec)[0] = seconds_since(setup_start, setup_end);
    REAL(timing_vec)[1] = seconds_since(scale_start, scale_end);
    REAL(timing_vec)[2] = seconds_since(radius_start, radius_end);
    REAL(timing_vec)[3] = seconds_since(materialization_start, materialization_end);
    SEXP timing_names = PROTECT(Rf_allocVector(STRSXP, 4));
    SET_STRING_ELT(timing_names, 0, Rf_mkChar("ann.setup"));
    SET_STRING_ELT(timing_names, 1, Rf_mkChar("ann.max.scale.search"));
    SET_STRING_ELT(timing_names, 2, Rf_mkChar("ann.fixed.radius.search"));
    SET_STRING_ELT(timing_names, 3, Rf_mkChar("ann.edge.materialization"));
    Rf_setAttrib(timing_vec, R_NamesSymbol, timing_names);
    SET_VECTOR_ELT(out, 3, timing_vec);

    UNPROTECT(8);
    return out;
}
