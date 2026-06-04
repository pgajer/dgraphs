#include <vector>
#include <cmath>
#include <algorithm>
#include <numeric>

#include "mst_completion_graphs.hpp"
#include "error_utils.h" // For REPORT_ERROR

#include <vector>
#include <cmath>
#include <algorithm>
#include <numeric>
#include <unordered_set>
#include <limits>
#include "mstree.h"

// Forward declaration of brute-force kNN
void compute_knn_brute_force(
	const std::vector<std::vector<double>>& X,
	std::vector<int>& nn_i,
	std::vector<double>& nn_d
	);

// Helper to compute Euclidean distance
inline double euclidean_dist(
	const std::vector<double>& x1,
	const std::vector<double>& x2
	) {
	double sum = 0.0;
	for (size_t i = 0; i < x1.size(); ++i) {
		double diff = x1[i] - x2[i];
		sum += diff * diff;
	}
	return std::sqrt(sum);
}

// Compute the same linear-interpolation quantile used by R's default type = 7.
static double quantile_type7(std::vector<double> values, double q) {
	if (values.empty()) {
		return std::numeric_limits<double>::quiet_NaN();
	}

	std::sort(values.begin(), values.end());

	if (q <= 0.0) {
		return values.front();
	}
	if (q >= 1.0) {
		return values.back();
	}

	double h = (static_cast<double>(values.size()) - 1.0) * q;
	size_t lower_idx = static_cast<size_t>(std::floor(h));
	size_t upper_idx = static_cast<size_t>(std::ceil(h));
	double fraction = h - std::floor(h);

	if (lower_idx == upper_idx) {
		return values[lower_idx];
	}

	return values[lower_idx] + fraction * (values[upper_idx] - values[lower_idx]);
}

/**
 * @brief Creates a minimal spanning tree (MST) completion from a data matrix
 *
 * @param X Data matrix [n_features][n_samples]
 * @param q_thold Quantile threshold
 * @param verbose Whether to print progress information
 * @return mst_completion_graph_t A struct with four components: mstree, completed_mstree, mstree_edge_weights, and q_thold
 */
mst_completion_graph_t create_mst_completion_graph(
	const std::vector<std::vector<double>>& X,
	double q_thold,
	bool verbose
	) {
	size_t n = X.size();
	if (n == 0 || X[0].empty()) {
		REPORT_ERROR("Input matrix X must be non-empty");
	}

	// Step 1: compute all (n - 1) nearest neighbors (brute-force)
	std::vector<int> nn_i;
	std::vector<double> nn_d;
	compute_knn_brute_force(X, nn_i, nn_d);

	if (verbose) Rprintf("Computed full pairwise distances\n");

	// Step 2: call C_mstree to get MST
	int iinit = 0;
	int n_int = static_cast<int>(n);
	size_t k = n - 1;
	double ldist = *std::max_element(nn_d.begin(), nn_d.end()) + 1;

	std::vector<int> mst_edges_flat(2 * k);
	std::vector<double> edge_lens(k);

	C_mstree(&iinit, nn_i.data(), nn_d.data(), &ldist, &n_int, mst_edges_flat.data(), edge_lens.data());

	if (verbose) Rprintf("MST constructed using C_mstree()\n");

	// Step 3: build set_wgraph_t for mstree
	set_wgraph_t mstree(n);
	for (size_t i = 0; i < k; ++i) {
		int u = mst_edges_flat[2 * i];
		int v = mst_edges_flat[2 * i + 1];
		double w = edge_lens[i];
		mstree.add_edge(u, v, w);
	}

	// Step 4: compute the MST edge-length quantile threshold
	double q_dist = quantile_type7(edge_lens, q_thold);

	if (verbose) Rprintf("Quantile threshold (q=%g): %g\n", q_thold, q_dist);

	// Step 5: build completed MST
	set_wgraph_t completed_mstree = mstree;
	std::unordered_set<size_t> existing_edges;

	for (size_t i = 0; i < k; ++i) {
		int u = mst_edges_flat[2 * i], v = mst_edges_flat[2 * i + 1];
		size_t uid = static_cast<size_t>(std::min(u, v)) * n + std::max(u, v);
		existing_edges.insert(uid);
	}

	for (size_t i = 0; i < n; ++i) {
		for (size_t j = i + 1; j < n; ++j) {
			size_t eid = i * n + j;
			if (existing_edges.count(eid)) continue;

			double dist = euclidean_dist(X[i], X[j]);
			double tol = std::max(1.0, std::abs(q_dist)) * 1e-12;
			if (dist <= q_dist + tol) {
				completed_mstree.add_edge(i, j, dist);
			}
		}
	}

	if (verbose) Rprintf("Completed MST with additional edges\n");

	// Step 6: Return final struct
	mst_completion_graph_t result;
	result.mstree = std::move(mstree);
	result.completed_mstree = std::move(completed_mstree);
	result.mstree_edge_weights = std::move(edge_lens);
	result.q_thold = q_dist;
	return result;
}


/**
 * @brief Computes full (n - 1)-nearest neighbors using brute-force Euclidean distances.
 *Output is sorted by distance and formatted for use with C_mstree.
 *
 * @param X Input data matrix of shape [n_points][n_dims]
 * @param nn_i Output flattened index array of shape [n_points * (n_points - 1)]
 * @param nn_d Output flattened distance array of shape [n_points * (n_points - 1)]
 */
void compute_knn_brute_force(
	const std::vector<std::vector<double>>& X,
	std::vector<int>& nn_i,
	std::vector<double>& nn_d
	) {
	size_t n_points = X.size();
	if (n_points < 2) REPORT_ERROR("Need at least two points.");
	size_t dim = X[0].size();

	size_t k = n_points - 1;
	nn_i.resize(n_points * k);
	nn_d.resize(n_points * k);

	for (size_t i = 0; i < n_points; ++i) {
		std::vector<std::pair<double, int>> dist_index;
		dist_index.reserve(k);
		for (size_t j = 0; j < n_points; ++j) {
			if (i == j) continue;
			double dist2 = 0.0;
			for (size_t d = 0; d < dim; ++d) {
				double diff = X[i][d] - X[j][d];
				dist2 += diff * diff;
			}
			dist_index.emplace_back(std::sqrt(dist2), static_cast<int>(j));
		}

		std::sort(dist_index.begin(), dist_index.end());

		for (size_t j = 0; j < k; ++j) {
			nn_d[i * k + j] = dist_index[j].first;
			nn_i[i * k + j] = dist_index[j].second;
		}
	}
}
