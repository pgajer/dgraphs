#ifndef GRAPH_DEG0_LOWESS_BUFFER_CV_HPP
#define GRAPH_DEG0_LOWESS_BUFFER_CV_HPP

#include <vector>
#include <cstddef>
using std::size_t;

/**
 * @brief Return structure for graph degree 0 LOWESS with cross-validation
 */
struct graph_deg0_lowess_buffer_cv_t {
    std::vector<double> predictions;       ///< predictions[i] is an estimate of E(Y|G) at the i-th vertex
    std::vector<std::vector<double>> bw_predictions; ///< bw_predictions[bw_idx] are predictions for the bandwidth index 'bw_idx'
    std::vector<double> bw_errors;         ///< bw_errors[bw_idx] the prediction error for bw with index bw_idx
    std::vector<double> bws;               ///< bws[i] is the i-th radius/bandwidth
    double opt_bw;                         ///< optimal bandwidth value
    size_t opt_bw_idx;                     ///< the index of opt_bw in bws
    size_t buffer_hops_used;               ///< the number of buffer hops actually used (when in the auto buffer hops mode)
};

#endif // GRAPH_DEG0_LOWESS_BUFFER_CV_HPP
