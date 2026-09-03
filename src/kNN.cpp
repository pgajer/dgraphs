#include "dgraphs/kNN.h"
#include "dgraphs/ann_raii.hpp"

#include <vector>
#include <cmath>
#include <stdexcept>

#include <ANN/ANN.h>
#include <R.h>
#include <Rinternals.h>

extern "C" {
    SEXP S_kNN(SEXP RX, SEXP Rk);
}

// ----------- C++ helper (RAII-only) -----------
knn_result_t kNN(const std::vector<std::vector<double>>& X, int k) {
    const int n = static_cast<int>(X.size());
    if (n <= 0) throw std::invalid_argument("kNN(): X has zero rows");
    const int d = static_cast<int>(X[0].size());
    if (d <= 0) throw std::invalid_argument("kNN(): X has zero columns");
    for (int i = 1; i < n; ++i) {
        if (static_cast<int>(X[i].size()) != d)
            throw std::invalid_argument("kNN(): inconsistent row lengths");
    }
    if (k <= 0)      throw std::invalid_argument("kNN(): k must be positive");
    if (k > n)       throw std::invalid_argument("kNN(): k cannot exceed n");

    // Build ANN dataset
    ann_dataset_t dataset(n, d);
    ANNpointArray dataPts = dataset.points;
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < d; ++j)
            dataPts[i][j] = X[i][j];

    dataset.tree = new ANNkd_tree(dataPts, n, d);
    ANNkd_tree* kdTree = dataset.tree;

    // Scratch buffers
    std::vector<ANNidx>  nnIdx(static_cast<size_t>(k));
    std::vector<ANNdist> nnDist(static_cast<size_t>(k));

    knn_result_t out;
    out.n = n; out.k = k;
    out.indices.resize(static_cast<size_t>(n) * k);
    out.distances.resize(static_cast<size_t>(n) * k);

    // Exact search
    for (int i = 0; i < n; ++i) {
        kdTree->annkSearch(dataPts[i], k, nnIdx.data(), nnDist.data(), 0.0);
        for (int j = 0; j < k; ++j) {
            const size_t off = static_cast<size_t>(i) * k + j;
            out.indices[off]   = nnIdx[j];
            out.distances[off] = ANN_ROOT(static_cast<double>(nnDist[j]));
        }
    }

    return out;
}

// Direct ANN implementation. The caller must protect the returned object.
SEXP S_kNN(SEXP RX, SEXP Rk) {

    if (!Rf_isMatrix(RX) || TYPEOF(RX) != REALSXP) {
        Rf_error("S_kNN: RX must be a numeric matrix");
    }
    const int k = Rf_asInteger(Rk);

    SEXP s_dim = PROTECT(Rf_getAttrib(RX, R_DimSymbol));
    if (s_dim == R_NilValue || TYPEOF(s_dim) != INTSXP || Rf_length(s_dim) < 2) {
        UNPROTECT(1);
        Rf_error("X must be a numeric matrix with valid dimensions.");
    }
    const int n = INTEGER(s_dim)[0];
    const int d = INTEGER(s_dim)[1];
    UNPROTECT(1); // s_dim

    if (n < 1 || d < 1 || k == NA_INTEGER || k < 1 || k > n) {
        Rf_error("S_kNN: require positive matrix dimensions and 1 <= k <= nrow(X)");
    }

    const double* X = REAL(RX);
    for (R_xlen_t i = 0; i < XLENGTH(RX); ++i) {
        if (!R_FINITE(X[i])) Rf_error("S_kNN: X must contain only finite values");
    }
    ann_dataset_t dataset(n, d);
    ANNpointArray dataPts = dataset.points;
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < d; ++j)
            dataPts[i][j] = X[i + n * j];

    dataset.tree = new ANNkd_tree(dataPts, n, d);
    ANNkd_tree* kdTree = dataset.tree;

    std::vector<ANNidx>  nnIdx(static_cast<size_t>(k));
    std::vector<ANNdist> nnDist(static_cast<size_t>(k));

    SEXP res = PROTECT(Rf_allocVector(VECSXP, 2));

    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));
        SET_STRING_ELT(names, 0, Rf_mkChar("indices"));
        SET_STRING_ELT(names, 1, Rf_mkChar("distances"));
        Rf_setAttrib(res, R_NamesSymbol, names);
        UNPROTECT(1); // names
    }

    {
        SEXP nn_i = PROTECT(Rf_allocMatrix(INTSXP,  n, k));
        SEXP nn_d = PROTECT(Rf_allocMatrix(REALSXP, n, k));

        for (int i = 0; i < n; ++i) {
            kdTree->annkSearch(dataPts[i], k, nnIdx.data(), nnDist.data(), 0.0);
            for (int j = 0; j < k; ++j) {
                INTEGER(nn_i)[i + n * j] = nnIdx[j];
                REAL(nn_d)[i + n * j]    = ANN_ROOT(static_cast<double>(nnDist[j]));
            }
        }

        SET_VECTOR_ELT(res, 0, nn_i);
        SET_VECTOR_ELT(res, 1, nn_d);
        UNPROTECT(2); // nn_i, nn_d
    }

    UNPROTECT(1); // res
    return res;
}
