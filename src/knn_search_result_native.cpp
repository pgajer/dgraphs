#include "knn_search_result.hpp"
#include "kNN_r.h"

#include <R.h>
#include <Rinternals.h>

knn_search_result_t compute_knn(SEXP RX, int k) {
    if (TYPEOF(RX) != REALSXP) {
        Rf_error("RX must be REALSXP.");
    }

    SEXP s_dim = PROTECT(Rf_getAttrib(RX, R_DimSymbol));
    if (s_dim == R_NilValue || TYPEOF(s_dim) != INTSXP || Rf_length(s_dim) < 2) {
        UNPROTECT(1);
        Rf_error("X must be a numeric matrix with valid dimensions.");
    }
    const int n_points = INTEGER(s_dim)[0];
    UNPROTECT(1);

    SEXP Rk = PROTECT(Rf_ScalarInteger(k));
    SEXP knn_res = PROTECT(S_kNN(RX, Rk));
    UNPROTECT(1);
    int* indices_raw = INTEGER(VECTOR_ELT(knn_res, 0));
    double* dist_raw = REAL(VECTOR_ELT(knn_res, 1));

    knn_search_result_t result(static_cast<size_t>(n_points),
                               static_cast<size_t>(k));

    for (int i = 0; i < n_points; ++i) {
        for (int j = 0; j < k; ++j) {
            result.indices[static_cast<size_t>(i)][static_cast<size_t>(j)] =
                indices_raw[i + n_points * j];
            result.distances[static_cast<size_t>(i)][static_cast<size_t>(j)] =
                dist_raw[i + n_points * j];
        }
    }

    UNPROTECT(1);
    return result;
}
