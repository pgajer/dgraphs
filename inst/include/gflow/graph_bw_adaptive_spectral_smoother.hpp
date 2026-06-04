#ifndef GRAPH_BW_ADAPTIVE_SPECTRAL_SMOOTHER_HPP
#define GRAPH_BW_ADAPTIVE_SPECTRAL_SMOOTHER_HPP

#include <vector>
#include <cstddef>
using std::size_t;

struct graph_bw_adaptive_spectral_smoother_t {
	std::vector<double> predictions;                 ///< predictions[i] is an estimate of E(Y|G) at the i-th vertex at the optimal bandwidth
	std::vector<std::vector<double>> bw_predictions; ///< bw_predictions[bw_idx] are predictions for bandwidth index 'bw_idx'
	std::vector<double> bw_mean_abs_errors;          ///< mean absolute error at each bandwidth index
	std::vector<double> vertex_min_bws;              ///< vertex-wise minimum bandwidth constraint
	size_t opt_bw_idx;                               ///< index of optimal bandwidth
};

#endif // GRAPH_BW_ADAPTIVE_SPECTRAL_SMOOTHER_HPP
