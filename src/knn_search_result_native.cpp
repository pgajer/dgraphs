#include "dgraphs/knn_search_result.hpp"
#include "dgraphs/kNN_r.h"
#include "dgraphs/neighborhood.hpp"
#include <R.h>
#include <Rinternals.h>
#include <limits>

knn_search_result_t compute_knn(SEXP RX, int k) {
    if (TYPEOF(RX) != REALSXP || !Rf_isMatrix(RX)) Rf_error("X must be a numeric matrix.");
    const int n = Rf_nrows(RX), p = Rf_ncols(RX);
    if (k < 1 || k > n) Rf_error("Invalid neighborhood size.");
    // One extra candidate detects boundary ties. Only tied rows need the
    // exact scan; sorting an arbitrary ANN tie subset would be insufficient.
    const int query_k = std::min(n, k + 1);
    SEXP Rk = PROTECT(Rf_ScalarInteger(query_k));
    SEXP neighbors = PROTECT(S_kNN(RX, Rk));
    const int* indices = INTEGER(VECTOR_ELT(neighbors, 0));
    const double* values = REAL(VECTOR_ELT(neighbors, 1));
    const double* x = REAL(RX);
    knn_search_result_t result(n, k);
    for (int i = 0; i < n; ++i) {
        std::vector<std::pair<double, int>> candidates;
        for (int j = 0; j < query_k; ++j) candidates.emplace_back(values[i+n*j], indices[i+n*j]);
        auto others = dgraphs_rank_others(std::move(candidates), i, k);
        const bool tied = k > 1 && static_cast<int>(others.size()) >= k &&
            others[k-2].first == others[k-1].first;
        if (tied || static_cast<int>(others.size()) < k-1) {
            candidates.clear();
            for (int v = 0; v < n; ++v) {
                double d = 0;
                for (int col = 0; col < p; ++col) {
                    const double delta = x[i+n*col] - x[v+n*col];
                    d += delta*delta;
                }
                candidates.emplace_back(std::sqrt(d), v);
            }
            others = dgraphs_rank_others(std::move(candidates), i, k-1);
        }
        result.indices[i][0] = i;
        result.distances[i][0] = 0;
        for (int j = 1; j < k; ++j) {
            result.indices[i][j] = others[j-1].second;
            result.distances[i][j] = others[j-1].first;
        }
    }
    UNPROTECT(2);
    return result;
}
