#ifndef LINFINITY_SIMPLEX_KNN_HPP
#define LINFINITY_SIMPLEX_KNN_HPP

#include "knn_search_result.hpp"

#include <Rinternals.h>

knn_search_result_t compute_linf_simplex_knn(SEXP RX, int k, double tol);

#endif // LINFINITY_SIMPLEX_KNN_HPP
