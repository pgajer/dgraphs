#include "dgraphs/neighborhood.hpp"
#include "dgraphs/linf_simplex_knn.hpp"
#include "dgraphs/linf_simplex_distance.hpp"
#include <R.h>
#include <R_ext/Utils.h>
#include <Rinternals.h>
#include <limits>

// Exhaustive row-wise search. Never restrict candidates to endpoint-face trees:
// a shorter path through an intermediate face can change neighbor identities.
// Working memory is O(n + n*k + nonzeros), not a dense n-by-n matrix.
knn_search_result_t compute_linf_simplex_knn(SEXP RX, int k, double tol) {
    if (TYPEOF(RX) != REALSXP || !Rf_isMatrix(RX)) Rf_error("X must be a numeric matrix.");
    SEXP dim = Rf_getAttrib(RX, R_DimSymbol);
    const int n = INTEGER(dim)[0], d = INTEGER(dim)[1];
    if (n <= 0 || d <= 0 || k <= 0 || k > n) Rf_error("Require positive dimensions and 1 <= k <= nrow(X).");
    if (!std::isfinite(tol) || tol <= 0) Rf_error("linf.tol must be positive and finite.");
    const double* x = REAL(RX);
    std::vector<dgraphs_simplex::Row> rows(n);
    for (int i = 0; i < n; ++i) {
        double maximum = 0;
        for (int j = 0; j < d; ++j) {
            double v = x[static_cast<size_t>(i)+static_cast<size_t>(n)*j];
            if (!std::isfinite(v) || v < -tol) Rf_error("X must be finite and nonnegative within linf.tol.");
            maximum = std::max(maximum,v);
        }
        if (std::fabs(maximum-1) > tol || maximum <= 0) Rf_error("Each row of X must be L-infinity normalized within linf.tol.");
        // Snap tiny negative roundoff to zero and normalize admitted near-one rows.
        // Active faces are exact maxima after normalization, as in the general API.
        for (int j = 0; j < d; ++j) if (x[static_cast<size_t>(i)+static_cast<size_t>(n)*j] > 0) {
            rows[i].id.push_back(j);rows[i].value.push_back(x[static_cast<size_t>(i)+static_cast<size_t>(n)*j]/maximum);
        }
    }
    knn_search_result_t result(static_cast<size_t>(n), static_cast<size_t>(k));
    std::vector<double> distances(n);
    for (int i = 0; i < n; ++i) {
        for (int j = 0; j < n; ++j) {
            if (j % 128 == 0) R_CheckUserInterrupt();
            distances[j] = dgraphs_simplex::solve(rows[i],rows[j]).distance;
        }
        auto others = dgraphs_nearest_others(distances,i,k-1);
        result.indices[i][0]=i;result.distances[i][0]=0;
        for (int j = 1; j < k; ++j) {
            result.indices[i][j]=others[j-1];result.distances[i][j]=distances[others[j-1]];
        }
    }
    return result;
}

extern "C" SEXP S_linf_simplex_knn(SEXP s_X, SEXP s_k, SEXP s_linf_tol) {
    const int k = Rf_asInteger(s_k);
    const double tol = Rf_asReal(s_linf_tol);

    const knn_search_result_t knn = compute_linf_simplex_knn(s_X, k, tol);
    const int n = static_cast<int>(knn.n_points);

    SEXP out = PROTECT(Rf_allocVector(VECSXP, 2));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(names, 0, Rf_mkChar("indices"));
    SET_STRING_ELT(names, 1, Rf_mkChar("distances"));
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(1);

    SEXP indices = PROTECT(Rf_allocMatrix(INTSXP, n, k));
    SEXP distances = PROTECT(Rf_allocMatrix(REALSXP, n, k));

    for (int i = 0; i < n; ++i) {
        for (int j = 0; j < k; ++j) {
            INTEGER(indices)[static_cast<size_t>(i) + static_cast<size_t>(n) * j] =
                knn.indices[static_cast<size_t>(i)][static_cast<size_t>(j)];
            REAL(distances)[static_cast<size_t>(i) + static_cast<size_t>(n) * j] =
                knn.distances[static_cast<size_t>(i)][static_cast<size_t>(j)];
        }
    }

    SET_VECTOR_ELT(out, 0, indices);
    SET_VECTOR_ELT(out, 1, distances);
    UNPROTECT(3);

    return out;
}
