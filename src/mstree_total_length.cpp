#include "mstree.h"
#include "mstree_total_length_r.h"
#include "kNN.h"
#include "SEXP_cpp_conversion_utils.hpp"

#include <vector>
#include <algorithm>
#include <numeric>
#include <cmath>
#include <cstdint>

#include <R.h>
#include <Rinternals.h>

/**
 * @brief Computes the total edge length of the minimal spanning tree
 * @param X A vector of vectors representing the input data points
 * @return The total edge length of the minimal spanning tree
 */
double compute_mstree_total_length(
    const std::vector<std::vector<double>>& X
    ) {

    size_t n_points = X.size();
    if (n_points > static_cast<size_t>(INT_MAX)) {
        Rf_error("Number of points exceeds maximum supported by C_mstree");
    }
    int n_points_int = static_cast<int>(n_points);
    size_t n_points_minus_one = n_points - 1;

    std::vector<int> nn_i(n_points * n_points_minus_one);
    std::vector<double> nn_d(n_points * n_points_minus_one);

    auto knn_res = kNN(X, n_points);

    for (size_t point = 0; point < n_points; ++point) {
        for (size_t j = 1; j < n_points; ++j) {
            size_t col_major_i = point + j * n_points;
            size_t row_major_i = point * n_points_minus_one + j - 1;
            nn_d[row_major_i] = knn_res.distances[col_major_i];
            nn_i[row_major_i] = static_cast<int>(knn_res.indices[col_major_i]);
            if (knn_res.indices[col_major_i] > INT_MAX) {
                Rf_error("Neighbor index exceeds maximum supported by C_mstree");
            }
        }
    }

    int iinit = 0;
    double ldist = *std::max_element(nn_d.begin(), nn_d.end()) + 1;
    std::vector<int> edges(2 * n_points_minus_one);
    std::vector<double> edge_lens(n_points_minus_one);

    C_mstree(&iinit, nn_i.data(), nn_d.data(), &ldist, &n_points_int, edges.data(), edge_lens.data());

    return std::accumulate(edge_lens.begin(), edge_lens.end(), 0.0);
}

/**
 * @brief Computes the total length of the minimal spanning tree for a given matrix.
 *
 * This function takes an R matrix as input, converts it to a C++ representation,
 * computes the total length of the minimal spanning tree using the
 * compute_mstree_total_length function, and returns the result as an R numeric value.
 *
 * @param s_X SEXP representing an R matrix. Must be a numeric (double) matrix.
 *
 * @return SEXP A single numeric value representing the total length of the minimal spanning tree.
 *
 * @throws Rf_error If the input is not a valid numeric matrix or if any other Rf_error occurs during computation.
 *
 * @note This function uses Rmatrix_to_cpp for R to C++ conversion and compute_mstree_total_length for MST calculation.
 *
 * Example usage in R:
 * @code
 * result <- .Call("S_compute_mstree_total_length", matrix)
 * @endcode
 */
SEXP S_compute_mstree_total_length(SEXP s_X) {
    // Converting R matrix to C++ vector of vectors
    std::vector<std::vector<double>> X = std::move(*Rmatrix_to_cpp(s_X));
    double total_length = compute_mstree_total_length(X);

    // Allocate and protect result separately to avoid sequence point Rf_warning
    SEXP result = Rf_allocVector(REALSXP, 1);
    PROTECT(result);
    REAL(result)[0] = total_length;
    UNPROTECT(1);

    return result;
}

#if 0
SEXP S_compute_mstree_total_length(SEXP s_X) {

    // Converting R matrix to C++ vector of vectors
    std::vector<std::vector<double>> X = std::move(*Rmatrix_to_cpp(s_X));

    double total_length = compute_mstree_total_length(X);

    SEXP result = PROTECT(result = Rf_allocVector(REALSXP, 1));
    REAL(result)[0] = total_length;
    UNPROTECT(1);

    return result;
}
#endif
