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
        Rf_error("ANN kd-tree construction failed.");
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
            const double sq_radius = search_radius * search_radius;
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
        Rf_error("ANN adaptive-radius edge construction failed.");
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
