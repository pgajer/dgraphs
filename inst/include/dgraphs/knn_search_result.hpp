#ifndef KNN_SEARCH_RESULT_HPP
#define KNN_SEARCH_RESULT_HPP

#include <cstddef>
#include <vector>

#include <Rinternals.h>

using std::size_t;

// Struct to hold kNN results
struct knn_search_result_t {
	std::vector<std::vector<int>> indices; // [n_points][k]
	std::vector<std::vector<double>> distances; // [n_points][k]
	size_t n_points;
	size_t k;

	knn_search_result_t(size_t n, size_t k_val) : n_points(n), k(k_val) {
		indices.resize(n_points, std::vector<int>(k));
		distances.resize(n_points, std::vector<double>(k));
	}
};

knn_search_result_t compute_knn(SEXP RX, int k);

#endif // KNN_SEARCH_RESULT_HPP
